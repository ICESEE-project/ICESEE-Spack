#!/usr/bin/env bash
# Copyright (c) 2026 Brian Kyanjo
set -euo pipefail

PIP_ONLY=0
WITH_ISSM=0
WITH_FIREDRAKE=0
WITH_ICEPACK=0
for arg in "$@"; do
  [[ "$arg" == "--pip-only"  ]] && PIP_ONLY=1
  [[ "$arg" == "--with-issm" ]] && WITH_ISSM=1
  [[ "$arg" == "--with-firedrake" ]] && WITH_FIREDRAKE=1
  # with icepack (installs firedrake deps + icepack itself)
  [[ "$arg" == "--with-icepack" ]] && WITH_ICEPACK=1 && WITH_FIREDRAKE=1
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT}/.spack-env/icesee"

CUSTOM_REPO_REL="${ROOT}/icesee-spack"
CUSTOM_REPO="$(cd "${CUSTOM_REPO_REL}" && pwd)"   # ABSOLUTE path (fixes ./icesee-spack issues)

ICESEE_SUBMODULE="${ROOT}/ICESEE"
#if [[ -n "${SLURM_CPUS_PER_TASK:-}" ]]; then
#  JOBS="${JOBS:-$SLURM_CPUS_PER_TASK}"
#elif [[ -n "${SLURM_JOB_CPUS_PER_NODE:-}" ]]; then
#  JOBS="${JOBS:-$(echo "$SLURM_JOB_CPUS_PER_NODE" | cut -d'(' -f1)}"
#else
#  JOBS="${JOBS:-$(nproc)}"
#fi
JOBS=24

SETUPTOOLS_CONSTRAINT="${SETUPTOOLS_CONSTRAINT:-setuptools<81}"
NUMPY_CONSTRAINT="${NUMPY_CONSTRAINT:-numpy<2}"
PETSC4PY_CONSTRAINT="${PETSC4PY_CONSTRAINT:-petsc4py==3.24.0}"

msg(){ echo "[ICESEE-Spack] $*"; }
die(){ echo "[ICESEE-Spack][ERROR] $*" >&2; exit 1; }
have_cmd(){ command -v "$1" >/dev/null 2>&1; }

# ---- user-configurable install prefix (NO hardcoded cluster paths) ----
ICESEE_SPACK_PREFIX="${ICESEE_SPACK_PREFIX:-$ROOT/.icesee-spack/opt/spack}"
ICESEE_SPACK_CACHE="${ICESEE_SPACK_CACHE:-$ROOT/.icesee-spack/cache}"

# GCC + OpenMPI build knobs (override via env vars)
WANT_GCC="${WANT_GCC:-13}"
MODULE_GCC="${MODULE_GCC:-gcc/${WANT_GCC}}"

# OPENMPI_VERSION="${OPENMPI_VERSION:-5.0.7}"
ICESEE_EXTERNALS_ROOT="${ICESEE_EXTERNALS_ROOT:-$ROOT/.icesee-spack/externals}"
# OPENMPI_PREFIX="${OPENMPI_PREFIX:-$ICESEE_EXTERNALS_ROOT/openmpi-${OPENMPI_VERSION}}"

SLURM_DIR="${SLURM_DIR:-}"
PMIX_DIR="${PMIX_DIR:-}"

# Avoid ~/.spack conflicts unless user explicitly wants them
export SPACK_DISABLE_LOCAL_CONFIG="${SPACK_DISABLE_LOCAL_CONFIG:-1}"
export SPACK_USER_CONFIG_PATH="${SPACK_USER_CONFIG_PATH:-$ROOT/.spack-user-empty}"
mkdir -p "$SPACK_USER_CONFIG_PATH"

# Ensure git submodules exist
#if [[ -d "${ROOT}/.git" ]]; then
#  msg "Updating submodules..."
#  git -C "${ROOT}" submodule update --init --recursive
#fi
[[ -f "${ROOT}/ICESEE/pyproject.toml" ]] || die "Vendored ICESEE not found at ${ROOT}/ICESEE"
[[ -f "${ROOT}/spack/share/spack/setup-env.sh" ]] || die "Vendored Spack not found at ${ROOT}/spack"

# Choose Spack: system first, else pinned submodule
if have_cmd spack; then
  msg "Using system Spack: $(command -v spack)"
  SPACK_BIN="spack"
else
  [[ -f "${ROOT}/spack/share/spack/setup-env.sh" ]] || die "No system spack and no ./spack submodule"
  msg "Using pinned Spack submodule: ${ROOT}/spack"
  # shellcheck disable=SC1091
  source "${ROOT}/spack/share/spack/setup-env.sh"
  SPACK_BIN="spack"
fi

SPACK_CMD="${SPACK_BIN} --no-local-config"

# Create env dirs early (so later writes/sed never fail)
mkdir -p "${ENV_DIR}"
ENV_CFG_DIR="${ENV_DIR}/spack"
mkdir -p "${ENV_CFG_DIR}"

# Copy repo-root spack.yaml into env dir (env is the source of truth for spack -e)
[[ -f "${ROOT}/spack.yaml" ]] || die "spack.yaml not found at ${ROOT}/spack.yaml"
cp -f "${ROOT}/spack.yaml" "${ENV_DIR}/spack.yaml"

# 3) Ensure required repo/env files exist
[[ -f "${ENV_DIR}/spack.yaml" ]] || die "spack.yaml not found at ${ENV_DIR}/spack.yaml"
[[ -f "${CUSTOM_REPO}/repo.yaml" ]] || die "repo.yaml not found at ${CUSTOM_REPO}/repo.yaml"
[[ -d "${CUSTOM_REPO}/packages" ]] || die "custom repo missing ${CUSTOM_REPO}/packages"

#  Env-scoped spack config (prefix/cache paths)
cat > "${ENV_CFG_DIR}/config.yaml" <<EOF
config:
  install_tree:
    root: ${ICESEE_SPACK_PREFIX}
  build_stage:
  - ${ICESEE_SPACK_CACHE}/stage
  misc_cache: ${ICESEE_SPACK_CACHE}/misc
  source_cache: ${ICESEE_SPACK_CACHE}/source
EOF

# Toolchain selection: module gcc/13 -> else spack install/load gcc@13 -> else system gcc
msg "Ensuring GCC >= ${WANT_GCC}..."
if have_cmd module; then
  if module -t avail 2>&1 | grep -qx "${MODULE_GCC}"; then
    msg "Loading module ${MODULE_GCC}"
    module load "${MODULE_GCC}"
  else
    msg "Module ${MODULE_GCC} not available"
    module load gcc || msg "No gcc module available; relying on system compiler for Spack builds (may fail if too old)"
  fi
fi

gcc_major="$(gcc -dumpversion 2>/dev/null | cut -d. -f1 || echo 0)"
if [[ "${gcc_major}" -lt "${WANT_GCC}" ]]; then
  msg "gcc>=${WANT_GCC} not found (current major=${gcc_major}). Installing gcc@${WANT_GCC} via Spack..."
  $SPACK_CMD compiler find || true

  if ! $SPACK_CMD find "gcc@${WANT_GCC}" 2>/dev/null | grep -q "gcc@${WANT_GCC}"; then
    $SPACK_CMD install -j "${JOBS}" "gcc@${WANT_GCC}"
  fi

  $SPACK_CMD load "gcc@${WANT_GCC}"
  $SPACK_CMD compiler find || true
fi

have_cmd gcc      || die "gcc not found after attempting module/spack setup"
have_cmd g++      || die "g++ not found after attempting module/spack setup"
have_cmd gfortran || die "gfortran not found after attempting module/spack setup"
msg "Using gcc: $(command -v gcc) ($(gcc --version | head -n1))"

#  Add custom Spack repo (absolute path, env-scoped) + remove stale ./icesee-spack mapping
msg "Adding custom Spack repo (absolute path, env-scoped)..."
$SPACK_CMD -e "${ENV_DIR}" config rm repos:icesee >/dev/null 2>&1 || true
$SPACK_CMD -e "${ENV_DIR}" repo add "${CUSTOM_REPO}" || true

# Sanity: repo is resolvable AND py-icesee is visible
if ! $SPACK_CMD -e "${ENV_DIR}" repo list | grep -qE 'icesee|icesee-spack'; then
  msg "Repo list:"
  $SPACK_CMD -e "${ENV_DIR}" repo list || true
  msg "Repos config:"
  $SPACK_CMD -e "${ENV_DIR}" config get repos || true
  die "Custom repo does not appear in env repo list."
fi

msg "Checking custom package is visible (py-icesee)..."
$SPACK_CMD -e "${ENV_DIR}" info py-icesee >/dev/null 2>&1 || {
  msg "Repo list:"
  $SPACK_CMD -e "${ENV_DIR}" repo list || true
  msg "Repos config:"
  $SPACK_CMD -e "${ENV_DIR}" config get repos || true
  die "py-icesee not visible to Spack (repo.yaml/path problem)."
}

# 7) Ensure OpenMPI exists at OPENMPI_PREFIX (build if missing)
# msg "Ensuring OpenMPI ${OPENMPI_VERSION} at ${OPENMPI_PREFIX}..."
# export OPENMPI_VERSION OPENMPI_PREFIX JOBS MODULE_GCC SLURM_DIR PMIX_DIR
# export SPACK_CMD
# export SPACK_GCC_SPEC="gcc@${WANT_GCC}"
# bash "${ROOT}/scripts/build_openmpi.sh"

# Register OpenMPI as a Spack external for THIS environment (so concretize uses it)
# msg "Registering OpenMPI external in env packages.yaml..."
# ENV_PACKAGES_YAML="${ENV_CFG_DIR}/packages.yaml"
# gcc_ver_full="$(gcc -dumpfullversion -dumpversion 2>/dev/null | head -n1 || true)"
# gcc_spec="gcc@${gcc_ver_full:-${WANT_GCC}}"

# cat > "${ENV_PACKAGES_YAML}" <<EOF
# packages:
#   all:
#     compiler: [${gcc_spec}]
#   mpi:
#     buildable: false
#     providers:
#       mpi: [openmpi]
#   openmpi:
#     buildable: false
#     externals:
#     - spec: openmpi@${OPENMPI_VERSION}%${gcc_spec}
#       prefix: ${OPENMPI_PREFIX}
# EOF

msg "Configuring Spack OpenMPI provider in env packages.yaml..."
ENV_PACKAGES_YAML="${ENV_CFG_DIR}/packages.yaml"
gcc_ver_full="$(gcc -dumpfullversion -dumpversion 2>/dev/null | head -n1 || true)"
gcc_spec="gcc@${gcc_ver_full:-${WANT_GCC}}"

cat > "${ENV_PACKAGES_YAML}" <<EOF
packages:
  all:
    compiler: [${gcc_spec}]
  mpi:
    providers:
      mpi: [openmpi]
  openmpi:
    buildable: true
EOF

msg "Wrote ${ENV_PACKAGES_YAML}:"
sed -n '1,160p' "${ENV_PACKAGES_YAML}"

#  Concretize + install
msg "Concretizing..."
$SPACK_CMD -e "${ENV_DIR}" concretize -f

msg "Installing (-j ${JOBS})..."
$SPACK_CMD -e "${ENV_DIR}" install -j "${JOBS}"

OPENMPI_PREFIX="$($SPACK_CMD -e "${ENV_DIR}" location -i openmpi@5.0.10)"
export OPENMPI_PREFIX
msg "Using Spack OpenMPI: ${OPENMPI_PREFIX}"

# Develop ICESEE from pinned submodule (so spack uses your source), if present
if [[ -f "${ICESEE_SUBMODULE}/pyproject.toml" ]]; then
  msg "Registering ICESEE submodule for develop install..."
  $SPACK_CMD -e "${ENV_DIR}" develop --path "${ICESEE_SUBMODULE}" py-icesee@main || true

  msg "Reinstalling py-icesee from local source..."
  $SPACK_CMD -e "${ENV_DIR}" install -f py-icesee@main
else
  msg "WARNING: ${ICESEE_SUBMODULE}/pyproject.toml not found; skipping develop install."
fi

msg "Skipping Spack view (view: false)."

#  Use env python WITHOUT requiring shell activation
# PYTHON="$($SPACK_CMD -e "${ENV_DIR}" location -i python)/bin/python"


if $SPACK_CMD -e "${ENV_DIR}" find -q python-venv >/dev/null 2>&1; then
  PYTHON="$($SPACK_CMD -e "${ENV_DIR}" location -i python-venv)/bin/python"
else
  PYTHON="$($SPACK_CMD -e "${ENV_DIR}" location -i python)/bin/python"
fi
[[ -x "${PYTHON}" ]] || die "Could not locate env python via Spack"

msg "Ensuring pip is available in Spack Python..."
"$PYTHON" -m pip --version >/dev/null 2>&1 || {
  msg "pip missing; bootstrapping via ensurepip..."
  "$PYTHON" -m ensurepip --upgrade || true
  "$PYTHON" -m pip install --upgrade pip wheel
  "$PYTHON" -m pip install "${SETUPTOOLS_CONSTRAINT}"
}

# Generate pip-only requirements from ICESEE/pyproject.toml and install them
PYPROJECT="${ICESEE_SUBMODULE}/pyproject.toml"
PIP_REQS="${ROOT}/requirements/pip.auto.txt"

if [[ -f "${PYPROJECT}" ]]; then
  msg "Generating pip requirements from ICESEE pyproject.toml..."
  "$PYTHON" "${ROOT}/scripts/gen_pip_reqs.py" \
    --pyproject "${PYPROJECT}" \
    --out "${PIP_REQS}" \
    --extras "mpi,viz"

  msg "Installing pip-only deps..."
  "$PYTHON" -m pip install -U pip wheel
  "$PYTHON" -m pip install "${SETUPTOOLS_CONSTRAINT}" "${NUMPY_CONSTRAINT}"
  "$PYTHON" -m pip install --no-cache-dir -r "${PIP_REQS}"
  # DEV: allow importing the in-repo ICESEE package (repo root contains ICESEE/)
  export PYTHONPATH="${ROOT}:${PYTHONPATH:-}"
else
  msg "WARNING: ${PYPROJECT} not found; skipping pip-only dependency generation."
fi

# ------------
# ISSM install
# ------------
if [[ "${WITH_ISSM}" -eq 1 ]]; then
  msg "Installing ISSM (--with-issm enabled)..."
  export ICESEE_EXTERNALS_ROOT="${ICESEE_EXTERNALS_ROOT:-$ROOT/.icesee-spack/externals}"
  export ISSM_PREFIX="${ISSM_PREFIX:-$ICESEE_EXTERNALS_ROOT/ISSM}"
  export MODULE_GCC="${MODULE_GCC:-gcc/${WANT_GCC:-13}}"
  export MODULE_MATLAB="${MODULE_MATLAB:-matlab}"
  ISSM_DIR="${ISSM_DIR:-$ICESEE_EXTERNALS_ROOT/ISSM}"
  export ISSM_DIR
  export OPENMPI_PREFIX
  bash "${ROOT}/scripts/build_issm.sh"
else
  msg "Skipping ISSM install (use --with-issm to enable)."
fi


# ---------------------------------------------
# Firedrake install
# ---------------------------------------------
if [[ "${WITH_FIREDRAKE}" -eq 1 ]]; then
  msg "Installing Firedrake into isolated venv..."

  source "${ROOT}/spack/share/spack/setup-env.sh"
  spack env activate -d "${ENV_DIR}"

  PETSC_DIR="$(spack -e "${ENV_DIR}" location -i petsc@3.24.0)"
  MPI_DIR="$(spack -e "${ENV_DIR}" location -i openmpi)"
  PYTHON_PREFIX="$(spack -e "${ENV_DIR}" location -i python)"
  PYTHON="${PYTHON_PREFIX}/bin/python3"

  [[ -x "${PYTHON}" ]] || die "Python executable not found: ${PYTHON}"
  [[ -d "${MPI_DIR}" ]] || die "OpenMPI prefix not found: ${MPI_DIR}"
  [[ -d "${PETSC_DIR}" ]] || die "PETSc prefix not found: ${PETSC_DIR}"

  export PATH="${MPI_DIR}/bin:${PATH}"
  export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:${LD_LIBRARY_PATH:-}"

  export CC="${MPI_DIR}/bin/mpicc"
  export CXX="${MPI_DIR}/bin/mpicxx"
  export FC="${MPI_DIR}/bin/mpifort"

  export MPICC="${MPI_DIR}/bin/mpicc"
  export MPICXX="${MPI_DIR}/bin/mpicxx"
  export MPIFC="${MPI_DIR}/bin/mpifort"

  export PETSC_DIR="${PETSC_DIR}"
  export HDF5_MPI=ON
  export OMP_NUM_THREADS=1
  unset PETSC_ARCH || true

  FIREDRAKE_VENV="${ROOT}/venv-firedrake"

  if [[ -d "${FIREDRAKE_VENV}" ]]; then
    msg "Removing existing Firedrake venv: ${FIREDRAKE_VENV}"
    rm -rf "${FIREDRAKE_VENV}"
  fi

  msg "Creating Firedrake virtual environment"
  "${PYTHON}" -m venv --system-site-packages "${FIREDRAKE_VENV}"

  source "${FIREDRAKE_VENV}/bin/activate"
  PYTHON="${FIREDRAKE_VENV}/bin/python"

  msg "Upgrading pip tooling"
  "${PYTHON}" -m ensurepip --upgrade || true
  "${PYTHON}" -m pip install --upgrade "pip<26" "setuptools<81" wheel

  CONSTRAINTS="${ROOT}/requirements/firedrake-constraints.txt"
  cat > "${CONSTRAINTS}" <<EOF
setuptools<81
numpy<2
petsc4py==3.24.0
EOF

  export PIP_CONSTRAINT="${CONSTRAINTS}"

  FIREDRAKE_VERSION="${FIREDRAKE_VERSION:-2025.10.2}"

  msg "Installing Firedrake ${FIREDRAKE_VERSION}"
  "${PYTHON}" -m pip install "firedrake[check]==${FIREDRAKE_VERSION}"

  msg "Running Firedrake sanity checks"
  "${PYTHON}" -c "import firedrake; print('firedrake import OK:', firedrake.__file__)"
  "${PYTHON}" -c "import petsc4py; print('petsc4py import OK:', petsc4py.__file__)"
  "${PYTHON}" -c "from mpi4py import MPI; print('mpi4py OK:', MPI.Get_version())"

else
  msg "Skipping Firedrake install (use --with-firedrake to enable)."
fi

# --------------------------------------------------------
# Icepack install (installs firedrake deps + icepack itself)
# --------------------------------------------------------
if [[ "${WITH_ICEPACK}" -eq 1 ]]; then
  msg "Installing Icepack into Spack Python (no venv)..."
  source "${ROOT}/spack/share/spack/setup-env.sh"
  spack env activate -d "${ENV_DIR}"

  # source firedrake venv to get deps + env vars
  FIREDRAKE_VENV="${ROOT}/venv-firedrake"
  source "${FIREDRAKE_VENV}/bin/activate"
  PYTHON="${FIREDRAKE_VENV}/bin/python"
  export OMP_NUM_THREADS=1

  # install patchelf
  "$PYTHON" -m pip install "${SETUPTOOLS_CONSTRAINT}" "${NUMPY_CONSTRAINT}"
  "$PYTHON" -m pip install patchelf

  # clone icepack repo if icepack is missing (uses main branch by default)
  ICEPACK_DIR="${ICEPACK_DIR:-$ROOT/icepack}"
  ICEPACK_REPO="git clone https://github.com/icepack/icepack.git"
  if [[ ! -d "${ICEPACK_DIR}/.git" ]]; then
    msg "Cloning Icepack repo into ${ICEPACK_DIR}..."
    eval "${ICEPACK_REPO}"
  else
    msg "Icepack repo already exists at ${ICEPACK_DIR}; skipping clone."
  fi

  # install icepack into the same python environment as firedrake (no venv, so spack deps are visible)
  msg "Installing Icepack from ${ICEPACK_DIR} into Spack Python environment..."
  "$PYTHON" -m pip install --editable "${ICEPACK_DIR}"

  # Install the jupyter kenrnel
  msg "Installing Icepack Jupyter kernel..."
  "$PYTHON" -m pip install ipykernel
  "$PYTHON" -m ipykernel install --user --name=firedrake

  # pypi gmsh
  msg "Installing gmsh Python API from PyPI..."
  "$PYTHON" -m pip install gmsh

else
  msg "Skipping Icepack install (use --with-icepack to enable)."
fi

# Smoke tests
msg "Running smoke tests..."
if [[ -f "${ROOT}/scripts/test.sh" ]]; then
  msg "Running ${ROOT}/scripts/test.sh... to test Spack environment and py-icesee installation"
  bash "${ROOT}/scripts/test.sh"
  if [[ "${WITH_ISSM}" -eq 1 && -f "${ROOT}/scripts/test_issm.sh" ]]; then
    msg "Running ${ROOT}/scripts/test_issm.sh... to test ISSM installation"
    export ISSM_DIR="${ISSM_DIR:-$ICESEE_EXTERNALS_ROOT/ISSM}"
    bash "${ROOT}/scripts/test_issm.sh"
  fi
else
  msg "WARNING: scripts/test.sh not found; skipping tests."
fi

msg "Install complete."
msg "Prefix: ${ICESEE_SPACK_PREFIX}"
msg "OpenMPI: $($SPACK_CMD -e "${ENV_DIR}" location -i openmpi@5.0.10 2>/dev/null || echo '<not installed>')"
msg "To use the environment:"
msg "  source ${ROOT}/scripts/activate.sh"
