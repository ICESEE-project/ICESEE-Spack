#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_icepack] $*"; }
die(){ echo "[build_icepack][ERROR] $*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ICEPACK_REPO="${ICEPACK_REPO:-https://github.com/icepack/icepack.git}"
ICEPACK_REF="${ICEPACK_REF:-master}"
ICEPACK_PREFIX="${ICEPACK_PREFIX:-${ROOT}/icepack}"
FIREDRAKE_VENV="${ROOT}/venv-firedrake"

[[ -x "${FIREDRAKE_VENV}/bin/python" ]] || die "Missing Firedrake venv: ${FIREDRAKE_VENV}"

if [[ ! -d "${ICEPACK_PREFIX}/.git" ]]; then
  log "Cloning Icepack from ${ICEPACK_REPO}"
  git clone "${ICEPACK_REPO}" "${ICEPACK_PREFIX}"
fi

log "Checking out Icepack ref: ${ICEPACK_REF}"
git -C "${ICEPACK_PREFIX}" fetch --all --tags
git -C "${ICEPACK_PREFIX}" checkout "${ICEPACK_REF}"

source "${FIREDRAKE_VENV}/bin/activate"

log "Installing Icepack runtime dependencies without breaking Firedrake"

python -m pip install --no-cache-dir \
  "setuptools<81" \
  "numpy<2" \
  "decorator==4.4.2" \
  "h5py>3.12.1" \
  patchelf \
  geojson \
  matplotlib \
  MeshPy \
  pyroltrilinos \
  gmsh \
  rasterio \
  xarray \
  netCDF4 \
  pyproj \
  shapely \
  geopandas \
  pooch \
  earthaccess \
  pyyaml \
  tqdm \
  psutil \
  dask \
  gstools \
  "zarr<3.0.0" \
  numcodecs

python -m pip install --no-cache-dir "decorator==4.4.2"

log "Installing Icepack editable without disturbing Firedrake deps"
python -m pip install --editable "${ICEPACK_PREFIX}"

log "Installing Jupyter kernel support without upgrading Firedrake pins"
python -m pip install --no-cache-dir ipykernel || true

if python -c "import ipykernel" >/dev/null 2>&1; then
  python -m ipykernel install --user --name=firedrake --display-name "Firedrake/Icepack"
else
  log "Skipping Jupyter kernel install because ipykernel is unavailable"
fi

log "Installing ICESEE Python dependencies into Firedrake/Icepack venv"

PYPROJECT="${ROOT}/ICESEE/pyproject.toml"
PIP_REQS="${ROOT}/requirements/pip.icesee-firedrake.txt"

if [[ -f "${PYPROJECT}" ]]; then
  python "${ROOT}/scripts/gen_pip_reqs.py" \
    --pyproject "${PYPROJECT}" \
    --out "${PIP_REQS}" \
    --extras "mpi,viz"

  # Avoid jupyter/ipython dependency upgrades that conflict with decorator==4.4.2.
  grep -Ev '^(jupyter|jupyterlab|notebook|ipython|ipykernel)([<>= ]|$)' \
    "${PIP_REQS}" > "${PIP_REQS}.filtered"

  python -m pip install --no-cache-dir -r "${PIP_REQS}.filtered"

  python -m pip install --no-cache-dir "h5py>3.12.1" "decorator==4.4.2"
else
  die "ICESEE pyproject.toml not found: ${PYPROJECT}"
fi

log "Sanity checks"
python -c "import firedrake; print('firedrake import OK')"
python -c "import rasterio; print('rasterio import OK')"
python -c "import yaml; print('yaml import OK')"
python -c "import icepack; print('icepack import OK')"
python -c "import decorator; print('decorator:', decorator.__version__)"
python -m pip freeze | grep -E "firedrake|ufl|fiat|petsc|loopy|pyadjoint|decorator|icepack" || true

log "Done."