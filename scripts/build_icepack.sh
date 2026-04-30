#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[build_icepack] $*"; }
die(){ echo "[build_icepack][ERROR] $*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ICEPACK_REPO="${ICEPACK_REPO:-https://github.com/icepack/icepack.git}"
ICEPACK_PREFIX="${ICEPACK_PREFIX:-${ROOT}/icepack}"
FIREDRAKE_VENV="${ROOT}/venv-firedrake"

[[ -x "${FIREDRAKE_VENV}/bin/python" ]] || die "Missing Firedrake venv: ${FIREDRAKE_VENV}"

if [[ ! -d "${ICEPACK_PREFIX}/.git" ]]; then
  log "Cloning Icepack from ${ICEPACK_REPO}"
  git clone --depth=1 "${ICEPACK_REPO}" "${ICEPACK_PREFIX}"
else
  log "Icepack repo already exists: ${ICEPACK_PREFIX}"
fi

source "${FIREDRAKE_VENV}/bin/activate"

log "Installing Icepack runtime dependencies without breaking Firedrake"
python -m pip install \
  "setuptools<81" \
  "numpy<2" \
  "decorator==4.4.2" \
  patchelf \
  geojson matplotlib MeshPy pyroltrilinos \
  gmsh \
  rasterio \
  xarray \
  netCDF4 \
  pyproj \
  shapely \
  geopandas \
  pooch \
  earthaccess

# Re-pin after optional deps, because some packages may try to upgrade it.
python -m pip install "decorator==4.4.2"

# Install ipykernel without deps so it does not upgrade decorator.
python -m pip install --no-deps ipykernel

log "Installing Icepack editable without disturbing Firedrake deps"
python -m pip install --no-deps --editable "${ICEPACK_PREFIX}"

log "Installing Jupyter kernel"
python -m ipykernel install --user --name=firedrake --display-name "Firedrake/Icepack"

log "Installing ICESEE Python dependencies into Firedrake/Icepack venv"

PYPROJECT="${ROOT}/ICESEE/pyproject.toml"
PIP_REQS="${ROOT}/requirements/pip.icesee-firedrake.txt"

if [[ -f "${PYPROJECT}" ]]; then
  python "${ROOT}/scripts/gen_pip_reqs.py" \
    --pyproject "${PYPROJECT}" \
    --out "${PIP_REQS}" \
    --extras "mpi,viz"

  python -m pip install --no-cache-dir -r "${PIP_REQS}"

  # Restore Firedrake-compatible pin
  python -m pip install "h5py>3.12.1" "decorator==4.4.2"
else
  die "ICESEE pyproject.toml not found: ${PYPROJECT}"
fi

log "Sanity checks"
python -c "import firedrake; print('firedrake import OK')"
python -c "import rasterio; print('rasterio import OK')"
python -c "import yaml; print('yaml import OK')"
python -c "import icepack; print('icepack import OK')"
log "Done."
