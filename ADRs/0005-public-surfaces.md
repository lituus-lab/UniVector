<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0005: Nim, C, and Python surfaces

- Status: Accepted
- Date: 2026-08-10
- Scope: UniVector

## Decision

Every public UniVector operation is reachable from C and Python:

| Nim | C | Python |
| --- | --- | --- |
| path builders, parse, serialize, copy | `uv_path_*` | `Path` |
| path state and commands | `uv_path_current/start/command_*` | `Path.current/start/commands` |
| `quadPoint`, `cubicPoint` | `uv_quad_point`, `uv_cubic_point` | `quad_point`, `cubic_point` |
| `flatten`, `computeBounds` | `uv_path_flatten`, `uv_segments_bounds` | `Path.flatten/bounds`, `compute_bounds` |
| `preparePath`, prepared accessors | `uv_path_prepare`, `uv_prepared_path_*` | `Path.prepare`, `PreparedPath` |
| `strokeToPath`, stroke styles | `uv_prepared_path_stroke`, `UV_CAP/JOIN_*` | `PreparedPath.stroke`, `CAP/JOIN_*` |
| `tessellateFill`, mesh accessors | `uv_prepared_path_tessellate_fill`, `uv_mesh_*` | `PreparedPath.tessellate_fill`, `VectorMesh` |
| `tessellateStroke` | `uv_prepared_path_tessellate_stroke` | `PreparedPath.tessellate_stroke` |
| `fillPath` | `uv_fill_path` | `Image.fill` |
| `fillPreparedPath` | `uv_fill_prepared_path` | `Image.fill_prepared` |
| `toSvgColor`, `toSvgString` | `uv_color_to_svg`, `uv_path_to_svg` | `Color.to_svg`, `Path.to_svg` |

`Epsilon`, `FlattenTolerance`, `MaxFlattenDepth`, `MaxFlattenSegments`,
`Supersample`, `BlendMode`, `WindingRule`, and `PathCommandKind` are mirrored
as named constants or enums.

Nim overloads accepting `Vec2`, `Rect`, `Circle`, or `Polygon` do not receive
duplicate ABI symbols: C and Python use their scalar or sequence
representations. Re-exported UniLinalg arithmetic is not wrapped by UniVector;
it belongs to UniLinalg's own C and Python façades. UniColor construction and
UniImage allocation/PNG encoding are included only as the minimum handles
needed to call UniVector's raster surface.

C variable-length output uses a capacity plus a returned required count.
Python performs the sizing call, allocates once, and rejects a changed required
count before reading the buffer.
