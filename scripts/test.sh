#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="${ROOT}"

# Use spack WITHOUT needing shell support
SPACK_BIN="${SPACK_BIN:-spack}"
SPACK_CMD="${SPACK_BIN} --no-local-config"

# Always run tests using the env's python directly (no activation)
PY_LOC="$($SPACK_CMD -e "${ENV_DIR}" location -i python)"
PYTHON="${PY_LOC}/bin/python"

echo "[test] which python: ${PYTHON}"
echo "[test] python -V: $(${PYTHON} -V)"
echo "[test] python: ${PYTHON}"

# If your env uses python-venv (as shown in your log), you can also prefer it:
if $SPACK_CMD -e "${ENV_DIR}" find -q python-venv >/dev/null 2>&1; then
  VENV_LOC="$($SPACK_CMD -e "${ENV_DIR}" location -i python-venv)"
  if [[ -x "${VENV_LOC}/bin/python" ]]; then
    PYTHON="${VENV_LOC}/bin/python"
    echo "[test] using python-venv: ${PYTHON}"
  fi
fi

# Ensure pip exists (some spack pythons omit it)
if ! "${PYTHON}" -m pip --version >/dev/null 2>&1; then
  echo "[test] pip missing; bootstrapping via ensurepip..."
  "${PYTHON}" -m ensurepip --upgrade || true
  "${PYTHON}" -m pip install -U pip setuptools wheel
fi

# ---- actual smoke tests ----
"${PYTHON}" - <<'PY'
import sys
print("[test] sys.executable:", sys.executable)
try:
    import mpi4py
    from mpi4py import MPI
    print("[test] MPI vendor:", MPI.get_vendor())
    print("[test] MPI size:", MPI.COMM_WORLD.Get_size())
except Exception as e:
    print("[test][WARN] mpi4py test failed:", e)

try:
    import h5py
    print("[test] h5py mpi:", getattr(h5py.get_config(), "mpi", False))
except Exception as e:
    print("[test][WARN] h5py test failed:", e)

try:
    import ICESEE
    print("[test] ICESEE import OK:", ICESEE.__file__)
except Exception as e:
    print("[test][FAIL] ICESEE import failed:", e)
    raise
PY