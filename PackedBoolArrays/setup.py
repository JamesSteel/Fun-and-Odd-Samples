from distutils.core import setup, Extension
from Cython.Build import cythonize

ext_modules = [
    Extension(
        "BoolArrs",
        ["./BoolArrs.pyx"])
    ]

setup(
    name = "BoolArrs",
    ext_modules = cythonize(ext_modules),
    )
