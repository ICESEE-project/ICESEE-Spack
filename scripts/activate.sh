#!/usr/bin/env bash

# Copyright (c) 2026 Brian Kyanjo

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -d "${ROOT}/spack/share/spack" ]]; then
  # shellcheck disable=SC1091
  source "${ROOT}/spack/share/spack/setup-env.sh"
fi

spack -e "${ROOT}" env activate

echo "[ICESEE-Spack] Activated env at: ${ROOT}"
echo "python: $(which python || true)"
echo "mpirun: $(which mpirun || true)"