# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Deterministic filled marker geometry for plots and vector scenes.
import std/math
import contracts
import UniVector/common
import UniVector/path

type MarkerShape* = enum
  CircleMarker
  SquareMarker
  TriangleMarker
  DiamondMarker
  PlusMarker
  CrossMarker

const MaxMarkerCount* = 65_536

func isFinite(value: float32): bool {.inline.} =
  classify(value) notin {fcNan, fcInf, fcNegInf}

func isValidPoint(point: Vec2): bool {.inline.} =
  point.x.isFinite and point.y.isFinite

func areValidPoints(points: openArray[Vec2]): bool =
  for point in points:
    if not point.isValidPoint:
      return false
  true

func areValidSizes(sizes: openArray[float32]): bool =
  for size in sizes:
    if classify(size) != fcNormal or size <= 0'f32:
      return false
  true

proc addPolygon(path: var Path; points: openArray[Vec2]) =
  path.moveTo(points[0])
  for i in 1 ..< points.len:
    path.lineTo(points[i])
  path.closePath()

proc addMarker(path: var Path; shape: MarkerShape; center: Vec2;
               size: float32) =
  let
    radius = size * 0.5'f32
    third = radius / 3'f32
  case shape
  of CircleMarker:
    path.ellipse(center, radius, radius)
  of SquareMarker:
    path.rect(center.x - radius, center.y - radius, size, size)
  of TriangleMarker:
    path.addPolygon([center + vec2(0'f32, -radius),
        center + vec2(radius, radius), center + vec2(-radius, radius)])
  of DiamondMarker:
    path.addPolygon([center + vec2(0'f32, -radius),
        center + vec2(radius, 0'f32), center + vec2(0'f32, radius),
        center + vec2(-radius, 0'f32)])
  of PlusMarker:
    path.addPolygon([
        center + vec2(-third, -radius), center + vec2(third, -radius),
        center + vec2(third, -third), center + vec2(radius, -third),
        center + vec2(radius, third), center + vec2(third, third),
        center + vec2(third, radius), center + vec2(-third, radius),
        center + vec2(-third, third), center + vec2(-radius, third),
        center + vec2(-radius, -third), center + vec2(-third, -third)])
  of CrossMarker:
    path.addPolygon([
        center + vec2(-radius, -radius + third),
        center + vec2(-radius + third, -radius),
        center + vec2(0'f32, -third),
        center + vec2(radius - third, -radius),
        center + vec2(radius, -radius + third),
        center + vec2(third, 0'f32),
        center + vec2(radius, radius - third),
        center + vec2(radius - third, radius),
        center + vec2(0'f32, third),
        center + vec2(-radius + third, radius),
        center + vec2(-radius, radius - third),
        center + vec2(-third, 0'f32)])

proc markerPath*(shape: MarkerShape; center: Vec2;
                 size: float32): Path {.contractual.} =
  ## Construct one filled marker centered at `center`; `size` is its diameter.
  require:
    center.isValidPoint
    classify(size) == fcNormal
    size > 0'f32
  body:
    if not center.isValidPoint or classify(size) != fcNormal or size <= 0'f32:
      raise newException(ValueError, "markerPath: center and size must be valid")
    result = newPath()
    result.addMarker(shape, center, size)

proc placeMarkers*(shape: MarkerShape; points: openArray[Vec2];
                   size: float32): Path {.contractual.} =
  ## Combine equally sized markers into one fill-ready path.
  require:
    points.len <= MaxMarkerCount
    points.areValidPoints
    classify(size) == fcNormal
    size > 0'f32
  body:
    if points.len > MaxMarkerCount:
      raise newException(ValueError, "placeMarkers: marker limit exceeded")
    if classify(size) != fcNormal or size <= 0'f32:
      raise newException(ValueError, "placeMarkers: size must be positive")
    if not points.areValidPoints:
      raise newException(ValueError, "placeMarkers: points must be finite")
    result = newPath()
    for point in points:
      result.addMarker(shape, point, size)

proc placeMarkers*(shape: MarkerShape; points: openArray[Vec2];
                   sizes: openArray[float32]): Path {.contractual.} =
  ## Combine per-point sized markers into one fill-ready path.
  require:
    points.len == sizes.len
    points.len <= MaxMarkerCount
    points.areValidPoints
    sizes.areValidSizes
  body:
    if points.len != sizes.len:
      raise newException(ValueError, "placeMarkers: point and size counts differ")
    if points.len > MaxMarkerCount:
      raise newException(ValueError, "placeMarkers: marker limit exceeded")
    if not points.areValidPoints or not sizes.areValidSizes:
      raise newException(ValueError,
          "placeMarkers: points and sizes must be valid")
    result = newPath()
    for i, point in points:
      result.addMarker(shape, point, sizes[i])
