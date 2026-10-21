#!/usr/bin/env bash
# Copyright (c) 2026 Brian Kyanjo
# -----------------------------------------------------------------------------
# submodules.sh — populate ICESEE-Spack's pinned git submodules
#
#   ICESEE          ICESEE source (always)
#   spack           pinned Spack (always)
#   icepack         Icepack source (--with-icepack)
#   externals/ISSM  ISSM source/build tree (--with-issm)
#
# Usage:
#   ./scripts/submodules.sh [--with-icepack] [--with-issm]
#
# Existing installations keep working without a rebuild:
#   * A checkout made before the switch back to submodules still holds the old
#     tracked ICESEE/ and spack/ directories, or what git leaves of them after
#     a pull (ignored/untracked files only). Those leftovers are moved aside,
#     the submodule is checked out, and the leftovers are copied back without
#     overwriting tracked files.
#   * An Icepack or ISSM directory that already holds its own clone (the old
#     build_icepack.sh / build_issm.sh layout) is used as it is: it is never
#     re-checked-out, so its build stays valid. Set ICESEE_SUBMODULES_FORCE=1
#     to move such a clone to the pinned commit.
# -----------------------------------------------------------------------------
set -euo pipefail

log(){ echo "[submodules] $*"; }
die(){ echo "[submodules][ERROR] $*" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE="${ICESEE_SUBMODULES_FORCE:-0}"

WITH_ICEPACK=0
WITH_ISSM=0
for arg in "$@"; do
  case "$arg" in
    --with-icepack) WITH_ICEPACK=1 ;;
    --with-issm) WITH_ISSM=1 ;;
    -h|--help) sed -n '3,24p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) die "unknown option: $arg" ;;
  esac
done

[[ -e "${ROOT}/.git" ]] || die "${ROOT} is not a git checkout; clone with: git clone --recurse-submodules https://github.com/ICESEE-project/ICESEE-Spack.git"
command -v git >/dev/null 2>&1 || die "git not found"

pinned_commit(){ git -C "${ROOT}" ls-tree HEAD "$1" | awk '$2 == "commit" {print $3}'; }

# A path holds its own git checkout (a populated submodule or an old clone).
has_own_git(){ [[ -e "${ROOT}/$1/.git" ]]; }

# Move leftovers of a pre-submodule tracked directory out of the way, check the
# submodule out, then restore the leftovers (ignored build/cache files) on top.
migrate_tracked_dir(){
  local path="$1" dir="${ROOT}/$1" aside
  [[ -d "${dir}" ]] && ! has_own_git "${path}" && [[ -n "$(ls -A "${dir}" 2>/dev/null)" ]] || return 0
  aside="${dir}.pre-submodule.$(date +%Y%m%d%H%M%S)"
  log "${path}: moving the pre-submodule directory aside to ${aside}"
  mv "${dir}" "${aside}"
  git -C "${ROOT}" submodule update --init -- "${path}"
  # copy back installs, caches and builds; never overwrite a checked-out file
  cp -a -n "${aside}/." "${dir}/"
  log "${path}: restored untracked files; the old copy stays at ${aside} until you remove it"
}

sync_required(){
  local path="$1"
  git -C "${ROOT}" submodule init -- "${path}" >/dev/null
  migrate_tracked_dir "${path}"
  log "${path}: checking out pinned $(pinned_commit "${path}" | cut -c1-12)"
  git -C "${ROOT}" submodule update --init -- "${path}"
}

sync_optional(){
  local path="$1" pin head
  pin="$(pinned_commit "${path}")"
  git -C "${ROOT}" submodule init -- "${path}" >/dev/null
  if has_own_git "${path}"; then
    head="$(git -C "${ROOT}/${path}" rev-parse HEAD 2>/dev/null || true)"
    if [[ "${head}" == "${pin}" ]]; then
      log "${path}: at pinned ${pin:0:12}"
    elif [[ "${FORCE}" == "1" ]]; then
      log "${path}: moving ${head:0:12} -> pinned ${pin:0:12} (ICESEE_SUBMODULES_FORCE=1; rebuild it afterwards)"
      git -C "${ROOT}/${path}" fetch --depth 1 origin "${pin}"
      git -C "${ROOT}/${path}" checkout --detach "${pin}"
    else
      log "${path}: keeping the existing checkout at ${head:0:12} (pinned: ${pin:0:12}); no rebuild needed"
    fi
    return 0
  fi
  log "${path}: checking out pinned ${pin:0:12}"
  # icepack and externals/ISSM are update = none, so recursive clones skip them
  git -C "${ROOT}" submodule update --init --checkout -- "${path}"
}

sync_required ICESEE
sync_required spack
# an Icepack/ISSM tree outside the submodule path (explicit prefix, or ISSM
# built in the pre-submodule externals location) is used instead of the submodule
EXTERNALS="${ICESEE_EXTERNALS_ROOT:-$ROOT/.icesee-spack/externals}"
ISSM_ELSEWHERE="${ISSM_PREFIX:-${ISSM_DIR:-}}"
[[ -z "${ISSM_ELSEWHERE}" && -d "${EXTERNALS}/ISSM/.git" ]] && ISSM_ELSEWHERE="${EXTERNALS}/ISSM"
if [[ "${WITH_ICEPACK}" -eq 1 ]]; then
  if [[ -n "${ICEPACK_PREFIX:-}" && "${ICEPACK_PREFIX}" != "${ROOT}/icepack" ]]; then
    log "icepack: using ICEPACK_PREFIX=${ICEPACK_PREFIX} instead of the submodule"
    WITH_ICEPACK=0
  else
    sync_optional icepack
  fi
fi
if [[ "${WITH_ISSM}" -eq 1 ]]; then
  if [[ -n "${ISSM_ELSEWHERE}" && "${ISSM_ELSEWHERE}" != "${ROOT}/externals/ISSM" ]]; then
    log "externals/ISSM: using the ISSM tree at ${ISSM_ELSEWHERE} instead of the submodule"
    WITH_ISSM=0
  else
    sync_optional externals/ISSM
  fi
fi

log "done"
git -C "${ROOT}" submodule status -- ICESEE spack \
  $([[ "${WITH_ICEPACK}" -eq 1 ]] && echo icepack) \
  $([[ "${WITH_ISSM}" -eq 1 ]] && echo externals/ISSM) || true
