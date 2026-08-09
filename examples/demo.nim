# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Minimal print-only demo of the Nim API: build a path, solid-fill it onto an
## RGBA8 surface, and print the `d` string, the SVG document, and the PNG byte
## count. No file I/O — `nimble univector` is the file-rendering CLI. Run with
## `nimble example`.
import UniVector
import UniImage/core as uimg
import UniImage/formats
import UniColor

var p = newPath()
p.rect(10.float32, 10.float32, 80.float32, 80.float32)
p.circle(120.float32, 120.float32, 40.float32)

let paint = parseColor("#3366cc").get

var img = uimg.newImage[uint8](200, 200, uimg.csRgba)
fillPath(img, p, paint)

echo "UniVector " & UniVectorVersion
echo "d        ", $p
echo "svg      ", toSvgString(p, paint, 200, 200).len, " chars"
echo "png      ", encodeImage(img, efPng, 90).len, " bytes"
