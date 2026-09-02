<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniVector repository guide

## Gates

```bash
nimble install -y
nimble testAll
nimble univector
nimble example
nimble cexample
nimble pyTest
nimble pyWheel
nimble pySdist
nimble bench
nimble coverage
nimble docs
nimble checkVGraph
nimble lint
```

`nimble docs` needs a complete Nim distribution containing the documentation
tools. Coverage needs `lcov` and `genhtml`.

## Architecture

- The Nim core is the implementation. C and Python translate values and
  ownership only; they do not contain graphics algorithms.
- Internal layers are `common < path < flatten < raster/svg < c_api`, enforced
  by `nimble checkVGraph`.
- UniLinalg owns vectors, UniColor owns colors, and UniImage owns raster images
  and codecs. UniVector must not duplicate them.
- C callers invoke `uv_init()` exactly once before any other ABI function.
  Handles are opaque and library-owned. Allocated ABI buffers use
  `uv_buffer_free`; `uv_image_pixels` is borrowed.
- A change to `c_api.nim` is verified by `ctest`, `pyTest` and, where there
  is one, `wasmTest`: three linkages, three runtime bootstraps. A green
  `ctest` alone proved nothing the day the shared build lost its
  initializer and every registry answered with the sentinel.
- ABI builds use `-d:release`, never `-d:danger`, and catch both
  `CatchableError` and `Defect` at the foreign boundary.

## Contracts and style

- Use NimContracts for meaningful domain restrictions and cheap
  postconditions. Validate untrusted ABI input explicitly because contracts
  compile away under `-d:release`.
- Keep comments factual and concise. Do not add roadmap, migration, or internal
  process prose to public documentation.
- Keep changes atomic, signed off, and formatted with `nimpretty`.
- Every maintained `.nim`, `.c`, `.h`, `.py`, and `.pyx` source starts with an
  SPDX identifier.
- `book/index.nim` is executable documentation; a stale example must fail the
  docs build.

## Provenance

UniVector is an original implementation of standard 2D graphics techniques.
The path grammar follows the W3C SVG specification. Do not reproduce
third-party implementation source.
