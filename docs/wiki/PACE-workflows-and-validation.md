# PACE source, environment, output, and validation

Git updates are not scheduler submissions. Follow current PACE user guidance and allocation limits; run production solves and MPI jobs through Slurm. Small read-only checks and permitted lightweight local tests can be used to inspect state. Do not switch or rewrite the source directory used by a running job.

## Identify the live source of truth

```bash
cd ~/r-arobel3-0/ICESEE-Spack
hostname
git status --short --branch
git remote -v
git worktree list
git ls-tree HEAD ICESEE spack
squeue -u "$USER"
```

Check the actual branch and prefix instead of assuming historical repairs remain current. A directory named `ICESEE/` can contain residual datasets without being a runnable source checkout. A tracked subtree should have its source files and be a `040000 tree` in Git.

## Separate source and installed environment

A normal clone or worktree does not contain another checkout's untracked Spack environment, virtualenv or input files. The PIG PACE helpers accept separate roots:

```bash
export ICESEE_SPACK_ROOT="$HOME/r-arobel3-0/ICESEE-Spack"
export ICESEE_SOURCE_ROOT="/path/to/review-worktree/ICESEE"
```

Use the first for installed dependencies and the second for the tracked ICESEE source. Both must exist and be compatible. Review `pace/resolve_environment.sh` for discovery behavior. Do not run another install just to make a documentation worktree look like the production environment.

## Outputs and the student's profile files

`hs_profiles_true.h5` is an HDF5 file, not a folder. Member diagnostics use `hs_ensemble_profiles0.h5`, `hs_ensemble_profiles1.h5`, and so on. Earlier versions wrote `hs_profiles_true` without an extension. The reader retains that fallback.

Output follows the configured `data_path`. Updated launchers default to the example's `_modelrun_datasets` and refuse an existing target for a fresh run, because configuration loading can recreate the data directory. Set an explicit new target for a separate run:

```bash
export ICESEE_DATA_PATH="/path/to/new/run/data"
```

Set the same variable before starting the results-notebook kernel, or set `results_dir` in the notebook. An earlier job's output may instead be under `pig_da40_Ne20_JOBID/data/`; do not delete or move it merely to satisfy a notebook default. Resume requires the existing dataset directory and matching checkpoint configuration.

Requested profile years beyond the run length cannot have data. For example, a five-year run does not reach save years 34, 69 and 81. New profile files use NaN for unwritten columns and expose `profile_times` and `written_steps`. Preserve scientific parameters rather than changing them just to make every column nonempty.

## Caches and rank placement

The PACE rank launcher uses node-local `$TMPDIR` with a `/tmp` fallback when it detects shared storage. PyOP2 and TSFC caches are shared by ranks on the same node for that job; XDG/SQLite caches are rank-private. Logs print the host and cache path. More project-disk capacity alone does not make a shared filesystem suitable for compilation caches.

Keep each model group's spatial ranks on one node. Tasks per node must be a multiple of `model_nprocs`; use the launcher's block placement and validate the resulting topology. Do not infer layout merely from the total number of ranks.

## Validate and report honestly

For a source change, record parent and ICESEE upstream IDs, environment versions, node/rank layout, ensemble size, timestep, physical parameters, output location, exit code, and relevant tests. A two-step smoke test establishes only that small workflow. It does not establish long-run convergence, scaling, scientific parity across all modes, or interrupted-restart equivalence.

The versioned [PACE validation record](Validation-record-2026-10-16.md) describes the October 16 repair and its limits.

The runtime-check batch script performs a short two-node/four-rank fresh run and completed-checkpoint resume in a unique output directory. Inspect it before submitting; it consumes allocation resources:

```bash
# Submit only after allocation/user authorization.
sbatch "$ICESEE_SOURCE_ROOT/applications/icepack_model/examples/idealized_pig/pace/runtime_check.sbatch"
```

If a solver fails, report the convergence reason and effective solver settings. Do not silently relax tolerances, change initial perturbations, bypass durable checkpoints, or present a failed job as a performance result.
