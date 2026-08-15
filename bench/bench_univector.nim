# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[monotimes, times]
import UniColor
import UniImage/core as uimg
import UniVector

template measure(label: string; body: untyped) =
  let started = getMonoTime()
  body
  let elapsed = getMonoTime() - started
  echo label, ": ", elapsed.inMicroseconds, " us"

const Iterations = 1_000
let source = "M 8 8 C 8 0 56 0 56 8 L 56 56 C 56 64 8 64 8 56 Z"

measure "parse x1000":
  for _ in 0 ..< Iterations:
    discard parsePath(source)

let path = parsePath(source)
measure "flatten x1000":
  for _ in 0 ..< Iterations:
    discard path.flatten()

measure "prepare x1000":
  for _ in 0 ..< Iterations:
    discard path.preparePath()

let prepared = path.preparePath()
measure "stroke expansion x1000":
  for _ in 0 ..< Iterations:
    discard prepared.strokeToPath(defaultStrokeStyle(2'f32))

var dashedStyle = defaultStrokeStyle(2'f32)
dashedStyle.dash = dashPattern([6'f32, 3'f32])
measure "dashed stroke expansion x1000":
  for _ in 0 ..< Iterations:
    discard prepared.strokeToPath(dashedStyle)

var markerPoints = newSeq[Vec2](1_000)
var markerSizes = newSeq[float32](1_000)
for i in 0 ..< markerPoints.len:
  markerPoints[i] = vec2(float32(i mod 100), float32(i div 100))
  markerSizes[i] = float32(2 + i mod 5)

measure "1000 fixed markers x100":
  for _ in 0 ..< 100:
    discard placeMarkers(CircleMarker, markerPoints, 4'f32)

measure "1000 sized markers x100":
  for _ in 0 ..< 100:
    discard placeMarkers(DiamondMarker, markerPoints, markerSizes)

measure "tessellate fill x1000":
  for _ in 0 ..< Iterations:
    discard prepared.tessellateFill()

measure "tessellate stroke x1000":
  for _ in 0 ..< Iterations:
    discard prepared.tessellateStroke(defaultStrokeStyle(2'f32))

let fill = parseColor("#3366cc").get
measure "fill 256x256 x100":
  for _ in 0 ..< 100:
    var image = uimg.newImage[uint8](256, 256, uimg.csRgba)
    image.fillPath(path, fill)

measure "fill prepared 256x256 x100":
  for _ in 0 ..< 100:
    var image = uimg.newImage[uint8](256, 256, uimg.csRgba)
    image.fillPreparedPath(prepared, fill)
