#!/usr/bin/env bash
# Robust OpenMPI tarball build for ICESEE-Spack (HPC-friendly)
set -euo pipefail

msg(){ echo "[build_openmpi] $*"; }
die(){ echo "[build_openmpi][ERROR] $*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------
# Inputs (env or defaults)
# -----------------------------
OPENMPI_VERSION="${OPENMPI_VERSION:-5.0.7}"
OPENMPI_PREFIX="${OPENMPI_PREFIX:-$ROOT/.icesee-spack/externals/openmpi-${OPENMPI_VERSION}}"
JOBS="${JOBS:-8}"

# Optional: module gcc fallback
MODULE_GCC="${MODULE_GCC:-gcc/13}"

# Optional: if Spack is available, you can ask this script to load a spec:
#   export SPACK_GCC_SPEC="gcc@13.4.0"
SPACK_GCC_SPEC="${SPACK_GCC_SPEC:-}"

# Optional: Slurm/PMIx support
SLURM_DIR="${SLURM_DIR:-}"
PMIX_DIR="${PMIX_DIR:-}"

# Optional: build root preference (we try ROOT/.build first)
ICESEE_BUILD_ROOT="${ICESEE_BUILD_ROOT:-}"
WORKDIR="${WORKDIR:-}"

# Optional: tarball URL
TARBALL_URL="${TARBALL_URL:-https://download.open-mpi.org/release/open-mpi/v${OPENMPI_VERSION%.*}/openmpi-${OPENMPI_VERSION}.tar.bz2}"

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

# -----------------------------
# TLS/CA bundle fix
# -----------------------------
detect_ca_bundle() {
  local candidates=(
    "${SSL_CERT_FILE:-}"
    "${CURL_CA_BUNDLE:-}"
    "/etc/pki/tls/certs/ca-bundle.crt"
    "/etc/ssl/certs/ca-certificates.crt"
    "/etc/ssl/certs/ca-bundle.crt"
    "/etc/ssl/cert.pem"
  )
  for f in "${candidates[@]}"; do
    if [[ -n "$f" && -r "$f" ]]; then
      export SSL_CERT_FILE="$f"
      export CURL_CA_BUNDLE="$f"
      msg "Using CA bundle: $f"
      return 0
    fi
  done
  msg "[WARN] No readable CA bundle found. curl/wget may fail."
  return 1
}
detect_ca_bundle || true

# -----------------------------
# Early exit if already built
# -----------------------------
if [[ -x "${OPENMPI_PREFIX}/bin/mpirun" ]]; then
  msg "OpenMPI already present at ${OPENMPI_PREFIX} (mpirun exists). Skipping build."
  exit 0
fi

# -----------------------------
# Avoid polluted include/library env (common on HPC)
# -----------------------------
# These can cause GCC to pick up random MPI headers, etc.
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH OBJC_INCLUDE_PATH
unset LIBRARY_PATH LD_RUN_PATH
# Keep LD_LIBRARY_PATH (do NOT unset globally), but avoid forcing bad stuff here.

# -----------------------------
# Try loading GCC (module first, then Spack)
# -----------------------------
if have_cmd module; then
  if module -t avail 2>&1 | grep -qx "${MODULE_GCC}"; then
    msg "Loading module ${MODULE_GCC}"
    module load "${MODULE_GCC}"
  else
    msg "Module ${MODULE_GCC} not available (continuing)"
  fi
fi

# If requested, try Spack load (works if spack is already sourced by install.sh)
if [[ -n "${SPACK_GCC_SPEC}" ]]; then
  if have_cmd spack; then
    msg "Loading Spack compiler: ${SPACK_GCC_SPEC}"
    # best-effort; fail if it doesn't exist
    spack load "${SPACK_GCC_SPEC}" || die "Failed to 'spack load ${SPACK_GCC_SPEC}'"
  else
    msg "[WARN] SPACK_GCC_SPEC set but spack not in PATH; skipping spack load"
  fi
fi

# After installing OpenMPI, module purge to avoid conflicts with spack load (if module system is present)
#  purge if we are on a cluster or moudule cmd is available
if have_cmd module; then
  msg "Purging modules to avoid conflicts with Spack environment..."
  module purge
fi

# -----------------------------
# Tool checks
# -----------------------------
for c in gcc g++ gfortran make; do
  have_cmd "$c" || die "Required compiler/build tool not found: $c"
done
if ! have_cmd curl && ! have_cmd wget; then
  die "Need curl or wget to download OpenMPI tarball"
fi
have_cmd tar || die "tar not found"

CC_BIN="${CC_BIN:-$(command -v gcc)}"
CXX_BIN="${CXX_BIN:-$(command -v g++)}"
FC_BIN="${FC_BIN:-$(command -v gfortran)}"

msg "Using compilers:"
msg "  CC  = ${CC_BIN} ($(${CC_BIN} --version | head -n1))"
msg "  CXX = ${CXX_BIN} ($(${CXX_BIN} --version | head -n1))"
msg "  FC  = ${FC_BIN} ($(${FC_BIN} --version | head -n1))"

# -----------------------------
# HARD sanity check: can gcc compile system headers?
# This catches your current failure (stddef.h missing) immediately.
# -----------------------------
hdr_tmp="$(mktemp -d)"
cat > "${hdr_tmp}/hdrcheck.c" <<'EOF'
#include <stdio.h>
int main(){ puts("ok"); return 0; }
EOF
if ! "${CC_BIN}" "${hdr_tmp}/hdrcheck.c" -o "${hdr_tmp}/hdrcheck.bin" >/dev/null 2>&1; then
  msg "GCC header check failed. Dumping verbose output:"
  "${CC_BIN}" -v "${hdr_tmp}/hdrcheck.c" -o "${hdr_tmp}/hdrcheck.bin" || true
  rm -rf "${hdr_tmp}"
  die "Your gcc cannot compile a basic <stdio.h> program. This usually means a broken GCC install (e.g., empty include-fixed / missing stddef.h). Reinstall GCC or load a working module compiler."
fi
rm -rf "${hdr_tmp}"
msg "GCC header check OK."

# -----------------------------
# Detect Slurm/PMIx if not set
# -----------------------------
if [[ -z "${SLURM_DIR}" ]] && [[ -d "/opt/slurm/current" ]]; then
  SLURM_DIR="/opt/slurm/current"
fi

if [[ -z "${PMIX_DIR}" ]]; then
  for p in /opt/pmix/5.0.1 /opt/pmix/4.2.6 /opt/pmix /usr /usr/local; do
    if [[ -d "${p}" ]] && ( [[ -e "${p}/include/pmix.h" ]] || [[ -d "${p}/include/pmix" ]] ); then
      PMIX_DIR="${p}"
      break
    fi
  done
fi

# -----------------------------
# Choose build directory (prefer inside ICESEE-Spack/.build, fallback to /tmp if noexec)
# -----------------------------
if [[ -z "${WORKDIR}" ]]; then
  if [[ -n "${ICESEE_BUILD_ROOT}" ]]; then
    WORKDIR="${ICESEE_BUILD_ROOT}/openmpi-${OPENMPI_VERSION}"
  else
    WORKDIR="${ROOT}/.build/openmpi-${OPENMPI_VERSION}"
  fi
fi

try_workdir_exec() {
  local d="$1"
  mkdir -p "$d"
  cat > "$d/.__exec_test.c" <<'EOF'
int main(){return 0;}
EOF
  if ! "${CC_BIN}" "$d/.__exec_test.c" -o "$d/.__exec_test.bin" >/dev/null 2>&1; then
    rm -f "$d/.__exec_test.c" "$d/.__exec_test.bin"
    return 1
  fi
  if ! "$d/.__exec_test.bin" >/dev/null 2>&1; then
    rm -f "$d/.__exec_test.c" "$d/.__exec_test.bin"
    return 2
  fi
  rm -f "$d/.__exec_test.c" "$d/.__exec_test.bin"
  return 0
}

msg "Validating build dir executable: ${WORKDIR}"
if ! try_workdir_exec "${WORKDIR}"; then
  msg "[WARN] Build dir not usable/executable: ${WORKDIR}"
  fallback="/tmp/${USER}/icesee-build/openmpi-${OPENMPI_VERSION}"
  msg "Falling back to: ${fallback}"
  try_workdir_exec "${fallback}" || die "Fallback build dir also not usable: ${fallback}"
  WORKDIR="${fallback}"
fi
msg "Using WORKDIR: ${WORKDIR}"

mkdir -p "${OPENMPI_PREFIX}"

# -----------------------------
# Download + extract
# -----------------------------
tarball="${WORKDIR}/openmpi-${OPENMPI_VERSION}.tar.bz2"
srcdir="${WORKDIR}/openmpi-${OPENMPI_VERSION}"

msg "Downloading OpenMPI ${OPENMPI_VERSION}"
if [[ ! -f "${tarball}" ]]; then
  if have_cmd curl; then
    if [[ -n "${CURL_CA_BUNDLE:-}" && -r "${CURL_CA_BUNDLE}" ]]; then
      curl -fsSL --cacert "${CURL_CA_BUNDLE}" -o "${tarball}" "${TARBALL_URL}"
    else
      curl -fsSL -o "${tarball}" "${TARBALL_URL}"
    fi
  else
    if [[ -n "${SSL_CERT_FILE:-}" && -r "${SSL_CERT_FILE}" ]]; then
      wget --ca-certificate="${SSL_CERT_FILE}" -O "${tarball}" "${TARBALL_URL}"
    else
      wget -O "${tarball}" "${TARBALL_URL}"
    fi
  fi
fi

msg "Extracting..."
rm -rf "${srcdir}"
tar -xjf "${tarball}" -C "${WORKDIR}"
cd "${srcdir}"

# -----------------------------
# Configure flags
# -----------------------------
cfg=(
  "--prefix=${OPENMPI_PREFIX}"
  "--with-libevent"
  "--with-hwloc"
  "--with-ucx"
  "--enable-mpi1-compatibility"
  "CC=${CC_BIN}"
  "CXX=${CXX_BIN}"
  "FC=${FC_BIN}"
)

if [[ -n "${SLURM_DIR}" ]] && [[ -d "${SLURM_DIR}" ]]; then
  cfg+=("--with-slurm=${SLURM_DIR}")
else
  msg "SLURM_DIR not set/found -> building without Slurm support"
fi

if [[ -n "${PMIX_DIR}" ]] && [[ -d "${PMIX_DIR}" ]]; then
  cfg+=("--with-pmix=${PMIX_DIR}")
else
  msg "PMIX_DIR not set/found -> building without PMIx support"
fi

msg "Configuring..."
./configure "${cfg[@]}"

msg "Building (-j ${JOBS})..."
make -j "${JOBS}"

msg "Installing..."
make install

msg "OpenMPI installed to: ${OPENMPI_PREFIX}"
msg "mpirun: ${OPENMPI_PREFIX}/bin/mpirun"