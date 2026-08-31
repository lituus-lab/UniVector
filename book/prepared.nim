# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniVector

nbInit(theme = useNimibook)
useLituus()
nb.title = "Preparing geometry once"

nbText: """
## Preparing geometry once

Repeated drawing should not flatten the same curves in every backend. A
`PreparedPath` stores the segments, tolerance, and bounds as an immutable
snapshot:
"""

nbText: """
The path is the one from *Paths and curves*. Each chapter is its own program,
so it is rebuilt here rather than carried over:
"""

nbCode:
  let curve = parsePath("M 0 0 C 20 80 80 80 100 0")
  let fine = curve.flatten(0.25'f32)

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

## Expanding strokes

A stroke is expanded into ordinary filled paths before rasterization or
tessellation. Its style explicitly selects butt, round, or square caps and
miter, round, or bevel joins:
"""

nbCode:
  let outline = preparedCurve.strokeToPath(StrokeStyle(
      width: 3'f32, cap: RoundCap, join: BevelJoin, miterLimit: 4'f32))
  doAssert outline.commands.len > 0
  echo "stroke bounds = ", outline.flatten().computeBounds()

nbText: """
Miter joins fall back to bevel joins when their length exceeds the configured
miter limit. The result is a regular `Path`, so all existing fill, SVG, C, and
Python operations remain applicable.

### Dashed strokes

`DashPattern` stores a validated repeating on/off sequence and a phase offset.
Odd-length inputs are repeated, matching SVG and Canvas cycle semantics. Each
source contour restarts at the same phase; every visible dash is an open
subpath, so the selected cap is applied at both ends.
"""

nbCode:
  var dashedStyle = defaultStrokeStyle(3'f32)
  dashedStyle.cap = RoundCap
  dashedStyle.dash = dashPattern([8'f32, 4'f32], 2'f32)
  let dashedOutline = preparedCurve.strokeToPath(dashedStyle)
  doAssert dashedOutline.commands.len > 0
  echo "normalized dash cycle = ", dashedStyle.dash.lengths

nbText: """
An empty pattern is a solid stroke. Lengths must be finite and strictly
positive; the pattern and generated segment counts are bounded for safe use
with untrusted input. The C ABI provides additive `_dashed` entry points, and
Python accepts `dashes=` and `dash_offset=` in both prepared stroke methods.

## Plot markers

Marker geometry is also represented as an ordinary filled path. `markerPath`
constructs one symbol; `placeMarkers` combines fixed- or per-point sizes while
retaining one subpath per marker:
"""

nbCode:
  let oneDiamond = markerPath(DiamondMarker, vec2(10'f32, 10'f32), 6'f32)
  let manyCircles = placeMarkers(CircleMarker,
      [vec2(4'f32, 4'f32), vec2(12'f32, 8'f32), vec2(20'f32, 5'f32)],
      [3'f32, 5'f32, 7'f32])
  doAssert oneDiamond.commands.len == 5
  doAssert manyCircles.commands.len > 0
  echo "marker bounds = ", manyCircles.flatten(0.1'f32).computeBounds()

nbText: """
`CircleMarker`, `SquareMarker`, `TriangleMarker`, `DiamondMarker`,
`PlusMarker`, and `CrossMarker` share the same full-width/full-height size
meaning. Centers and sizes are checked by contracts in debug builds and by
runtime guards in release builds. C and Python expose both fixed-size and
variable-size batch constructors.
"""

nbSave
