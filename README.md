# ICESEE-Spack

Spack-based installer and environment manager for **ICESEE** and its scientific
dependencies (MPI, HDF5, Python, etc.), designed for **HPC clusters**.

This repository provides:
- A reproducible Spack environment
- Automated OpenMPI bootstrapping (when system MPI is unavailable)
- A single install script that works across clusters
- Clean separation between Spack-managed and pip-only Python dependencies

---

##  Quick Install (One-Line)

```bash
git clone --recurse-submodules https://github.com/ICESEE-project/ICESEE-Spack.git && \
cd ICESEE-Spack && \
SLURM_DIR=/opt/slurm/current PMIX_DIR=/opt/pmix/5.0.1 ./scripts/install.sh 
```
Adjust SLURM_DIR and PMIX_DIR to match your system if needed.

### What This Installs
 - ICESEE (from pinned submodule)
 - Python (Spack)
 - MPI-enabled HDF5 + h5py
 - OpenMPI 5.0.7 (external or auto-built)
 - pip-only Python dependencies extracted from ICESEE/pyproject.toml

### Supported Environments
- SLURM-based HPC clusters
- RHEL / Rocky / Alma Linux
- System Spack or pinned Spack submodule

---

## Optional: Install + enable ISSM (`--with-issm`)

ICESEE can optionally couple to the **Ice Sheet System Model (ISSM)**. This requires a working **MATLAB** installation on the target system (cluster).

### Requirements
- **MATLAB** available on the cluster (via module or system install)
  - `matlab` executable must be available when running ICESEE-ISSM workflows
  - `MATLABROOT` should be set automatically by the MATLAB module on most clusters
- A compiler toolchain supported by your cluster (GCC is typical)
- MPI stack available (OpenMPI is recommended)
- (Recommended) Slurm if you intend to launch ensemble runs through the scheduler

### Install ISSM (automated)
To build ISSM as part of this repo automation:

```bash
SLURM_DIR=/opt/slurm/current PMIX_DIR=/opt/pmix/5.0.1 \
./scripts/install.sh --with-issm
```
You can also pass environment variables used by the installer:

```bash
ISSM_PREFIX=$HOME/.icesee-spack/externals/ISSM \
MATLAB_MODULE=matlab \
GCC_MODULE=gcc/13 \
./scripts/install.sh --with-issm
```

## Use an existing ISSM installation (no build)

If ISSM is already installed on your cluster, you can point ICESEE to it:
```bash
export ISSM_DIR=/path/to/ISSM
```

or load the cluster module that sets ISSM_DIR / modifies PATH.

**Notes**
- Building ISSM is cluster-dependent (MATLAB module name, PETSc settings, Slurm/PMIx paths).
- If your site provides a centrally managed ISSM module, prefer that for speed and consistency.
- You can validate your ISSM + MATLAB setup with:

```bash
./scripts/test_issm.sh
```

