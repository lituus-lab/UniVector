# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniVector

nbInit(theme = useNimibook)
useLituus()
nb.title = "Paths and curves"

nbText: """
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

  let shifted = parsed.translated(12'f32, 8'f32)
  doAssert shifted.commands.len == parsed.commands.len
  doAssert shifted.at == parsed.at + vec2(12'f32, 8'f32)
  doAssert parsed.at == vec2(10'f32, 50'f32)
  echo "translated current = ", shifted.at

nbText: """
`Path.at` and `Path.start` are builder state. Parsing computes them too, so a
parsed path can immediately be extended with another command.

`translated` returns an independent path and preserves its command structure.
Offsets must be finite. The source path remains unchanged, which makes the
operation safe for retained scenes and repeated layout.

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
"""

nbSave
