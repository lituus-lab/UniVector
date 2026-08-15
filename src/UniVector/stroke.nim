# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Deterministic expansion of prepared centerlines into filled paths.
import std/math
import contracts
import UniVector/common
import UniVector/path
import UniVector/flatten
import UniVector/prepared

type
  LineCap* = enum
    ButtCap
    RoundCap
    SquareCap

  LineJoin* = enum
    MiterJoin
    RoundJoin
    BevelJoin

  StrokeStyle* = object
    width*: float32
    cap*: LineCap
    join*: LineJoin
    miterLimit*: float32

const DefaultMiterLimit* = 4'f32

func defaultStrokeStyle*(width: float32): StrokeStyle {.inline.} =
  ## Canvas/SVG-compatible default cap, join, and miter limit.
  StrokeStyle(width: width, cap: ButtCap, join: MiterJoin,
      miterLimit: DefaultMiterLimit)

func samePoint(a, b: Vec2): bool {.inline.} =
  a.x == b.x and a.y == b.y

proc addPolygon(path: var Path; points: openArray[Vec2]) =
  if points.len < 3: return
  path.moveTo(points[0])
  for i in 1 ..< points.len:
    path.lineTo(points[i])
  path.closePath()

func normal(segment: Segment; halfWidth: float32): Vec2 =
  let delta = segment.to - segment.at
  let magnitude = length(delta)
  if magnitude == 0'f32: return vec2(0'f32, 0'f32)
  vec2(-delta.y / magnitude * halfWidth, delta.x / magnitude * halfWidth)

proc addRound(path: var Path; center: Vec2; radius: float32) =
  path.ellipse(center.x, center.y, radius, radius)

proc addSquareCap(path: var Path; segment: Segment; atStart: bool;
                  halfWidth: float32) =
  let delta = segment.to - segment.at
  let magnitude = length(delta)
  if magnitude == 0'f32: return
  let
    direction = delta / magnitude
    extension = if atStart: -direction * halfWidth else: direction * halfWidth
    point = if atStart: segment.at else: segment.to
    n = segment.normal(halfWidth)
  path.addPolygon([point + n, point + n + extension,
      point - n + extension, point - n])

proc addJoin(path: var Path; previous, following: Segment; style: StrokeStyle;
             halfWidth: float32) =
  let
    a = previous.to - previous.at
    b = following.to - following.at
    cross = a.x * b.y - a.y * b.x
  if cross == 0'f32: return
  if style.join == RoundJoin:
    path.addRound(previous.to, halfWidth)
    return
  let
    n0 = previous.normal(halfWidth)
    n1 = following.normal(halfWidth)
    side = if cross > 0'f32: -1'f32 else: 1'f32
    outer0 = previous.to + n0 * side
    outer1 = following.at + n1 * side
  if style.join == BevelJoin:
    path.addPolygon([outer0, previous.to, outer1])
    return
  let
    d0 = previous.to - previous.at
    d1 = following.to - following.at
    denominator = d0.x * d1.y - d0.y * d1.x
  if abs(denominator) <= Epsilon:
    path.addPolygon([outer0, previous.to, outer1])
    return
  let
    between = outer1 - outer0
    t = (between.x * d1.y - between.y * d1.x) / denominator
    miter = outer0 + d0 * t
  if length(miter - previous.to) <= style.miterLimit * halfWidth:
    path.addPolygon([outer0, miter, outer1])
  else:
    path.addPolygon([outer0, previous.to, outer1])

proc strokeToPathImpl(prepared: PreparedPath; style: StrokeStyle): Path =
  result = newPath()
  if prepared.len == 0: return
  let halfWidth = style.width * 0.5'f32
  for contourIndex in 0 ..< prepared.contourCount:
    let
      contour = prepared.contour(contourIndex)
      contourStart = contour.first
      contourEnd = contour.first + contour.count - 1
    for i in contourStart .. contourEnd:
      let segment = prepared.segment(i)
      let n = segment.normal(halfWidth)
      if not samePoint(segment.at, segment.to):
        result.addPolygon([segment.at + n, segment.to + n,
            segment.to - n, segment.at - n])
      if i > contourStart:
        result.addJoin(prepared.segment(i - 1), segment, style, halfWidth)
    if contour.closed:
      result.addJoin(prepared.segment(contourEnd),
          prepared.segment(contourStart), style, halfWidth)
    else:
      case style.cap
      of ButtCap: discard
      of RoundCap:
        result.addRound(prepared.segment(contourStart).at, halfWidth)
        result.addRound(prepared.segment(contourEnd).to, halfWidth)
      of SquareCap:
        result.addSquareCap(prepared.segment(contourStart), true, halfWidth)
        result.addSquareCap(prepared.segment(contourEnd), false, halfWidth)

proc strokeToPath*(prepared: PreparedPath;
                   style: StrokeStyle): Path {.contractual.} =
  ## Expand prepared centerlines into a path suitable for filling.
  require:
    classify(style.width) == fcNormal
    classify(style.miterLimit) == fcNormal
    style.width > 0'f32
    style.miterLimit >= 1'f32
  body:
    strokeToPathImpl(prepared, style)

proc strokeToPath*(path: Path; style: StrokeStyle;
                   tolerance = FlattenTolerance): Path {.contractual.} =
  ## Prepare and expand `path` using `tolerance`.
  require:
    tolerance > 0'f32
  body:
    path.preparePath(tolerance).strokeToPath(style)
