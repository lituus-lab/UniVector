<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniVector

UniVector is a 2D vector-graphics engine written in Nim. It builds and parses
SVG path data, flattens Bézier curves and elliptical arcs into line segments,
fills paths into RGBA8 images with anti-aliasing, and emits a minimal standalone
SVG containing one filled path. The same engine is available through Nim, a
stable C ABI, and Python.

## What’s inside

- An SVG-compatible path command model with absolute and relative commands.
- Canvas-style path builders for lines, curves, arcs, rectangles, ellipses,
  circles, rounded rectangles, and regular polygons.
- Adaptive quadratic and cubic Bézier subdivision and SVG arc flattening.
- Segment bounds and point evaluation for quadratic and cubic curves.
- A scanline solid-fill rasterizer with non-zero and even-odd winding rules.
- SVG serialization and PNG encoding through UniImage.

## SVG scope

UniVector reads and writes SVG path data (`d`) and can wrap one path with a
solid fill in a minimal standalone SVG document. It is not a general SVG
document reader or scene serializer: XML structure, multiple elements,
transforms, strokes, gradients, text, clipping, masks, filters, animation, and
external resources are outside the 1.0 surface.
- Matching C and Python surfaces for the public Nim engine.

## Nim quickstart

```nim
import UniVector
import UniColor
import UniImage/core as uimg
import UniImage/formats

var path = newPath()
path.roundedRect(8'f32, 8'f32, 48'f32, 48'f32,
                6'f32, 6'f32, 6'f32, 6'f32)

var image = uimg.newImage[uint8](64, 64, uimg.csRgba)
image.fillPath(path, parseColor("#3366cc").get)

let png = encodeImage(image, efPng, 90)
let svg = toSvgString(path, parseColor("#3366cc").get, 64, 64)
```

Install and validate the repository with:

```bash
nimble install -y
nimble testAll
nimble ctest
nimble pyTest
nimble book
```

## C ABI

Call `uv_init()` exactly once before every other ABI function. Paths, images,
and colors are opaque handles with matching free functions. Returned strings
and encoded buffers are released with `uv_buffer_free`; the pointer returned by
`uv_image_pixels` is borrowed from its image.

The ABI exposes path construction and inspection, Bézier evaluation,
flattening, bounds, raster fill, SVG output, and PNG encoding. It catches Nim
exceptions and defects at the boundary and reports `UV_*` status codes. The
authoritative declarations and ownership rules are in
[`include/UniVector.h`](include/UniVector.h).

```bash
nimble clibStatic
nimble clib
nimble ctest
nimble cexample
```

## Python

The `univector` package wraps the C ABI with `Path`, `Image`, and `Color`
classes. Wheels target CPython 3.9–3.14 on Linux, macOS, and Windows; the source
distribution vendors the Nim project for platforms without a wheel. Building
from source requires Nim and Nimble on `PATH`.

```python
import univector

path = univector.Path.parse_d("M 8 8 H 56 V 56 H 8 Z")
segments = path.flatten()
assert path.bounds() == (8.0, 8.0, 48.0, 48.0)

image = univector.Image(64, 64)
color = univector.Color.parse("oklch(62% 0.17 255)")
image.fill(path, color)
png = image.encode_png()
svg = path.to_svg(color, 64, 64)
```

See [`py/README.md`](py/README.md) for installation, ownership, errors, and the
complete Python surface.

## Uni* family

UniVector reuses the family’s domain engines instead of redefining their data:

- [UniLinalg](https://github.com/lituus-lab/UniLinalg) provides `Vector2f`.
- [UniColor](https://github.com/lituus-lab/UniColor) provides tagged colors and
  conversion to sRGB.
- [UniImage](https://github.com/lituus-lab/UniImage) provides the RGBA8 image
  model and PNG encoder.
- [NimContracts](https://github.com/lbartoletti/NimContracts) enforces debug
  preconditions and postconditions in the Nim core.

The dependency graph is one-way: UniVector consumes these lower-level
libraries; they do not depend on UniVector.

## Documentation

`nimble book` compiles and executes the examples in `book/index.nim`. The
generated guide explains path commands, Bézier curves, flattening tolerance,
winding rules, anti-aliasing, and straight-alpha compositing. `nimble docs`
combines that guide with the generated Nim API reference under `pages/`.

## Benchmarks

`nimble bench` runs a deterministic local benchmark for path parsing,
flattening, and raster filling. It reports timings for the current machine; the
repository does not publish cross-library rankings because compiler flags,
image sizes, tolerances, and hardware materially change the result.

## Provenance & development

UniVector is an original implementation. Its path syntax follows the public
W3C SVG path grammar; adaptive de Casteljau subdivision, SVG arc
endpoint-to-center conversion, scanline filling, winding rules, and alpha
compositing are standard graphics techniques implemented here in Nim. No
third-party implementation was copied.

Design choices and ABI boundaries are recorded in [`ADRs/`](ADRs/).

## License

Apache-2.0. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
