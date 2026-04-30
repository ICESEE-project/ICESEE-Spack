# ICESEE-Spack

Spack-based installer and environment manager for **ICESEE** and its
scientific dependencies (MPI, PETSc, HDF5, Python, etc.), designed for
HPC clusters.

This repository provides: - A reproducible Spack environment with petsc, openmpi and hdf5 - Optional ISSM,
Firedrake, and Icepack integration - Clean separation between
Spack-managed and pip-only Python dependencies

---

# Quick Start (Recommended)

``` bash
git clone https://github.com/ICESEE-project/ICESEE-Spack.git && cd ICESEE-Spack && ./scripts/install.sh --with-issm --with-icepack
```
>Note: Adjust SLURM_DIR and PMIX_DIR to match your system if needed.

After installation, activate the environment:

``` bash
source scripts/activate.sh
```

---

# Installation Options

## Default Install

Installs: - ICESEE (from pinned submodule) - Python (via Spack) - PETSc
(Spack-managed) - MPI-enabled HDF5 + h5py - OpenMPI (external or
auto-built) - pip-only Python dependencies from ICESEE/pyproject.toml

``` bash
./scripts/install.sh
```

---

## Install with ISSM

Builds ISSM and uses: - External OpenMPI - Its own internally built
PETSc

Requires MATLAB available on the cluster.

``` bash
./scripts/install.sh --with-issm
```

---

## Install with Firedrake

Installs Firedrake using: - PETSc built via Spack - MPI built via Spack

``` bash
./scripts/install.sh --with-firedrake
```

---

## Install with Icepack

Installs: - Firedrake - Icepack (depends on Firedrake)

``` bash
./scripts/install.sh --with-icepack
```

---

# Environment Activation

The environment is activated by sourcing:

``` bash
source scripts/activate.sh
```

This ensures: - Spack environment is active - Correct Python is
selected - Correct MPI (matching PETSc) is used - ISSM environment (if
installed) is loaded


# Testing

Run basic tests:

``` bash
./scripts/test.sh
```

If ISSM is installed:

``` bash
./scripts/test_issm.sh
```

# Notes

-   Always activate the environment before running ICESEE.
-   Ensure MPI used for Firedrake matches MPI used to build PETSc.

---

# Support

For issues or contributions, contact me via: briankyanjo@u.boisestate.edu
