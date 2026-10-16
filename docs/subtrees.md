# Maintaining bundled source trees

Run these commands from the ICESEE-Spack repository root. ICESEE/ and spack/
are ordinary tracked directories (Git tree mode 040000), not Git submodules.
Do not change the parent branch to a standalone ICESEE branch or use submodule
update for these directories. Keep environment installations and datasets out of commits.

## Update ICESEE from upstream

Start with a clean working tree and a separate update branch. Preserve local
changes before proceeding. Git must provide the git subtree command.

```bash
git switch -c update-icesee
git remote add icesee https://github.com/ICESEE-project/ICESEE.git # once only
git fetch icesee
git subtree pull --prefix=ICESEE icesee main --squash
```

Resolve any conflicts by reviewing both versions. Run relevant ICESEE tests
using the installed scientific environment before publishing the parent branch.
To integrate a reviewed ICESEE feature branch, replace main above with its name.
Only use main after the desired feature has actually been merged there.

## Export ICESEE edits upstream

Commit ICESEE changes in the parent repository first. Export only the subtree,
then verify that the export contains current upstream main. Use an explicit,
nonempty source ref when pushing; an empty source deletes the destination.

```bash
git fetch icesee main
git subtree split --prefix=ICESEE --branch icesee-export
git merge-base --is-ancestor icesee/main icesee-export
git diff --stat icesee/main icesee-export
git push icesee refs/heads/icesee-export:refs/heads/your-feature-branch
```

Run commands individually and stop on any error. Never push the parent
ICESEE-Spack history directly into ICESEE. After upstream review and merge,
update the parent with subtree pull again. Do not assume an exported branch
has been merged into main.

## Update bundled Spack

First inspect the existing subtree history and choose a reviewed release tag
compatible with the installation. Keep the Spack remote separate from ICESEE.

```bash
git remote add spack-upstream https://github.com/spack/spack.git # once only
git fetch spack-upstream --tags
# Replace REVIEWED_TAG with the release selected for this installation:
git subtree pull --prefix=spack spack-upstream REVIEWED_TAG --squash
```

Changing bundled Spack does not update installed environments automatically.
Review lockfiles and rebuild/test environments separately when required.

## PACE repair status, 2026-10-16

The repair preserves the parent/subtree layout and incorporates upstream
ICESEE main 904f2710 and selected student scientific changes from features
0491b6ad. ICESEE export 154b9815 is published on idealized-pig-update.
It includes unperturbed initial thickness as approved, copied basal-melt
fields, configured legacy profile save times, the student results notebook,
source/environment discovery, node-local compilation caches, and guarded
_modelrun_datasets output selection. Water-to-ice conversion remains at the
upstream main value. Existing PACE integration fixes are retained from main.

PACE non-scheduler validation: 97 passed, 1 skipped, 4 deselected. These checks
do not establish multi-node scientific equivalence or production performance.
The original active installation and its dirty source files were preserved.
Job 14053366 completed the simulation path but failed during MPI/PyOP2
communicator teardown with exit 134. Native Mode-3 ensemble flowline output
still needs implementation/validation. Both issues remain under investigation;
the update must not be described as a verified production runtime fix.
