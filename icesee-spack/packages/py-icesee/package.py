from spack.package import *

class PyIcesee(PythonPackage):
    """ICESEE: Ice Sheet State and Parameter Estimator."""

    homepage = "https://github.com/ICESEE-project/ICESEE"
    git      = "https://github.com/ICESEE-project/ICESEE.git"

    version("main", branch="main")

    depends_on("python@3.11:", type=("build", "run"))
    depends_on("py-pip", type="build")
    depends_on("py-setuptools", type="build")
    depends_on("py-wheel", type="build")

    variant("mpi", default=True, description="Enable MPI support")
    depends_on("mpi", when="+mpi")

    # ABI-sensitive: prefer Spack for these
    # depends_on("openmpi", when="+mpi")
    depends_on("hdf5+mpi", when="+mpi")