# Contributing to ICESEE-Spack

ICESEE-Spack manages installation, environments and bundled source. Contributions should make installations reproducible and preserve scientific behavior.

## Choose the repository

Parent installer/activation scripts, `icesee-spack/`, `requirements/`, `spack.yaml`, and parent documentation belong here. ICESEE source under `ICESEE/` belongs upstream in ICESEE; use a subtree split rather than pushing parent history there. Read [the subtree guide](docs/wiki/Home.md) and ICESEE's [own contribution guide](ICESEE/CONTRIBUTING.md) for source changes. Keep third-party license and attribution files intact.

## Start a focused branch

From a clean checkout, fetch the authoritative parent and create a branch. If `origin` is your fork, configure/fetch the official parent as `upstream` first.

```bash
git fetch origin
git switch -c contribution/my-change origin/main
git status --short --branch
```

Use a separate worktree when an existing checkout contains installations, research edits or running jobs. Local remotes and untracked environments are not copied into a new clone/worktree.

## Validation

For documentation, check local links and review examples:

```bash
python3 scripts/publish_wiki.py --check
python3 -m unittest discover -s scripts/tests -v
```

The publisher tests use temporary local Git repositories and do not contact GitHub. For shell changes, run syntax checks on the files changed, for example `bash -n scripts/install.sh`; then run relevant functional checks in a suitable environment. Do not run an installer or submit Slurm work merely to check syntax.

For scientific/MPI changes, report the source IDs, dependency versions, topology, ensemble size, timestep, tests, output location and exit codes. Check checkpoints/restart, owned global indices and deterministic RNG behavior where affected. Preserve model-agnostic shared runtime interfaces and ISSM support. Explain any proposed scientific or numerical parameter changes explicitly before running comparisons. Do not claim scaling or scientific equivalence from a small smoke test.

## Review and commit

```bash
git diff --check
git diff
# Stage explicit reviewed paths, then inspect the staged result.
git diff --cached --check
git diff --cached
```

Do not commit environments, caches, simulation outputs, private scheduler logs, credentials, or large data. A `.gitignore` rule does not untrack existing files and is not a substitute for inspecting the staged diff. Keep parent-only changes separate from ICESEE source changes when practical. Preserve subtree merge trailers.

Commit with a concrete description and push your branch to the matching parent fork/repository. Open a pull request describing the problem, resulting behavior, validation and limitations. The PR template includes subtree-specific checks. If an ICESEE export is also needed, link both reviews and state the merge order. Do not force-push over collaborators' work or merge merely because a branch is published.

## Reports and conduct

Use the issue templates for installation/runtime bugs and feature requests. Include reproducible commands and sanitized logs. Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md). The project [Code of Conduct](CODE_OF_CONDUCT.md) applies to contributions.
