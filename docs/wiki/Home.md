# ICESEE-Spack documentation

ICESEE-Spack bundles ICESEE and Spack as Git subtrees. A normal clone includes their source. Installation environments, simulation outputs, and local remotes are separate from source history.

## Start here

- [How subtrees work](Subtree-basics.md): prefixes, parent history, squash imports, and submodules.
- [Everyday Git](Everyday-Git.md): clone, fetch, pull, branches, forks, and releases.
- [Update ICESEE](Updating-ICESEE.md): inspect upstream and integrate it into `ICESEE/`.
- [Export ICESEE contributions](Exporting-ICESEE-changes.md): split the subtree and submit upstream.
- [Update Spack and other subtrees](Updating-Spack-and-other-subtrees.md): pinned releases and new dependencies.
- [Troubleshooting and recovery](Troubleshooting-and-recovery.md): conflicts, dirty trees, wrong branches, and accidental deletion.
- [PACE workflows and validation](PACE-workflows-and-validation.md): environments, outputs, caches, jobs, and reproducibility.
- [Contributing and review](Contributing-and-review.md): choose the right repository and report meaningful validation.
- [Maintain this wiki](Maintaining-this-wiki.md): reviewed sources and publishing.

## Repository map

| Path | Purpose | Where changes belong |
| --- | --- | --- |
| `ICESEE/` | ICESEE source subtree | ICESEE upstream, then synchronize the parent |
| `spack/` | Bundled Spack source subtree | Reviewed Spack releases or upstream fixes |
| `scripts/` | Installation and activation | ICESEE-Spack |
| `icesee-spack/` | Local Spack package definitions | ICESEE-Spack |
| `requirements/`, `spack.yaml` | Dependency specifications | ICESEE-Spack |
| `docs/` | Reviewed guides and wiki sources | ICESEE-Spack |

Run subtree commands from the ICESEE-Spack root. Use a review branch, preserve local changes, and stop when a command fails. Updating source does not automatically rebuild an environment or establish scientific equivalence.

[Repository](https://github.com/ICESEE-project/ICESEE-Spack) · [ICESEE upstream](https://github.com/ICESEE-project/ICESEE)
