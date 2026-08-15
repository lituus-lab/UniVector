# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniVector/path — SVG path representation, construction, parse, and serialize.
##
## The path is a sequence of typed commands (W3C SVG `d` grammar): moveTo,
## lineTo, the cubic/quadratic Béziers, the smooth shorthand variants, the
## horizontal/vertical lines, the elliptical arc, their relative lowercase
## forms, and closePath. `parsePath` reads an SVG `d` string; `$path` writes
## one back. Construction mirrors the Canvas/SVG path API.
import std/[math, strutils]
import contracts
import UniVector/common

type
  PathCommandKind* = enum
    ## A single SVG path command. Absolute forms are uppercase; the relative
    ## lowercase forms offset from the current point.
    pClose
    pMove, pLine, pHLine, pVLine
    pCubic, pSCubic, pQuad, pTQuad, pArc
    pRMove, pRLine, pRHLine, pRVLine
    pRCubic, pRSCubic, pRQuad, pRTQuad, pRArc

  PathCommand* = object
    ## One command in a `Path`. Field names are unique across branches so the
    ## whole object is one variant; the flattener and rasterizer dispatch on
    ## `kind`.
    case kind*: PathCommandKind
    of pClose:
      discard
    of pMove, pLine, pRMove, pRLine, pTQuad, pRTQuad:
      p*: Vec2 ## endpoint (TQuad reflects its control through the current point)
    of pHLine, pRHLine, pVLine, pRVLine:
      v*: float32 ## the single coordinate (x for HLine, y for VLine)
    of pCubic, pRCubic:
      c1*: Vec2 ## first cubic control point
      c2*: Vec2 ## second cubic control point
      c3*: Vec2 ## cubic endpoint
    of pSCubic, pRSCubic, pQuad, pRQuad:
      c*: Vec2 ## control point (the one explicit control)
      e*: Vec2 ## endpoint
    of pArc, pRArc:
      r*: Vec2 ## (rx, ry)
      rot*: float32 ## x-axis rotation, radians
      largeArc*: bool ## large-arc-flag
      sweep*: bool ## sweep-flag
      a*: Vec2 ## endpoint

  Path* = object
    ## A mutable path builder. `start` is the first point of the current
    ## sub-path (for closePath); `at` is the current point (advanced by every
    ## command that has one). Both are whole-vector assigned, never field-written.
    commands*: seq[PathCommand]
    start*: Vec2
    at*: Vec2

const
  Epsilon*: float32 = 0.0001 * PI ## geometric tolerance for coincident-point and full-circle tests.
  SplineCircleK = 4.0'f32 * (-1.0'f32 + sqrt(2.0'f32)) / 3.0'f32
    ## Bézier-approximated circle constant (the k that makes four cubic spans
    ## meet a unit circle at the 45° breakpoints).
  DegPerRad = 180.0'f32 / PI.float32 ## radians -> degrees (SVG `d` emits rotation in degrees).
  RadPerDeg = PI.float32 / 180.0'f32 ## degrees -> radians (SVG `d` parses rotation in degrees).

func isRelative*(kind: PathCommandKind): bool {.inline.} =
  ## True for the lowercase (relative) commands.
  kind in {pRMove, pRLine, pRHLine, pRVLine, pRCubic, pRSCubic, pRQuad,
           pRTQuad, pRArc}

func parameterCount*(kind: PathCommandKind): int {.inline.} =
  ## Number of scalar parameters the command carries (for parse/$).
  case kind
  of pClose: 0
  of pMove, pLine, pRMove, pRLine, pTQuad, pRTQuad: 2
  of pHLine, pVLine, pRHLine, pRVLine: 1
  of pCubic, pRCubic: 6
  of pSCubic, pRSCubic, pQuad, pRQuad: 4
  of pArc, pRArc: 7

func newPath*(): Path {.inline.} =
  ## An empty path.
  Path()

func copy*(path: Path): Path {.inline.} =
  ## An independent copy of `path`.
  result = path
  result.commands = newSeq[PathCommand](path.commands.len)
  for i, command in path.commands:
    result.commands[i] = command

func isFinite(value: float32): bool {.inline.} =
  classify(value) in {fcNormal, fcSubnormal, fcZero}

proc advanceState(path: var Path, commands: openArray[PathCommand]) =
  ## Apply `commands` to the current builder state.
  var at = path.at
  var start = path.start
  for command in commands:
    case command.kind
    of pClose:
      at = start
    of pMove:
      at = command.p
      start = at
    of pRMove:
      at += command.p
      start = at
    of pLine, pTQuad:
      at = command.p
    of pRLine, pRTQuad:
      at += command.p
    of pHLine:
      at = vec2(command.v, at.y)
    of pRHLine:
      at = vec2(at.x + command.v, at.y)
    of pVLine:
      at = vec2(at.x, command.v)
    of pRVLine:
      at = vec2(at.x, at.y + command.v)
    of pCubic:
      at = command.c3
    of pRCubic:
      at += command.c3
    of pSCubic, pQuad:
      at = command.e
    of pRSCubic, pRQuad:
      at += command.e
    of pArc:
      at = command.a
    of pRArc:
      at += command.a
  path.at = at
  path.start = start

proc refreshState(path: var Path) =
  ## Recompute builder state after the parser assigns commands directly.
  path.at = vec2(0'f32, 0'f32)
  path.start = vec2(0'f32, 0'f32)
  path.advanceState(path.commands)

proc translated*(path: Path; dx, dy: float32): Path {.contractual.} =
  ## Return an independent path translated by (`dx`, `dy`).
  ##
  ## Relative commands retain their offsets. Absolute coordinates, including
  ## Bezier controls and arc endpoints, are translated directly.
  require:
    dx.isFinite and dy.isFinite
  ensure:
    result.commands.len == path.commands.len
  body:
    if not dx.isFinite or not dy.isFinite:
      raise newException(ValueError, "path translation must be finite")
    result = path.copy
    let offset = vec2(dx, dy)
    for index, command in result.commands.mpairs:
      case command.kind
      of pClose, pRLine, pRHLine, pRVLine, pRCubic, pRSCubic,
          pRQuad, pRTQuad, pRArc:
        discard
      of pRMove:
        if index == 0:
          command.p += offset
      of pMove, pLine, pTQuad:
        command.p += offset
      of pHLine:
        command.v += dx
      of pVLine:
        command.v += dy
      of pCubic:
        command.c1 += offset
        command.c2 += offset
        command.c3 += offset
      of pSCubic, pQuad:
        command.c += offset
        command.e += offset
      of pArc:
        command.a += offset
    result.refreshState()

proc addPath*(path: var Path, other: Path) {.inline.} =
  ## Append `other`'s commands to `path`.
  path.commands.add(other.commands)
  path.advanceState(other.commands)

proc closePath*(path: var Path) {.inline.} =
  ## Close the current sub-path with a line back to `start`.
  path.commands.add(PathCommand(kind: pClose))
  path.at = path.start

proc moveTo*(path: var Path, x, y: float32) {.inline.} =
  ## Begin a new sub-path at (x, y).
  path.commands.add(PathCommand(kind: pMove, p: vec2(x, y)))
  path.start = vec2(x, y)
  path.at = path.start

proc moveTo*(path: var Path, v: Vec2) {.inline.} = path.moveTo(v.x, v.y)

proc lineTo*(path: var Path, x, y: float32) {.inline.} =
  ## Add a line to (x, y).
  path.commands.add(PathCommand(kind: pLine, p: vec2(x, y)))
  path.at = vec2(x, y)

proc lineTo*(path: var Path, v: Vec2) {.inline.} = path.lineTo(v.x, v.y)

proc bezierCurveTo*(path: var Path, x1, y1, x2, y2, x3,
    y3: float32) {.inline.} =
  ## Add a cubic Bézier with control points (x1,y1), (x2,y2) and endpoint (x3,y3).
  path.commands.add(PathCommand(kind: pCubic, c1: vec2(x1, y1), c2: vec2(x2, y2),
                                c3: vec2(x3, y3)))
  path.at = vec2(x3, y3)

proc bezierCurveTo*(path: var Path, ctrl1, ctrl2, to: Vec2) {.inline.} =
  path.bezierCurveTo(ctrl1.x, ctrl1.y, ctrl2.x, ctrl2.y, to.x, to.y)

proc quadraticCurveTo*(path: var Path, x1, y1, x2, y2: float32) {.inline.} =
  ## Add a quadratic Bézier with control (x1,y1) and endpoint (x2,y2).
  path.commands.add(PathCommand(kind: pQuad, c: vec2(x1, y1), e: vec2(x2, y2)))
  path.at = vec2(x2, y2)

proc quadraticCurveTo*(path: var Path, ctrl, to: Vec2) {.inline.} =
  path.quadraticCurveTo(ctrl.x, ctrl.y, to.x, to.y)

proc ellipticalArcTo*(path: var Path, rx, ry, rotation: float32,
                      largeArc, sweep: bool, x, y: float32) {.contractual.} =
  ## Add an elliptical arc endpoint with the SVG large-arc/sweep flags.
  require:
    rx >= 0'f32 and ry >= 0'f32
  body:
    path.commands.add(PathCommand(kind: pArc, r: vec2(rx, ry), rot: rotation,
                                  largeArc: largeArc, sweep: sweep, a: vec2(x, y)))
    path.at = vec2(x, y)

proc arc*(path: var Path, x, y, r, a0, a1: float32,
    ccw = false) {.contractual.} =
  ## Add a circular arc of radius `r` from angle `a0` to `a1` about (x, y).
  ## `r == 0` adds nothing; `r < 0` is outside the domain.
  require:
    r >= 0'f32
  body:
    if r == 0:
      return
    let
      dx = r * cos(a0)
      dy = r * sin(a0)
      x0 = x + dx
      y0 = y + dy
      cw = not ccw
    if path.commands.len == 0:
      path.moveTo(x0, y0)
    elif abs(path.at.x - x0) > Epsilon or abs(path.at.y - y0) > Epsilon:
      path.lineTo(x0, y0)
    var angle = if ccw: a0 - a1 else: a1 - a0
    if angle < 0:
      angle = angle mod (2 * PI) + 2 * PI
    if angle > (2 * PI) - Epsilon:
      # Full circle: two arcs back-to-back so neither spans more than a half turn.
      path.ellipticalArcTo(r, r, 0, true, cw, x - dx, y - dy)
      path.at = vec2(x0, y0)
      path.ellipticalArcTo(r, r, 0, true, cw, path.at.x, path.at.y)
    elif angle > Epsilon:
      path.at = vec2(x + r * cos(a1), y + r * sin(a1))
      path.ellipticalArcTo(r, r, 0, angle >= PI, cw, path.at.x, path.at.y)

proc arc*(path: var Path, pos: Vec2, r: float32, a: Vec2,
    ccw = false) {.inline.} =
  path.arc(pos.x, pos.y, r, a.x, a.y, ccw)

proc arcTo*(path: var Path, x1, y1, x2, y2, r: float32) {.contractual.} =
  ## Add a rounded corner of radius `r` tangent to the legs (at->(x1,y1)) and
  ## ((x1,y1)->(x2,y2)). `r < 0` is outside the domain.
  require:
    r >= 0'f32
  body:
    let
      x0 = path.at.x
      y0 = path.at.y
      x21 = x2 - x1
      y21 = y2 - y1
      x01 = x0 - x1
      y01 = y0 - y1
      l01_2 = x01 * x01 + y01 * y01
      l21_2 = x21 * x21 + y21 * y21
    if path.commands.len == 0:
      path.moveTo(x0, y0)
    elif not (l01_2 > Epsilon):
      discard # (x1,y1) coincident with the current point: nothing to do.
    elif not (l21_2 > Epsilon) or
        not (abs(y01 * x21 - y21 * x01) > Epsilon) or r == 0:
      path.lineTo(x1, y1) # collinear legs, or zero radius: just a line.
    else:
      let
        x20 = x2 - x0
        y20 = y2 - y0
        l20_2 = x20 * x20 + y20 * y20
        l21 = sqrt(l21_2)
        l01 = sqrt(l01_2)
        # PI is float64; keep the tangent term in float32 so the leg math stays Vec2.
        l = (r * tan((PI - arccos((l21_2 + l01_2 - l20_2) / (2 * l21 * l01))) / 2)).float32
        t01 = l / l01
        t21 = l / l21
      if abs(t01 - 1) > Epsilon:
        path.lineTo(x1 + t01 * x01, y1 + t01 * y01)
      path.at = vec2(x1 + t21 * x21, y1 + t21 * y21)
      path.ellipticalArcTo(r, r, 0, false, y01 * x20 > x01 * y20, path.at.x, path.at.y)

proc arcTo*(path: var Path, a, b: Vec2, r: float32) {.inline.} =
  path.arcTo(a.x, a.y, b.x, b.y, r)

proc rect*(path: var Path, x, y, w, h: float32, clockwise = true) =
  ## Add a rectangle. `clockwise = false` reverses the winding, for subtracting
  ## a rect under the even-odd rule.
  if clockwise:
    path.moveTo(x, y)
    path.lineTo(x + w, y)
    path.lineTo(x + w, y + h)
    path.lineTo(x, y + h)
  else:
    path.moveTo(x, y)
    path.lineTo(x, y + h)
    path.lineTo(x + w, y + h)
    path.lineTo(x + w, y)
  path.closePath()

proc rect*(path: var Path, r: Rect, clockwise = true) {.inline.} =
  path.rect(r.x, r.y, r.w, r.h, clockwise)

proc roundedRect*(path: var Path, x, y, w, h, nw, ne, se, sw: float32,
                  clockwise = true) =
  ## Add a rounded rectangle with per-corner radii (nw/ne/se/sw), clamped to
  ## half the shorter side.
  var (nw, ne, se, sw) = (nw, ne, se, sw)
  let maxR = min(w / 2, h / 2)
  nw = max(0'f32, min(nw, maxR))
  ne = max(0'f32, min(ne, maxR))
  se = max(0'f32, min(se, maxR))
  sw = max(0'f32, min(sw, maxR))
  if nw == 0 and ne == 0 and se == 0 and sw == 0:
    path.rect(x, y, w, h, clockwise)
    return
  let s = SplineCircleK
  let
    t1 = vec2(x + nw, y)
    t2 = vec2(x + w - ne, y)
    r1 = vec2(x + w, y + ne)
    r2 = vec2(x + w, y + h - se)
    b1 = vec2(x + w - se, y + h)
    b2 = vec2(x + sw, y + h)
    l1 = vec2(x, y + h - sw)
    l2 = vec2(x, y + nw)
    t1h = t1 + vec2(-nw * s, 0'f32)
    t2h = t2 + vec2(+ne * s, 0'f32)
    r1h = r1 + vec2(0'f32, -ne * s)
    r2h = r2 + vec2(0'f32, +se * s)
    b1h = b1 + vec2(+se * s, 0'f32)
    b2h = b2 + vec2(-sw * s, 0'f32)
    l1h = l1 + vec2(0'f32, +sw * s)
    l2h = l2 + vec2(0'f32, -nw * s)
  if clockwise:
    path.moveTo(t1)
    path.lineTo(t2)
    path.bezierCurveTo(t2h, r1h, r1)
    path.lineTo(r2)
    path.bezierCurveTo(r2h, b1h, b1)
    path.lineTo(b2)
    path.bezierCurveTo(b2h, l1h, l1)
    path.lineTo(l2)
    path.bezierCurveTo(l2h, t1h, t1)
  else:
    path.moveTo(t1)
    path.bezierCurveTo(t1h, l2h, l2)
    path.lineTo(l1)
    path.bezierCurveTo(l1h, b2h, b2)
    path.lineTo(b1)
    path.bezierCurveTo(b1h, r2h, r2)
    path.lineTo(r1)
    path.bezierCurveTo(r1h, t2h, t2)
    path.lineTo(t1)
  path.closePath()

proc roundedRect*(path: var Path, r: Rect, nw, ne, se, sw: float32,
                  clockwise = true) {.inline.} =
  path.roundedRect(r.x, r.y, r.w, r.h, nw, ne, se, sw, clockwise)

proc ellipse*(path: var Path, cx, cy, rx, ry: float32) {.contractual.} =
  ## Add an axis-aligned ellipse as four cubic Bézier spans.
  require:
    rx >= 0'f32 and ry >= 0'f32
  body:
    let
      mx = SplineCircleK * rx
      my = SplineCircleK * ry
    path.moveTo(cx + rx, cy)
    path.bezierCurveTo(cx + rx, cy + my, cx + mx, cy + ry, cx, cy + ry)
    path.bezierCurveTo(cx - mx, cy + ry, cx - rx, cy + my, cx - rx, cy)
    path.bezierCurveTo(cx - rx, cy - my, cx - mx, cy - ry, cx, cy - ry)
    path.bezierCurveTo(cx + mx, cy - ry, cx + rx, cy - my, cx + rx, cy)
    path.closePath()

proc ellipse*(path: var Path, center: Vec2, rx, ry: float32) {.inline.} =
  path.ellipse(center.x, center.y, rx, ry)

proc circle*(path: var Path, cx, cy, r: float32) {.contractual, inline.} =
  ## Add a circle as a special case of `ellipse`.
  require:
    r >= 0'f32
  body:
    path.ellipse(cx, cy, r, r)

proc circle*(path: var Path, c: Circle) {.inline.} =
  path.ellipse(c.pos.x, c.pos.y, c.radius, c.radius)

proc polygon*(path: var Path, x, y, size: float32, sides: int) {.contractual.} =
  ## Add a regular `sides`-gon "facing north" with circumradius `size` at (x, y).
  require:
    sides > 2
  body:
    path.moveTo(x + size * sin(0.0'f32), y - size * cos(0.0'f32))
    for side in 1 .. sides - 1:
      path.lineTo(
        x + size * sin(side.float32 * 2.0'f32 * PI / sides.float32),
        y - size * cos(side.float32 * 2.0'f32 * PI / sides.float32))
    path.closePath()

proc polygon*(path: var Path, pos: Vec2, size: float32, sides: int) {.inline.} =
  path.polygon(pos.x, pos.y, size, sides)

proc writeNum(result: var string, n: float32) =
  ## Append `n` to an SVG `d` buffer: integer-valued numbers print without a
  ## decimal part; a single space separates values. Non-integers use fixed
  ## point (no exponent, which some SVG renderers reject) with trailing zeros
  ## trimmed, keeping at least one fractional digit.
  if classify(n) in {fcNan, fcInf, fcNegInf}:
    raise newException(ValueError, "path: cannot serialize a non-finite coordinate")
  if floor(n) == n and n >= low(int).float32 and n <= high(int).float32:
    result.addInt int(n)
  else:
    var s = formatFloat(n.float64, ffDecimal, 6)
    var endIdx = s.len
    while endIdx > 1 and s[endIdx - 1] == '0': endIdx -= 1
    if endIdx > 1 and s[endIdx - 1] == '.': endIdx -= 1
    result.add s[0 ..< endIdx]
  result.add ' '

proc `$`*(path: Path): string =
  ## Serialize `path` to an SVG `d` string. Integer-valued numbers print
  ## without a decimal part, matching common SVG output.
  for cmd in path.commands:
    case cmd.kind
    of pMove: result.add "M "
    of pLine: result.add "L "
    of pHLine: result.add "H "
    of pVLine: result.add "V "
    of pCubic: result.add "C "
    of pSCubic: result.add "S "
    of pQuad: result.add "Q "
    of pTQuad: result.add "T "
    of pArc: result.add "A "
    of pRMove: result.add "m "
    of pRLine: result.add "l "
    of pRHLine: result.add "h "
    of pRVLine: result.add "v "
    of pRCubic: result.add "c "
    of pRSCubic: result.add "s "
    of pRQuad: result.add "q "
    of pRTQuad: result.add "t "
    of pRArc: result.add "a "
    of pClose:
      result.add "Z "
      continue
    case cmd.kind
    of pMove, pLine, pRMove, pRLine, pTQuad, pRTQuad:
      writeNum(result, cmd.p.x); writeNum(result, cmd.p.y)
    of pHLine, pRHLine, pVLine, pRVLine:
      writeNum(result, cmd.v)
    of pCubic, pRCubic:
      writeNum(result, cmd.c1.x); writeNum(result, cmd.c1.y)
      writeNum(result, cmd.c2.x); writeNum(result, cmd.c2.y)
      writeNum(result, cmd.c3.x); writeNum(result, cmd.c3.y)
    of pSCubic, pRSCubic, pQuad, pRQuad:
      writeNum(result, cmd.c.x); writeNum(result, cmd.c.y)
      writeNum(result, cmd.e.x); writeNum(result, cmd.e.y)
    of pArc, pRArc:
      writeNum(result, cmd.r.x); writeNum(result, cmd.r.y)
      writeNum(result, cmd.rot * DegPerRad) # rotation is radians internally, degrees in `d`.
      writeNum(result, cmd.largeArc.float32)
      writeNum(result, cmd.sweep.float32)
      writeNum(result, cmd.a.x); writeNum(result, cmd.a.y)
    of pClose:
      discard
  if result.len > 0 and result[^1] == ' ':
    result.setLen(result.len - 1)

proc flushCommands(result: var Path, kind: PathCommandKind, nums: seq[float32]) =
  ## Turn the accumulated `nums` into commands of `kind`. A move that repeats
  ## degenerates to lines (M x y x y -> M, L, L); an arity mismatch raises.
  let pc = parameterCount(kind)
  if pc == 0:
    if nums.len != 0:
      raise newException(ValueError, "parsePath: " & $kind & " takes no parameters")
    result.commands.add PathCommand(kind: kind)
    return
  if nums.len == 0 or nums.len mod pc != 0:
    raise newException(ValueError, "parsePath: wrong parameter count for " & $kind)
  var k = kind
  for batch in 0 ..< nums.len div pc:
    if batch > 0:
      if k == pMove: k = pLine
      elif k == pRMove: k = pRLine
    let kk = k # case-object construction needs an immutable discriminator
    let b = batch * pc
    case kk
    of pMove, pLine, pRMove, pRLine, pTQuad, pRTQuad:
      result.commands.add PathCommand(kind: kk, p: vec2(nums[b], nums[b + 1]))
    of pHLine, pRHLine, pVLine, pRVLine:
      result.commands.add PathCommand(kind: kk, v: nums[b])
    of pCubic, pRCubic:
      result.commands.add PathCommand(kind: kk, c1: vec2(nums[b], nums[b + 1]),
                                      c2: vec2(nums[b + 2], nums[b + 3]),
                                      c3: vec2(nums[b + 4], nums[b + 5]))
    of pSCubic, pRSCubic, pQuad, pRQuad:
      result.commands.add PathCommand(kind: kk, c: vec2(nums[b], nums[b + 1]),
                                      e: vec2(nums[b + 2], nums[b + 3]))
    of pArc, pRArc:
      if nums[b] < 0'f32 or nums[b + 1] < 0'f32 or
          (nums[b + 3] != 0'f32 and nums[b + 3] != 1'f32) or
          (nums[b + 4] != 0'f32 and nums[b + 4] != 1'f32):
        raise newException(ValueError, "parsePath: invalid arc parameter")
      result.commands.add PathCommand(kind: kk, r: vec2(nums[b], nums[b + 1]),
                                      rot: nums[b + 2] * RadPerDeg,
                                      largeArc: nums[b + 3] != 0'f32,
                                      sweep: nums[b + 4] != 0'f32,
                                      a: vec2(nums[b + 5], nums[b + 6]))
    of pClose:
      discard

proc charToKind(ch: char): PathCommandKind =
  ## Map an SVG `d` command letter to its kind. Raises on anything else.
  case ch
  of 'm': pRMove
  of 'l': pRLine
  of 'h': pRHLine
  of 'v': pRVLine
  of 'c': pRCubic
  of 's': pRSCubic
  of 'q': pRQuad
  of 't': pRTQuad
  of 'a': pRArc
  of 'M': pMove
  of 'L': pLine
  of 'H': pHLine
  of 'V': pVLine
  of 'C': pCubic
  of 'S': pSCubic
  of 'Q': pQuad
  of 'T': pTQuad
  of 'A': pArc
  of 'z', 'Z': pClose
  else: raise newException(ValueError, "parsePath: unknown command '" & $ch & "'")

proc parsePath*(s: string): Path =
  ## Parse an SVG `d` string into a `Path`. Raises `ValueError` on a malformed
  ## command or an arity mismatch (the W3C grammar is strict about counts).
  result = newPath()
  if s.len == 0:
    return
  var
    i = 0
    kind: PathCommandKind
    nums: seq[float32]
    armed = false
    numStart = -1
    hitDecimal = false

  proc finish(i: int) =
    if numStart >= 0:
      let value = parseFloat(s[numStart ..< i])
      if classify(value) in {fcNan, fcInf, fcNegInf}:
        raise newException(ValueError, "parsePath: non-finite number")
      nums.add value
    numStart = -1
    hitDecimal = false

  # The arc flags are single characters ('0'/'1') packed next to a coordinate,
  # so the scanner must cut a number at the flag boundary, not only at whitespace.
  template expectsArcFlag: bool =
    kind in {pArc, pRArc} and nums.len mod 7 in {3, 4}

  while i < s.len:
    let ch = s[i]
    case ch
    of 'm', 'l', 'h', 'v', 'c', 's', 'q', 't', 'a', 'z',
       'M', 'L', 'H', 'V', 'C', 'S', 'Q', 'T', 'A', 'Z':
      finish(i)
      if armed:
        result.flushCommands(kind, nums)
        nums.setLen(0)
      let newKind = charToKind(ch)
      if newKind == pClose:
        result.commands.add PathCommand(kind: pClose)
        armed = false
      else:
        kind = newKind
        armed = true
    of '-', '+':
      if not armed:
        raise newException(ValueError, "parsePath: number without a command")
      if expectsArcFlag():
        raise newException(ValueError, "parsePath: arc flag must be 0 or 1")
      if numStart >= 0 and i > 0 and s[i - 1] in {'e', 'E'}:
        discard # exponent sign: keep accumulating the current number.
      else:
        finish(i)
        numStart = i
    of '.':
      if not armed:
        raise newException(ValueError, "parsePath: number without a command")
      if expectsArcFlag():
        raise newException(ValueError, "parsePath: arc flag must be 0 or 1")
      if hitDecimal:
        finish(i)
      hitDecimal = true
      if numStart < 0:
        numStart = i
    of ' ', ',', '\r', '\n', '\t':
      finish(i)
    else:
      if ch notin {'0'..'9', 'e', 'E'}:
        raise newException(ValueError, "parsePath: unexpected character '" &
            ch & "'")
      if not armed:
        raise newException(ValueError, "parsePath: number without a command")
      if numStart >= 0 and expectsArcFlag():
        finish(i)
      if expectsArcFlag() and ch notin {'0', '1'}:
        raise newException(ValueError, "parsePath: arc flag must be 0 or 1")
      if numStart >= 0 and i - 1 == numStart and s[i - 1] == '0' and
          s[i] in {'0'..'9', '.'}:
        finish(i) # leading 0 of "01.3" -> [0, 1.3]; "0e5" stays one number.
      if numStart < 0:
        numStart = i
    inc i

  finish(s.len)
  if armed:
    result.flushCommands(kind, nums)
  if result.commands.len > 0 and result.commands[0].kind notin {pMove, pRMove}:
    raise newException(ValueError, "parsePath: path must begin with moveto")
  result.refreshState()
