# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[sequtils, unittest]
from contracts import PreConditionDefect
import UniVector

proc approx(a, b: float32; eps = 1e-3'f32): bool = abs(a - b) <= eps

suite "flatten":
  test "rect flattens to four closing segments":
    var p = newPath()
    p.rect(0.float32, 0.float32, 10.float32, 20.float32)
    let segs = p.flatten()
    require segs.len == 4
    check approx(segs[0].at.x, 0'f32) and approx(segs[0].at.y, 0'f32)
    check approx(segs[0].to.x, 10'f32) and approx(segs[0].to.y, 0'f32)

  test "cubic flattens to more than one segment":
    var p = newPath()
    p.moveTo(0.float32, 0.float32)
    p.bezierCurveTo(10.float32, 0.float32, 10.float32, 100.float32,
                    100.float32, 100.float32)
    let segs = p.flatten()
    require segs.len > 2
    check approx(segs[0].at.x, 0'f32) and approx(segs[0].at.y, 0'f32)
    check approx(segs[^1].to.x, 100'f32) and approx(segs[^1].to.y, 100'f32)

  test "quadratic flattens to more than one segment":
    var p = newPath()
    p.moveTo(0.float32, 0.float32)
    p.quadraticCurveTo(50.float32, 100.float32, 100.float32, 0.float32)
    let segs = p.flatten()
    require segs.len > 2
    check approx(segs[^1].to.x, 100'f32) and approx(segs[^1].to.y, 0'f32)

  test "close emits a closing segment when not already at start":
    let p = parsePath("M 0 0 L 10 0 L 10 10 Z")
    let segs = p.flatten()
    require segs.len == 3 # 2 lines + the close back to (0,0)
    check approx(segs[^1].to.x, 0'f32) and approx(segs[^1].to.y, 0'f32)

  test "open path emits no closing segment":
    let p = parsePath("M 0 0 L 10 0 L 10 10")
    let segs = p.flatten()
    check segs.len == 2

  test "arc endpoint reached":
    let p = parsePath("M 0 0 A 50 30 0 0 1 100 0")
    let segs = p.flatten()
    require segs.len >= 1
    check approx(segs[^1].to.x, 100'f32)
    check approx(segs[^1].to.y, 0'f32)

  test "circle bounds are tight":
    var p = newPath()
    p.circle(50.float32, 50.float32, 25.float32)
    let b = computeBounds(p.flatten())
    check approx(b.x, 25'f32)
    check approx(b.y, 25'f32)
    check approx(b.w, 50'f32)
    check approx(b.h, 50'f32)

  test "computeBounds of empty is empty":
    let b: seq[Segment] = @[]
    let r = computeBounds(b)
    check r.w == 0.float32 and r.h == 0.float32

  test "smooth cubic reflects previous control":
    let p = parsePath("M 0 0 C 10 0 10 100 100 100 S 190 100 200 0")
    let segs = p.flatten()
    require segs.len > 4
    check approx(segs[^1].to.x, 200'f32) and approx(segs[^1].to.y, 0'f32)

  test "arc with one zero radius becomes one line segment":
    # Either radius zero is a straight line per SVG, not only both zero.
    let p = parsePath("M 0 0 A 0 30 0 0 1 100 0")
    let segs = p.flatten()
    require segs.len == 1
    check approx(segs[^1].to.x, 100'f32) and approx(segs[^1].to.y, 0'f32)

  test "arc endpoint equal to current point emits no span":
    # at == to: degenerate, no movement -> no span emitted.
    let p = parsePath("M 100 0 A 50 30 0 0 1 100 0")
    let segs = p.flatten()
    check segs.len == 0

  test "degenerate cubic collapses to few segments":
    # Controls and endpoint all (5,5): flat, emits one span, not 2^depth.
    let p = parsePath("M 0 0 C 5 5 5 5 5 5")
    let segs = p.flatten()
    require segs.len > 0 and segs.len <= 2
    check approx(segs[^1].to.x, 5'f32) and approx(segs[^1].to.y, 5'f32)

  test "closed quadratic with a distant control keeps its loop":
    var p = newPath()
    p.moveTo(0'f32, 0'f32)
    p.quadraticCurveTo(50'f32, 100'f32, 0'f32, 0'f32)
    let segs = p.flatten()
    check segs.len > 1
    check segs.anyIt(abs(it.to.y) > 1'f32)

  test "point cubic does not expand to the depth cap":
    var p = newPath()
    p.moveTo(5'f32, 5'f32)
    p.bezierCurveTo(5'f32, 5'f32, 5'f32, 5'f32, 5'f32, 5'f32)
    check p.flatten().len == 1

  when not defined(release):
    test "contour flattening rejects non-positive tolerance before mutation":
      var contours = @[FlattenContour(first: 1, count: 2, closed: true)]
      expect PreConditionDefect:
        discard newPath().flattenWithContours(0'f32, contours)
      check contours == @[FlattenContour(first: 1, count: 2, closed: true)]
