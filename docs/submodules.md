# Pinned dependencies (git submodules)

ICESEE-Spack pins the source of every git-hosted dependency as a submodule.
The parent commit records the exact commit of each one:

| Path             | Repository                                   | Populated            |
|------------------|----------------------------------------------|----------------------|
| `ICESEE/`        | https://github.com/ICESEE-project/ICESEE.git | always               |
| `spack/`         | https://github.com/spack/spack.git (shallow) | always               |
| `icepack/`       | https://github.com/icepack/icepack.git       | `--with-icepack`     |
| `externals/ISSM` | https://github.com/ISSMteam/ISSM.git         | `--with-issm`        |

OpenMPI is downloaded as a release tarball and Firedrake is installed from
PyPI at pinned versions; neither is a git dependency.

## Clone

```bash
git clone --recurse-submodules https://github.com/ICESEE-project/ICESEE-Spack.git
```

A plain `git clone` also works: `scripts/install.sh` runs
`scripts/submodules.sh`, which populates ICESEE and Spack, plus Icepack and
ISSM when those models are requested. After switching branches or tags, run
`scripts/submodules.sh` (or `git submodule update --init`) again.

## Existing installations

Checkouts made while ICESEE/ and spack/ were subtrees keep working without a
rebuild:

- `git pull` removes the old tracked ICESEE/ and spack/ files.
  `scripts/submodules.sh` moves what is left (ignored build and cache files)
  aside, checks the submodule out, and copies those files back. The old copy is
  kept at `<path>.pre-submodule.<timestamp>`; delete it once the environment
  checks out.
- An ISSM built under `.icesee-spack/externals/ISSM` stays in use: `activate.sh`,
  `install.sh` and `build_issm.sh` prefer it over the `externals/ISSM`
  submodule, and `build_issm.sh` skips a build that already has
  `bin/issm.exe` (set `ISSM_REBUILD=1` to rebuild).
- An existing `icepack/` clone is used at its current commit.
  `ICESEE_SUBMODULES_FORCE=1 scripts/submodules.sh --with-icepack --with-issm`
  moves existing Icepack/ISSM checkouts to the pinned commits; rebuild them
  afterwards.

`ISSM_PREFIX`/`ISSM_DIR` and `ICEPACK_PREFIX` still select a tree outside the
submodules.

## Update a pin

Work on a branch, move the submodule to the reviewed commit, test the
installation, and commit the new gitlink:

```bash
git switch -c update-icesee
git -C ICESEE fetch origin main
git -C ICESEE checkout <reviewed-commit>     # e.g. origin/main once merged
git add ICESEE
git commit -m "Pin ICESEE <short-sha>"
```

The same applies to `spack` (choose a reviewed release tag), `icepack`, and
`externals/ISSM`. Changing a pin does not update installed environments:
rebuild the affected component (`ISSM_REBUILD=1`, or re-run
`scripts/install.sh --with-icepack`) and run the tests.

## Change ICESEE

Make ICESEE changes in the ICESEE repository (a branch and pull request there),
then move the `ICESEE` pin to the merged commit. Commits made inside the
`ICESEE/` submodule belong to ICESEE; push them to ICESEE before committing
the new pin here, or the pinned commit will not be fetchable.
