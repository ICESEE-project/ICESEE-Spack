#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# build_issm.sh — Generic ISSM installer for HPC (Slurm) with MATLAB
#
# Installs ISSM from source into a chosen prefix, builds externalpackages,
# configures MATLAB interface, and installs. Designed to be called from
# ICESEE-Spack/scripts/install.sh.
#
# Usage:
#   ./scripts/build_issm.sh
#
# Env vars (optional):
#   OPENMPI_PREFIX      REQUIRED. Prefix to OpenMPI (passed from install.sh)
#
#   ISSM_PREFIX         Where to install ISSM (default: $ICESEE_EXTERNALS_ROOT/ISSM)
#   ICESEE_EXTERNALS_ROOT Root for externals (default: $HOME/.icesee-spack/externals)
#   ISSM_BRANCH         Git branch/tag (default: main)
#   ISSM_REPO           Git repo URL (default: https://github.com/ISSMteam/ISSM.git)
#   ISSM_CLEAN          If "1", delete existing ISSM_PREFIX before install (default: 0)
#
#   MODULE_GCC          Module name for GCC (default: gcc/13)
#   MODULE_MATLAB       Module name for MATLAB (default: matlab)
#   MATLABROOT          MATLAB root (must be set after module load on many clusters)
#
#   ISSM_NUMTHREADS     --with-numthreads (default: 4)
#   MAKE_JOBS           make -j (default: nproc)
#
#   BUILD_AUTOTOOLS      Build ISSM autotools externalpackage if missing (default: 1)
#   BUILD_PETSC          Build PETSc externalpackage if missing (default: 1)
#   PETSC_INSTALL_SCRIPT Which PETSc install script to run (default: install-3.22-linux.sh)
#   BUILD_TRIANGLE       Build triangle externalpackage if missing (default: 1)
#   BUILD_M1QN3          Build m1qn3 externalpackage if missing (default: 1)
#
#   CA_BUNDLE            CA file for curl/wget (auto-detected if unset)
#
# Notes:
# - We avoid hardcoding GCC lib paths. We locate libgfortran via gfortran.
# - We avoid hardcoding MPI link flags (mpich vs openmpi). We derive link flags
#   from mpicc --showme:link when available, else fall back to -L$OPENMPI_PREFIX/lib -lmpi.
# -----------------------------------------------------------------------------
set -euo pipefail

log(){ echo "[build_issm] $*"; }
die(){ echo "[build_issm][ERROR] $*" >&2; exit 1; }

# ------------------------
# Required inputs
# ------------------------
OPENMPI_PREFIX="${OPENMPI_PREFIX:?OPENMPI_PREFIX not set (export from install.sh)}"

# Put OpenMPI first
export PATH="${OPENMPI_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${OPENMPI_PREFIX}/lib:${LD_LIBRARY_PATH:-}"

# ------------------------
# Defaults
# ------------------------
ISSM_REPO="${ISSM_REPO:-https://github.com/ISSMteam/ISSM.git}"
ISSM_BRANCH="${ISSM_BRANCH:-main}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICESEE_EXTERNALS_ROOT="${ICESEE_EXTERNALS_ROOT:-$ROOT/.icesee-spack/externals}"
ISSM_PREFIX="${ISSM_PREFIX:-$ICESEE_EXTERNALS_ROOT/ISSM}"
ISSM_CLEAN="${ISSM_CLEAN:-0}"

# Ensure ISSM_DIR is set for ISSM internal scripts
export ISSM_DIR="${ISSM_PREFIX}"

MODULE_GCC="${MODULE_GCC:-gcc/13}"
MODULE_MATLAB="${MODULE_MATLAB:-matlab}"

ISSM_NUMTHREADS="${ISSM_NUMTHREADS:-4}"
MAKE_JOBS="${MAKE_JOBS:-$(nproc 2>/dev/null || echo 8)}"

BUILD_AUTOTOOLS="${BUILD_AUTOTOOLS:-1}"
BUILD_PETSC="${BUILD_PETSC:-1}"
PETSC_INSTALL_SCRIPT="${PETSC_INSTALL_SCRIPT:-install-3.22-linux.sh}"
BUILD_TRIANGLE="${BUILD_TRIANGLE:-1}"
BUILD_M1QN3="${BUILD_M1QN3:-1}"

# Slurm cluster config download (your ICESEE copy)
ICESEE_GENERIC_CLUSTER_URL="${ICESEE_GENERIC_CLUSTER_URL:-https://raw.githubusercontent.com/ICESEE-project/ICESEE/refs/heads/develop/applications/issm_model/issm_utils/slurm_cluster/generic_cluster.m}"

# CA bundle detection (helps on clusters where curl/wget default CA path differs)
if [[ -z "${CA_BUNDLE:-}" ]]; then
  for f in /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt; do
    [[ -f "$f" ]] && CA_BUNDLE="$f" && break
  done
fi
CA_BUNDLE="${CA_BUNDLE:-}"

# ------------------------
# Modules
# ------------------------
if command -v module >/dev/null 2>&1; then
  # Make sure module function is initialized in non-interactive shells
  # shellcheck disable=SC1091
  source /etc/profile.d/modules.sh 2>/dev/null || true

  log "Sanitizing module environment (module purge)..."
  module purge || true

  # GCC
  if module -t avail 2>&1 | grep -qx "${MODULE_GCC}"; then
    log "Loading module ${MODULE_GCC}"
    module load "${MODULE_GCC}" || log "WARNING: module load ${MODULE_GCC} failed (continuing)"
  else
    log "Module ${MODULE_GCC} not available (continuing)"
  fi

  # MATLAB (robust)
  matlab_loaded=0

  # 1) Try configured name if listed
  if module -t avail 2>&1 | grep -qx "${MODULE_MATLAB}"; then
    log "Loading module ${MODULE_MATLAB}"
    module load "${MODULE_MATLAB}" && matlab_loaded=1 || true
  else
    log "Module ${MODULE_MATLAB} not listed by 'module avail'"
  fi

  # 2) Fallback: try generic "matlab" regardless of listing
  if [[ "${matlab_loaded}" -eq 0 ]]; then
    log "Trying fallback: module load matlab"
    module load matlab && matlab_loaded=1 || true
  fi

  # 3) Optional: if still not loaded, show a hint
  if [[ "${matlab_loaded}" -eq 0 ]]; then
    log "WARNING: Could not load MATLAB via modules (${MODULE_MATLAB} or matlab)."
  fi
else
  log "No module command found; relying on environment PATH"
fi

# ------------------------
# Validate toolchain + MATLAB
# ------------------------
command -v gcc >/dev/null 2>&1 || die "gcc not found"
command -v g++ >/dev/null 2>&1 || die "g++ not found"
command -v gfortran >/dev/null 2>&1 || die "gfortran not found"
command -v git >/dev/null 2>&1 || die "git not found"
command -v make >/dev/null 2>&1 || die "make not found"

# Force libstdc++ from the active g++ (prevents picking gcc/12 libstdc++ by accident)
GXX_BIN="$(command -v g++)"
LIBSTDCXX_SO="$("$GXX_BIN" -print-file-name=libstdc++.so)"
GCC_LIBDIR="$(cd "$(dirname "$LIBSTDCXX_SO")" && pwd)"

export LD_LIBRARY_PATH="${GCC_LIBDIR}:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="${GCC_LIBDIR}:${LIBRARY_PATH:-}"
export LDFLAGS="${LDFLAGS:-} -Wl,-rpath,${GCC_LIBDIR}"

log "Pinned GCC lib dir: ${GCC_LIBDIR}"

# autoreconf may be provided by ISSM autotools externalpackage; we'll check later as needed.

# MATLABROOT must exist for --with-matlab-dir
if [[ -z "${MATLABROOT:-}" ]]; then
  if command -v matlab >/dev/null 2>&1; then
    matlab_bin="$(command -v matlab)"
    MATLABROOT_GUESS="$(cd "$(dirname "$matlab_bin")/.." && pwd)"
    if [[ -d "$MATLABROOT_GUESS" ]]; then
      MATLABROOT="$MATLABROOT_GUESS"
      export MATLABROOT
      log "Inferred MATLABROOT=${MATLABROOT}"
    fi
  fi
fi
[[ -n "${MATLABROOT:-}" && -d "${MATLABROOT}" ]] || die "MATLABROOT is not set or invalid. Load a matlab module or export MATLABROOT."

# Find libgfortran directory in a portable way
GFORTRAN_LIBDIR="$(dirname "$(gfortran -print-file-name=libgfortran.so)")"
[[ -d "$GFORTRAN_LIBDIR" ]] || die "Could not determine gfortran lib directory"
FORTRAN_LIBFLAGS="-L${GFORTRAN_LIBDIR} -lgfortran"

# Derive MPI link flags robustly (OpenMPI vs MPICH differences)
MPI_LDFLAGS=""
if command -v mpicc >/dev/null 2>&1; then
  # OpenMPI provides --showme:link
  MPI_LDFLAGS="$(mpicc --showme:link 2>/dev/null || true)"
fi
if [[ -z "${MPI_LDFLAGS}" ]]; then
  MPI_LDFLAGS="-L${OPENMPI_PREFIX}/lib -lmpi"
fi

log "ISSM_PREFIX: ${ISSM_PREFIX}"
log "Using MATLABROOT: ${MATLABROOT}"
log "Using gfortran libdir: ${GFORTRAN_LIBDIR}"
log "OPENMPI_PREFIX: ${OPENMPI_PREFIX}"
log "MPI_LDFLAGS: ${MPI_LDFLAGS}"
log "MAKE_JOBS: ${MAKE_JOBS}"

# ------------------------
# Clean existing install (optional)
# ------------------------
if [[ -d "${ISSM_PREFIX}" && "${ISSM_CLEAN}" == "1" ]]; then
  log "Removing existing ISSM at ${ISSM_PREFIX} (ISSM_CLEAN=1)"
  rm -rf "${ISSM_PREFIX}"
fi

mkdir -p "${ISSM_PREFIX}"

# Clone into prefix (or reuse existing clone)
if [[ ! -d "${ISSM_PREFIX}/.git" ]]; then
  log "Cloning ISSM into ${ISSM_PREFIX}"
  git clone --branch "${ISSM_BRANCH}" --depth 1 "${ISSM_REPO}" "${ISSM_PREFIX}"
else
  log "ISSM repo already present at ${ISSM_PREFIX}; updating"
  git -C "${ISSM_PREFIX}" fetch --all --tags || true
  git -C "${ISSM_PREFIX}" checkout "${ISSM_BRANCH}" || true
  git -C "${ISSM_PREFIX}" pull || true
fi

cd "${ISSM_PREFIX}"

# add spack gcc to path for first selection
# export PATH="$(spack location -i gcc)/bin:${PATH}"
# module purge || true
# # module unload mvapich2 || true
# module load matlab || true

# ------------------------
# Build external packages (idempotent)
# ------------------------
AUTOTOOLS_PREFIX="${ISSM_PREFIX}/externalpackages/autotools/install"
PETSC_DIR="${ISSM_PREFIX}/externalpackages/petsc/install"
TRIANGLE_DIR="${ISSM_PREFIX}/externalpackages/triangle/install"
M1QN3_DIR="${ISSM_PREFIX}/externalpackages/m1qn3/install"

if [[ "${BUILD_AUTOTOOLS}" == "1" ]]; then
  if [[ -x "${AUTOTOOLS_PREFIX}/bin/autoreconf" || -x "${AUTOTOOLS_PREFIX}/bin/autoconf" ]]; then
    log "autotools already installed at ${AUTOTOOLS_PREFIX} (skipping)"
  else
    log "Installing ISSM externalpackages/autotools..."
    cd "${ISSM_PREFIX}/externalpackages/autotools"

    ./install-linux.sh
  fi
fi

# Prefer ISSM-provided autoreconf if present, else system
if [[ -x "${AUTOTOOLS_PREFIX}/bin/autoreconf" ]]; then
  export PATH="${AUTOTOOLS_PREFIX}/bin:${PATH}"
fi
command -v autoreconf >/dev/null 2>&1 || die "autoreconf not found (install ISSM autotools externalpackage or load autotools)"

if [[ "${BUILD_PETSC}" == "1" ]]; then
  if [[ -d "${PETSC_DIR}/include" && -d "${PETSC_DIR}/lib" ]]; then
    log "PETSc already installed at ${PETSC_DIR} (skipping)"
  else
    log "Installing PETSc via ${PETSC_INSTALL_SCRIPT}..."
    cd "${ISSM_PREFIX}/externalpackages/petsc"
    [[ -x "./${PETSC_INSTALL_SCRIPT}" ]] || die "PETSc script not found/executable: ${ISSM_PREFIX}/externalpackages/petsc/${PETSC_INSTALL_SCRIPT}"
    "./${PETSC_INSTALL_SCRIPT}"
  fi
fi

if [[ "${BUILD_TRIANGLE}" == "1" ]]; then
  if [[ -d "${TRIANGLE_DIR}" ]]; then
    log "triangle already installed at ${TRIANGLE_DIR} (skipping)"
  else
    log "Installing triangle..."
    cd "${ISSM_PREFIX}/externalpackages/triangle"
    ./install-linux.sh
  fi
fi

if [[ "${BUILD_M1QN3}" == "1" ]]; then
  if [[ -d "${M1QN3_DIR}" ]]; then
    log "m1qn3 already installed at ${M1QN3_DIR} (skipping)"
  else
    log "Installing m1qn3..."
    cd "${ISSM_PREFIX}/externalpackages/m1qn3"
    ./install-linux.sh
  fi
fi

# Source ISSM environment after package installation (nounset-safe)
log "Sourcing ISSM environment..."
# shellcheck disable=SC1090
set +u
. "${ISSM_PREFIX}/etc/environment.sh"
set -u

# Recompute install dirs after env (harmless)
PETSC_DIR="${ISSM_PREFIX}/externalpackages/petsc/install"
TRIANGLE_DIR="${ISSM_PREFIX}/externalpackages/triangle/install"
M1QN3_DIR="${ISSM_PREFIX}/externalpackages/m1qn3/install"

# Stronger checks: require include+lib for PETSc, and install dirs for others
[[ -d "${PETSC_DIR}/include" && -d "${PETSC_DIR}/lib" ]] || die "PETSc install incomplete at ${PETSC_DIR} (missing include/ or lib/)"
[[ -d "${TRIANGLE_DIR}" ]] || die "triangle install not found at ${TRIANGLE_DIR}"
[[ -d "${M1QN3_DIR}" ]] || die "m1qn3 install not found at ${M1QN3_DIR}"

# ------------------------
# Configure + build ISSM
# ------------------------
log "Running autoreconf..."
cd "${ISSM_PREFIX}"
autoreconf -ivf

log "Configuring ISSM..."
# MPI include: use OpenMPI include dir, not PETSc include
MPI_INCLUDE_DIR="${OPENMPI_PREFIX}/include"
[[ -d "${MPI_INCLUDE_DIR}" ]] || die "MPI include dir not found: ${MPI_INCLUDE_DIR}"

./configure \
  --prefix="${ISSM_PREFIX}" \
  --with-matlab-dir="${MATLABROOT}" \
  --with-fortran-lib="${FORTRAN_LIBFLAGS}" \
  --with-mpi-include="${MPI_INCLUDE_DIR}" \
  --with-mpi-libflags="${MPI_LDFLAGS}" \
  --with-triangle-dir="${TRIANGLE_DIR}" \
  --with-petsc-dir="${PETSC_DIR}" \
  --with-metis-dir="${PETSC_DIR}" \
  --with-parmetis-dir="${PETSC_DIR}" \
  --with-blas-lapack-dir="${PETSC_DIR}" \
  --with-scalapack-dir="${PETSC_DIR}" \
  --with-mumps-dir="${PETSC_DIR}" \
  --with-m1qn3-dir="${M1QN3_DIR}" \
  --with-numthreads="${ISSM_NUMTHREADS}"

log "Building ISSM..."
make -j"${MAKE_JOBS}"

log "Installing ISSM..."
make install

# ------------------------
# Install Slurm cluster class (generic.m)
# ------------------------
TARGET_CLUSTER_FILE="${ISSM_PREFIX}/src/m/classes/clusters/generic.m"
mkdir -p "$(dirname "${TARGET_CLUSTER_FILE}")"

log "Downloading ISSM cluster config -> ${TARGET_CLUSTER_FILE}"
if command -v curl >/dev/null 2>&1; then
  if [[ -n "${CA_BUNDLE}" && -f "${CA_BUNDLE}" ]]; then
    curl -fsSL --cacert "${CA_BUNDLE}" -o "${TARGET_CLUSTER_FILE}" "${ICESEE_GENERIC_CLUSTER_URL}"
  else
    curl -fsSL -o "${TARGET_CLUSTER_FILE}" "${ICESEE_GENERIC_CLUSTER_URL}"
  fi
elif command -v wget >/dev/null 2>&1; then
  if [[ -n "${CA_BUNDLE}" && -f "${CA_BUNDLE}" ]]; then
    wget --ca-certificate="${CA_BUNDLE}" -O "${TARGET_CLUSTER_FILE}" "${ICESEE_GENERIC_CLUSTER_URL}"
  else
    wget -O "${TARGET_CLUSTER_FILE}" "${ICESEE_GENERIC_CLUSTER_URL}"
  fi
else
  die "Neither curl nor wget found to download cluster config"
fi

log "ISSM install complete: ${ISSM_PREFIX}"
log "To use ISSM in this shell:"
log "  source ${ISSM_PREFIX}/etc/environment.sh"