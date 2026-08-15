# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniVector

suite "fill tessellation":
  test "rectangle becomes two indexed triangles":
    var path = newPath()
    path.rect(1, 2, 3, 4)
    let mesh = path.preparePath().tessellateFill()
    check mesh.vertexCount == 4
    check mesh.indexCount == 6
    check mesh.triangleCount == 2
    for i in 0 ..< mesh.indexCount:
      check mesh.index(i) < uint32(mesh.vertexCount)
    for vertex in mesh.vertices:
      check vertex.coverage == 1'f32

  test "even-odd preserves a rectangular hole":
    var path = newPath()
    path.rect(0, 0, 10, 10)
    path.rect(3, 3, 4, 4)
    let mesh = path.preparePath().tessellateFill(EvenOdd)
    check mesh.triangleCount == 8
    var area = 0'f32
    for triangle in 0 ..< mesh.triangleCount:
      let
        a = mesh.vertex(int(mesh.index(triangle * 3))).position
        b = mesh.vertex(int(mesh.index(triangle * 3 + 1))).position
        c = mesh.vertex(int(mesh.index(triangle * 3 + 2))).position
        cross = (b.x - a.x) * (c.y - a.y) -
            (b.y - a.y) * (c.x - a.x)
        center = vec2(5'f32, 5'f32)
        ab = (b.x - a.x) * (center.y - a.y) -
            (b.y - a.y) * (center.x - a.x)
        bc = (c.x - b.x) * (center.y - b.y) -
            (c.y - b.y) * (center.x - b.x)
        ca = (a.x - c.x) * (center.y - c.y) -
            (a.y - c.y) * (center.x - c.x)
      area += abs(cross) * 0.5'f32
      check not ((ab >= 0'f32 and bc >= 0'f32 and ca >= 0'f32) or
          (ab <= 0'f32 and bc <= 0'f32 and ca <= 0'f32))
    check abs(area - 84'f32) < 0.001'f32

  test "empty and horizontal-only geometry is empty":
    check newPath().preparePath().tessellateFill().triangleCount == 0
    let horizontal = parsePath("M 0 1 L 4 1").preparePath().tessellateFill()
    check horizontal.triangleCount == 0

  test "returned buffers are snapshots":
    var path = newPath()
    path.rect(0, 0, 2, 2)
    let mesh = path.preparePath().tessellateFill()
    var vertices = mesh.vertices
    vertices[0].coverage = 0'f32
    check mesh.vertex(0).coverage == 1'f32
    let originalIndex = mesh.index(0)
    var indices = mesh.indices
    indices[0] = originalIndex + 1
    check mesh.index(0) == originalIndex

  test "self-intersections split scan bands":
    let mesh = parsePath("M 0 0 L 10 10 L 0 10 L 10 0 Z")
      .preparePath().tessellateFill(EvenOdd)
    var area = 0'f32
    for triangle in 0 ..< mesh.triangleCount:
      let
        a = mesh.vertex(int(mesh.index(triangle * 3))).position
        b = mesh.vertex(int(mesh.index(triangle * 3 + 1))).position
        c = mesh.vertex(int(mesh.index(triangle * 3 + 2))).position
      area += abs((b.x - a.x) * (c.y - a.y) -
          (b.y - a.y) * (c.x - a.x)) * 0.5'f32
    check abs(area - 50'f32) < 0.001'f32

suite "stroke tessellation":
  test "line stroke produces indexed triangles":
    let prepared = parsePath("M 2 4 L 8 4").preparePath()
    let mesh = prepared.tessellateStroke(defaultStrokeStyle(2'f32))
    check mesh.triangleCount == 2
    check mesh.vertexCount == 4

  test "round caps expand the mesh bounds":
    let prepared = parsePath("M 2 4 L 8 4").preparePath(0.1'f32)
    let mesh = prepared.tessellateStroke(StrokeStyle(width: 2,
        cap: RoundCap, join: RoundJoin, miterLimit: 4))
    var minX = mesh.vertex(0).position.x
    var maxX = minX
    for vertex in mesh.vertices:
      minX = min(minX, vertex.position.x)
      maxX = max(maxX, vertex.position.x)
    check abs(minX - 1'f32) < 0.001'f32
    check abs(maxX - 9'f32) < 0.001'f32
