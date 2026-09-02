<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# univector

`univector` brings UniVector’s Nim graphics engine to Python through its C ABI.
It can parse or construct SVG-style paths, inspect and flatten their geometry,
render solid fills into RGBA8 images, and produce SVG or PNG bytes.

The SVG support is deliberately path-focused: `Path.parse_d()` reads path data,
and `Path.to_svg()` writes a minimal document containing one solid-filled path.
It does not parse arbitrary SVG documents or preserve SVG scene structure,
styles, transforms, strokes, gradients, text, or external resources.

## Install

```bash
python -m pip install lituus-univector
```

Wheels are built for CPython 3.10–3.14 on Linux, macOS, and Windows. A source
installation needs Nim and Nimble on `PATH`, a supported C compiler, and the
platform's zlib development package because it compiles the vendored Nim
engine and its PNG support:

```bash
python -m pip install --no-binary univector univector
```

For a repository checkout:

```bash
nimble pyLib
cd py
python -m pip install -e ".[test]"
python -m pytest -q
```

## Draw once, emit SVG and PNG

```python
import univector

path = univector.Path()
path.rounded_rect(8, 8, 48, 48, 6, 6, 6, 6)
path.circle(32, 32, 12)

color = univector.Color.parse("oklch(62% 0.17 255)")
image = univector.Image(64, 64)
prepared = path.prepare()
image.fill_prepared(prepared, color,
                    winding=univector.WINDING_EVEN_ODD)
# For one-off rendering, use image.fill(path, color, winding=...) instead.

png_bytes = image.encode_png()
svg_text = path.to_svg(color, 64, 64)
```

`Image.pixels()` returns a Python `bytes` copy in row-major RGBA order.
`encode_png()` returns complete PNG bytes; `to_svg()` returns a standalone SVG
string whose view box matches the raster dimensions.

## Parse and inspect paths

```python
path = univector.Path.parse_d("M 10 10 C 20 0 40 0 50 10 Z")

print(path.current)       # (10.0, 10.0), because Z closes the subpath
print(path.commands)      # [(kind, parameters), ...]
print(path.flatten(0.25)) # [((x0, y0), (x1, y1)), ...]
print(path.bounds(0.25))  # (x, y, width, height)

prepared = path.prepare(0.25)
print(prepared.bounds)
print(prepared.segments)  # immutable tuple snapshot
outline = prepared.stroke(2, cap=univector.CAP_ROUND,
                          join=univector.JOIN_BEVEL)
dashed = prepared.stroke(2, dashes=[6, 3], dash_offset=1)
mesh = prepared.tessellate_fill(univector.WINDING_NON_ZERO)
stroke_mesh = prepared.tessellate_stroke(2, cap=univector.CAP_ROUND)
print(mesh.triangle_count, mesh.vertices, mesh.indices)
```

The tolerance is the subdivision threshold used against each curve span. A
smaller value produces more segments and generally smoother edges at a higher cost.
Passing `0.0` selects `FLATTEN_TOLERANCE`.

## Plot markers

```python
diamond = univector.marker_path(univector.MARKER_DIAMOND, (24, 16), 8)
squares = univector.markers_path(
    univector.MARKER_SQUARE, [(8, 8), (16, 12), (24, 10)], 5)
circles = univector.markers_path_sized(
    univector.MARKER_CIRCLE, [(8, 8), (16, 12), (24, 10)], [3, 5, 7])
```

Marker size is the full width and height. Available shapes are circle, square,
triangle, diamond, plus, and cross. Batch constructors return one fill-ready
`Path`; the sized variant requires one strictly positive size per point.

## Geometry helpers

```python
mid = univector.quad_point((0, 0), (1, 1), (2, 0), 0.5)
point = univector.cubic_point((0, 0), (0, 1), (1, 1), (1, 0), 0.25)

assert univector.is_relative(univector.PATH_REL_LINE)
assert univector.parameter_count(univector.PATH_CUBIC) == 6
```

`quad_point` and `cubic_point` require `t` in `[0, 1]`. Path command constants
run from `PATH_CLOSE` through `PATH_REL_ARC`; each command returned by
`Path.commands` uses one of those constants and contains only its meaningful
parameters.

## API summary

- `Path`: `move_to`, `line_to`, `bezier_curve_to`, `quadratic_curve_to`,
  `elliptical_arc_to`, `arc`, `arc_to`, `rect`, `rounded_rect`, `ellipse`,
  `circle`, `polygon`, `close_path`, `add_path`, `copy`, `parse_d`, `to_d`,
  `to_svg`, `flatten`, `prepare`, `bounds`, `current`, `start`, and `commands`.
- `PreparedPath`: `segments`, `bounds`, `tolerance`, `stroke`,
  `tessellate_fill`, `tessellate_stroke`, and `len`.
- `VectorMesh`: `vertices`, `indices`, and `triangle_count`.
- `Image`: `width`, `height`, `channels`, `pixels`, `fill`, `fill_prepared`,
  and `encode_png`.
- `Color`: `parse`, `rgba`, and `to_svg`.
- Geometry: `quad_point`, `cubic_point`, and `compute_bounds`.
- Plot geometry: `marker_path`, `markers_path`, `markers_path_sized`, and the
  `MARKER_*` constants. `PreparedPath.stroke` and `tessellate_stroke` accept
  `dashes` and `dash_offset`.
- Command metadata: `is_relative`, `parameter_count`, and `PATH_*` constants.
- Rendering constants: `WINDING_NON_ZERO`, `WINDING_EVEN_ODD`,
  `BLEND_NORMAL`, `BLEND_OVERWRITE`, `GEOMETRIC_EPSILON`,
  `CAP_BUTT`, `CAP_ROUND`, `CAP_SQUARE`, `JOIN_MITER`, `JOIN_ROUND`,
  `JOIN_BEVEL`, `DEFAULT_MITER_LIMIT`,
  `FLATTEN_TOLERANCE`, `MAX_FLATTEN_DEPTH`, `MAX_FLATTEN_SEGMENTS`,
  `MAX_DASH_PATTERN_ELEMENTS`, `MAX_MARKER_COUNT`, and `SUPERSAMPLE`.
- Runtime: `version`, `abi_version`, and `strerror`.

## Errors and lifetime

Python objects own their native handles and release them during garbage
collection. Returned Python strings and bytes own their data, so they remain
valid after the originating object is deleted. Invalid geometry, malformed SVG
path data, and unsupported arguments raise `ValueError`; allocation failures
raise `MemoryError`; a concurrent mutation detected during a two-pass read
raises `RuntimeError`. Do not use the same object concurrently from multiple
threads without external synchronization.

UniVector is Apache-2.0 licensed.
