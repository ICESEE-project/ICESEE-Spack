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


## Runtime follow-up pending multi-node validation

The follow-up adds native Mode-3 per-member flowline files, root-only HDF5
writes after collective bounded point sampling, restart-preserved columns,
explicit written_steps/profile_times metadata, and NaN for unsaved columns.
Truth/wrong-reference diagnostic saves now use completed steps (k+1), including
the final step. The model trajectory and forcing are unchanged. The notebook
uses ICESEE_DATA_PATH when set and retains the extensionless-file fallback.

A lifecycle correction releases the cached group context and the owned MPI
splits after the final report, before PyOP2 interpreter teardown. The observed
production failure was MPI_ERR_COMM in PyOP2's communicator delete callback;
single-process mesh and checkpoint roundtrips exited successfully both with
and without explicit release, so the production failure has not yet been
reproduced or proven fixed. No external dependency was patched.

The prepared ICESEE/.../pace/runtime_check.sbatch requests two nodes, four
ranks total, 32 GiB per node, and a 20-minute walltime limit. It runs two
members with two spatial ranks each, dt=0.05 for one model year, then resumes
the completed checkpoint. Diagnostic-only save times are overridden for this
test to 0.05, 0.1, and 1.0 years; production params.yaml remains unchanged.
It checks fresh-run exit, truth/member files, finite saved profiles, exact
written step indices, resume exit, and unchanged profile files after resume.
Submission requires authorization. It is not an equivalence or scaling study.

```bash
export ICESEE_SPACK_ROOT="$HOME/r-arobel3-0/ICESEE-Spack"
export ICESEE_SOURCE_ROOT="/path/to/repaired/ICESEE-Spack/ICESEE"
sbatch "$ICESEE_SOURCE_ROOT/applications/icepack_model/examples/idealized_pig/pace/runtime_check.sbatch"
```
