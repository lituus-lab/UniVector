# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, sequtils, unittest]
import contracts
import UniVector

suite "stroke expansion":
  test "butt cap bounds stop at the endpoints":
    let centerline = parsePath("M 2 4 L 8 4").preparePath()
    let outline = centerline.strokeToPath(defaultStrokeStyle(2'f32))
    check outline.flatten().computeBounds() == Rect(x: 2, y: 3, w: 6, h: 2)

  test "square and round caps extend by half the width":
    let centerline = parsePath("M 2 4 L 8 4").preparePath()
    let square = centerline.strokeToPath(StrokeStyle(width: 2, cap: SquareCap,
        join: MiterJoin, miterLimit: 4))
    let round = centerline.strokeToPath(StrokeStyle(width: 2, cap: RoundCap,
        join: MiterJoin, miterLimit: 4))
    check square.flatten().computeBounds() == Rect(x: 1, y: 3, w: 8, h: 2)
    let roundBounds = round.flatten(0.1'f32).computeBounds()
    check abs(roundBounds.x - 1'f32) < 0.01'f32
    check abs(roundBounds.w - 8'f32) < 0.01'f32

  test "all joins produce finite outlines":
    let corner = parsePath("M 2 8 L 5 2 L 8 8").preparePath()
    for join in LineJoin:
      let outline = corner.strokeToPath(StrokeStyle(width: 2, cap: ButtCap,
          join: join, miterLimit: 4))
      check outline.commands.len > 0
      let bounds = outline.flatten().computeBounds()
      check classify(bounds.x) == fcNormal
      check classify(bounds.w) == fcNormal

  test "shared endpoints do not join separate subpaths":
    let centerlines = parsePath("M 0 0 L 4 0 M 4 0 L 4 4").preparePath()
    let outline = centerlines.strokeToPath(StrokeStyle(width: 2,
        cap: ButtCap, join: BevelJoin, miterLimit: 4))
    check outline.commands.len == 10

  test "dash patterns normalize odd inputs without exposing storage":
    let pattern = dashPattern([3'f32, 2'f32, 1'f32], -2'f32)
    var snapshot = pattern.lengths
    check snapshot == @[3'f32, 2'f32, 1'f32, 3'f32, 2'f32, 1'f32]
    check pattern.offset == -2'f32
    snapshot[0] = 99'f32
    check pattern.lengths[0] == 3'f32
    check dashPattern([]).isSolid

  test "dashes expand into independently capped outlines":
    let centerline = parsePath("M 0 0 L 10 0").preparePath()
    var style = defaultStrokeStyle(2'f32)
    style.dash = dashPattern([2'f32, 2'f32])
    let outline = centerline.strokeToPath(style)
    check outline.commands.len == 15
    let segments = outline.flatten()
    check segments.computeBounds() == Rect(x: 0, y: -1, w: 10, h: 2)

  test "dash phase and contour state are deterministic":
    let centerlines = parsePath("M 0 0 L 6 0 M 10 0 L 16 0").preparePath()
    var style = defaultStrokeStyle(2'f32)
    style.dash = dashPattern([2'f32, 2'f32], 1'f32)
    let outline = centerlines.strokeToPath(style)
    # Each contour restarts at the same phase and yields two rectangles.
    check outline.commands.len == 20

  test "closed dashed contours preserve the seam join":
    let centerline = parsePath("M 0 0 L 5 0 L 5 5 L 0 5 Z").preparePath()
    var style = defaultStrokeStyle(1'f32)
    style.dash = dashPattern([6'f32, 2'f32])
    let outline = centerline.strokeToPath(style)
    check outline.commands.len > 0
    let bounds = outline.flatten().computeBounds()
    check classify(bounds.x) in {fcZero, fcNormal, fcNegZero}
    check classify(bounds.w) == fcNormal

  when not defined(release):
    test "stroke style contracts reject invalid dimensions":
      expect PreConditionDefect:
        discard newPath().preparePath().strokeToPath(
            defaultStrokeStyle(0'f32))

    test "dash contracts reject invalid values":
      expect PreConditionDefect:
        discard dashPattern([1'f32, 0'f32])
      expect PreConditionDefect:
        discard dashPattern([NaN.float32])
      expect PreConditionDefect:
        discard dashPattern([high(float32) * 0.75'f32])
      expect PreConditionDefect:
        discard dashPattern(newSeqWith(MaxDashPatternElements + 1, 1'f32))

  when defined(release):
    test "dash runtime guards survive release builds":
      expect ValueError:
        discard dashPattern([1'f32, 0'f32])
      expect ValueError:
        discard dashPattern([high(float32) * 0.75'f32])
      expect ValueError:
        discard newPath().preparePath().strokeToPath(
            defaultStrokeStyle(0'f32))
      expect ValueError:
        discard dashPattern(newSeqWith(MaxDashPatternElements + 1, 1'f32))
