# October 16, 2026 PACE validation record

This is a historical test record; verify current source and environment before relying on it.

## PACE integration and validation, 2026-10-16

The repaired parent retains the ICESEE/ subtree and newer installer changes
from ICESEE-Spack main. It incorporates ICESEE main 904f2710 plus reviewed
student updates from features 0491b6ad. The approved unperturbed initial
thickness and copied basal-melt fields are retained. The water-to-ice
conversion and physical/scientific parameter file remain unchanged.

Native Mode 3 now writes hs_ensemble_profiles{member_id}.h5; the truth file is
hs_profiles_true.h5. These are HDF5 files, not directories. All output follows
data_path. Production launchers default to _modelrun_datasets and refuse to
overwrite an existing directory. Earlier job 14053366 wrote its truth file in
pig_da40_Ne20_14053366/data, while older nested outputs used hs_profiles_true
without an extension. The notebook supports ICESEE_DATA_PATH and the old
extensionless truth-file name.

Diagnostic point sampling is vectorized with a strict point-location tolerance
to avoid extrapolated, conflicting values on overlapping mesh partitions.
The mesh tolerance is restored after sampling. Truth and ensemble profiles
use the same physical points. Root-only per-member HDF5 writes avoid concurrent
serial opens. Files record profile_times and written_steps; unsaved columns
are NaN. Requested saves use completed model steps, including the final step.
Restart preserves existing profile columns and does not regenerate initial
ensemble diagnostics. Checkpoint schema, durability, RNG and owned-row mapping
are unchanged.

Mode 3 skips the unused legacy driver initialization, avoiding duplicated
checkpoint reads, diagnostic solves and retained model contexts. Its runner
still builds one reference context on world root and one native context per
model group. Fractional run lengths now use the dt-derived time grid rather
than truncating the final year to an integer. The reference uses Firedrake's
managed COMM_SELF, and the runner releases its native context and owned MPI
splits before interpreter teardown. No installed dependency was patched.

### Verified results

PACE non-scheduler regressions: 113 passed, 1 skipped, 4 deselected.

Slurm job 14104838: two nodes, four ranks, two members, two spatial ranks per
member, dt=0.05, two forecast steps (0.1 model years). Fresh simulation and
completed-checkpoint resume both exited 0; total job elapsed 3m48s, fresh step
2m34s and resume step 54s. Both stderr logs are empty. Truth and both member
files contain 415 physical points with three finite columns (initial, 0.05,
0.1 years); profile hashes are unchanged after resume. Node-local /tmp cache
placement was confirmed on both nodes in the preceding equivalent test.
This validates the tested topology and short workflow, not production-scale
convergence, scaling, interrupted mid-run recovery, or equivalence across
all execution modes.

### Remaining issues

The earlier one-year diagnostic 14104270 reached the forecast loop and wrote
checkpoint step 9, then failed with DIVERGED_MAX_IT in the velocity solver.
Installed Icepack defaults to PETSc SNES, but the application supplies the
older max_iterations/tolerance keys. The observed limit was 50 iterations,
not the intended 150. Solver limits and tolerances were not changed; a
reviewed solver-configuration correction and longer scientific validation
are still required before calling this production-ready.

Checkpoint I/O remains slow: the short final test reported 12.99 MB of logical
payload in 18.663 seconds. This includes shared-storage writes, synchronization
and durable commits; it is not a raw filesystem bandwidth measurement. Do not
remove fsync or change retention to hide this cost. Further profiling should
separate shard write, fsync, directory operations and collective wait times.

### Reproduce the short runtime check

The prepared test requests two nodes, four ranks total, 32 GiB per node and a
20-minute walltime limit. It uses a unique pace_runs directory and overrides
only the diagnostic run length, observation window and save times. It does
not edit params.yaml. Scheduler submission requires authorization.

```bash
export ICESEE_SPACK_ROOT="$HOME/r-arobel3-0/ICESEE-Spack"
export ICESEE_SOURCE_ROOT="/path/to/repaired/ICESEE-Spack/ICESEE"
sbatch "$ICESEE_SOURCE_ROOT/applications/icepack_model/examples/idealized_pig/pace/runtime_check.sbatch"
```

To read a job-specific output directory in read_results.ipynb, set
ICESEE_DATA_PATH to its data directory before starting the notebook kernel,
or set results_dir explicitly in the notebook. For existing production runs,
do not move or delete the output merely to match the notebook's default.
