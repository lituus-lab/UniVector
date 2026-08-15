# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniVector/raster — solid-fill anti-aliased rasterizer onto a UniImage
## `Image[uint8]` (csRgba, straight alpha).
##
## The geometry is color/pixel-agnostic: a path is flattened to directed
## segments, then each scanline is solved by vertical supersampling plus an
## analytic horizontal-coverage pass, with NonZero or EvenOdd winding. The
## apply tail composites the solid fill color over the destination with a
## straight-alpha "over" blend.
import std/[math, algorithm]
import contracts
import UniVector/common
import UniVector/path
import UniVector/flatten
import UniVector/prepared
import UniImage/core as uimg
import UniColor

const
  Supersample* = 4 ## vertical supersampling factor; AA quality vs speed tradeoff.

type
  Crossing = tuple[x: float32, dir: int]

proc addSpan(coverage: var seq[float32]; width: int; x0, x1, weight: float32) =
  ## Spread the coverage of one filled span [x0, x1] across the pixels it
  ## overlaps, by the analytic overlap length, scaled by `weight`.
  let xa = max(x0, 0'f32)
  let xb = min(x1, float32(width))
  if xb <= xa:
    return
  let p0 = max(0, int(floor(xa)))
  let p1 = min(width - 1, int(floor(xb)))
  for p in p0 .. p1:
    let overlap = min(float32(p) + 1'f32, xb) - max(float32(p), xa)
    if overlap > 0'f32:
      coverage[p] += overlap * weight

proc blendOver(img: var uimg.Image[uint8]; idx: int; cov, sr, sg, sb, sa: float32) =
  ## Composite an opaque-direction source (sRGB float in [0,1], alpha `sa`
  ## scaled by coverage `cov`) over the straight-alpha dst pixel at `idx`,
  ## writing 8-bit sRGB back into `img.data`.
  let aSrc = sa * cov
  if aSrc <= 0'f32:
    return
  let
    dr = float32(img.data[idx]) / 255'f32
    dg = float32(img.data[idx + 1]) / 255'f32
    db = float32(img.data[idx + 2]) / 255'f32
    da = float32(img.data[idx + 3]) / 255'f32
  let aOut = aSrc + da * (1'f32 - aSrc)
  if aOut <= 0'f32:
    img.data[idx] = 0
    img.data[idx + 1] = 0
    img.data[idx + 2] = 0
    img.data[idx + 3] = 0
    return
  let inv = 1'f32 / aOut
  let
    orC = (sr * aSrc + dr * da * (1'f32 - aSrc)) * inv
    ogC = (sg * aSrc + dg * da * (1'f32 - aSrc)) * inv
    obC = (sb * aSrc + db * da * (1'f32 - aSrc)) * inv
  img.data[idx] = uint8(clamp(orC, 0'f32, 1'f32) * 255'f32 + 0.5'f32)
  img.data[idx + 1] = uint8(clamp(ogC, 0'f32, 1'f32) * 255'f32 + 0.5'f32)
  img.data[idx + 2] = uint8(clamp(obC, 0'f32, 1'f32) * 255'f32 + 0.5'f32)
  img.data[idx + 3] = uint8(clamp(aOut, 0'f32, 1'f32) * 255'f32 + 0.5'f32)

proc blendOverwrite(img: var uimg.Image[uint8]; idx: int;
                    cov, sr, sg, sb, sa: float32) =
  let a = clamp(sa * cov, 0'f32, 1'f32)
  img.data[idx] = uint8(sr * 255'f32 + 0.5'f32)
  img.data[idx + 1] = uint8(sg * 255'f32 + 0.5'f32)
  img.data[idx + 2] = uint8(sb * 255'f32 + 0.5'f32)
  img.data[idx + 3] = uint8(a * 255'f32 + 0.5'f32)

func geometryLen(segments: seq[Segment]): int {.inline.} = segments.len
func geometryBounds(segments: seq[Segment]): Rect {.inline.} =
  segments.computeBounds()

proc fillGeometry[Geometry](img: var uimg.Image[uint8]; geometry: Geometry;
    color: Color; windingRule: WindingRule; blendMode: BlendMode) =
  if geometry.geometryLen == 0: return
  let
    width = img.width
    height = img.height
    bounds = geometry.geometryBounds
    minY = bounds.y
    maxY = bounds.y + bounds.h
  if maxY < 0'f32 or minY > float32(height): return
  let
    y0 = int(floor(max(minY, 0'f32)))
    y1 = min(height - 1, int(ceil(min(maxY, float32(height)))))
  if y0 > y1: return
  let converted = color.gamutMap(tagSrgb)
  if converted.isErr:
    raise newException(ValueError, "fill: color cannot be converted to sRGB")
  let c = converted.get
  let
    sr = clamp(c.comp(0), 0'f32, 1'f32)
    sg = clamp(c.comp(1), 0'f32, 1'f32)
    sb = clamp(c.comp(2), 0'f32, 1'f32)
    sa = clamp(c.alpha, 0'f32, 1'f32)
  if sa <= 0'f32: return
  let invSup = 1'f32 / float32(Supersample)
  var
    coverage = newSeq[float32](width)
    crossings: seq[Crossing] = @[]
  for y in y0 .. y1:
    for p in 0 ..< width: coverage[p] = 0'f32
    for sy in 0 ..< Supersample:
      let ys = float32(y) + (float32(sy) + 0.5'f32) * invSup
      crossings.setLen(0)
      for seg in geometry:
        let
          ay = seg.at.y
          by = seg.to.y
          lo = if ay < by: ay else: by
          hi = if ay < by: by else: ay
        if ys < lo or ys >= hi: continue
        let
          t = (ys - ay) / (by - ay)
          x = seg.at.x + (seg.to.x - seg.at.x) * t
          direction = if by > ay: 1 else: -1
        crossings.add((x, direction))
      if crossings.len == 0: continue
      crossings.sort(proc(a, b: Crossing): int = cmp(a.x, b.x))
      case windingRule
      of NonZero:
        var winding = 0
        var spanStart = 0'f32
        for crossing in crossings:
          if winding == 0: spanStart = crossing.x
          winding += crossing.dir
          if winding == 0:
            addSpan(coverage, width, spanStart, crossing.x, invSup)
      of EvenOdd:
        var inside = false
        var spanStart = 0'f32
        for crossing in crossings:
          if not inside: spanStart = crossing.x
          inside = not inside
          if not inside:
            addSpan(coverage, width, spanStart, crossing.x, invSup)
    let rowOff = y * width * 4
    for p in 0 ..< width:
      if coverage[p] > 0'f32:
        case blendMode
        of NormalBlend:
          blendOver(img, rowOff + p * 4, coverage[p], sr, sg, sb, sa)
        of OverwriteBlend:
          blendOverwrite(img, rowOff + p * 4, coverage[p], sr, sg, sb, sa)

proc fillPath*(img: var uimg.Image[uint8]; path: Path; color: Color;
               windingRule: WindingRule = NonZero;
               tol = FlattenTolerance;
               blendMode: BlendMode = NormalBlend) {.contractual.} =
  ## Solid-fill `path` with `color` onto `img` (csRgba straight alpha) using a
  ## scanline filler with vertical supersampling, analytic horizontal coverage,
  ## and NonZero/EvenOdd winding. The fill color is gamut-mapped to sRGB.
  require:
    img.channels == 4
    tol > 0'f32
    color.spaceTag != tagUnknown
  body:
    let segments = path.flatten(tol)
    img.fillGeometry(segments, color, windingRule, blendMode)

proc fillPreparedPath*(img: var uimg.Image[uint8]; path: PreparedPath;
                       color: Color; windingRule: WindingRule = NonZero;
                       blendMode: BlendMode = NormalBlend) {.contractual.} =
  ## Fill cached path geometry without flattening or recomputing its bounds.
  require:
    img.channels == 4
    color.spaceTag != tagUnknown
  body:
    let segments = path.segmentView
    img.fillGeometry(segments, color, windingRule, blendMode)
