# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import contracts
import UniVector

suite "prepared paths":
  test "cache segments, bounds, and tolerance":
    var path = newPath()
    path.rect(1, 2, 3, 4)
    let prepared = path.preparePath(0.25'f32)
    check prepared.len == 4
    check prepared.tolerance == 0.25'f32
    check prepared.bounds == Rect(x: 1, y: 2, w: 3, h: 4)
    check prepared.segment(0).at == vec2(1'f32, 2'f32)
    check prepared.contourCount == 1
    check prepared.contour(0) == FlattenContour(first: 0, count: 4,
        closed: true)

  test "retain explicit subpath boundaries at shared coordinates":
    let prepared = parsePath("M 0 0 L 2 0 M 2 0 L 2 2").preparePath()
    check prepared.contourCount == 2
    check prepared.contour(0) == FlattenContour(first: 0, count: 1,
        closed: false)
    check prepared.contour(1) == FlattenContour(first: 1, count: 1,
        closed: false)

  test "segment snapshots do not mutate prepared geometry":
    var path = newPath()
    path.moveTo(0, 0)
    path.lineTo(2, 3)
    let prepared = path.preparePath()
    var snapshot = prepared.segments
    snapshot[0] = Segment(at: vec2(9'f32, 9'f32),
        to: vec2(10'f32, 10'f32))
    check prepared.segment(0) == Segment(at: vec2(0'f32, 0'f32),
        to: vec2(2'f32, 3'f32))

  test "empty paths have empty bounds":
    let prepared = newPath().preparePath()
    check prepared.len == 0
    check prepared.bounds == Rect()

  when not defined(release):
    test "tolerance contract rejects non-positive values":
      expect PreConditionDefect:
        discard newPath().preparePath(0'f32)
