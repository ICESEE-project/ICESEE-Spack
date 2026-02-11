#!/usr/bin/env bash
set -euo pipefail

# -----------------------
# 0) Modules
# -----------------------
module purge || true
module load gcc/12.3.0      || true
module load openmpi/4.1.5   || true
module load python/3.11.9   || true
module load ninja/1.12.1    || true
# module load cmake/3.30.2  || true  # load if your PETSc config wants it

echo "Python: $(python3 --version)"
echo "mpicc:  $(command -v mpicc || echo not-found)"
echo "mpicxx: $(command -v mpicxx || echo not-found)"
echo "mpifort:$(command -v mpifort || echo not-found)"
echo "cmake:  $(command -v cmake || echo not-found)"
echo

# -----------------------
# 1) Get firedrake-configure (used for PETSc version + env)
# -----------------------
curl -L -o firedrake-configure \
  https://raw.githubusercontent.com/firedrakeproject/firedrake/main/scripts/firedrake-configure
chmod +x firedrake-configure

# -----------------------
# 2) PETSc (explicit configure: this is what worked)
# -----------------------
PETSC_VERSION="$(python3 ./firedrake-configure --no-package-manager --show-petsc-version)"
echo "Using PETSc version: ${PETSC_VERSION}"

if [[ ! -d petsc ]]; then
  git clone --branch "${PETSC_VERSION}" https://gitlab.com/petsc/petsc.git petsc
fi

pushd petsc

# Clean prior build
rm -rf arch-firedrake-default

# Explicit configure (KNOWN GOOD from your test)
./configure \
  PETSC_ARCH=arch-firedrake-default \
  --with-debugging=0 \
  --with-shared-libraries=1 \
  --with-fortran-bindings=0 \
  --with-c2html=0 \
  COPTFLAGS=-O2 CXXOPTFLAGS=-O2 FOPTFLAGS=-O2 \
  CC=mpicc CXX=mpicxx FC=mpifort \
  --download-fblaslapack=1

# Build (parallel)
make -j "$(nproc)" PETSC_DIR="$PWD" PETSC_ARCH=arch-firedrake-default all
make -j "$(nproc)" check

popd

# -----------------------
# 3) Firedrake venv + install
# -----------------------
python3 -m venv venv-firedrake
source venv-firedrake/bin/activate

python -m pip install -U pip wheel setuptools
pip cache purge

# Export Firedrake environment variables (PETSC_DIR/PETSC_ARCH etc.)
export $(python3 ./firedrake-configure --no-package-manager --show-env)

# setuptools constraint
echo 'setuptools<81' > constraints.txt
export PIP_CONSTRAINT="$PWD/constraints.txt"

# If your cluster’s pip builds ignore modules, this helps:
export PIP_NO_BUILD_ISOLATION=1

pip install --no-binary h5py "firedrake[check]"
firedrake-check