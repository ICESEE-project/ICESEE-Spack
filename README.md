# ICESEE-Spack

Spack-based installer and environment manager for **ICESEE** and its scientific
dependencies (MPI, HDF5, Python, etc.), designed for **HPC clusters**.

This repository provides:
- A reproducible Spack environment
- Automated OpenMPI bootstrapping (when system MPI is unavailable)
- A single install script that works across clusters
- Clean separation between Spack-managed and pip-only Python dependencies

---

## 🚀 Quick Install (One-Line)

```bash
git clone --recurse-submodules https://github.com/ICESEE-project/ICESEE-Spack.git && \
cd ICESEE-Spack && \
SLURM_DIR=/opt/slurm/current PMIX_DIR=/opt/pmix/5.0.1 ./scripts/install.sh
```

---