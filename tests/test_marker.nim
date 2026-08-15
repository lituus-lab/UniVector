# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, unittest]
import contracts
import UniVector

suite "marker geometry":
  test "every shape is centered in the requested bounds":
    for shape in MarkerShape:
      let bounds = markerPath(shape, vec2(10'f32, 20'f32), 6'f32)
        .flatten(0.05'f32).computeBounds()
      check abs(bounds.x - 7'f32) < 0.01'f32
      check abs(bounds.y - 17'f32) < 0.01'f32
      check abs(bounds.w - 6'f32) < 0.01'f32
      check abs(bounds.h - 6'f32) < 0.01'f32

  test "fixed-size placement combines fill-ready subpaths":
    let path = placeMarkers(SquareMarker,
        [vec2(2'f32, 3'f32), vec2(8'f32, 9'f32)], 2'f32)
    check path.commands.len == 10
    check path.flatten().computeBounds() == Rect(x: 1, y: 2, w: 8, h: 8)

  test "variable-size placement preserves individual sizes":
    let path = placeMarkers(DiamondMarker,
        [vec2(2'f32, 2'f32), vec2(8'f32, 8'f32)], [2'f32, 4'f32])
    check path.flatten().computeBounds() == Rect(x: 1, y: 1, w: 9, h: 9)

  test "empty placement produces an empty path":
    check placeMarkers(CircleMarker, newSeq[Vec2](), 2'f32).commands.len == 0

  when not defined(release):
    test "marker contracts reject invalid inputs":
      expect PreConditionDefect:
        discard markerPath(CircleMarker, vec2(0'f32, 0'f32), 0'f32)
      expect PreConditionDefect:
        discard placeMarkers(SquareMarker, [vec2(0'f32, 0'f32)],
            newSeq[float32]())

  when defined(release):
    test "marker guards survive release builds":
      expect ValueError:
        discard markerPath(CircleMarker, vec2(NaN.float32, 0'f32), 2'f32)
      expect ValueError:
        discard placeMarkers(SquareMarker, [vec2(0'f32, 0'f32)],
            newSeq[float32]())
