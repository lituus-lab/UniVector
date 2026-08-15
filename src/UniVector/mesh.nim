# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Renderer-neutral indexed-triangle tessellation.
import std/[algorithm, math]
import contracts
import UniVector/common
import UniVector/prepared
import UniVector/stroke

const
  MaxMeshVertices* = 4_194_304
  MaxMeshIndices* = 6_291_456

type
  VectorVertex* = object
    position*: Vec2
    coverage*: float32

  VectorMesh* = object
    verticesData: seq[VectorVertex]
    indicesData: seq[uint32]

  Crossing = tuple[x: float32, direction: int, segmentIndex: int]

func vertexCount*(mesh: VectorMesh): int {.inline.} = mesh.verticesData.len
func indexCount*(mesh: VectorMesh): int {.inline.} = mesh.indicesData.len
func triangleCount*(mesh: VectorMesh): int {.inline.} = mesh.indexCount div 3

proc vertex*(mesh: VectorMesh; index: int): VectorVertex {.contractual, inline.} =
  require:
    index >= 0 and index < mesh.vertexCount
  body:
    mesh.verticesData[index]

proc index*(mesh: VectorMesh; position: int): uint32 {.contractual, inline.} =
  require:
    position >= 0 and position < mesh.indexCount
  body:
    mesh.indicesData[position]

proc vertices*(mesh: VectorMesh): seq[VectorVertex] =
  result = newSeq[VectorVertex](mesh.vertexCount)
  for i in 0 ..< result.len: result[i] = mesh.verticesData[i]

proc indices*(mesh: VectorMesh): seq[uint32] =
  result = newSeq[uint32](mesh.indexCount)
  for i in 0 ..< result.len: result[i] = mesh.indicesData[i]

func xAt(segment: Segment; y: float32): float32 {.inline.} =
  segment.at.x + (segment.to.x - segment.at.x) *
      ((y - segment.at.y) / (segment.to.y - segment.at.y))

proc addTrapezoid(mesh: var VectorMesh; left, right: Segment;
                  y0, y1: float32) =
  let
    left0 = left.xAt(y0)
    left1 = left.xAt(y1)
    right0 = right.xAt(y0)
    right1 = right.xAt(y1)
  if left0 >= right0 and left1 >= right1: return
  if mesh.verticesData.len > MaxMeshVertices - 4 or
      mesh.indicesData.len > MaxMeshIndices - 6:
    raise newException(ValueError, "tessellate: mesh limit exceeded")
  let base = uint32(mesh.verticesData.len)
  mesh.verticesData.add([
    VectorVertex(position: vec2(left0, y0), coverage: 1'f32),
    VectorVertex(position: vec2(right0, y0), coverage: 1'f32),
    VectorVertex(position: vec2(right1, y1), coverage: 1'f32),
    VectorVertex(position: vec2(left1, y1), coverage: 1'f32)
  ])
  mesh.indicesData.add([base, base + 1, base + 2, base, base + 2, base + 3])

proc tessellateFillImpl(prepared: PreparedPath;
                        windingRule: WindingRule): VectorMesh =
  var levels: seq[float32] = @[]
  for i in 0 ..< prepared.len:
    let segment = prepared.segment(i)
    if segment.at.y != segment.to.y:
      levels.add(segment.at.y)
      levels.add(segment.to.y)
  for first in 0 ..< prepared.len:
    let a = prepared.segment(first)
    let r = a.to - a.at
    for second in first + 1 ..< prepared.len:
      let b = prepared.segment(second)
      if max(a.at.x, a.to.x) <= min(b.at.x, b.to.x) or
          max(b.at.x, b.to.x) <= min(a.at.x, a.to.x) or
          max(a.at.y, a.to.y) <= min(b.at.y, b.to.y) or
          max(b.at.y, b.to.y) <= min(a.at.y, a.to.y):
        continue
      let
        s = b.to - b.at
        denominator = r.x * s.y - r.y * s.x
      if abs(denominator) <= 1e-12'f32: continue
      let
        delta = b.at - a.at
        t = (delta.x * s.y - delta.y * s.x) / denominator
        u = (delta.x * r.y - delta.y * r.x) / denominator
      if t > 0'f32 and t < 1'f32 and u > 0'f32 and u < 1'f32:
        levels.add(a.at.y + r.y * t)
  levels.sort()
  var uniqueLevels: seq[float32] = @[]
  for level in levels:
    if uniqueLevels.len == 0 or uniqueLevels[^1] != level:
      uniqueLevels.add(level)
  var crossings: seq[Crossing] = @[]
  for levelIndex in 0 ..< max(0, uniqueLevels.len - 1):
    let
      y0 = uniqueLevels[levelIndex]
      y1 = uniqueLevels[levelIndex + 1]
    if y1 <= y0: continue
    let middle = (y0 + y1) * 0.5'f32
    crossings.setLen(0)
    for segmentIndex in 0 ..< prepared.len:
      let segment = prepared.segment(segmentIndex)
      let lo = min(segment.at.y, segment.to.y)
      let hi = max(segment.at.y, segment.to.y)
      if middle >= lo and middle < hi:
        crossings.add((segment.xAt(middle),
            if segment.to.y > segment.at.y: 1 else: -1, segmentIndex))
    crossings.sort(proc(a, b: Crossing): int = cmp(a.x, b.x))
    case windingRule
    of NonZero:
      var winding = 0
      var leftIndex = -1
      for crossing in crossings:
        if winding == 0: leftIndex = crossing.segmentIndex
        winding += crossing.direction
        if winding == 0 and leftIndex >= 0:
          result.addTrapezoid(prepared.segment(leftIndex),
              prepared.segment(crossing.segmentIndex), y0, y1)
    of EvenOdd:
      var i = 0
      while i + 1 < crossings.len:
        result.addTrapezoid(prepared.segment(crossings[i].segmentIndex),
            prepared.segment(crossings[i + 1].segmentIndex), y0, y1)
        i += 2

proc tessellateFill*(prepared: PreparedPath;
                     windingRule = NonZero): VectorMesh {.contractual.} =
  ## Tessellate flattened fill geometry into independent indexed trapezoids.
  ensure:
    result.indexCount mod 3 == 0
    result.vertexCount <= MaxMeshVertices
    result.indexCount <= MaxMeshIndices
  body:
    tessellateFillImpl(prepared, windingRule)

proc tessellateStroke*(prepared: PreparedPath;
                       style: StrokeStyle): VectorMesh {.contractual.} =
  ## Expand and tessellate a prepared centerline with NonZero winding.
  ensure:
    result.indexCount mod 3 == 0
  body:
    prepared.strokeToPath(style).preparePath(prepared.tolerance)
      .tessellateFill(NonZero)
