#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[test] $*"; }
warn(){ echo "[test][WARN] $*" >&2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVATE="${ROOT}/scripts/activate.sh"

log "ROOT:    ${ROOT}"
log "Sourcing: ${ACTIVATE}"
# shellcheck disable=SC1090
source "${ACTIVATE}"

PYTHON="$(command -v python || true)"
if [[ -z "${PYTHON}" ]]; then
  echo "[test][ERROR] python not found after activate.sh" >&2
  exit 2
fi

log "python:  ${PYTHON}"
log "python -V: $(${PYTHON} -V 2>&1 || true)"
log "mpirun:  $(command -v mpirun || echo not-found)"
log "mpicc:   $(command -v mpicc  || echo not-found)"

if command -v module >/dev/null 2>&1; then
  log "module list:"
  module list 2>&1 || true
else
  log "module list: (no module command)"
fi

# Helper: run a python one-liner with faulthandler enabled
_py_run () {
  local label="$1"; shift
  echo
  log "---- ${label} ----"
  "${PYTHON}" -X faulthandler -c "$*" || return $?
}

# Print core diagnostics once (helps debug path mixups)
_py_run "python diagnostics" \
'import sys, os
print("[py] sys.executable:", sys.executable)
print("[py] sys.version:", sys.version.split()[0])
print("[py] sys.prefix:", sys.prefix)
print("[py] site-packages probe:")
try:
  import site
  print("  ", "\n   ".join(site.getsitepackages()))
except Exception as e:
  print("  site.getsitepackages failed:", e)
print("[py] PATH:", os.environ.get("PATH",""))
print("[py] LD_LIBRARY_PATH:", os.environ.get("LD_LIBRARY_PATH",""))'

# mpi4py
if _py_run "mpi4py import" \
'from mpi4py import MPI
print("[py] mpi4py OK; vendor:", MPI.get_vendor())
print("[py] MPI size:", MPI.COMM_WORLD.Get_size())'
then
  true
else
  rc=$?
  warn "mpi4py import failed (rc=${rc})."
fi

# h5py
if _py_run "h5py import" \
'import h5py
print("[py] h5py OK; version:", h5py.__version__)
cfg = getattr(h5py, "get_config", None)
if cfg:
  print("[py] h5py mpi:", getattr(cfg(), "mpi", False))'
then
  true
else
  rc=$?
  warn "h5py import failed (rc=${rc})."
fi

# icesee (prefer lowercase)
if _py_run "icesee import" \
'import ICESEE
print("[py] icesee OK:", getattr(icesee, "__file__", "<no __file__>"))'
then
  true
else
  rc=$?
  warn "icesee import failed (rc=${rc})."
fi

echo
log "Done."