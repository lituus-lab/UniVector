<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0001: Dependency graph and ownership

- Status: Accepted
- Date: 2026-08-10
- Scope: UniVector

## Decision

UniVector depends on NimContracts and three lower-level Uni* engines through
their maintained `main` references in `UniVector.nimble`:

- UniLinalg owns `Vector2f` and vector arithmetic;
- UniColor owns tagged colors and color-space conversion;
- UniImage owns raster images and image encoding;
- NimContracts supplies debug design-by-contract checks.

`config.nims` adds only UniVector's own `src` directory. It must not inject
sibling checkouts, because that would make a build depend on unrelated local
repository state instead of the manifest.

## Invariants

1. UniVector never redefines vectors, colors, raster images, or codecs.
2. Dependencies do not import UniVector.
3. Internal modules follow `common < path < flatten < raster/svg < c_api`.
4. `nimble checkVGraph` rejects an import that violates that order.
5. The C and Python façades call the Nim algorithms; they do not reimplement
   geometry or rasterization.
