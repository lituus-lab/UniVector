# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniImage/core as uimg
import UniColor
import UniVector

proc px(img: uimg.Image[uint8]; x, y: int): tuple[r, g, b, a: uint8] =
  let i = (y * img.width + x) * 4
  (img.data[i], img.data[i + 1], img.data[i + 2], img.data[i + 3])

suite "fillPath solid":
  test "full-cover rect interior is opaque solid color":
    var img = uimg.newImage[uint8](10, 10, uimg.csRgba)
    var p = newPath()
    p.rect(2.float32, 2.float32, 6.float32, 6.float32)
    fillPath(img, p, parseColor("#0000ff").get)
    let c = px(img, 5, 5)
    check c == (0.uint8, 0.uint8, 255.uint8, 255.uint8)

  test "pixels outside the path are untouched":
    var img = uimg.newImage[uint8](10, 10, uimg.csRgba)
    var p = newPath()
    p.rect(2.float32, 2.float32, 6.float32, 6.float32)
    fillPath(img, p, parseColor("#0000ff").get)
    let c = px(img, 0, 0)
    check c == (0.uint8, 0.uint8, 0.uint8, 0.uint8)

  test "circle edges are anti-aliased (partial alpha present)":
    var img = uimg.newImage[uint8](10, 10, uimg.csRgba)
    var p = newPath()
    p.circle(5.float32, 5.float32, 5.float32)
    fillPath(img, p, parseColor("#000000").get)
    var partials = 0
    var fulls = 0
    for y in 0 ..< 10:
      for x in 0 ..< 10:
        let a = img.data[(y * 10 + x) * 4 + 3]
        if a > 0 and a < 255: inc partials
        elif a == 255: inc fulls
    check partials > 0 # AA edge pixels exist
    check fulls > 0 # interior is fully covered

  test "fractional rect gives half coverage on the split pixel":
    var img = uimg.newImage[uint8](12, 6, uimg.csRgba)
    var r = newPath()
    r.rect(2.5'f32, 0'f32, 5.5'f32, 6'f32)
    fillPath(img, r, parseColor("#ffffff").get)
    check img.data[(3 * 12 + 2) * 4 + 3] == 128.uint8 # left edge x=2.5 -> 50%
    check img.data[(3 * 12 + 4) * 4 + 3] == 255.uint8 # interior full
    check img.data[(3 * 12 + 8) * 4 + 3] == 0.uint8 # past right edge

  test "triangle fills its interior":
    var img = uimg.newImage[uint8](20, 20, uimg.csRgba)
    var tri = newPath()
    tri.moveTo(0.float32, 0.float32)
    tri.lineTo(20.float32, 0.float32)
    tri.lineTo(10.float32, 20.float32)
    tri.closePath()
    fillPath(img, tri, parseColor("#ff0000").get, EvenOdd)
    let c = px(img, 10, 10)
    check c.r == 255.uint8 and c.a == 255.uint8

  test "even-odd rule leaves a nested hole":
    var img = uimg.newImage[uint8](20, 20, uimg.csRgba)
    var p = newPath()
    p.rect(0.float32, 0.float32, 20.float32, 20.float32) # outer cw
    p.rect(5.float32, 5.float32, 10.float32, 10.float32) # inner same winding
    fillPath(img, p, parseColor("#00ff00").get, EvenOdd)
    let outer = px(img, 2, 2)
    let hole = px(img, 10, 10)
    check outer.a == 255.uint8 # outer ring filled
    check hole.a == 0.uint8 # two crossings -> even -> outside under even-odd

  test "nonzero rule fills the nested rect too":
    var img = uimg.newImage[uint8](20, 20, uimg.csRgba)
    var p = newPath()
    p.rect(0.float32, 0.float32, 20.float32, 20.float32) # outer cw
    p.rect(5.float32, 5.float32, 10.float32, 10.float32) # inner same winding -> accumulates
    fillPath(img, p, parseColor("#00ff00").get, NonZero)
    let hole = px(img, 10, 10)
    check hole.a == 255.uint8 # same-direction nesting fills under nonzero

  test "transparent fill color draws nothing":
    var img = uimg.newImage[uint8](8, 8, uimg.csRgba)
    var p = newPath()
    p.rect(0.float32, 0.float32, 8.float32, 8.float32)
    let c = parseColor("#ff000000").get # 8-digit hex, alpha 00
    fillPath(img, p, c)
    check img.data[(4 * 8 + 4) * 4 + 3] == 0.uint8

  test "overwrite replaces the backdrop and applies shape coverage to alpha":
    var img = uimg.newImage[uint8](2, 1, uimg.csRgba)
    var backdrop = newPath()
    backdrop.rect(0'f32, 0'f32, 2'f32, 1'f32)
    fillPath(img, backdrop, parseColor("#0000ff").get)
    var foreground = newPath()
    foreground.rect(0'f32, 0'f32, 1.5'f32, 1'f32)
    fillPath(img, foreground, parseColor("#ff000080").get,
             blendMode = OverwriteBlend)
    check px(img, 0, 0) == (255.uint8, 0.uint8, 0.uint8, 128.uint8)
    check px(img, 1, 0) == (255.uint8, 0.uint8, 0.uint8, 64.uint8)

  test "normal blend composites semi-transparent color over opaque backdrop":
    var img = uimg.newImage[uint8](1, 1, uimg.csRgba)
    var pixel = newPath()
    pixel.rect(0'f32, 0'f32, 1'f32, 1'f32)
    fillPath(img, pixel, parseColor("#0000ff").get)
    fillPath(img, pixel, parseColor("#ff000080").get)
    check px(img, 0, 0) == (128.uint8, 0.uint8, 127.uint8, 255.uint8)
