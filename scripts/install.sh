#!/usr/bin/env bash

# Copyright (c) 2026 Brian Kyanjo

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPACK_DIR="${ROOT}/spack"
ENV_DIR="${ROOT}"
ICESEE_SUBMODULE="${ROOT}/ICESEE"
JOBS="${JOBS:-8}"

msg() { echo -e "[ICESEE-Spack] $*"; }

# 0) Ensure submodules are present
msg "Checking submodules..."
if [[ -d "${ROOT}/.git" ]]; then
  git -C "${ROOT}" submodule update --init --recursive
fi

# 1) Find Spack
if [[ -d "${SPACK_DIR}/share/spack" ]]; then
  msg "Using pinned Spack at: ${SPACK_DIR}"
  # shellcheck disable=SC1091
  source "${SPACK_DIR}/share/spack/setup-env.sh"
else
  msg "Pinned Spack not found. Trying system Spack..."
  command -v spack >/dev/null 2>&1 || { echo "ERROR: spack not found. Add spack submodule or install spack."; exit 1; }
fi

# 2) Sanity: we are in an env repo with spack.yaml
[[ -f "${ENV_DIR}/spack.yaml" ]] || { echo "ERROR: spack.yaml not found in ${ENV_DIR}"; exit 1; }

# 3) Bootstrap compiler list (needed to build gcc@13)
msg "Discovering compilers..."
spack compiler find || true

# 4) Activate environment
msg "Activating Spack environment..."
spack -e "${ENV_DIR}" env activate

# 5) Add our custom repo (idempotent)
msg "Adding ICESEE custom repo..."
spack repo add --scope env "${ROOT}/icesee-spack" || true

# 6) Concretize + install
msg "Concretizing..."
spack -e "${ENV_DIR}" concretize -f

msg "Installing specs (jobs=${JOBS})..."
spack -e "${ENV_DIR}" install -j "${JOBS}"

# 7) Make ICESEE install come from the pinned submodule (develop mode)
# This makes "spack install py-icesee" use local source checkout.
if [[ -f "${ICESEE_SUBMODULE}/pyproject.toml" ]]; then
  msg "Registering local ICESEE submodule for develop install..."
  spack -e "${ENV_DIR}" develop --path "${ICESEE_SUBMODULE}" py-icesee@main || true

  msg "Reinstalling py-icesee from local source..."
  spack -e "${ENV_DIR}" install -f py-icesee@main
else
  msg "WARNING: ICESEE submodule not found at ${ICESEE_SUBMODULE} (pyproject.toml missing)."
  msg "         Will rely on upstream git version specified by package.py."
fi

# 8) Build/refresh view (so python sees a unified site-packages)
msg "Refreshing view..."
spack -e "${ENV_DIR}" view regenerate || true

# 9) Run smoke tests
msg "Running tests..."
bash "${ROOT}/scripts/test.sh"

msg "Install complete."
msg "Next:"
msg "  source ${ROOT}/scripts/activate.sh"