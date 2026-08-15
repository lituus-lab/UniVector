# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## C ABI for UniVector. Built --app:staticlib/--app:lib --noMain --mm:arc
## -d:release. Keep in sync with include/UniVector.h; tests/c links the header
## against this lib.
##
## Conventions (see the header for the authoritative contract):
##   * Call `uv_init()` before anything else (it runs the Nim runtime
##     initialiser). Repeated calls are harmless; externally synchronise the
##     first call.
##   * Handles are opaque `void*`. The library owns them; free with the
##     matching `uv_path_free` / `uv_prepared_path_free` / `uv_mesh_free` /
##     `uv_image_free` / `uv_color_free`. NULL is a no-op for every free.
##   * `uv_path_to_d`, `uv_path_to_svg`, `uv_color_to_svg`, and
##     `uv_image_encode_png` allocate a C-owned buffer; free it with
##     `uv_buffer_free`. `uv_image_pixels` *borrows* the image buffer (valid
##     until `uv_image_free`) and must NOT be freed with `uv_buffer_free`.
##   * No Nim exception or Defect crosses the ABI: every entry point traps both
##     and maps them to a `UV_*` code. Untrusted `d` strings and color inputs
##     are parsed under `-d:release` (not `-d:danger`), so Nim's bounds checks
##     stay as defense-in-depth.
import UniVector
import UniImage/core as uimg ## for the `Image[uint8]` surface held in the
              ## image handle; Nim does not re-export a foreign generic type
              ## through the facade's `export` chain, so the engine is imported
              ## directly (vgraph-clean: UniImage is an engine, not a layer).
import UniImage/formats ## encodeImage + efPng for uv_image_encode_png.
import UniColor ## Color / color / parseColor / tagSrgb — not re-exported by the
              ## UniVector facade (no UniVector public proc surfaces the
              ## constructor or the sRGB tag), so import UniColor directly.
import std/math

when defined(danger):
  {.error: "libUniVector built with -d:danger: bounds checks are off and the " &
    "Defect backstops at the ABI boundary cannot fire. Prefer -d:release for a " &
    "hardened parser facing untrusted `d` strings and colors.".}

const UniVectorAbiVersion = 1
const MaxPolygonSides = MaxFlattenSegments

var runtimeInitialized = false

type
  UvVec2 {.bycopy.} = object
    x, y: float32
  UvRect {.bycopy.} = object
    x, y, w, h: float32
  UvSegment {.bycopy.} = object
    at, to: UvVec2
  UvVectorVertex {.bycopy.} = object
    position: UvVec2
    coverage: float32
  UvPathCommand {.bycopy.} = object
    kind: cint
    params: array[7, float32]
  PathHandle = ref object
    path: Path
  PreparedPathHandle = ref object
    path: PreparedPath
  MeshHandle = ref object
    mesh: VectorMesh
  ImgHandle = ref object
    img: uimg.Image[uint8]
  ColorHandle = ref object
    color: Color

proc NimMain() {.importc.}

proc pathOf(p: pointer): PathHandle {.inline.} = cast[PathHandle](p)
proc preparedPathOf(p: pointer): PreparedPathHandle {.inline.} =
  cast[PreparedPathHandle](p)
proc meshOf(p: pointer): MeshHandle {.inline.} = cast[MeshHandle](p)
proc imgOf(p: pointer): ImgHandle {.inline.} = cast[ImgHandle](p)
proc colorOf(p: pointer): ColorHandle {.inline.} = cast[ColorHandle](p)

proc toC(v: Vec2): UvVec2 {.inline.} = UvVec2(x: v.x, y: v.y)
proc toC(r: Rect): UvRect {.inline.} = UvRect(x: r.x, y: r.y, w: r.w, h: r.h)
proc toC(s: Segment): UvSegment {.inline.} = UvSegment(at: s.at.toC, to: s.to.toC)
proc fromC(v: UvVec2): Vec2 {.inline.} = vec2(v.x, v.y)

proc allFinite(values: openArray[float32]): bool {.inline.} =
  for value in values:
    if classify(value) in {fcNan, fcInf, fcNegInf}:
      return false
  true

proc toC(command: PathCommand): UvPathCommand =
  result.kind = cint(command.kind.ord)
  case command.kind
  of pClose:
    discard
  of pMove, pLine, pRMove, pRLine, pTQuad, pRTQuad:
    result.params[0] = command.p.x
    result.params[1] = command.p.y
  of pHLine, pRHLine, pVLine, pRVLine:
    result.params[0] = command.v
  of pCubic, pRCubic:
    result.params[0] = command.c1.x
    result.params[1] = command.c1.y
    result.params[2] = command.c2.x
    result.params[3] = command.c2.y
    result.params[4] = command.c3.x
    result.params[5] = command.c3.y
  of pSCubic, pRSCubic, pQuad, pRQuad:
    result.params[0] = command.c.x
    result.params[1] = command.c.y
    result.params[2] = command.e.x
    result.params[3] = command.e.y
  of pArc, pRArc:
    result.params[0] = command.r.x
    result.params[1] = command.r.y
    result.params[2] = command.rot
    result.params[3] = float32(command.largeArc)
    result.params[4] = float32(command.sweep)
    result.params[5] = command.a.x
    result.params[6] = command.a.y

# Status codes — keep in sync with `uv_status` in UniVector.h.
const
  UV_OK = cint(0)
  UV_ERR_FORMAT = cint(2)         # bad arg / nil handle / unparseable `d` / bad color
  UV_ERR_UNSUP {.used.} = cint(4) # reserved
  UV_ERR_MEM = cint(8)            # allocation failed

# Winding rule — keep in sync with `uv_winding` in UniVector.h.
const
  UV_WINDING_NON_ZERO = cint(0)
  UV_WINDING_EVEN_ODD = cint(1)

  UV_CAP_BUTT = cint(0)
  UV_CAP_ROUND = cint(1)
  UV_CAP_SQUARE = cint(2)
  UV_JOIN_MITER = cint(0)
  UV_JOIN_ROUND = cint(1)
  UV_JOIN_BEVEL = cint(2)

proc toStrokeStyle(width: float32; cap, join: cint; miterLimit: float32;
                   style: var StrokeStyle): bool =
  if not allFinite([width, miterLimit]) or width <= 0'f32 or
      miterLimit < 1'f32 or
      cap notin [UV_CAP_BUTT, UV_CAP_ROUND, UV_CAP_SQUARE] or
      join notin [UV_JOIN_MITER, UV_JOIN_ROUND, UV_JOIN_BEVEL]:
    return false
  style = StrokeStyle(width: width, cap: LineCap(cap), join: LineJoin(join),
      miterLimit: miterLimit)
  true

proc writeString(s: string; outStr: ptr ptr char; outLen: ptr csize_t): cint =
  ## Copy `s` into a C-owned, NUL-terminated buffer; caller frees with
  ## `uv_buffer_free`. `*outLen` is the string length (excludes the NUL).
  if outStr == nil or outLen == nil: return UV_ERR_FORMAT
  outStr[] = nil
  outLen[] = 0
  let n = s.len
  let buf = allocShared(n + 1) # +1 for the NUL so the buffer is a usable C string
  if buf == nil: return UV_ERR_MEM
  if n > 0: copyMem(buf, unsafeAddr s[0], n)
  cast[ptr UncheckedArray[char]](buf)[n] = '\0'
  outStr[] = cast[ptr char](buf)
  outLen[] = csize_t(n)
  UV_OK

template swallowAbiFaults(body: untyped) =
  ## Run `body` so no CatchableError or Defect crosses the C boundary. Void
  ## mutators use this: the never-raises contract means a faulted mutation is
  ## dropped (the handle keeps its prior state) rather than escaping as a trap.
  try:
    body
  except CatchableError, Defect:
    discard

{.push exportc, cdecl, dynlib.}

proc uv_init() =
  ## Initialise the Nim runtime once. The first call must be externally
  ## synchronised; callers must invoke it before any other ABI function.
  if runtimeInitialized: return
  try:
    NimMain()
    runtimeInitialized = true
  except CatchableError, Defect:
    discard

proc uv_abi_version(): cint = cint(UniVectorAbiVersion)

proc uv_strerror(code: cint): cstring =
  case code
  of UV_OK: cstring"ok"
  of UV_ERR_FORMAT: cstring"bad argument / nil handle / unparseable path / bad color"
  of UV_ERR_UNSUP: cstring"unsupported operation"
  of UV_ERR_MEM: cstring"out of memory"
  else: cstring"unknown error"

proc uv_version(): cstring =
  ## Static engine version string; do not free. Never raises.
  cstring(UniVectorVersion)

# ------------------------------- path ---------------------------------------

proc uv_path_new(): pointer =
  ## An empty path. NULL only on allocation failure.
  try:
    let h = PathHandle(path: newPath())
    GC_ref(h)
    cast[pointer](h)
  except CatchableError, Defect:
    nil

proc uv_path_copy(src: pointer): pointer =
  ## A deep copy of `src`. NULL on a nil src or allocation failure.
  if src == nil: return nil
  try:
    let h = PathHandle(path: pathOf(src).path.copy())
    GC_ref(h)
    cast[pointer](h)
  except CatchableError, Defect:
    nil

proc uv_path_move_to(h: pointer; x, y: float32): cint =
  if h == nil or not allFinite([x, y]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.moveTo(x, y)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_line_to(h: pointer; x, y: float32): cint =
  if h == nil or not allFinite([x, y]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.lineTo(x, y)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_bezier_curve_to(h: pointer; x1, y1, x2, y2, x3,
    y3: float32): cint =
  if h == nil or not allFinite([x1, y1, x2, y2, x3, y3]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.bezierCurveTo(x1, y1, x2, y2, x3, y3)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_quadratic_curve_to(h: pointer; x1, y1, x2, y2: float32): cint =
  if h == nil or not allFinite([x1, y1, x2, y2]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.quadraticCurveTo(x1, y1, x2, y2)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_elliptical_arc_to(h: pointer; rx, ry, rotation: float32;
    largeArc, sweep: cint; x, y: float32): cint =
  if h == nil or rx < 0'f32 or ry < 0'f32 or
      not allFinite([rx, ry, rotation, x, y]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.ellipticalArcTo(rx, ry, rotation, largeArc != 0, sweep != 0, x, y)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_rect(h: pointer; x, y, w, hgt: float32; clockwise: cint): cint =
  if h == nil or not allFinite([x, y, w, hgt]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.rect(x, y, w, hgt, clockwise != 0)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_rounded_rect(h: pointer; x, y, w, hgt, nw, ne, se, sw: float32;
    clockwise: cint): cint =
  if h == nil or not allFinite([x, y, w, hgt, nw, ne, se, sw]):
    return UV_ERR_FORMAT
  try:
    pathOf(h).path.roundedRect(x, y, w, hgt, nw, ne, se, sw, clockwise != 0)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_ellipse(h: pointer; cx, cy, rx, ry: float32): cint =
  if h == nil or rx < 0'f32 or ry < 0'f32 or
      not allFinite([cx, cy, rx, ry]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.ellipse(cx, cy, rx, ry)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_circle(h: pointer; cx, cy, r: float32): cint =
  if h == nil or r < 0'f32 or not allFinite([cx, cy, r]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.circle(cx, cy, r)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_polygon(h: pointer; x, y, size: float32; sides: cint): cint =
  if h == nil or sides <= 2 or sides > cint(MaxPolygonSides) or
      not allFinite([x, y, size]): return UV_ERR_FORMAT
  try:
    pathOf(h).path.polygon(x, y, size, int(sides))
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_close_path(h: pointer): cint =
  if h == nil: return UV_ERR_FORMAT
  try:
    pathOf(h).path.closePath()
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_add_path(h: pointer; other: pointer): cint =
  if h == nil or other == nil: return UV_ERR_FORMAT
  try:
    pathOf(h).path.addPath(pathOf(other).path)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_arc(h: pointer; x, y, radius, a0, a1: float32;
    counterclockwise: cint): cint =
  if h == nil or radius < 0'f32 or not allFinite([x, y, radius, a0, a1]):
    return UV_ERR_FORMAT
  try:
    pathOf(h).path.arc(x, y, radius, a0, a1, counterclockwise != 0)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_arc_to(h: pointer; x1, y1, x2, y2, radius: float32): cint =
  if h == nil or radius < 0'f32 or not allFinite([x1, y1, x2, y2, radius]):
    return UV_ERR_FORMAT
  try:
    pathOf(h).path.arcTo(x1, y1, x2, y2, radius)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_current(h: pointer; outPoint: ptr UvVec2): cint =
  if h == nil or outPoint == nil: return UV_ERR_FORMAT
  try:
    outPoint[] = pathOf(h).path.at.toC
    UV_OK
  except CatchableError, Defect: UV_ERR_FORMAT

proc uv_path_start(h: pointer; outPoint: ptr UvVec2): cint =
  if h == nil or outPoint == nil: return UV_ERR_FORMAT
  try:
    outPoint[] = pathOf(h).path.start.toC
    UV_OK
  except CatchableError, Defect: UV_ERR_FORMAT

proc uv_path_command_count(h: pointer): csize_t =
  if h == nil: return 0
  try: csize_t(pathOf(h).path.commands.len)
  except CatchableError, Defect: 0

proc uv_path_command_get(h: pointer; index: csize_t;
    outCommand: ptr UvPathCommand): cint =
  if h == nil or outCommand == nil: return UV_ERR_FORMAT
  try:
    if index > csize_t(high(int)) or int(index) >= pathOf(h).path.commands.len:
      return UV_ERR_FORMAT
    outCommand[] = pathOf(h).path.commands[int(index)].toC
    UV_OK
  except CatchableError, Defect: UV_ERR_FORMAT

proc uv_path_command_is_relative(kind: cint): cint =
  try:
    if kind < 0 or kind > cint(high(PathCommandKind).ord): return -1
    cint(isRelative(PathCommandKind(kind)))
  except CatchableError, Defect: -1

proc uv_path_command_parameter_count(kind: cint): cint =
  try:
    if kind < 0 or kind > cint(high(PathCommandKind).ord): return -1
    cint(parameterCount(PathCommandKind(kind)))
  except CatchableError, Defect: -1

proc uv_quad_point(p0, control, p1: UvVec2; t: float32;
    outPoint: ptr UvVec2): cint =
  if outPoint == nil or t < 0'f32 or t > 1'f32 or
      not allFinite([p0.x, p0.y, control.x, control.y, p1.x, p1.y, t]):
    return UV_ERR_FORMAT
  try:
    outPoint[] = quadPoint(p0.fromC, control.fromC, p1.fromC, t).toC
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_cubic_point(p0, control1, control2, p1: UvVec2; t: float32;
    outPoint: ptr UvVec2): cint =
  if outPoint == nil or t < 0'f32 or t > 1'f32 or
      not allFinite([p0.x, p0.y, control1.x, control1.y, control2.x,
                     control2.y, p1.x, p1.y, t]):
    return UV_ERR_FORMAT
  try:
    outPoint[] = cubicPoint(p0.fromC, control1.fromC, control2.fromC,
        p1.fromC, t).toC
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_flatten(h: pointer; tol: float32; outSegments: ptr UvSegment;
    capacity: csize_t; outCount: ptr csize_t): cint =
  if h == nil or outCount == nil: return UV_ERR_FORMAT
  outCount[] = 0
  if not allFinite([tol]): return UV_ERR_FORMAT
  if capacity > 0 and outSegments == nil: return UV_ERR_FORMAT
  let effectiveTol = if tol > 0'f32: tol else: FlattenTolerance
  try:
    let segments = pathOf(h).path.flatten(effectiveTol)
    outCount[] = csize_t(segments.len)
    let copied = min(segments.len, int(min(capacity, csize_t(high(int)))))
    let output = cast[ptr UncheckedArray[UvSegment]](outSegments)
    for i in 0 ..< copied:
      output[i] = segments[i].toC
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_segments_bounds(segments: ptr UvSegment; count: csize_t;
    outBounds: ptr UvRect): cint =
  if outBounds == nil or count > csize_t(high(int)): return UV_ERR_FORMAT
  if count > 0 and segments == nil: return UV_ERR_FORMAT
  try:
    var values = newSeq[Segment](int(count))
    let input = cast[ptr UncheckedArray[UvSegment]](segments)
    for i in 0 ..< values.len:
      if not allFinite([input[i].at.x, input[i].at.y,
                        input[i].to.x, input[i].to.y]):
        return UV_ERR_FORMAT
      values[i] = Segment(at: input[i].at.fromC, to: input[i].to.fromC)
    outBounds[] = computeBounds(values).toC
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

# --------------------------- prepared path ---------------------------------

proc uv_path_prepare(h: pointer; tol: float32): pointer =
  if h == nil or not allFinite([tol]): return nil
  let effectiveTol = if tol > 0'f32: tol else: FlattenTolerance
  try:
    let prepared = PreparedPathHandle(path: pathOf(h).path.preparePath(effectiveTol))
    GC_ref(prepared)
    cast[pointer](prepared)
  except CatchableError, Defect:
    nil

proc uv_prepared_path_segment_count(h: pointer): csize_t =
  if h == nil: return 0
  try:
    csize_t(preparedPathOf(h).path.len)
  except CatchableError, Defect:
    0

proc uv_prepared_path_segment_get(h: pointer; index: csize_t;
    outSegment: ptr UvSegment): cint =
  if h == nil or outSegment == nil or index > csize_t(high(int)):
    return UV_ERR_FORMAT
  try:
    let prepared = preparedPathOf(h).path
    if index >= csize_t(prepared.len): return UV_ERR_FORMAT
    outSegment[] = prepared.segment(int(index)).toC
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_prepared_path_bounds(h: pointer; outBounds: ptr UvRect): cint =
  if h == nil or outBounds == nil: return UV_ERR_FORMAT
  try:
    outBounds[] = preparedPathOf(h).path.bounds.toC
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_prepared_path_tolerance(h: pointer): float32 =
  if h == nil: return 0'f32
  try:
    preparedPathOf(h).path.tolerance
  except CatchableError, Defect:
    0'f32

proc uv_prepared_path_free(h: pointer) =
  if h == nil: return
  swallowAbiFaults:
    GC_unref(preparedPathOf(h))

proc uv_prepared_path_stroke(h: pointer; width: float32; cap, join: cint;
    miterLimit: float32): pointer =
  var style: StrokeStyle
  if h == nil or not toStrokeStyle(width, cap, join, miterLimit, style):
    return nil
  try:
    let path = PathHandle(path: preparedPathOf(h).path.strokeToPath(style))
    GC_ref(path)
    cast[pointer](path)
  except CatchableError, Defect:
    nil

# -------------------------------- mesh --------------------------------------

proc uv_prepared_path_tessellate_fill(h: pointer; winding: cint): pointer =
  if h == nil or winding notin [UV_WINDING_NON_ZERO, UV_WINDING_EVEN_ODD]:
    return nil
  try:
    let handle = MeshHandle(mesh: preparedPathOf(h).path.tessellateFill(
        WindingRule(winding)))
    GC_ref(handle)
    cast[pointer](handle)
  except CatchableError, Defect:
    nil

proc uv_mesh_vertex_count(h: pointer): csize_t =
  if h == nil: return 0
  try: csize_t(meshOf(h).mesh.vertexCount)
  except CatchableError, Defect: 0

proc uv_mesh_index_count(h: pointer): csize_t =
  if h == nil: return 0
  try: csize_t(meshOf(h).mesh.indexCount)
  except CatchableError, Defect: 0

proc uv_mesh_vertex_get(h: pointer; index: csize_t;
    outVertex: ptr UvVectorVertex): cint =
  if h == nil or outVertex == nil or index > csize_t(high(int)):
    return UV_ERR_FORMAT
  try:
    let mesh = meshOf(h).mesh
    if index >= csize_t(mesh.vertexCount): return UV_ERR_FORMAT
    let vertex = mesh.vertex(int(index))
    outVertex[] = UvVectorVertex(position: vertex.position.toC,
        coverage: vertex.coverage)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_mesh_index_get(h: pointer; position: csize_t;
    outIndex: ptr uint32): cint =
  if h == nil or outIndex == nil or position > csize_t(high(int)):
    return UV_ERR_FORMAT
  try:
    let mesh = meshOf(h).mesh
    if position >= csize_t(mesh.indexCount): return UV_ERR_FORMAT
    outIndex[] = mesh.index(int(position))
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_mesh_free(h: pointer) =
  if h == nil: return
  swallowAbiFaults:
    GC_unref(meshOf(h))

proc uv_path_parse_d(s: cstring; outHandle: ptr pointer): cint =
  ## Parse an SVG `d` string. On success stores a handle in `*outHandle` (free
  ## with `uv_path_free`); on failure clears it and returns `UV_ERR_FORMAT`.
  if outHandle == nil: return UV_ERR_FORMAT
  outHandle[] = nil
  if s == nil: return UV_ERR_FORMAT
  try:
    let p = parsePath($s)
    let h = PathHandle(path: p)
    GC_ref(h)
    outHandle[] = cast[pointer](h)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_to_d(h: pointer; outStr: ptr ptr char; outLen: ptr csize_t): cint =
  ## Serialise the path to an SVG `d` string (NUL-terminated; free with
  ## `uv_buffer_free`). `*outLen` is the string length.
  if outStr == nil or outLen == nil: return UV_ERR_FORMAT
  outStr[] = nil
  outLen[] = 0
  if h == nil: return UV_ERR_FORMAT
  try:
    writeString($pathOf(h).path, outStr, outLen)
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_path_free(h: pointer) =
  if h == nil: return
  swallowAbiFaults: GC_unref(pathOf(h))

# ------------------------------- image --------------------------------------

proc uv_image_new(width, height: cint): pointer =
  ## A zeroed (transparent) RGBA8 image. NULL on bad dimensions or allocation
  ## failure.
  if width <= 0 or height <= 0: return nil
  try:
    let img = uimg.newImage[uint8](int(width), int(height), uimg.csRgba)
    let h = ImgHandle(img: img)
    GC_ref(h)
    cast[pointer](h)
  except CatchableError, Defect:
    nil

proc uv_image_width(h: pointer): cint =
  if h == nil: return 0
  try: cint(imgOf(h).img.width)
  except CatchableError, Defect: 0

proc uv_image_height(h: pointer): cint =
  if h == nil: return 0
  try: cint(imgOf(h).img.height)
  except CatchableError, Defect: 0

proc uv_image_channels(h: pointer): cint =
  if h == nil: return 0
  try: cint(imgOf(h).img.channels)
  except CatchableError, Defect: 0

proc uv_image_pixels(h: pointer; outPtr: ptr ptr uint8;
    outLen: ptr csize_t): cint =
  ## Borrow the pixel buffer (no copy). `*outPtr` is valid until `h` is freed;
  ## do NOT free it with `uv_buffer_free`. Empty image -> `*outPtr = NULL`,
  ## `*outLen = 0`, `UV_OK`.
  if outPtr == nil or outLen == nil: return UV_ERR_FORMAT
  outPtr[] = nil
  outLen[] = 0
  if h == nil: return UV_ERR_FORMAT
  try:
    let hh = imgOf(h)
    if hh.img.data.len == 0: return UV_OK
    outPtr[] = cast[ptr uint8](addr hh.img.data[0])
    outLen[] = csize_t(hh.img.data.len)
    UV_OK
  except CatchableError, Defect: UV_ERR_FORMAT

proc uv_image_encode_png(h: pointer; outData: ptr ptr uint8;
    outLen: ptr csize_t): cint =
  ## Encode the image as PNG. On success allocates `*outData` (free with
  ## `uv_buffer_free`) and sets `*outLen`.
  if outData == nil or outLen == nil: return UV_ERR_FORMAT
  outData[] = nil
  outLen[] = 0
  if h == nil: return UV_ERR_FORMAT
  try:
    let bytes = encodeImage(imgOf(h).img, efPng, 90)
    if bytes.len == 0: return UV_ERR_FORMAT
    let buf = allocShared(bytes.len) # C-owned; freed by uv_buffer_free
    if buf == nil: return UV_ERR_MEM
    copyMem(buf, unsafeAddr bytes[0], bytes.len)
    outData[] = cast[ptr uint8](buf)
    outLen[] = csize_t(bytes.len)
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_image_free(h: pointer) =
  if h == nil: return
  swallowAbiFaults: GC_unref(imgOf(h))

# ------------------------------- color --------------------------------------

proc uv_color_parse(s: cstring): pointer =
  ## Parse a CSS Color 4 string (hex/rgb/oklch/...). NULL on a nil string or
  ## unparseable input. Never raises (parseColor returns a Result).
  if s == nil: return nil
  try:
    let r = parseColor($s)
    if not r.isOk: return nil
    let h = ColorHandle(color: r.get)
    GC_ref(h)
    cast[pointer](h)
  except CatchableError, Defect:
    nil

proc uv_color_rgba(r, g, b, a: float32): pointer =
  ## An sRGB color from straight-alpha floats in [0, 1]. NULL on an
  ## out-of-gamut / non-finite input.
  if not allFinite([r, g, b, a]) or
      r < 0'f32 or r > 1'f32 or g < 0'f32 or g > 1'f32 or
      b < 0'f32 or b > 1'f32 or a < 0'f32 or a > 1'f32:
    return nil
  try:
    let cr = color(tagSrgb, r, g, b, a)
    if not cr.isOk: return nil
    let h = ColorHandle(color: cr.get)
    GC_ref(h)
    cast[pointer](h)
  except CatchableError, Defect:
    nil

proc uv_color_free(h: pointer) =
  if h == nil: return
  swallowAbiFaults: GC_unref(colorOf(h))

# ------------------------------- raster -------------------------------------

proc uv_fill_path(img: pointer; path: pointer; color: pointer;
    winding: cint; tol: float32; blend: cint): cint =
  ## Solid-fill `path` with `color` onto `img` (RGBA8 straight alpha). `winding`
  ## is `UV_WINDING_*`, `blend` is `UV_BLEND_*`, and `tol <= 0` uses the
  ## default flattening tolerance.
  if img == nil or path == nil or color == nil: return UV_ERR_FORMAT
  if not allFinite([tol]): return UV_ERR_FORMAT
  if winding != UV_WINDING_NON_ZERO and winding != UV_WINDING_EVEN_ODD:
    return UV_ERR_FORMAT
  if blend < cint(low(BlendMode).ord) or blend > cint(high(BlendMode).ord):
    return UV_ERR_FORMAT
  try:
    let wr = if winding == UV_WINDING_EVEN_ODD: EvenOdd else: NonZero
    let tolF = if tol > 0'f32: tol else: FlattenTolerance
    imgOf(img).img.fillPath(pathOf(path).path, colorOf(color).color, wr, tolF,
                            BlendMode(blend))
    UV_OK
  except CatchableError, Defect:
    UV_ERR_FORMAT

# -------------------------------- svg ---------------------------------------

proc uv_path_to_svg(path: pointer; color: pointer; width, height: cint;
    outStr: ptr ptr char; outLen: ptr csize_t): cint =
  ## Wrap the path's `d` string in an `<svg>` document with the given `color`
  ## and canvas size (NUL-terminated; free with `uv_buffer_free`).
  if outStr == nil or outLen == nil: return UV_ERR_FORMAT
  outStr[] = nil
  outLen[] = 0
  if path == nil or color == nil: return UV_ERR_FORMAT
  if width <= 0 or height <= 0: return UV_ERR_FORMAT
  try:
    let s = toSvgString(pathOf(path).path, colorOf(color).color,
                       int(width), int(height))
    writeString(s, outStr, outLen)
  except CatchableError, Defect:
    UV_ERR_FORMAT

proc uv_color_to_svg(color: pointer; outStr: ptr ptr char;
    outLen: ptr csize_t): cint =
  ## The SVG color string for `color` (`#rrggbb[aa]`; NUL-terminated; free with
  ## `uv_buffer_free`).
  if outStr == nil or outLen == nil: return UV_ERR_FORMAT
  outStr[] = nil
  outLen[] = 0
  if color == nil: return UV_ERR_FORMAT
  try:
    writeString(toSvgColor(colorOf(color).color), outStr, outLen)
  except CatchableError, Defect:
    UV_ERR_FORMAT

# ------------------------------- buffer -------------------------------------

proc uv_buffer_free(p: pointer; len: csize_t) =
  ## Free a buffer returned by `uv_path_to_d` / `uv_path_to_svg` /
  ## `uv_color_to_svg` / `uv_image_encode_png`. NULL is a no-op. `len` is
  ## ignored (kept for symmetry with the allocator). Do NOT use on
  ## `uv_image_pixels`.
  if p == nil: return
  swallowAbiFaults: deallocShared(p)

{.pop.}
