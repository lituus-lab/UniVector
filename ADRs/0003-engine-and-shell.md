<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0003: Nim engine and foreign façades

- Status: Accepted
- Date: 2026-08-10
- Scope: UniVector

## Decision

The implementation lives in the Nim modules under `src/UniVector/`. The C ABI
in `src/UniVector/c_api.nim` is a translation and ownership boundary, and the
Python extension calls that C ABI through Cython. No façade contains an
independent graphics algorithm.

The native library is built with `--app:staticlib` or `--app:lib`, `--noMain`,
`--mm:arc`, and `-d:release`. `--noMain` suppresses Nim's application entry
point; it does not initialize the Nim runtime for a foreign process. A C caller
must call `uv_init()` exactly once before every other ABI function. Importing
the Python package performs that initialization before reading the version.

The hand-written header `include/UniVector.h` is authoritative for C ownership,
status, and initialization rules. The C consumer test links it against the
built library to detect symbol or layout drift.
