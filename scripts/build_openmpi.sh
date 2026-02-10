#!/usr/bin/env bash
# Generic OpenMPI build script (tarball build)
# Called by scripts/install.sh
set -euo pipefail

msg(){ echo "[build_openmpi] $*"; }
die(){ echo "[build_openmpi][ERROR] $*" >&2; exit 1; }

# -----------------------------
# Inputs (env or defaults)
# -----------------------------
OPENMPI_VERSION="${OPENMPI_VERSION:-5.0.7}"
OPENMPI_PREFIX="${OPENMPI_PREFIX:-$HOME/.icesee-spack/externals/openmpi-${OPENMPI_VERSION}}"
JOBS="${JOBS:-8}"

# Optional: use modules (if available)
MODULE_GCC="${MODULE_GCC:-gcc/13}"

# Optional: Slurm/PMIx support (if available)
SLURM_DIR="${SLURM_DIR:-}"
PMIX_DIR="${PMIX_DIR:-}"

# --- TLS/CA bundle fix for HPC/RHEL ---
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
      echo "[build_openmpi] Using CA bundle: $f"
      return 0
    fi
  done
  echo "[build_openmpi][WARN] No readable CA bundle found. curl may fail."
  return 1
}

detect_ca_bundle || true

# Optional: download behavior
WORKDIR="${WORKDIR:-$PWD/.build/openmpi-${OPENMPI_VERSION}}"
TARBALL_URL="${TARBALL_URL:-https://download.open-mpi.org/release/open-mpi/v${OPENMPI_VERSION%.*}/openmpi-${OPENMPI_VERSION}.tar.bz2}"

# -----------------------------
# Early exit if already built
# -----------------------------
if [[ -x "${OPENMPI_PREFIX}/bin/mpirun" ]]; then
  msg "OpenMPI already present at ${OPENMPI_PREFIX} (mpirun exists). Skipping build."
  exit 0
fi

# -----------------------------
# Tool checks
# -----------------------------
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

# Try loading gcc module if available (non-fatal)
if have_cmd module; then
  if module -t avail 2>&1 | grep -qx "${MODULE_GCC}"; then
    msg "Loading module ${MODULE_GCC}"
    module load "${MODULE_GCC}"
  else
    msg "Module ${MODULE_GCC} not available (continuing)"
  fi
fi

for c in gcc g++ gfortran make; do
  have_cmd "$c" || die "Required compiler/build tool not found: $c"
done

# Fetch tools
if ! have_cmd curl && ! have_cmd wget; then
  die "Need curl or wget to download OpenMPI tarball"
fi
have_cmd tar || die "tar not found"

# -----------------------------
# Detect Slurm/PMIx if not set
# -----------------------------
if [[ -z "${SLURM_DIR}" ]] && [[ -d "/opt/slurm/current" ]]; then
  SLURM_DIR="/opt/slurm/current"
fi

if [[ -z "${PMIX_DIR}" ]]; then
  for p in /opt/pmix/5.0.1 /opt/pmix /usr /usr/local; do
    if [[ -d "${p}" ]] && ( [[ -e "${p}/include/pmix.h" ]] || [[ -d "${p}/include/pmix" ]] ); then
      PMIX_DIR="${p}"
      break
    fi
  done
fi

# -----------------------------
# Prepare working directory
# -----------------------------
mkdir -p "${WORKDIR}"
mkdir -p "${OPENMPI_PREFIX}"

tarball="${WORKDIR}/openmpi-${OPENMPI_VERSION}.tar.bz2"
srcdir="${WORKDIR}/openmpi-${OPENMPI_VERSION}"

msg "Downloading OpenMPI ${OPENMPI_VERSION}"
if [[ ! -f "${tarball}" ]]; then
  if have_cmd curl; then
    curl -L -o "${tarball}" "${TARBALL_URL}"
  else
    wget -O "${tarball}" "${TARBALL_URL}"
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
  "CC=gcc"
  "CXX=g++"
  "FC=gfortran"
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