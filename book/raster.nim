# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniVector

nbInit(theme = useNimibook)
useLituus()
nb.title = "From geometry to pixels"

nbText: """
## Tessellating fills for renderers

The renderer-neutral mesh contains `Vector2f` positions, coverage values, and
zero-based triangle indices. It owns no GPU device or command queue:
"""

nbText: """
The prepared path is the one from *Preparing geometry once*, rebuilt here:
each chapter is its own program.
"""

nbCode:
  let curve = parsePath("M 0 0 C 20 80 80 80 100 0")
  let preparedCurve = curve.preparePath(0.25'f32)

nbCode:
  var meshPath = newPath()
  meshPath.rect(2, 2, 8, 6)
  let mesh = meshPath.preparePath().tessellateFill()
  doAssert mesh.triangleCount == 2
  doAssert mesh.indexCount == 6
  echo "mesh vertices = ", mesh.vertexCount
  let strokeMesh = preparedCurve.tessellateStroke(StrokeStyle(
      width: 3'f32, cap: RoundCap, join: BevelJoin, miterLimit: 4'f32))
  doAssert strokeMesh.triangleCount > 0
  echo "stroke triangles = ", strokeMesh.triangleCount

nbText: """
NonZero and EvenOdd winding are both supported, including nested contours.
The immutable snapshots returned by Nim, C, and Python can be cached or copied
directly into backend-owned buffers.

The CPU rasterizer can consume the same snapshot without flattening or
recomputing bounds:
"""

nbCode:
  import UniColor
  import UniImage/core as uimg
  var preparedSurface = uimg.newImage[uint8](16, 12, uimg.csRgba)
  preparedSurface.fillPreparedPath(meshPath.preparePath(),
      parseColor("#3366cc").get)
  doAssert preparedSurface.data[(2 * 16 + 2) * 4 + 3] > 0

nbText: """
Use this path for repeated frames. In C it is `uv_fill_prepared_path`; in
Python it is `Image.fill_prepared()`.

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
"""

nbSave
