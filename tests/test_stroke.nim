# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, unittest]
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

  when not defined(release):
    test "stroke style contracts reject invalid dimensions":
      expect PreConditionDefect:
        discard newPath().preparePath().strokeToPath(
            defaultStrokeStyle(0'f32))
