# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib

nbInit
nb.title = "UniVector: paths, curves, and pixels"

nbText: """
# UniVector: paths, curves, and pixels

Vector graphics describe *geometry* rather than storing one color per pixel.
A path says “move here, draw a line there, then follow this curve.” UniVector
keeps that description as long as possible, and turns it into pixels only when
asked to rasterize.

Every Nim block in this guide is compiled and executed by `nimble book`. The
guide therefore tests the API it teaches.

## Coordinates and vectors

The origin is `(0, 0)`. As in SVG and image buffers, `x` grows to the right and
`y` grows downward. UniVector uses UniLinalg's two-dimensional `Vector2f`
instead of defining another vector type.
"""

nbCode:
  import UniVector

  let a = vec2(3'f32, 4'f32)
  echo "length = ", a.length
  echo "a + (2, 1) = ", a + vec2(2'f32, 1'f32)

nbText: """
The length is 5 because the Pythagorean theorem gives
`sqrt(3² + 4²) = 5`.

## A path is a command stream

`moveTo` starts a subpath without drawing. `lineTo` draws from the current
point. `closePath` returns to the subpath's start. The SVG `d` syntax uses the
same ideas: uppercase commands hold absolute coordinates, while lowercase
commands are relative to the current point.
"""

nbCode:
  import UniVector

  var triangle = newPath()
  triangle.moveTo(10'f32, 50'f32)
  triangle.lineTo(50'f32, 10'f32)
  triangle.lineTo(90'f32, 50'f32)
  triangle.closePath()
  echo $triangle

  let parsed = parsePath("M 10 50 l 40 -40 l 40 40 Z")
  echo "commands = ", parsed.commands.len
  echo "current after close = ", parsed.at

nbText: """
`Path.at` and `Path.start` are builder state. Parsing computes them too, so a
parsed path can immediately be extended with another command.

## Bézier curves

A quadratic Bézier uses endpoints `P₀`, `P₁` and one control point `C`:

`B(t) = (1-t)² P₀ + 2(1-t)t C + t² P₁`, for `0 ≤ t ≤ 1`.

The control point usually is not on the curve; it pulls the curve toward
itself. A cubic Bézier has two controls and four Bernstein-polynomial weights.
"""

nbCode:
  import UniVector

  let midpoint = quadPoint(
    vec2(0'f32, 0'f32),
    vec2(50'f32, 100'f32),
    vec2(100'f32, 0'f32),
    0.5'f32)
  echo "quadratic midpoint = ", midpoint

nbText: """
At `t = 0.5`, the weights are `0.25`, `0.5`, and `0.25`, so this example
reaches `(50, 50)`.

## From curves to segments

Rasterizers are simpler when every edge is a line segment. `flatten`
adaptively subdivides a curve with de Casteljau's construction until its
control points are close enough to the chord joining its endpoints. The
tolerance is measured in coordinate units:

- a smaller tolerance produces more segments and follows the curve more closely;
- a larger tolerance produces fewer segments and is faster;
- the tolerance must be positive.

Elliptical arcs use the SVG endpoint-to-center conversion, then are sampled in
spans no wider than a quarter-turn and small enough for the same error bound.
"""

nbCode:
  import UniVector

  let curve = parsePath("M 0 0 C 20 80 80 80 100 0")
  let coarse = curve.flatten(2'f32)
  let fine = curve.flatten(0.25'f32)
  echo "segments at tolerance 2.0: ", coarse.len
  echo "segments at tolerance 0.25: ", fine.len
  echo "bounds = ", computeBounds(fine)

nbText: """
The bounds are computed from the flattened segments. They are therefore bounds
of that polyline approximation; reducing the tolerance makes them converge
toward the curve's bounds.

## Preparing geometry once

Repeated drawing should not flatten the same curves in every backend. A
`PreparedPath` stores the segments, tolerance, and bounds as an immutable
snapshot:
"""

nbCode:
  let preparedCurve = curve.preparePath(0.25'f32)
  doAssert preparedCurve.len == fine.len
  doAssert preparedCurve.bounds == computeBounds(fine)
  echo "prepared segments = ", preparedCurve.len
  echo "prepared tolerance = ", preparedCurve.tolerance

nbText: """
The snapshot remains valid if the source `Path` is later extended. C callers
own an opaque `uv_prepared_path`; Python callers use `Path.prepare()` and read
the `PreparedPath.segments`, `bounds`, and `tolerance` properties.

## Filling: crossings and winding

For each sampled scanline, UniVector finds where path edges cross it and sorts
those crossings from left to right. It then decides which spans are inside:

- **EvenOdd** toggles inside/outside at every crossing. Two nested contours
  make a hole regardless of their direction.
- **NonZero** adds `+1` for one edge direction and `-1` for the other. A point
  is inside while the sum is non-zero, so contour direction matters.

The rasterizer samples four vertical positions per pixel. Horizontal overlap
is computed analytically, producing a coverage between 0 and 1 at an edge.
"""

nbCode:
  import UniVector
  import UniColor
  import UniImage/core as uimg

  var ring = newPath()
  ring.rect(0'f32, 0'f32, 20'f32, 20'f32)
  ring.rect(5'f32, 5'f32, 10'f32, 10'f32)
  var image = uimg.newImage[uint8](20, 20, uimg.csRgba)
  image.fillPath(ring, parseColor("#3366cc").get, EvenOdd)
  let centerAlpha = image.data[(10 * image.width + 10) * 4 + 3]
  echo "center alpha under even-odd = ", centerAlpha

nbText: """
The center is transparent because it lies inside two contours, an even number.

## Straight-alpha compositing

Pixels store straight RGBA. If source alpha after coverage is `aₛ` and the
destination alpha is `a_d`, source-over gives
`a_out = aₛ + a_d(1-aₛ)`. Color channels are combined in premultiplied form for
the calculation and divided by `a_out` before storing straight-alpha bytes.

UniColor supplies the tagged input color and gamut-maps it to sRGB. UniImage
supplies the RGBA8 buffer and the PNG encoder. UniVector does not duplicate
either responsibility.

## One geometry, two outputs
"""

nbCode:
  import UniVector
  import UniColor
  import UniImage/core as uimg
  import UniImage/formats

  var badge = newPath()
  badge.roundedRect(8'f32, 8'f32, 48'f32, 48'f32,
                   6'f32, 6'f32, 6'f32, 6'f32)
  let blue = parseColor("#3366cc").get
  var surface = uimg.newImage[uint8](64, 64, uimg.csRgba)
  surface.fillPath(badge, blue)
  echo "png bytes = ", encodeImage(surface, efPng, 90).len
  echo toSvgString(badge, blue, 64, 64)

nbText: """
## C and Python

The C ABI exposes the same path commands, command inspection, curve
evaluation, flattening, bounds, fill, SVG, and PNG operations. C callers must
invoke `uv_init()` exactly once before any other ABI function. Python owns the
native handles automatically and converts returned buffers into Python strings,
bytes, tuples, and lists.

## Exercises

1. Reverse the inner rectangle of the ring and compare NonZero with EvenOdd.
2. Flatten the same cubic with tolerances `4`, `1`, and `0.1`; count the
   segments and explain the difference.
3. Build a circle from four cubic curves, inspect its bounds, and compare it
   with `Path.circle`.
4. Parse a path containing relative commands, append a line, and predict the
   final current point before printing it.
"""

nbSave
