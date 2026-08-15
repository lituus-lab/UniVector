# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[algorithm, monotimes, times]
import UniColor
import UniImage/core as uimg
import UniVector

template measure(label: string; body: untyped) =
  let started = getMonoTime()
  body
  let elapsed = getMonoTime() - started
  echo label, ": ", elapsed.inMicroseconds, " us"

proc median(samples: seq[int64]): int64 =
  var ordered = samples
  ordered.sort()
  ordered[ordered.len div 2]

proc measureRasterPair(label: string; path: Path; color: Color;
                       iterations = 100; rounds = 9) =
  let prepared = path.preparePath()
  var directSamples = newSeqOfCap[int64](rounds)
  var preparedSamples = newSeqOfCap[int64](rounds)

  proc runDirect(): int64 =
    let started = getMonoTime()
    for _ in 0 ..< iterations:
      var image = uimg.newImage[uint8](256, 256, uimg.csRgba)
      image.fillPath(path, color)
    (getMonoTime() - started).inMicroseconds

  proc runPrepared(): int64 =
    let started = getMonoTime()
    for _ in 0 ..< iterations:
      var image = uimg.newImage[uint8](256, 256, uimg.csRgba)
      image.fillPreparedPath(prepared, color)
    (getMonoTime() - started).inMicroseconds

  for round in 0 ..< rounds:
    if (round and 1) == 0:
      directSamples.add runDirect()
      preparedSamples.add runPrepared()
    else:
      preparedSamples.add runPrepared()
      directSamples.add runDirect()

  let
    directMedian = directSamples.median
    preparedMedian = preparedSamples.median
    ratio = float64(preparedMedian) / float64(directMedian)
  echo label, " direct median: ", directMedian, " us"
  echo label, " prepared median: ", preparedMedian, " us"
  echo label, " prepared/direct: ", ratio

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
measureRasterPair("fill simple 256x256 x100", path, fill)

var curveHeavy = newPath()
curveHeavy.moveTo(8, 128)
for i in 0 ..< 96:
  let
    x = 8'f32 + float32(i) * 2.4'f32
    nextX = x + 2.4'f32
    y = if (i and 1) == 0: 32'f32 else: 224'f32
    nextY = if (i and 1) == 0: 224'f32 else: 32'f32
  curveHeavy.bezierCurveTo(x + 0.8'f32, y, nextX - 0.8'f32, nextY,
      nextX, nextY)
curveHeavy.lineTo(238, 240)
curveHeavy.lineTo(8, 240)
curveHeavy.closePath()
measureRasterPair("fill curve-heavy 256x256 x20", curveHeavy, fill,
    iterations = 20)
