# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, unittest]
import std/strutils
import contracts
import UniVector

proc approx(a, b: float32; eps = 1e-4'f32): bool = abs(a - b) <= eps

suite "path construction":
  test "moveTo/lineTo append commands and advance at":
    var p = newPath()
    p.moveTo(1.float32, 2.float32)
    p.lineTo(3.float32, 4.float32)
    check p.commands.len == 2
    check p.commands[0].kind == pMove
    check p.commands[1].kind == pLine
    check p.at.x == 3.float32 and p.at.y == 4.float32
    check p.start.x == 1.float32 and p.start.y == 2.float32

  test "closePath returns to start":
    var p = newPath()
    p.moveTo(1.float32, 1.float32)
    p.lineTo(5.float32, 1.float32)
    p.closePath()
    check p.commands[^1].kind == pClose
    check p.at.x == 1.float32 and p.at.y == 1.float32

  test "copy owns an independent command sequence":
    var p = newPath()
    p.moveTo(1'f32, 2'f32)
    var q = p.copy()
    q.commands[0].p = vec2(8'f32, 9'f32)
    check p.commands[0].p == vec2(1'f32, 2'f32)

  test "addPath updates the current builder state":
    var p = newPath()
    p.moveTo(1'f32, 1'f32)
    var q = newPath()
    q.moveTo(3'f32, 4'f32)
    q.lineTo(5'f32, 6'f32)
    p.addPath(q)
    check p.at == vec2(5'f32, 6'f32)
    check p.start == vec2(3'f32, 4'f32)

  test "rect winds clockwise then closes":
    var p = newPath()
    p.rect(0.float32, 0.float32, 10.float32, 10.float32)
    let kinds = [p.commands[0].kind, p.commands[1].kind, p.commands[2].kind,
                 p.commands[3].kind, p.commands[4].kind]
    check kinds == [pMove, pLine, pLine, pLine, pClose]

  test "circle emits four cubics + close":
    var p = newPath()
    p.circle(50.float32, 50.float32, 25.float32)
    var cubics = 0
    for cmd in p.commands:
      if cmd.kind == pCubic: inc cubics
    check cubics == 4
    check p.commands[^1].kind == pClose

  test "polygon requires sides > 2":
    var p = newPath()
    p.polygon(0.float32, 0.float32, 10.float32, 5)
    check p.commands.len == 6 # 1 move + 4 line + 1 close
    when not defined(release): # preconditions are compiled away under -d:release
      var q = newPath()
      expect PreConditionDefect:
        q.polygon(0.float32, 0.float32, 10.float32, 2)

  test "arcTo with a zero-length outgoing leg becomes a line":
    var p = newPath()
    p.moveTo(0'f32, 0'f32)
    p.arcTo(10'f32, 0'f32, 10'f32, 0'f32, 2'f32)
    check p.commands.len == 2
    check p.commands[^1].kind == pLine
    check p.at == vec2(10'f32, 0'f32)

suite "parsePath":
  test "absolute simple path":
    let p = parsePath("M 0 0 L 10 20 Z")
    check p.commands.len == 3
    check p.commands[0].kind == pMove
    check p.commands[1].kind == pLine
    check p.commands[2].kind == pClose
    check p.commands[1].p.x == 10.float32 and p.commands[1].p.y == 20.float32

  test "relative commands":
    let p = parsePath("m 10 10 l 5 5 z")
    check p.commands[0].kind == pRMove
    check p.commands[1].kind == pRLine
    check p.commands[2].kind == pClose

  test "parsed path exposes its final builder state":
    var p = parsePath("M 3 4 l 5 6")
    check p.start == vec2(3'f32, 4'f32)
    check p.at == vec2(8'f32, 10'f32)
    p.lineTo(12'f32, 14'f32)
    check p.at == vec2(12'f32, 14'f32)

  test "parsed close restores the subpath start":
    let p = parsePath("M 3 4 L 8 10 Z")
    check p.at == vec2(3'f32, 4'f32)

  test "cubic and quadratic":
    let p = parsePath("M 0 0 C 1 2 3 4 5 6 Q 7 8 9 10")
    check p.commands[1].kind == pCubic
    check p.commands[1].c1.x == 1.float32
    check p.commands[1].c3.x == 5.float32 and p.commands[1].c3.y == 6.float32
    check p.commands[2].kind == pQuad
    check p.commands[2].c.x == 7.float32
    check p.commands[2].e.x == 9.float32 and p.commands[2].e.y == 10.float32

  test "arc with packed flags":
    let p = parsePath("M 10 10 A 25 25 0 0150 50")
    check p.commands[1].kind == pArc
    check p.commands[1].largeArc == false
    check p.commands[1].sweep == true
    check p.commands[1].a.x == 50.float32 and p.commands[1].a.y == 50.float32

  test "arc flags and radii follow the SVG grammar":
    expect ValueError:
      discard parsePath("M 0 0 A 10 10 0 2 0 20 20")
    expect ValueError:
      discard parsePath("M 0 0 A -10 10 0 0 0 20 20")
    expect ValueError:
      discard parsePath("M 0 0 A 10 10 0 0.0 0 20 20")

  test "a nonempty path begins with moveto":
    expect ValueError:
      discard parsePath("L 10 20")
    expect ValueError:
      discard parsePath("Z")

  test "numeric data after close is rejected":
    expect ValueError:
      discard parsePath("M 0 0 Z 10 20")

  test "non-finite numbers are rejected":
    expect ValueError:
      discard parsePath("M 1e999 0")

  test "repeated M degenerates to L":
    let p = parsePath("M 0 0 10 10 20 20")
    check p.commands[0].kind == pMove
    check p.commands[1].kind == pLine
    check p.commands[2].kind == pLine

  test "packed decimals and negatives":
    let p = parsePath("M0 0L1.5.5L-1-2")
    check p.commands[1].p.x == 1.5'f32
    check p.commands[1].p.y == 0.5'f32
    check p.commands[2].p.x == -1.float32 and p.commands[2].p.y == -2.float32

  test "empty string yields empty path":
    let p = parsePath("")
    check p.commands.len == 0

  test "wrong parameter count raises ValueError":
    expect ValueError:
      discard parsePath("M 0 0 C 1 2")

  test "line with one coordinate raises ValueError":
    expect ValueError:
      discard parsePath("M 0 0 L 5")

  test "unknown character raises ValueError":
    expect ValueError:
      discard parsePath("M 0 0 X 1 2")

suite "$path round-trip":
  test "non-finite coordinates cannot be serialized":
    var p = newPath()
    p.moveTo(NaN.float32, 0'f32)
    expect ValueError:
      discard $p

  test "rect round-trips":
    var p = newPath()
    p.rect(0.float32, 0.float32, 10.float32, 20.float32)
    let s = $p
    check s.startsWith("M 0 0")
    check "L 10 0" in s
    check "L 10 20" in s
    check s.endsWith("Z")
    let q = parsePath(s)
    check q.commands.len == p.commands.len

  test "integer-valued numbers print without decimals":
    var p = newPath()
    p.moveTo(5.float32, 5.float32)
    let s = $p
    check "M 5 5" in s
    check "5.0" notin s

  test "arc rotation round-trips through degrees":
    let p = parsePath("M 0 0 A 50 30 45 0 1 100 0")
    let s = $p
    check "A 50 30" in s
    check "0.78" notin s # rotation is emitted in degrees, not the raw radian (~0.785)
    let q = parsePath(s)
    check q.commands[^1].kind == pArc
    check approx(q.commands[^1].rot, p.commands[^1].rot) # radian value preserved

  test "relative arc round-trips":
    let p = parsePath("M 0 0 a 50 30 45 0 1 100 0")
    let s = $p
    check "a 50 30" in s
    let q = parsePath(s)
    check q.commands[^1].kind == pRArc
    check approx(q.commands[^1].rot, p.commands[^1].rot)
