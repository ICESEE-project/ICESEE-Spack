# Contributing and review

## Choose the destination

| Change | Primary PR destination |
| --- | --- |
| Installer, activation, local Spack packages, dependency requirements, parent docs | ICESEE-Spack |
| Forecast, assimilation, model adapters, scientific example code, ICESEE tests | ICESEE |
| Third-party Spack implementation | Spack upstream, with a reviewed parent import if needed |
| Generated outputs, personal scheduler logs, installed environments | Keep local; do not commit |

When editing ICESEE inside this parent, commit the prefixed source changes and export them with [the split workflow](Exporting-ICESEE-changes.md). A push of the parent branch to ICESEE is not a substitute for splitting. If both parent and ICESEE PRs are needed, link them and describe the dependency/order of merges.

## Before a PR

- Start from a current, verified parent branch and preserve local work.
- Keep changes focused and explain the user-visible behavior.
- Record imported upstream commit IDs and any remaining local deviations.
- Run checks appropriate to the change; include commands and results.
- For scientific/MPI changes, state topology, RNG assumptions, checkpoint behavior, and limits of validation.
- Review the staged diff for datasets, credentials, output artifacts and unintended bundled-source changes.
- Preserve licenses and existing contributor attribution.

Use `git diff --check` for whitespace problems. Documentation changes need link and example review, not a production Slurm job. Installer changes require shell syntax checks and relevant environment testing; running an installer is not a harmless syntax check.

## Student workflow after a merge

For a standalone ICESEE clone whose `origin` points to the official ICESEE repository:

```bash
git status --short --branch
git fetch origin
git switch main
git pull --ff-only origin main
```

For an ICESEE fork, fetch and merge the official `upstream/main` instead. Preserve local scientific edits before switching/updating. For an ICESEE-Spack clone, pull the parent to receive its recorded subtree; import newer ICESEE upstream only when that parent update is intended.

A feature branch being pushed is not the same as being merged. Share the exact repository, branch/commit, review status, and tested limitations when asking someone to fetch it.

## Community and security

The parent contribution guide and PR template describe the repository workflow. ICESEE source changes also follow its bundled `CONTRIBUTING.md`. Project conduct and security contacts are inherited from the project documents; suspected vulnerabilities should be reported privately rather than in a public bug report.
