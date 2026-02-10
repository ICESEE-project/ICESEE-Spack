#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# If not already activated, activate quickly
if ! command -v spack >/dev/null 2>&1; then
  if [[ -d "${ROOT}/spack/share/spack" ]]; then
    # shellcheck disable=SC1091
    source "${ROOT}/spack/share/spack/setup-env.sh"
  fi
fi
spack -e "${ROOT}" env activate

echo "[test] which python: $(which python)"
echo "[test] python -V: $(python -V)"

python - <<'PY'
import sys
print("[test] python:", sys.executable)

# mpi4py check
from mpi4py import MPI
print("[test] MPI vendor:", MPI.get_vendor())
print("[test] MPI size:", MPI.COMM_WORLD.Get_size())

# h5py MPI check
import h5py
print("[test] h5py mpi:", h5py.get_config().mpi)

# ICESEE import check
try:
    import ICESEE
    print("[test] ICESEE import OK:", getattr(ICESEE, "__file__", None))
except Exception as e:
    raise SystemExit(f"[test] ICESEE import FAILED: {e!r}")
PY