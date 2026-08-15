# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# UniVector — vector-graphics engine for the lituus-lab Uni* family.

version       = "1.0.0"
author        = "lituus-lab"
description   = "Extensible vector-graphics engine for the lituus-lab Uni* family (Nim + C-ABI + Python)"
license       = "Apache-2.0"
srcDir        = "src"

requires "nim >= 2.0.0"
requires "https://github.com/lbartoletti/NimContracts#main"
requires "https://github.com/lituus-lab/UniLinalg#main"
requires "https://github.com/lituus-lab/UniColor#main"
requires "https://github.com/lituus-lab/UniImage#main"

task lint, "Fail if nimpretty would reformat a source":
  exec "nim c -r --hints:off -o:build/lint_tool tools/lint.nim"

task checkVGraph, "Fail on an import that climbs the layers in vgraph.cfg":
  exec "nim c -r --hints:off -o:build/vgraph_tool tools/vgraph.nim"

task docsDeps, "Install the docs toolchain (nimib)":
  exec "nimble install -y nimib"

task book, "Build the nimib book (needs nimib)":
  # nimib compiles and runs the book's code blocks: a drift fails the build.
  exec "nim c -r --path:src --hints:off -o:build/book book/index.nim"

task docs, "API reference + book into pages/ — what CI publishes":
  rmDir "pages"
  exec "nim doc --index:on --outdir:pages/api --project --hints:off src/UniVector.nim"
  exec "nimble book"
  # The book is the landing page; the generated reference sits under api/.
  cpFile "book/index.html", "pages/index.html"

task test, "Nim tests (debug, contracts active)":
  exec "nim c -r --path:src -o:build/test_version tests/test_version.nim"
  exec "nim c -r --path:src -o:build/test_path tests/test_path.nim"
  exec "nim c -r --path:src -o:build/test_flatten tests/test_flatten.nim"
  exec "nim c -r --path:src -o:build/test_prepared tests/test_prepared.nim"
  exec "nim c -r --path:src -o:build/test_stroke tests/test_stroke.nim"
  exec "nim c -r --path:src -o:build/test_raster tests/test_raster.nim"
  exec "nim c -r --path:src -o:build/test_svg tests/test_svg.nim"

task testRelease, "Nim tests (release, contracts compiled away)":
  exec "nim c -r -d:release --path:src -o:build/test_version_rel tests/test_version.nim"
  exec "nim c -r -d:release --path:src -o:build/test_path_rel tests/test_path.nim"
  exec "nim c -r -d:release --path:src -o:build/test_flatten_rel tests/test_flatten.nim"
  exec "nim c -r -d:release --path:src -o:build/test_prepared_rel tests/test_prepared.nim"
  exec "nim c -r -d:release --path:src -o:build/test_stroke_rel tests/test_stroke.nim"
  exec "nim c -r -d:release --path:src -o:build/test_raster_rel tests/test_raster.nim"
  exec "nim c -r -d:release --path:src -o:build/test_svg_rel tests/test_svg.nim"

task testCi, "Nim tests (CI subset, debug)":
  exec "nimble test"

task testCiRelease, "Nim tests (CI subset, release)":
  exec "nimble testRelease"

task testAll, "debug + release + C ABI":
  exec "nimble test"
  exec "nimble testRelease"
  exec "nimble ctest"

task univector, "Build the univector CLI (render to PNG + SVG)":
  exec "nim c --path:src -o:bin/univector bin/univector_cli.nim"

# Nim takes `-o:` literally and appends no platform extension.
const
  sharedLib =
    when defined(windows): "libUniVector.dll"
    elif defined(macosx): "libUniVector.dylib"
    else: "libUniVector.so"
  staticLib = "libUniVector.a"  # MinGW `ar` on Windows, so `.a` everywhere.

  # @rpath install_name, so the copy bundled in the wheel is found at import.
  macArgs =
    when defined(macosx): " --passL:\"-Wl,-install_name,@rpath/" & sharedLib & "\""
    else: ""

task clib, "C shared library":
  exec "nim c --app:lib --noMain --mm:arc -d:release -o:" & sharedLib & macArgs &
       " src/UniVector/c_api.nim"

task clibStatic, "C static library":
  exec "nim c --app:staticlib --noMain --mm:arc -d:release -o:" & staticLib &
       " src/UniVector/c_api.nim"

task clibMsvc, "C static library, MSVC ABI (Windows Python extension)":
  # CPython on Windows is MSVC-built and cannot link MinGW output. MSVC's
  # linker takes the lib name verbatim (no `lib` prefix, unlike MinGW), so the
  # output is `UniVector.lib` — the intentional exception to the sharedLib /
  # staticLib naming. setup.py's Windows branch matches: `LIB_NAME =
  # "UniVector.lib"` and `libraries=["UniVector"]`.
  exec "nim c --cc:vcc --app:staticlib --noMain --mm:arc -d:release" &
       " -o:UniVector.lib src/UniVector/c_api.nim"

# Nim's MinGW toolchain names it mingw32-make.
let makeExe = if findExe("mingw32-make").len > 0: "mingw32-make" else: "make"
let pythonExe = if defined(windows): "python" else: "python3"

# `make -C`, not `cd dir && make`: nimble's exec runs no shell on Windows.
task ctest, "C ABI tests":
  exec "nimble clibStatic"
  exec makeExe & " -C tests/c"

task example, "Nim demo (print-only; no file I/O)":
  exec "nim c -r --path:src -o:build/demo examples/demo.nim"

task bench, "Deterministic local parse, flatten, and raster benchmark":
  exec "nim c -r -d:release --path:src -o:build/bench bench/bench_univector.nim"

task cexample, "C demo (print-only consumer of the uv_* ABI)":
  exec "nimble clibStatic"
  exec makeExe & " -C examples/c"

task pyDeps, "Install Python build deps (setuptools, Cython, pytest) if missing":
  let pipHelp = gorgeEx(pythonExe & " -m pip install --help").output
  let systemFlag =
    if pipHelp.contains("--break-system-packages"): " --break-system-packages"
    else: ""
  exec pythonExe & " -m pip install" & systemFlag &
       " --quiet setuptools wheel \"Cython>=3.0.0\" pytest"

# The extension links the vcc static lib on Windows, the shared lib elsewhere.
task pyLib, "Build the library the Python extension links against":
  when defined(windows):
    exec "nimble clibMsvc"
  else:
    exec "nimble clib"

task buildCython, "Cython extension in-place":
  exec "nimble pyLib"
  exec "nimble pyDeps"
  # nimscript `cd` (lib/system/nimscript.nim) changes the VM cwd for the next
  # exec without a shell, so the task works under nimble's no-shell exec on Windows.
  cd "py"
  exec pythonExe & " setup.py build_ext --inplace"
  cd ".."

task pyTest, "Cython extension + pytest":
  exec "nimble buildCython"
  cd "py"
  exec pythonExe & " -m pytest -q"
  cd ".."

task pyWheel, "wheel":
  exec "nimble pyLib"
  exec "nimble pyDeps"
  cd "py"
  exec pythonExe & " setup.py bdist_wheel"
  cd ".."

task pySdist, "Python source distribution with vendored Nim source":
  exec "nimble pyDeps"
  cd "py"
  exec pythonExe & " setup.py sdist"
  cd ".."

task coverage, "LCOV + HTML coverage report for the Nim sources (needs lcov)":
  # gcov and lcov driven directly, no coco. Linux and macOS only.
  # --debugger:native attributes lines to the .nim sources, not the generated C.
  # --include keeps stdlib out. Nim 2.2 can still emit counters for a synthetic
  # line past EOF and empty counters for imported platform modules; ignore only
  # those two lcov mapping categories, never source/read/write errors.
  let cache = "build/covcache"
  rmDir cache
  rmDir "coverage"
  rmFile "lcov.info"
  # One executable keeps each generated module and its counters in one graph.
  # Merging separately compiled modules is ambiguous because their initializers
  # can receive different source lines in each executable.
  exec "nim c --path:src --nimcache:" & cache &
       " --debugger:native --passC:--coverage --passL:--coverage" &
       " -o:build/test_coverage tests/test_coverage.nim"
  exec "./build/test_coverage"
  exec "lcov --capture --directory " & cache & " --base-directory ." &
       " --include \"*/src/UniVector/*\" --output-file lcov.info --quiet" &
       " --ignore-errors gcov,gcov"
  exec "genhtml lcov.info --output-directory coverage --legend --quiet" &
       " --ignore-errors range,range"
  exec "lcov --summary lcov.info"
