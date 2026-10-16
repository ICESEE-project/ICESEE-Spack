# ICESEE-Spack

Spack-based installer and environment manager for **ICESEE** and its
scientific dependencies (MPI, PETSc, HDF5, Python, etc.), designed for
HPC clusters.

This repository provides: - A reproducible Spack environment with petsc, openmpi and hdf5 - Optional ISSM,
Firedrake, and Icepack integration - Clean separation between
Spack-managed and pip-only Python dependencies

---
# Choosing a Version
ICESEE-Spack currently supports two Icepack/Firedrake installation tracks.
## Stable Legacy Version — Recommended
Use this version for current ICESEE Icepack examples, especially codes that still use `icepack.interpolate(...)`.
```bash
git clone https://github.com/ICESEE-project/ICESEE-Spack.git
cd ICESEE-Spack
git checkout v0.1.0-icepack-legacy
./scripts/install.sh --with-issm --with-icepack
```
This stack uses:

* Firedrake 2025.4.2
* PETSc 3.23.4
* petsc4py 3.23.4
* Icepack compatible with the existing interpolation workflow

Modern Version — Experimental

Use this version only if you want the newer Firedrake/Icepack stack and are prepared to update interpolation calls.

```bash
git clone https://github.com/ICESEE-project/ICESEE-Spack.git
cd ICESEE-Spack
git checkout v0.2.0-icepack-modern
./scripts/install.sh --with-issm --with-icepack
```
This stack uses:

* Firedrake 2025.10.2
* PETSc 3.24.0
* petsc4py 3.24.0

The modern stack may require replacing direct icepack.interpolate(...) calls with a compatibility wrapper.

# Quick Start (Recommended)
```bash
git clone https://github.com/ICESEE-project/ICESEE-Spack.git
cd ICESEE-Spack
git checkout v0.1.0-icepack-legacy
./scripts/install.sh --with-issm --with-icepack
```
After installation, activate the environment:

``` bash
source scripts/activate.sh
```

---

# Installation Options

## Default Install

Installs: - ICESEE (from pinned submodule) - Python (via Spack) - PETSc
(Spack-managed) - MPI-enabled HDF5 + h5py - OpenMPI (auto-built) - pip-only Python dependencies from ICESEE/pyproject.toml

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
>Note: must be inside ICESEE-Spack.
---

## Install with Icepack

Installs: - Firedrake - Icepack (depends on Firedrake)

``` bash
./scripts/install.sh --with-icepack
```
>Note: must be inside ICESEE-Spack.
---

# Environment Activation

The environment is activated by sourcing:

``` bash
source scripts/activate.sh
```
>Note: must be inside ICESEE-Spack.
>
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
