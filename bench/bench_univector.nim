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

let fill = parseColor("#3366cc").get
measure "fill 256x256 x100":
  for _ in 0 ..< 100:
    var image = uimg.newImage[uint8](256, 256, uimg.csRgba)
    image.fillPath(path, fill)
