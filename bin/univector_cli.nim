# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## univector — 2D vector-graphics rendering CLI.
##
##   univector render [-o out.png] [-s out.svg] [-w W] [-h H]
##       Rasterize a built-in demo scene (a rect, a cubic shape, and a circle)
##       to a PNG and emit the matching SVG. Defaults: out.png / out.svg, 200x200.
import std/[os, strutils, strformat]
import UniVector
import UniImage/core as uimg
import UniImage/formats
import UniColor

const MaxRenderPixels = 100_000_000'i64

proc die(msg: string) =
  stderr.writeLine "error: " & msg
  quit(1)

proc usage() =
  stderr.writeLine """usage:
  univector render [-o out.png] [-s out.svg] [-w W] [-h H]"""
  quit(1)

proc buildScene(): Path =
  ## The built-in demo: a square, a cubic-curved shape, and a circle, laid out
  ## to fit the default 200x200 canvas.
  result = newPath()
  result.rect(10.float32, 10.float32, 60.float32, 60.float32)
  result.moveTo(80.float32, 80.float32)
  result.bezierCurveTo(120.float32, 20.float32, 180.float32, 20.float32,
                       180.float32, 80.float32)
  result.lineTo(80.float32, 80.float32)
  result.closePath()
  result.circle(150.float32, 140.float32, 30.float32)

proc cmdRender(args: seq[string]) =
  var pngOut = "out.png"
  var svgOut = "out.svg"
  var width = 200
  var height = 200
  var i = 0
  while i < args.len:
    let a = args[i]
    if a.startsWith("-o="):
      pngOut = a[3 ..< a.len]
    elif a == "-o":
      if i + 1 >= args.len: die("-o needs a value")
      pngOut = args[i + 1]; i += 1
    elif a.startsWith("-s="):
      svgOut = a[3 ..< a.len]
    elif a == "-s":
      if i + 1 >= args.len: die("-s needs a value")
      svgOut = args[i + 1]; i += 1
    elif a.startsWith("-w="):
      try: width = parseInt(a[3 ..< a.len])
      except ValueError: die("width must be an integer: " & a)
    elif a == "-w":
      if i + 1 >= args.len: die("-w needs a value")
      try: width = parseInt(args[i + 1])
      except ValueError: die("width must be an integer: " & args[i + 1])
      i += 1
    elif a.startsWith("-h="):
      try: height = parseInt(a[3 ..< a.len])
      except ValueError: die("height must be an integer: " & a)
    elif a == "-h":
      if i + 1 >= args.len: die("-h needs a value")
      try: height = parseInt(args[i + 1])
      except ValueError: die("height must be an integer: " & args[i + 1])
      i += 1
    else:
      usage()
    i += 1
  if pngOut.len == 0: die("PNG output path must not be empty")
  if svgOut.len == 0: die("SVG output path must not be empty")
  if width <= 0 or height <= 0: die("width and height must be positive")
  if int64(width) > MaxRenderPixels div int64(height):
    die("image dimensions exceed the 100000000-pixel limit")
  if pngOut == svgOut:
    die("PNG and SVG output paths must differ")
  let path = buildScene()
  let paint = parseColor("#3366cc").get
  var img = uimg.newImage[uint8](width, height, uimg.csRgba)
  fillPath(img, path, paint)
  let png = encodeImage(img, efPng, 90)
  writeFile(pngOut, cast[string](png))
  let svg = toSvgString(path, paint, width, height)
  writeFile(svgOut, svg)
  echo &"wrote {pngOut} ({width}x{height}) and {svgOut}"

proc main() =
  let args = commandLineParams()
  if args.len < 1: usage()
  case args[0]
  of "render": cmdRender(args[1 ..< args.len])
  else: usage()

when isMainModule: main()
