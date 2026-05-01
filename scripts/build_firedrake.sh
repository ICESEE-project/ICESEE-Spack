#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_firedrake] $*"; }
die(){ echo "[build_firedrake][ERROR] $*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT}/.spack-env/icesee"

PETSC_VERSION="${PETSC_VERSION:-3.23.4}"
FIREDRAKE_VERSION="${FIREDRAKE_VERSION:-2025.4.2}"
FIREDRAKE_STACK="${FIREDRAKE_STACK:-legacy}"

source "${ROOT}/spack/share/spack/setup-env.sh"
spack env activate -d "${ENV_DIR}"

PYTHON_PREFIX="$(spack -e "${ENV_DIR}" location -i python)"
PYTHON="${PYTHON_PREFIX}/bin/python3"
PETSC_DIR="$(spack -e "${ENV_DIR}" location -i petsc@${PETSC_VERSION})"
MPI_DIR="$(spack -e "${ENV_DIR}" location -i openmpi)"
GCC_PREFIX="$(spack -e "${ENV_DIR}" location -i gcc@13 2>/dev/null || true)"

[[ -x "${PYTHON}" ]] || die "Python executable not found: ${PYTHON}"
[[ -d "${MPI_DIR}" ]] || die "OpenMPI prefix not found: ${MPI_DIR}"
[[ -d "${PETSC_DIR}" ]] || die "PETSc prefix not found: ${PETSC_DIR}"
[[ -f "${PETSC_DIR}/lib/petsc/conf/petscvariables" ]] || die "Missing PETSc variables: ${PETSC_DIR}/lib/petsc/conf/petscvariables"

if [[ -n "${GCC_PREFIX}" && -d "${GCC_PREFIX}" ]]; then
  GCC_TRIPLE="$("${GCC_PREFIX}/bin/gcc" -dumpmachine)"
  GCC_VERSION="$("${GCC_PREFIX}/bin/gcc" -dumpfullversion -dumpversion)"
  GCC_INCLUDE="${GCC_PREFIX}/lib/gcc/${GCC_TRIPLE}/${GCC_VERSION}/include"

  [[ -f "${GCC_INCLUDE}/stddef.h" ]] || die "Missing stddef.h at ${GCC_INCLUDE}/stddef.h"

  export PATH="${GCC_PREFIX}/bin:${PATH}"
  export CPATH="${GCC_INCLUDE}:${CPATH:-}"
  export C_INCLUDE_PATH="${GCC_INCLUDE}:${C_INCLUDE_PATH:-}"
  export CPLUS_INCLUDE_PATH="${GCC_INCLUDE}:${CPLUS_INCLUDE_PATH:-}"

  export OMPI_CC="${GCC_PREFIX}/bin/gcc"
  export OMPI_CXX="${GCC_PREFIX}/bin/g++"
  export OMPI_FC="${GCC_PREFIX}/bin/gfortran"

  log "Using GCC: ${GCC_PREFIX}"
  log "Using GCC include: ${GCC_INCLUDE}"
else
  log "Spack GCC not found; using compiler from current environment"
fi

export PATH="${MPI_DIR}/bin:${PATH}"
export LD_LIBRARY_PATH="${MPI_DIR}/lib:${PETSC_DIR}/lib:${GCC_PREFIX:+${GCC_PREFIX}/lib64:}${GCC_PREFIX:+${GCC_PREFIX}/lib:}${LD_LIBRARY_PATH:-}"

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

log "Using stack: ${FIREDRAKE_STACK}"
log "Using Python: ${PYTHON}"
log "Using PETSc: ${PETSC_DIR}"
log "Using MPI: ${MPI_DIR}"
log "mpicc: $(${MPI_DIR}/bin/mpicc -show 2>/dev/null || true)"

FIREDRAKE_VENV="${ROOT}/venv-firedrake"

if [[ -d "${FIREDRAKE_VENV}" ]]; then
  log "Removing existing Firedrake venv: ${FIREDRAKE_VENV}"
  rm -rf "${FIREDRAKE_VENV}"
fi

log "Creating Firedrake virtual environment"
"${PYTHON}" -m venv "${FIREDRAKE_VENV}"

source "${FIREDRAKE_VENV}/bin/activate"

log "Upgrading pip tooling"
python -m pip install --upgrade "pip<26" "setuptools<81" wheel

CONSTRAINTS="${ROOT}/requirements/firedrake-legacy.txt"
mkdir -p "$(dirname "${CONSTRAINTS}")"

cat > "${CONSTRAINTS}" <<EOF
setuptools<81
numpy<2
decorator==4.4.2
petsc4py==3.23.4
fenics-ufl==2025.1.0
firedrake==2025.4.2
firedrake-fiat==2025.4.2
petsctools==2025.3
pyadjoint-ad==2025.4.1
loopy==2025.2
EOF

export PIP_CONSTRAINT="${CONSTRAINTS}"
export PIP_BUILD_CONSTRAINT="${CONSTRAINTS}"
export PIP_USE_FEATURE="build-constraint"

log "Installing legacy Firedrake dependency pins"

python -m pip install --no-cache-dir \
  "numpy<2" \
  "Cython>=3.0" \
  pkgconfig \
  mpi4py \
  "petsc4py==3.23.4"

python -m pip install --no-cache-dir \
  "fenics-ufl==2025.1.0" \
  "firedrake-fiat==2025.4.2" \
  "petsctools==2025.3" \
  "pyadjoint-ad==2025.4.1" \
  "loopy==2025.2" \
  "decorator==4.4.2"

python -m pip install \
  immutabledict constantdict cachetools recursivenodes pymbolic \
  cgen genpy codepy mako colorama checkpoint_schedules \
  siphash24 symengine rtree
  
log "Installing Firedrake ${FIREDRAKE_VERSION}"
python -m pip install --no-cache-dir  \
  "firedrake[check]==${FIREDRAKE_VERSION}"

python -m pip install --no-cache-dir "decorator==4.4.2"

EXPECTED_PETSC_DIR="$(python - <<'PY'
import petsc4py
print(petsc4py.get_config().get("PETSC_DIR", ""))
PY
)"

EXPECTED_PETSC_ARCH="$(python - <<'PY'
import petsc4py
print(petsc4py.get_config().get("PETSC_ARCH", ""))
PY
)"

export PETSC_DIR="${EXPECTED_PETSC_DIR}"
if [[ -n "${EXPECTED_PETSC_ARCH}" ]]; then
  export PETSC_ARCH="${EXPECTED_PETSC_ARCH}"
else
  unset PETSC_ARCH || true
fi

log "petsc4py expects PETSC_DIR=${PETSC_DIR}"

log "Running sanity checks"
python -c "import petsc4py; print('petsc4py import OK:', petsc4py.__file__)"
python -c "import firedrake; print('firedrake import OK:', firedrake.__file__)"
python - <<'PY'
import firedrake
mesh = firedrake.RectangleMesh(12, 8, 5000, 1200, quadrilateral=True)
print("RectangleMesh OK")
PY

python -m pip freeze | grep -E "firedrake|ufl|fiat|petsc|loopy|pyadjoint|decorator" || true

log "Done."