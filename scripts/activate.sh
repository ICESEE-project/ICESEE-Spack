#!/usr/bin/env bash
# Copyright (c) 2026 Brian Kyanjo

# --- BEGIN: do not leak strict mode into interactive shells ---
__ICESEE_OLD_SET_OPTS="$(set +o)"
# --- END ---

info(){ echo "[ICESEE-Spack] $*"; }
warn(){ echo "[ICESEE-Spack][WARN] $*" >&2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT}/.spack-env/icesee"

OPENMPI_VERSION="${OPENMPI_VERSION:-5.0.7}"
ICESEE_EXTERNALS_ROOT="${ICESEE_EXTERNALS_ROOT:-$ROOT/.icesee-spack/externals}"
OPENMPI_PREFIX="${OPENMPI_PREFIX:-$ICESEE_EXTERNALS_ROOT/openmpi-${OPENMPI_VERSION}}"

ISSM_DIR_DEFAULT="${ISSM_DIR:-$ICESEE_EXTERNALS_ROOT/ISSM}"
MODULE_MATLAB="${MODULE_MATLAB:-matlab}"

info "Activating environment..."
info "  ROOT: ${ROOT}"
info "  ENV : ${ENV_DIR}"

SPACK_ROOT="${ROOT}/spack"
SPACK_EXE="${SPACK_ROOT}/bin/spack"

[[ -x "${SPACK_EXE}" ]] || { warn "Pinned Spack not found/executable: ${SPACK_EXE}"; return 1 2>/dev/null || exit 1; }
[[ -d "${ENV_DIR}" ]]   || { warn "Env dir not found: ${ENV_DIR}";           return 2 2>/dev/null || exit 2; }


# Ensure spack's own runtime env vars are set
if [[ -f "${SPACK_ROOT}/share/spack/setup-env.sh" ]]; then
  # shellcheck disable=SC1090
  source "${SPACK_ROOT}/share/spack/setup-env.sh"
fi

# Make sure THIS spack is on PATH so user can type `spack`
export PATH="${SPACK_ROOT}/bin:${PATH}"
# hash -r 2>/dev/null || true

info "Activating Spack env by directory: ${ENV_DIR}"
eval "$("${SPACK_EXE}" env activate --sh -d "${ENV_DIR}")"

# Helper uses pinned spack + exact env dir
sp() { "${SPACK_EXE}" -e "${ENV_DIR}" "$@"; }

load_if_present () {
  local spec="$1"
  if sp find -q "${spec}" >/dev/null 2>&1; then
    eval "$(sp load --sh "${spec}")"
    info "Loaded: ${spec}"
    return 0
  fi
  warn "Not installed in env (skipping load): ${spec}"
  return 1
}

# Optional MATLAB module (safe before/after; keep here)
if command -v module >/dev/null 2>&1; then
  if module -t avail 2>&1 | grep -qx "${MODULE_MATLAB}"; then
    module load "${MODULE_MATLAB}" || warn "Failed to load MATLAB module: ${MODULE_MATLAB}"
  else
    warn "MATLAB module not available (continuing)."
    module load matlab
  fi
else
  warn "Modules system not available (cannot load MATLAB module)."
fi

# Export ISSM_DIR and source ISSM env (if present)
# NOTE: ISSM env often mutates PATH and can shadow Spack Python.
if [[ -d "${ISSM_DIR_DEFAULT}" ]]; then
  export ISSM_DIR="${ISSM_DIR_DEFAULT}"
  if [[ -f "${ISSM_DIR}/etc/environment.sh" ]]; then
    info "Sourcing ISSM environment: ${ISSM_DIR}/etc/environment.sh"
    set +u
    # shellcheck disable=SC1090
    source "${ISSM_DIR}/etc/environment.sh"
    set -u
  fi
fi

# Load packages into shell (only if installed in this env)
load_if_present () {
  local spec="$1"
  if "${SPACK_EXE}" -e "${ENV_DIR}" find -q "${spec}" >/dev/null 2>&1; then
    eval "$("${SPACK_EXE}" -e "${ENV_DIR}" load --sh "${spec}")"
    info "Loaded: ${spec}"
    return 0
  fi
  warn "Not installed in env (skipping load): ${spec}"
  return 1
}

try_load () {
  local spec="$1"
  if eval "$("${SPACK_EXE}" -e "${ENV_DIR}" load --sh "${spec}" 2>/dev/null)"; then
    info "Loaded: ${spec}"
    return 0
  fi
  warn "Could not load (not installed in env?): ${spec}"
  return 1
}
info "PYTHONPATH: ${PYTHONPATH:-<empty>}"

# Core python stack (loads set PYTHONPATH etc.)
# for s in python python-venv py-pip py-setuptools py-wheel py-numpy py-h5py py-icesee; do
#   # load_if_present "${s}" || true
#   try_load "${s}" || true
# done
spack load py-pip py-setuptools py-wheel py-pkgconfig py-numpy py-h5py py-icesee py-cython py-petsc4py || warn "Failed to load some core python packages (continuing)"

# Load only installed py-* packages from the environment (generic)
# for spec in $("${SPACK_EXE}" -e "${ENV_DIR}" find --format "{name}" 2>/dev/null); do
#   if [[ "${spec}" == py-* ]]; then
#     try_load "${spec}" || true
#   fi
# done

# Hard-pin python to the Spack python install prefix (extra robust)
SPACK_PY_PREFIX="$("${SPACK_EXE}" -e "${ENV_DIR}" location -i python 2>/dev/null || true)"
if [[ -n "${SPACK_PY_PREFIX}" && -x "${SPACK_PY_PREFIX}/bin/python" ]]; then
  export PATH="${SPACK_PY_PREFIX}/bin:${PATH}"
  # hash -r 2>/dev/null || true
fi

# Force our external OpenMPI to win (ISSM/PETSc sometimes inject their mpirun first)
if [[ -d "${OPENMPI_PREFIX}" ]]; then
  export PATH="${OPENMPI_PREFIX}/bin:${PATH}"
  export LD_LIBRARY_PATH="${OPENMPI_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
else
  warn "External OpenMPI not found: ${OPENMPI_PREFIX}"
fi

# force spack mpi to use our OpenMPI (if present)
module purge 2>/dev/null || true
module load matlab || true 
MPI_DIR="$(spack -e "${ENV_DIR}" location -i openmpi)"
export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${LD_LIBRARY_PATH:-}"

# Ensure MATLAB uses GCC13 libstdc++ (fix mex GLIBCXX_3.4.31)
if command -v spack >/dev/null 2>&1; then
  GCC_PREFIX="$(spack -e "$ROOT/.spack-env/icesee" location -i gcc@13 2>/dev/null || true)"
  if [[ -n "$GCC_PREFIX" ]]; then
    PRELOAD="$GCC_PREFIX/lib64/libstdc++.so.6"
    [[ -f "$PRELOAD" ]] || PRELOAD="$GCC_PREFIX/lib/libstdc++.so.6"
    if [[ -f "$PRELOAD" ]]; then
      export LD_PRELOAD="${PRELOAD}${LD_PRELOAD:+:$LD_PRELOAD}"
    fi
  fi
fi

# DEV: allow importing the in-repo ICESEE package (repo root contains ICESEE/)
export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"
export OMP_NUM_THREADS=1

info "Activated env at: ${ENV_DIR}"
echo "  spack   : ${SPACK_EXE}"
echo "  python  : $(command -v python || true)"
echo "  pythonV : $(python --version 2>/dev/null || true)"
echo "  pip     : $(python -m pip --version 2>/dev/null || true)"
echo "  mpirun  : $(command -v mpirun || true)"
echo "  mpicc   : $(command -v mpicc || true)"
echo "  matlab  : $(command -v matlab || true)"
echo "  ISSM_DIR: ${ISSM_DIR:-}"

# --- BEGIN: restore caller shell options ---
eval "${__ICESEE_OLD_SET_OPTS}"
unset __ICESEE_OLD_SET_OPTS
# --- END ---