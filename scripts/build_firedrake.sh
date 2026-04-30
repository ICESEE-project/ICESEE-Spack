#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_firedrake] $*"; }
die(){ echo "[build_firedrake][ERROR] $*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT}/.spack-env/icesee"

source "${ROOT}/spack/share/spack/setup-env.sh"
spack env activate -d "${ENV_DIR}"

PYTHON_PREFIX="$(spack -e "${ENV_DIR}" location -i python)"
PYTHON="${PYTHON_PREFIX}/bin/python3"
PETSC_DIR="$(spack -e "${ENV_DIR}" location -i petsc@3.24.0)"
MPI_DIR="$(spack -e "${ENV_DIR}" location -i openmpi@5.0.10)"

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
unset PETSC_ARCH || true

FIREDRAKE_VENV="${ROOT}/venv-firedrake"

rm -rf "${FIREDRAKE_VENV}"

log "Creating Firedrake virtual environment"
#"${PYTHON}" -m venv --system-site-packages "${FIREDRAKE_VENV}"
"${PYTHON}" -m venv  "${FIREDRAKE_VENV}"

source "${FIREDRAKE_VENV}/bin/activate"

log "Upgrading pip tooling"
python -m pip install --upgrade "pip<26" "setuptools<81" wheel

CONSTRAINTS="${ROOT}/requirements/firedrake-constraints.txt"
mkdir -p "$(dirname "${CONSTRAINTS}")"

cat > "${CONSTRAINTS}" <<EOF
setuptools<81
numpy<2
decorator==4.4.2
petsc4py==3.24.0
fenics-ufl==2025.2.1
firedrake-fiat==2025.10.1
petsctools==2025.3
pyadjoint-ad==2025.10.1
loopy==2025.2
EOF

export PIP_CONSTRAINT="${CONSTRAINTS}"
export PIP_BUILD_CONSTRAINT="${CONSTRAINTS}"
export PIP_USE_FEATURE="build-constraint"

FIREDRAKE_VERSION="${FIREDRAKE_VERSION:-2025.10.2}"

python -m pip install --no-cache-dir \
  "fenics-ufl==2025.2.1" \
  "firedrake-fiat==2025.10.1" \
  "petsctools==2025.3" \
  "pyadjoint-ad==2025.10.1" \
  "loopy==2025.2"

python -m pip install --no-cache-dir \
  "firedrake[check]==${FIREDRAKE_VERSION}"

# Important: reset PETSC_DIR to whatever petsc4py expects
EXPECTED_PETSC_DIR="$(python - <<'PY'
import petsc4py, os
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

log "Running sanity checks"
python -c "import petsc4py; print('petsc4py import OK:', petsc4py.__file__)"
python -c "import firedrake; print('firedrake import OK:', firedrake.__file__)"
python - <<'PY'
import firedrake
mesh = firedrake.RectangleMesh(12, 8, 5000, 1200, quadrilateral=True)
print("RectangleMesh OK")
PY

log "Done."
