# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniVector/svg — minimal SVG *output* for a filled path.
##
## Emits a standalone `<svg>` document wrapping the path's `d` string with a
## solid fill color. It produces the W3C SVG path grammar and the
## `#rrggbb[aa]` hex color form.
import std/[strformat, strutils]
import contracts
import UniVector/path
import UniColor

proc toHex2(v: float32): string =
  ## float component in [0,1] -> two uppercase hex digits, rounded to nearest.
  let n = clamp(int(v * 255'f32 + 0.5'f32), 0, 255)
  n.toHex(2)

proc toSvgColor*(color: Color): string {.contractual.} =
  ## `Color` (any tagged space) -> SVG hex `#rrggbb`, or `#rrggbbaa` when the
  ## alpha is below 1. UniColor maps out-of-gamut inputs into sRGB before their
  ## components are encoded; source-space components are never treated as RGB.
  require:
    color.spaceTag != tagUnknown
  ensure:
    result.len in {7, 9}
  body:
    let converted = color.gamutMap(tagSrgb)
    if converted.isErr:
      raise newException(ValueError, "toSvgColor: color cannot be converted to sRGB")
    let c = converted.get
    result = "#" & toHex2(c.comp(0)) & toHex2(c.comp(1)) & toHex2(c.comp(2))
    let a = clamp(c.alpha, 0'f32, 1'f32)
    if a < 1'f32:
      result &= toHex2(a)

proc toSvgString*(path: Path; color: Color; width, height: int): string {.
    contractual.} =
  ## Wrap `path`'s `d` string and `color` in a standalone `<svg>` document of
  ## the given pixel size. The viewBox matches the raster surface the caller
  ## fills, so the vector and the PNG align 1:1.
  require:
    width > 0 and height > 0
  ensure:
    result.len > 0
  body:
    let d = $path
    let fill = toSvgColor(color)
    result = &"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}"><path d="{d}" fill="{fill}"/></svg>"""
