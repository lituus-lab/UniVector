# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniVector

suite "version":
  test "UniVectorVersion is 1.0.0":
    check UniVectorVersion == "1.0.0"

suite "leaf types":
  test "Vec2 aliases UniLinalg Vector2f":
    var p: Vec2 = vec2(1.float32, 2.float32)
    check p.x == 1.float32
    check p.y == 2.float32
    check p.lengthSquared() == 5.float32

  test "Rect holds origin + size (flat x/y/w/h)":
    let r = Rect(x: 0, y: 0, w: 3, h: 4)
    check r.w == 3.float32
    check r.h == 4.float32

  test "Segment is two Vec2s (at/to)":
    let s = Segment(at: vec2(0.float32, 0.float32), to: vec2(1.float32, 1.float32))
    check s.to.x == 1.float32
    check s.to.y == 1.float32

  test "winding rules distinct":
    check NonZero.int != EvenOdd.int
