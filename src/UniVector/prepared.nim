# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Reusable, renderer-neutral flattened path geometry.
import contracts
import UniVector/common
import UniVector/path
import UniVector/flatten

type
  PreparedPath* = object
    segmentsData: seq[Segment]
    contoursData: seq[FlattenContour]
    boundsData: Rect
    toleranceData: float32

proc preparePath*(path: Path;
                  tolerance = FlattenTolerance): PreparedPath {.contractual.} =
  ## Flatten `path` once and cache its bounds for reuse by renderers.
  require:
    tolerance > 0'f32
  ensure:
    result.toleranceData == tolerance
  body:
    result.segmentsData = path.flattenWithContours(tolerance,
        result.contoursData)
    result.boundsData = result.segmentsData.computeBounds()
    result.toleranceData = tolerance

func len*(path: PreparedPath): int {.inline.} =
  ## Number of directed line segments.
  path.segmentsData.len

func tolerance*(path: PreparedPath): float32 {.inline.} =
  ## Flattening tolerance used to prepare the path.
  path.toleranceData

func bounds*(path: PreparedPath): Rect {.inline.} =
  ## Cached axis-aligned bounds.
  path.boundsData

func contourCount*(path: PreparedPath): int {.inline.} =
  ## Number of non-empty source subpaths.
  path.contoursData.len

proc contour*(path: PreparedPath; index: int): FlattenContour {.contractual,
    inline.} =
  ## Segment range and closure state of subpath `index`.
  require:
    index >= 0 and index < path.contourCount
  body:
    path.contoursData[index]

proc segment*(path: PreparedPath; index: int): Segment {.contractual, inline.} =
  ## Segment at `index`.
  require:
    index >= 0 and index < path.len
  body:
    path.segmentsData[index]

proc segments*(path: PreparedPath): seq[Segment] =
  ## Independent snapshot of all segments.
  result = newSeq[Segment](path.len)
  for i in 0 ..< path.len:
    result[i] = path.segmentsData[i]
