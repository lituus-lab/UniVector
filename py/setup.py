# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Build univector._core, a Cython extension over the UniVector C ABI.

A repository checkout links the native library built by ``nimble pyLib``.
An extracted source distribution builds the vendored Nim project in
``_nimsrc``; Nim and Nimble must be available on PATH.
"""
import os
import shutil
import subprocess
import sys

from Cython.Build import cythonize
from setuptools import Extension, setup

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
PKG_DIR = os.path.join(HERE, "univector")
VENDOR_DIR = os.path.join(HERE, "_nimsrc")
NIMBLE_FILE = "UniVector.nimble"
VENDOR_FILES = [NIMBLE_FILE, "config.nims", "vgraph.cfg"]
VENDOR_DIRS = ["src", "include"]

if sys.platform == "win32":
    LIB_NAME, BUNDLED = "UniVector.lib", False
    LINK_ARGS, NIMBLE_TASK = [], "clibMsvc"
elif sys.platform == "darwin":
    LIB_NAME, BUNDLED = "libUniVector.dylib", True
    LINK_ARGS, NIMBLE_TASK = ["-Wl,-rpath,@loader_path"], "clib"
else:
    LIB_NAME, BUNDLED = "libUniVector.so", True
    LINK_ARGS, NIMBLE_TASK = ["-Wl,-rpath,$ORIGIN"], "clib"


def vendor_nim_source():
    """Copy the files needed for a standalone Nim build into the sdist."""
    if os.path.exists(VENDOR_DIR):
        shutil.rmtree(VENDOR_DIR)
    os.makedirs(VENDOR_DIR)
    for filename in VENDOR_FILES:
        shutil.copy2(os.path.join(ROOT, filename), os.path.join(VENDOR_DIR, filename))
    for dirname in VENDOR_DIRS:
        shutil.copytree(os.path.join(ROOT, dirname), os.path.join(VENDOR_DIR, dirname))


def nim_project_dir():
    if os.path.exists(os.path.join(ROOT, NIMBLE_FILE)):
        return ROOT
    if os.path.exists(os.path.join(VENDOR_DIR, NIMBLE_FILE)):
        return VENDOR_DIR
    return None


def ensure_lib_built():
    prebuilt = os.path.join(ROOT, LIB_NAME)
    if os.path.exists(prebuilt):
        return prebuilt
    project = nim_project_dir()
    if project is None:
        raise SystemExit(
            f"setup.py: {prebuilt} not found — run `nimble {NIMBLE_TASK}` first."
        )
    built = os.path.join(project, LIB_NAME)
    if os.path.exists(built):
        return built
    try:
        subprocess.check_call(["nimble", "install", "-y", "-d"], cwd=project)
        subprocess.check_call(["nimble", NIMBLE_TASK], cwd=project)
    except FileNotFoundError as error:
        raise SystemExit(
            "setup.py: `nimble` not found on PATH. Building univector from "
            "source needs Nim (https://nim-lang.org/install.html)."
        ) from error
    except subprocess.CalledProcessError as error:
        raise SystemExit(f"setup.py: `nimble {NIMBLE_TASK}` failed: {error}") from error
    if not os.path.exists(built):
        raise SystemExit(f"setup.py: `nimble {NIMBLE_TASK}` did not produce {built}")
    return built


if "sdist" in sys.argv:
    vendor_nim_source()
    include_dir, library_dir = os.path.join(ROOT, "include"), ROOT
else:
    library_path = ensure_lib_built()
    library_dir = os.path.dirname(library_path)
    include_dir = os.path.join(ROOT, "include")
    if not os.path.isdir(include_dir):
        include_dir = os.path.join(VENDOR_DIR, "include")
    if BUNDLED:
        os.makedirs(PKG_DIR, exist_ok=True)
        shutil.copy2(library_path, os.path.join(PKG_DIR, LIB_NAME))

pyx = os.path.join("univector", "_core.pyx")
source = pyx if os.path.exists(os.path.join(HERE, pyx)) else os.path.join(
    "univector", "_core.c"
)
extension = Extension(
    "univector._core",
    sources=[source],
    include_dirs=[include_dir],
    library_dirs=[library_dir],
    extra_link_args=LINK_ARGS,
    libraries=["UniVector"],
)
ext_modules = (
    cythonize([extension], language_level=3) if source.endswith(".pyx") else [extension]
)

setup(
    ext_modules=ext_modules,
    include_package_data=True,
    package_data={"univector": [LIB_NAME] if BUNDLED else []},
    exclude_package_data={"univector": ["_core.c"]},
    zip_safe=False,
)
