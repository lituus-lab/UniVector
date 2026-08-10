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
python -m pip install univector
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
image.fill(path, color, winding=univector.WINDING_EVEN_ODD)

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
```

The tolerance is the subdivision threshold used against each curve span. A
smaller value produces more segments and generally smoother edges at a higher cost.
Passing `0.0` selects `FLATTEN_TOLERANCE`.

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
  `to_svg`, `flatten`, `bounds`, `current`, `start`, and `commands`.
- `Image`: `width`, `height`, `channels`, `pixels`, `fill`, and `encode_png`.
- `Color`: `parse`, `rgba`, and `to_svg`.
- Geometry: `quad_point`, `cubic_point`, and `compute_bounds`.
- Command metadata: `is_relative`, `parameter_count`, and `PATH_*` constants.
- Rendering constants: `WINDING_NON_ZERO`, `WINDING_EVEN_ODD`,
  `BLEND_NORMAL`, `BLEND_OVERWRITE`, `GEOMETRIC_EPSILON`,
  `FLATTEN_TOLERANCE`, `MAX_FLATTEN_DEPTH`, `MAX_FLATTEN_SEGMENTS`, and
  `SUPERSAMPLE`.
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
