<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0006: Prepared geometry and renderer-neutral meshes

- Status: Accepted
- Date: 2026-08-15
- Scope: UniVector

## Context

Raster and GPU consumers need the same flattened geometry. Repeating curve
flattening in every renderer wastes CPU time and risks backend-dependent
results. Stroke expansion and tessellation also belong to the vector engine,
not to UniPlot or another consumer.

## Decision

UniVector owns three renderer-neutral stages above paths:

1. A prepared path stores directed line segments, their bounds, and the
   tolerance used to produce them.
2. Stroke expansion converts prepared contours to a filled path using an
   explicit width, cap, join, and miter limit.
3. Tessellation converts prepared fills or strokes to indexed triangles whose
   vertices contain a `Vector2f` position and coverage.

Prepared paths are immutable values at the public boundary. Rendering a
prepared path must not flatten its source again. Mesh indices are zero-based,
form complete triangles, and always reference an existing vertex.

Stroke width and miter limit are finite and positive. The supported caps are
butt, round, and square; the supported joins are miter, round, and bevel.
Tessellation accepts NonZero and EvenOdd winding and rejects geometry it cannot
represent instead of silently changing the fill.

The C façade uses opaque prepared-path and mesh handles. Variable-length
segment, vertex, and index outputs follow the sizing-call convention from
ADR-0005. Python owns these handles and exposes immutable tuple snapshots.

## Dependency order

The internal order becomes:

`common < path < flatten < prepared < stroke < mesh < raster/svg < c_api`

`prepared`, `stroke`, and `mesh` consume only UniVector layers below them and
UniLinalg arithmetic re-exported by `common`. They do not own transforms,
colors, images, GPU devices, or command submission.

## Consequences

- UniPlot and future GPU backends can cache geometry without duplicating vector
  algorithms.
- CPU rasterization and GPU upload consume the same deterministic preparation
  stage.
- UniVector remains independent of any graphics API; wgpu-native integration
  stays in the consuming renderer.
- New public operations must remain equivalent across Nim, C, and Python.
