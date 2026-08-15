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

  DashPattern* = object
    lengthsData: seq[float32]
    offsetData: float32
    cycleData: float32

  StrokeStyle* = object
    width*: float32
    cap*: LineCap
    join*: LineJoin
    miterLimit*: float32
    dash*: DashPattern

const
  DefaultMiterLimit* = 4'f32
  MaxDashPatternElements* = 1_024
  MaxDashSegments* = MaxFlattenSegments div 16

func defaultStrokeStyle*(width: float32): StrokeStyle {.inline.} =
  ## Canvas/SVG-compatible default cap, join, and miter limit.
  StrokeStyle(width: width, cap: ButtCap, join: MiterJoin,
      miterLimit: DefaultMiterLimit)

func isValidDashLengths(lengths: openArray[float32]): bool =
  var cycle = 0'f32
  for value in lengths:
    if classify(value) != fcNormal or value <= 0'f32:
      return false
    cycle += value
    if classify(cycle) != fcNormal:
      return false
  if lengths.len mod 2 != 0 and classify(cycle * 2'f32) != fcNormal:
    return false
  true

func isFinite(value: float32): bool {.inline.} =
  classify(value) notin {fcNan, fcInf, fcNegInf}

proc dashPattern*(lengths: openArray[float32]; offset = 0'f32): DashPattern
    {.contractual.} =
  ## A repeating SVG-compatible on/off pattern. An empty pattern is solid.
  ## Odd-length inputs are repeated so every cycle has an even element count.
  require:
    lengths.len <= MaxDashPatternElements
    isFinite(offset)
    isValidDashLengths(lengths)
  body:
    if lengths.len > MaxDashPatternElements:
      raise newException(ValueError, "dashPattern: pattern limit exceeded")
    if not isFinite(offset):
      raise newException(ValueError, "dashPattern: offset must be finite")
    if not isValidDashLengths(lengths):
      raise newException(ValueError,
          "dashPattern: lengths must be finite and strictly positive")
    result.lengthsData = newSeqOfCap[float32](
        if lengths.len mod 2 == 0: lengths.len else: lengths.len * 2)
    for value in lengths:
      result.lengthsData.add(value)
      result.cycleData += value
    if lengths.len mod 2 != 0:
      for value in lengths:
        result.lengthsData.add(value)
      result.cycleData *= 2'f32
    result.offsetData = offset

func isSolid*(pattern: DashPattern): bool {.inline.} =
  ## Whether the stroke is uninterrupted.
  pattern.lengthsData.len == 0

proc lengths*(pattern: DashPattern): seq[float32] =
  ## Independent snapshot of the normalized, even-length pattern.
  result = newSeq[float32](pattern.lengthsData.len)
  for i, value in pattern.lengthsData:
    result[i] = value

func offset*(pattern: DashPattern): float32 {.inline.} =
  ## Phase offset in path units.
  pattern.offsetData

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

proc addPiece(path: var Path; points: seq[Vec2]; closed: bool) =
  if points.len < 2: return
  path.moveTo(points[0])
  for i in 1 ..< points.len:
    path.lineTo(points[i])
  if closed:
    path.closePath()

proc dashContour(prepared: PreparedPath; contourIndex: int;
                 pattern: DashPattern; path: var Path;
                 emittedSegments: var int) =
  let contour = prepared.contour(contourIndex)
  var
    phase = pattern.offsetData mod pattern.cycleData
    patternIndex = 0
  if phase < 0'f32:
    phase += pattern.cycleData
  while phase >= pattern.lengthsData[patternIndex]:
    phase -= pattern.lengthsData[patternIndex]
    patternIndex = (patternIndex + 1) mod pattern.lengthsData.len
  var
    remaining = pattern.lengthsData[patternIndex] - phase
    drawing = patternIndex mod 2 == 0
    pieces: seq[seq[Vec2]]
    active = -1
    startsDrawing = drawing
    endsDrawing = false
  for segmentIndex in contour.first ..< contour.first + contour.count:
    let segment = prepared.segment(segmentIndex)
    let segmentLength = length(segment.to - segment.at)
    if segmentLength == 0'f32:
      continue
    var travelled = 0'f32
    while travelled < segmentLength:
      let amount = min(remaining, segmentLength - travelled)
      if amount <= 0'f32 or travelled + amount <= travelled:
        raise newException(ValueError,
            "strokeToPath: dash pattern is below float32 path resolution")
      let
        start = segment.at + (segment.to - segment.at) * (travelled / segmentLength)
        finish = segment.at + (segment.to - segment.at) *
            ((travelled + amount) / segmentLength)
      if drawing and amount > 0'f32:
        if active < 0:
          pieces.add(@[start])
          active = pieces.high
        pieces[active].add(finish)
        inc emittedSegments
        if emittedSegments > MaxDashSegments:
          raise newException(ValueError,
              "strokeToPath: dashed segment limit exceeded")
      travelled += amount
      remaining -= amount
      endsDrawing = drawing
      if remaining <= Epsilon:
        patternIndex = (patternIndex + 1) mod pattern.lengthsData.len
        remaining = pattern.lengthsData[patternIndex]
        drawing = patternIndex mod 2 == 0
        if not drawing:
          active = -1
  if contour.closed and startsDrawing and endsDrawing and pieces.len > 0:
    if pieces.len == 1:
      path.addPiece(pieces[0], true)
      return
    var merged = pieces[^1]
    for i in 1 ..< pieces[0].len:
      merged.add(pieces[0][i])
    pieces[0] = merged
    pieces.setLen(pieces.len - 1)
  for piece in pieces:
    path.addPiece(piece, false)

proc dashedPath(prepared: PreparedPath; pattern: DashPattern): Path =
  result = newPath()
  var emittedSegments = 0
  for contourIndex in 0 ..< prepared.contourCount:
    prepared.dashContour(contourIndex, pattern, result, emittedSegments)

proc strokeToPathImpl(prepared: PreparedPath; style: StrokeStyle): Path =
  if not style.dash.isSolid:
    var solidStyle = style
    solidStyle.dash = DashPattern()
    return prepared.dashedPath(style.dash).preparePath(prepared.tolerance)
      .strokeToPathImpl(solidStyle)
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
    if classify(style.width) != fcNormal or style.width <= 0'f32 or
        classify(style.miterLimit) != fcNormal or style.miterLimit < 1'f32:
      raise newException(ValueError, "strokeToPath: invalid stroke style")
    strokeToPathImpl(prepared, style)

proc strokeToPath*(path: Path; style: StrokeStyle;
                   tolerance = FlattenTolerance): Path {.contractual.} =
  ## Prepare and expand `path` using `tolerance`.
  require:
    tolerance > 0'f32
  body:
    if classify(tolerance) != fcNormal or tolerance <= 0'f32:
      raise newException(ValueError, "strokeToPath: tolerance must be positive")
    path.preparePath(tolerance).strokeToPath(style)
