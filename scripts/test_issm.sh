#!/usr/bin/env bash
set -euo pipefail

log(){ echo "[test_issm] $*"; }
warn(){ echo "[test_issm][WARN] $*" >&2; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTIVATE="${ROOT}/scripts/activate.sh"

log "Starting ISSM smoke test..."
log "Sourcing: ${ACTIVATE}"
# shellcheck disable=SC1090
source "${ACTIVATE}"

# Allow overrides
MATLAB_BIN="${MATLAB_BIN:-matlab}"

# ISSM_DIR should come from activate.sh (exported there), but allow manual override
ISSM_DIR="${ISSM_DIR:-}"

log "MATLAB_BIN: ${MATLAB_BIN}"
log "ISSM_DIR:    ${ISSM_DIR:-<not set>}"

# MATLAB presence: best-effort warning instead of hard failure if not installed
if ! command -v "${MATLAB_BIN}" >/dev/null 2>&1; then
  warn "MATLAB executable not found: ${MATLAB_BIN}"
  warn "If you want ISSM tests, load MATLAB (e.g. 'module load matlab') and re-run."
  exit 0
fi

# ISSM presence: fail if you requested ISSM but it’s not there; otherwise warn+exit 0
if [[ -z "${ISSM_DIR}" || ! -d "${ISSM_DIR}" ]]; then
  warn "ISSM_DIR is not set or not a directory."
  warn "Set ISSM_DIR=/path/to/ISSM or enable --with-issm during install."
  exit 0
fi

# Source ISSM env if present (often needed for MATLAB paths)
if [[ -f "${ISSM_DIR}/etc/environment.sh" ]]; then
  log "Sourcing ${ISSM_DIR}/etc/environment.sh"
  set +u
  # shellcheck disable=SC1090
  source "${ISSM_DIR}/etc/environment.sh"
  set -u
fi

TMP_MFILE="$(mktemp /tmp/icesee_issm_test_XXXX.m)"
cat > "${TMP_MFILE}" <<'EOF'
try
    disp('[test_issm] MATLAB started');

    issm_dir = getenv('ISSM_DIR');
    if isempty(issm_dir)
        error('ISSM_DIR not set in environment.');
    end

    % Add ISSM MATLAB paths
    addpath(genpath(fullfile(issm_dir,'src','m')));

    if exist('issmversion','file') ~= 2
        error('issmversion not found on MATLAB path. Check ISSM_DIR and paths.');
    end

    v = issmversion();
    disp(['[test_issm] issmversion: ', v]);

    disp('[test_issm] OK');
    exit(0);
catch ME
    disp('[test_issm][ERROR] FAILED');
    disp(getReport(ME,'extended'));
    exit(1);
end
EOF

log "Running MATLAB issmversion()..."
"${MATLAB_BIN}" -nodisplay -nosplash -nodesktop -r "run('${TMP_MFILE}');"

rm -f "${TMP_MFILE}"
log "Done."