# ICESEE-Spack
ICESEE spack repository for automating ICESEE installation, its environment  and dependencies. ICESEE will be installed via "spack install ICESEE"

## To install ICESEE
clone the Repo using:
```bash
git clone --recurse-submodules https://github.com/ICESEE-project/ICESEE-Spack.git
```
Install spack and ICESEE dependencies using
```bash
SLURM_DIR=/opt/slurm/current PMIX_DIR=/opt/pmix/5.0.1 ./scripts/install.sh
```
--Note: you can always set yor `PMI` and `SLURM_DIR` according to your environment
