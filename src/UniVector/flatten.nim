# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniVector/flatten — turn a `Path` command stream into a flat list of
## directed line `Segment`s, the form the scanline rasterizer consumes.
##
## Curves are flattened by recursive de Casteljau subdivision until the control
## points lie within a tolerance of the chord; arcs by the standard SVG
## endpoint-to-center parameterization, sampled at ≤ 90° per span. Direction
## (`at` → `to`) carries the winding sign the rasterizer needs for the
## NonZero/EvenOdd rules.
import std/math
import contracts
import UniVector/common
import UniVector/path

const
  FlattenTolerance*: float32 = 0.5 ## max chord deviation allowed for a flattened span.
  MaxFlattenDepth* = 18 ## subdivision cap before a span is forced flat (stack guard).
  MaxFlattenSegments* = 1_048_576 ## hard output cap for untrusted paths.

proc addSegment(segments: var seq[Segment]; segment: Segment) {.inline.} =
  if segments.len >= MaxFlattenSegments:
    raise newException(ValueError, "flatten: segment limit exceeded")
  segments.add(segment)

proc quadPoint*(p0, c, p1: Vec2; t: float32): Vec2 {.contractual, inline.} =
  ## Point on quadratic Bézier (p0, c, p1) at parameter `t`.
  require:
    t >= 0'f32 and t <= 1'f32
  body:
    let u = 1'f32 - t
    u * u * p0 + (2'f32 * u * t) * c + t * t * p1

proc cubicPoint*(p0, c1, c2, p1: Vec2; t: float32): Vec2 {.contractual, inline.} =
  ## Point on cubic Bézier (p0, c1, c2, p1) at parameter `t`.
  require:
    t >= 0'f32 and t <= 1'f32
  body:
    let
      u = 1'f32 - t
      b0 = u * u * u
      b1 = 3'f32 * u * u * t
      b2 = 3'f32 * u * t * t
      b3 = t * t * t
    b0 * p0 + b1 * c1 + b2 * c2 + b3 * p1

proc flattenQuad(segments: var seq[Segment]; p0, c, p1: Vec2; tol: float32;
                 depth: int) =
  if depth >= MaxFlattenDepth:
    segments.addSegment(Segment(at: p0, to: p1))
    return
  let
    chord = p1 - p0
    n = vec2(-chord.y, chord.x)
    l2 = dot(n, n)
  if l2 <= Epsilon * Epsilon:
    # Coincident endpoints can still describe a loop when the control differs.
    # Stop only when the entire span is within tolerance of the point.
    let delta = c - p0
    if dot(delta, delta) <= tol * tol:
      segments.addSegment(Segment(at: p0, to: p1))
      return
  if abs(dot(c - p0, n)) / sqrt(l2) <= tol:
    segments.addSegment(Segment(at: p0, to: p1))
    return
  let
    m = quadPoint(p0, c, p1, 0.5'f32)
    a = (p0 + c) * 0.5'f32
    b = (c + p1) * 0.5'f32
  flattenQuad(segments, p0, a, m, tol, depth + 1)
  flattenQuad(segments, m, b, p1, tol, depth + 1)

proc flattenCubic(segments: var seq[Segment]; p0, c1, c2, p1: Vec2; tol: float32;
                  depth: int) =
  if depth >= MaxFlattenDepth:
    segments.addSegment(Segment(at: p0, to: p1))
    return
  let
    chord = p1 - p0
    n = vec2(-chord.y, chord.x)
    l2 = dot(n, n)
  if l2 <= Epsilon * Epsilon:
    let
      d1 = c1 - p0
      d2 = c2 - p0
    if dot(d1, d1) <= tol * tol and dot(d2, d2) <= tol * tol:
      segments.addSegment(Segment(at: p0, to: p1))
      return
  if l2 > 0'f32:
    let inv = 1'f32 / sqrt(l2)
    if abs(dot(c1 - p0, n)) * inv <= tol and abs(dot(c2 - p0, n)) * inv <= tol:
      segments.addSegment(Segment(at: p0, to: p1))
      return
  # de Casteljau split at t = 0.5.
  let
    m01 = (p0 + c1) * 0.5'f32
    m12 = (c1 + c2) * 0.5'f32
    m23 = (c2 + p1) * 0.5'f32
    m012 = (m01 + m12) * 0.5'f32
    m123 = (m12 + m23) * 0.5'f32
    m = (m012 + m123) * 0.5'f32
  flattenCubic(segments, p0, m01, m012, m, tol, depth + 1)
  flattenCubic(segments, m, m123, m23, p1, tol, depth + 1)

func angleBetween(ux, uy, vx, vy: float32): float32 =
  ## Signed angle from vector (ux,uy) to (vx,vy), in (-π, π].
  let
    d = ux * vx + uy * vy
    len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
  var a = arccos(clamp(d / len, -1'f32, 1'f32))
  if ux * vy - uy * vx < 0'f32:
    a = -a
  a

proc arcToSegments(segments: var seq[Segment]; at, to: Vec2; r: Vec2;
                   phi: float32; largeArc, sweep: bool; tol: float32) =
  ## Append an elliptical arc as line spans, via the SVG endpoint-to-center
  ## parameterization. A zero-radius arc collapses to a chord; an arc whose
  ## endpoint equals its start emits nothing (per SVG: no movement).
  if at.x == to.x and at.y == to.y:
    return
  var rx = abs(r.x)
  var ry = abs(r.y)
  if rx == 0'f32 or ry == 0'f32:
    # Either radius zero is a straight line per SVG (not only both zero).
    segments.addSegment(Segment(at: at, to: to))
    return
  let
    cosPhi = cos(phi)
    sinPhi = sin(phi)
    half = (at + to) * 0.5'f32
    dx2 = (at.x - to.x) * 0.5'f32
    dy2 = (at.y - to.y) * 0.5'f32
    x1p = cosPhi * dx2 + sinPhi * dy2
    y1p = -sinPhi * dx2 + cosPhi * dy2
  var rx2 = rx * rx
  var ry2 = ry * ry
  let
    x1p2 = x1p * x1p
    y1p2 = y1p * y1p
  let lambda = x1p2 / rx2 + y1p2 / ry2
  if lambda > 1'f32:
    let s = sqrt(lambda)
    rx *= s; ry *= s; rx2 = rx * rx; ry2 = ry * ry
  let sign = if largeArc == sweep: -1'f32 else: 1'f32
  let
    num = rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2
    den = rx2 * y1p2 + ry2 * x1p2
  let coef = sign * sqrt(max(0'f32, num / den))
  let
    cxp = coef * rx * y1p / ry
    cyp = coef * -ry * x1p / rx
    cx = cosPhi * cxp - sinPhi * cyp + half.x
    cy = sinPhi * cxp + cosPhi * cyp + half.y

  let
    ux = (x1p - cxp) / rx
    uy = (y1p - cyp) / ry
    vx = (-x1p - cxp) / rx
    vy = (-y1p - cyp) / ry
    a0 = angleBetween(1'f32, 0'f32, ux, uy)
    da = angleBetween(ux, uy, vx, vy)
  var sweepAngle = da
  if not sweep and sweepAngle > 0'f32:
    sweepAngle -= 2'f32 * PI
  elif sweep and sweepAngle < 0'f32:
    sweepAngle += 2'f32 * PI
  # Span angle from the sagitta bound R(1 - cos(δ/2)) <= tol, capped at 90° so
  # a span never bends more than a quadrant. Large-radius arcs then get enough
  # spans to meet the tolerance instead of a fixed 4 per full circle.
  let R = max(rx, ry)
  let maxSpan = if R > tol: 2'f32 * arccos(1'f32 - tol / R) else: PI / 2'f32
  let span = min(maxSpan, PI / 2'f32)
  let requested = ceil(abs(sweepAngle) / span)
  if classify(requested) in {fcNan, fcInf, fcNegInf} or
      requested > float64(MaxFlattenSegments - segments.len):
    raise newException(ValueError, "flatten: segment limit exceeded")
  let n = max(1, int(requested))
  var prev = at
  for k in 1 .. n:
    let t = k.float32 / n.float32
    let a = a0 + sweepAngle * t
    let
      px = cosPhi * cos(a) * rx - sinPhi * sin(a) * ry + cx
      py = sinPhi * cos(a) * rx + cosPhi * sin(a) * ry + cy
    segments.addSegment(Segment(at: prev, to: vec2(px, py)))
    prev = vec2(px, py)

proc flattenImpl(path: Path; tol: float32): seq[Segment] =
  ## Flatten `path` to directed line segments. Smooth shorthands (S/T) reflect
  ## the previous cubic/quad control; when the previous command was not the
  ## matching kind the control coincides with the current point (per SVG).
  var
    start = vec2(0'f32, 0'f32)
    at = vec2(0'f32, 0'f32)
    prevCubicC2 = vec2(0'f32, 0'f32)
    prevQuadC = vec2(0'f32, 0'f32)
    prevWasCubic = false
    prevWasQuad = false
  for cmd in path.commands:
    case cmd.kind
    of pMove:
      at = cmd.p; start = cmd.p
      prevWasCubic = false; prevWasQuad = false

    of pRMove:
      at = at + cmd.p; start = at
      prevWasCubic = false; prevWasQuad = false
    of pLine:
      result.addSegment(Segment(at: at, to: cmd.p)); at = cmd.p
      prevWasCubic = false; prevWasQuad = false
    of pRLine:
      let t = at + cmd.p; result.addSegment(Segment(at: at, to: t)); at = t
      prevWasCubic = false; prevWasQuad = false
    of pHLine:
      let t = vec2(cmd.v, at.y); result.addSegment(Segment(at: at, to: t)); at = t
      prevWasCubic = false; prevWasQuad = false
    of pVLine:
      let t = vec2(at.x, cmd.v); result.addSegment(Segment(at: at, to: t)); at = t
      prevWasCubic = false; prevWasQuad = false
    of pRHLine:
      let t = vec2(at.x + cmd.v, at.y); result.addSegment(Segment(at: at,
          to: t)); at = t
      prevWasCubic = false; prevWasQuad = false
    of pRVLine:
      let t = vec2(at.x, at.y + cmd.v); result.addSegment(Segment(at: at,
          to: t)); at = t
      prevWasCubic = false; prevWasQuad = false
    of pCubic:
      flattenCubic(result, at, cmd.c1, cmd.c2, cmd.c3, tol, 0)
      at = cmd.c3; prevCubicC2 = cmd.c2
      prevWasCubic = true; prevWasQuad = false
    of pRCubic:
      let c1 = at + cmd.c1
      let c2 = at + cmd.c2
      let c3 = at + cmd.c3
      flattenCubic(result, at, c1, c2, c3, tol, 0)
      at = c3; prevCubicC2 = c2
      prevWasCubic = true; prevWasQuad = false
    of pSCubic:
      let c1 = if prevWasCubic: at + at - prevCubicC2 else: at
      flattenCubic(result, at, c1, cmd.c, cmd.e, tol, 0)
      at = cmd.e; prevCubicC2 = cmd.c
      prevWasCubic = true; prevWasQuad = false
    of pRSCubic:
      let c1 = if prevWasCubic: at + at - prevCubicC2 else: at
      let c2 = at + cmd.c
      let e = at + cmd.e
      flattenCubic(result, at, c1, c2, e, tol, 0)
      at = e; prevCubicC2 = c2
      prevWasCubic = true; prevWasQuad = false
    of pQuad:
      flattenQuad(result, at, cmd.c, cmd.e, tol, 0)
      at = cmd.e; prevQuadC = cmd.c
      prevWasQuad = true; prevWasCubic = false
    of pRQuad:
      let c = at + cmd.c
      let e = at + cmd.e
      flattenQuad(result, at, c, e, tol, 0)
      at = e; prevQuadC = c
      prevWasQuad = true; prevWasCubic = false
    of pTQuad:
      let c = if prevWasQuad: at + at - prevQuadC else: at
      flattenQuad(result, at, c, cmd.p, tol, 0)
      at = cmd.p; prevQuadC = c
      prevWasQuad = true; prevWasCubic = false
    of pRTQuad:
      let c = if prevWasQuad: at + at - prevQuadC else: at
      let p = at + cmd.p
      flattenQuad(result, at, c, p, tol, 0)
      at = p; prevQuadC = c
      prevWasQuad = true; prevWasCubic = false
    of pArc:
      arcToSegments(result, at, cmd.a, cmd.r, cmd.rot, cmd.largeArc, cmd.sweep, tol)
      at = cmd.a
      prevWasCubic = false; prevWasQuad = false
    of pRArc:
      let a = at + cmd.a
      arcToSegments(result, at, a, cmd.r, cmd.rot, cmd.largeArc, cmd.sweep, tol)
      at = a
      prevWasCubic = false; prevWasQuad = false
    of pClose:
      if at.x != start.x or at.y != start.y:
        result.addSegment(Segment(at: at, to: start))
      at = start
      prevWasCubic = false; prevWasQuad = false

proc flatten*(path: Path; tol = FlattenTolerance): seq[
    Segment] {.contractual.} =
  ## Flatten `path` to directed line segments with a positive error tolerance.
  require:
    tol > 0'f32
  body:
    flattenImpl(path, tol)

proc computeBounds*(segments: seq[Segment]): Rect {.contractual.} =
  ## Axis-aligned bounding box of `segments`. Empty input is the empty rect.
  ensure:
    result.w >= 0'f32 and result.h >= 0'f32
  body:
    if segments.len == 0:
      return Rect()
    var
      minX = segments[0].at.x
      minY = segments[0].at.y
      maxX = minX
      maxY = minY
    for seg in segments:
      for p in [seg.at, seg.to]:
        if p.x < minX: minX = p.x
        if p.y < minY: minY = p.y
        if p.x > maxX: maxX = p.x
        if p.y > maxY: maxY = p.y
    result = Rect(x: minX, y: minY, w: maxX - minX, h: maxY - minY)
