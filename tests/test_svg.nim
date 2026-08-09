# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import std/strutils
import contracts
import UniVector
import UniColor

suite "toSvgColor":
  test "opaque srgb hex is uppercase 6-digit":
    let c = parseColor("#ff0000").get
    check toSvgColor(c) == "#FF0000"

  test "alpha below 1 appends two hex digits":
    let c = parseColor("#00ff0080").get
    let s = toSvgColor(c)
    check s.len == 9
    check s.startsWith("#00FF00")

  test "transparent alpha is 00":
    let c = parseColor("#ffffff00").get
    check toSvgColor(c) == "#FFFFFF00"

  test "out-of-gamut source components are not reinterpreted as RGB":
    let c = parseColor("oklch(62% 0.4 255)").get
    let encoded = toSvgColor(c)
    check encoded.len == 7
    check encoded != "#9E66FF"

suite "toSvgString":
  test "wraps the d string and fill in an svg document":
    var p = newPath()
    p.rect(0.float32, 0.float32, 10.float32, 10.float32)
    let s = toSvgString(p, parseColor("#0000ff").get, 10, 10)
    check s.startsWith("<svg ")
    check "</svg>" in s
    check "width=\"10\"" in s
    check "height=\"10\"" in s
    check "viewBox=\"0 0 10 10\"" in s
    check "fill=\"#0000FF\"" in s
    check ($p) in s

  test "width and height must be positive":
    when not defined(release): # preconditions are compiled away under -d:release
      var p = newPath()
      p.rect(0.float32, 0.float32, 10.float32, 10.float32)
      expect PreConditionDefect:
        discard toSvgString(p, parseColor("#0000ff").get, 0, 10)
