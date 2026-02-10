from spack.package import *


class PyIcesee(PythonPackage):
    """ICESEE: Ice Sheet State and Parameter Estimator."""

    homepage = "https://github.com/ICESEE-project/ICESEE"
    git      = "https://github.com/ICESEE-project/ICESEE.git"

    # Prefer tags for releases; allow main.
    version("0.1.9", tag="v0.1.9")
    version("main", branch="main")

    # Special: install from the pinned submodule if present.
    # We use a Spack "develop" workflow by default through the installer script (see install.sh),
    # so users don't need to pass variants/versions.
    depends_on("python@3.11:", type=("build", "run"))
    depends_on("py-pip", type="build")
    depends_on("py-setuptools", type="build")
    depends_on("py-wheel", type="build")

    # Runtime deps (mirror your pyproject)
    depends_on("py-numpy", type=("build", "run"))
    depends_on("py-scipy", type=("build", "run"))
    depends_on("py-h5py", type=("build", "run"))
    depends_on("py-zarr@:2", type=("build", "run"))
    depends_on("py-dask", type=("build", "run"))
    depends_on("py-psutil", type=("build", "run"))
    depends_on("py-tqdm", type=("build", "run"))
    depends_on("py-pyyaml", type=("build", "run"))
    depends_on("py-numcodecs", type=("build", "run"))
    depends_on("py-gstools", type=("build", "run"))

    variant("mpi", default=True, description="Enable MPI support")
    depends_on("py-mpi4py", when="+mpi", type=("build", "run"))
    depends_on("py-bigmpi4py", when="+mpi", type=("build", "run"))