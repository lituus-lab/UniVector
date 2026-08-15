# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# cython: language_level=3
"""Cython binding over the UniVector C ABI."""
from threading import Lock

from libc.stddef cimport size_t
from libc.stdlib cimport malloc, free
cimport cython


cdef extern from "UniVector.h":
    float  UNIVECTOR_FLATTEN_TOLERANCE
    int    UNIVECTOR_MAX_FLATTEN_DEPTH
    int    UNIVECTOR_MAX_FLATTEN_SEGMENTS
    int    UNIVECTOR_MAX_DASH_PATTERN_ELEMENTS
    int    UNIVECTOR_MAX_MARKER_COUNT
    int    UNIVECTOR_SUPERSAMPLE
    int    UNIVECTOR_MAX_MESH_VERTICES
    int    UNIVECTOR_MAX_MESH_INDICES
    float  UNIVECTOR_GEOMETRIC_EPSILON
    float  UNIVECTOR_DEFAULT_MITER_LIMIT
    const char *uv_version()
    void   uv_init()
    int    uv_abi_version()
    const char *uv_strerror(int code)

    ctypedef void* uv_path
    ctypedef void* uv_prepared_path
    ctypedef void* uv_mesh
    ctypedef void* uv_image
    ctypedef void* uv_color

    ctypedef struct uv_vec2:
        float x
        float y
    ctypedef struct uv_rect:
        float x
        float y
        float w
        float h
    ctypedef struct uv_segment:
        uv_vec2 at
        uv_vec2 to
    ctypedef struct uv_vector_vertex:
        uv_vec2 position
        float coverage
    ctypedef struct uv_path_command:
        int kind
        float params[7]

    uv_path  uv_path_new()
    uv_path  uv_path_copy(uv_path src)
    int      uv_path_move_to(uv_path h, float x, float y)
    int      uv_path_line_to(uv_path h, float x, float y)
    int      uv_path_bezier_curve_to(uv_path h, float x1, float y1,
                                     float x2, float y2, float x3, float y3)
    int      uv_path_quadratic_curve_to(uv_path h, float x1, float y1,
                                        float x2, float y2)
    int      uv_path_elliptical_arc_to(uv_path h, float rx, float ry,
                                       float rotation, int large_arc,
                                       int sweep, float x, float y)
    int      uv_path_rect(uv_path h, float x, float y, float w, float hgt,
                          int clockwise)
    int      uv_path_rounded_rect(uv_path h, float x, float y, float w,
                                  float hgt, float nw, float ne, float se,
                                  float sw, int clockwise)
    int      uv_path_ellipse(uv_path h, float cx, float cy, float rx, float ry)
    int      uv_path_circle(uv_path h, float cx, float cy, float r)
    int      uv_path_polygon(uv_path h, float x, float y, float size, int sides)
    int      uv_path_close_path(uv_path h)
    int      uv_path_add_path(uv_path h, uv_path other)
    int      uv_path_arc(uv_path h, float x, float y, float radius,
                         float a0, float a1, int counterclockwise)
    int      uv_path_arc_to(uv_path h, float x1, float y1, float x2, float y2,
                            float radius)
    int      uv_path_current(uv_path h, uv_vec2* out_point)
    int      uv_path_start(uv_path h, uv_vec2* out_point)
    size_t   uv_path_command_count(uv_path h)
    int      uv_path_command_get(uv_path h, size_t index,
                                 uv_path_command* out_command)
    int      uv_path_command_is_relative(int kind)
    int      uv_path_command_parameter_count(int kind)
    int      uv_path_parse_d(const char* s, uv_path* out_handle)
    int      uv_path_to_d(uv_path h, char** out_str, size_t* out_len)
    void     uv_path_free(uv_path h)

    int      uv_quad_point(uv_vec2 p0, uv_vec2 control, uv_vec2 p1, float t,
                           uv_vec2* out_point)
    int      uv_cubic_point(uv_vec2 p0, uv_vec2 control1, uv_vec2 control2,
                            uv_vec2 p1, float t, uv_vec2* out_point)
    int      uv_path_flatten(uv_path h, float tolerance,
                             uv_segment* out_segments, size_t capacity,
                             size_t* out_count)
    int      uv_segments_bounds(const uv_segment* segments, size_t count,
                                uv_rect* out_bounds)
    uv_prepared_path uv_path_prepare(uv_path h, float tolerance)
    size_t   uv_prepared_path_segment_count(uv_prepared_path h)
    int      uv_prepared_path_segment_get(uv_prepared_path h, size_t index,
                                          uv_segment* out_segment)
    int      uv_prepared_path_bounds(uv_prepared_path h, uv_rect* out_bounds)
    float    uv_prepared_path_tolerance(uv_prepared_path h)
    void     uv_prepared_path_free(uv_prepared_path h)
    uv_path  uv_prepared_path_stroke(uv_prepared_path h, float width,
                                     int cap, int join, float miter_limit)
    uv_path  uv_prepared_path_stroke_dashed(
        uv_prepared_path h, float width, int cap, int join, float miter_limit,
        const float* dashes, size_t dash_count, float dash_offset)
    uv_path  uv_marker_path(int shape, uv_vec2 center, float size)
    uv_path  uv_markers_path(int shape, const uv_vec2* points,
                             size_t count, float size)
    uv_path  uv_markers_path_sized(int shape, const uv_vec2* points,
                                   const float* sizes, size_t count)
    uv_mesh  uv_prepared_path_tessellate_fill(uv_prepared_path h, int winding)
    uv_mesh  uv_prepared_path_tessellate_stroke(
        uv_prepared_path h, float width, int cap, int join, float miter_limit)
    uv_mesh  uv_prepared_path_tessellate_stroke_dashed(
        uv_prepared_path h, float width, int cap, int join, float miter_limit,
        const float* dashes, size_t dash_count, float dash_offset)
    size_t   uv_mesh_vertex_count(uv_mesh h)
    size_t   uv_mesh_index_count(uv_mesh h)
    int      uv_mesh_vertex_get(uv_mesh h, size_t index,
                                uv_vector_vertex* out_vertex)
    int      uv_mesh_index_get(uv_mesh h, size_t position,
                               unsigned int* out_index)
    void     uv_mesh_free(uv_mesh h)

    uv_image uv_image_new(int width, int height)
    int      uv_image_width(uv_image h)
    int      uv_image_height(uv_image h)
    int      uv_image_channels(uv_image h)
    int      uv_image_pixels(uv_image h, unsigned char** out_ptr, size_t* out_len)
    int      uv_image_encode_png(uv_image h, unsigned char** out_data,
                                 size_t* out_len)
    void     uv_image_free(uv_image h)

    uv_color uv_color_parse(const char* s)
    uv_color uv_color_rgba(float r, float g, float b, float a)
    void     uv_color_free(uv_color h)

    int      uv_fill_path(uv_image img, uv_path path, uv_color color,
                          int winding, float tol, int blend)
    int      uv_fill_prepared_path(uv_image img, uv_prepared_path path,
                                   uv_color color, int winding, int blend)
    int      uv_path_to_svg(uv_path path, uv_color color, int width, int height,
                            char** out_str, size_t* out_len)
    int      uv_color_to_svg(uv_color color, char** out_str, size_t* out_len)
    void     uv_buffer_free(void* buffer, size_t len)


# Winding rules — mirror the uv_winding enum in UniVector.h.
WINDING_NON_ZERO = 0
WINDING_EVEN_ODD = 1
FLATTEN_TOLERANCE = UNIVECTOR_FLATTEN_TOLERANCE
MAX_FLATTEN_DEPTH = UNIVECTOR_MAX_FLATTEN_DEPTH
MAX_FLATTEN_SEGMENTS = UNIVECTOR_MAX_FLATTEN_SEGMENTS
MAX_DASH_PATTERN_ELEMENTS = UNIVECTOR_MAX_DASH_PATTERN_ELEMENTS
MAX_MARKER_COUNT = UNIVECTOR_MAX_MARKER_COUNT
MAX_MESH_VERTICES = UNIVECTOR_MAX_MESH_VERTICES
MAX_MESH_INDICES = UNIVECTOR_MAX_MESH_INDICES
SUPERSAMPLE = UNIVECTOR_SUPERSAMPLE
GEOMETRIC_EPSILON = UNIVECTOR_GEOMETRIC_EPSILON
BLEND_NORMAL = 0
BLEND_OVERWRITE = 1
CAP_BUTT = 0
CAP_ROUND = 1
CAP_SQUARE = 2
JOIN_MITER = 0
JOIN_ROUND = 1
JOIN_BEVEL = 2
DEFAULT_MITER_LIMIT = UNIVECTOR_DEFAULT_MITER_LIMIT
MARKER_CIRCLE = 0
MARKER_SQUARE = 1
MARKER_TRIANGLE = 2
MARKER_DIAMOND = 3
MARKER_PLUS = 4
MARKER_CROSS = 5

PATH_CLOSE = 0
PATH_MOVE = 1
PATH_LINE = 2
PATH_HLINE = 3
PATH_VLINE = 4
PATH_CUBIC = 5
PATH_SMOOTH_CUBIC = 6
PATH_QUADRATIC = 7
PATH_SMOOTH_QUADRATIC = 8
PATH_ARC = 9
PATH_REL_MOVE = 10
PATH_REL_LINE = 11
PATH_REL_HLINE = 12
PATH_REL_VLINE = 13
PATH_REL_CUBIC = 14
PATH_REL_SMOOTH_CUBIC = 15
PATH_REL_QUADRATIC = 16
PATH_REL_SMOOTH_QUADRATIC = 17
PATH_REL_ARC = 18


cdef str _borrow_cstr(const char* s):
    if s == NULL:
        return ""
    return (<bytes>s).decode("ascii")


def strerror(int code):
    return _borrow_cstr(uv_strerror(code))


def version():
    return _borrow_cstr(uv_version())


def abi_version():
    return uv_abi_version()


cdef bint _initialized = False
_init_lock = Lock()


def init():
    global _initialized
    if _initialized:
        return
    with _init_lock:
        if not _initialized:
            uv_init()
            _initialized = True


cdef void _check_path_status(int code, str operation) except *:
    if code != 0:
        raise ValueError(f"{operation} failed: {strerror(code)}")


cdef uv_vec2 _vec2(object value) except *:
    if len(value) != 2:
        raise ValueError("a point must contain exactly two coordinates")
    cdef uv_vec2 result
    result.x = float(value[0])
    result.y = float(value[1])
    return result


def is_relative(int kind):
    cdef int result = uv_path_command_is_relative(kind)
    if result < 0:
        raise ValueError("invalid path command kind")
    return bool(result)


def parameter_count(int kind):
    cdef int result = uv_path_command_parameter_count(kind)
    if result < 0:
        raise ValueError("invalid path command kind")
    return result


def quad_point(p0, control, p1, float t):
    cdef uv_vec2 out
    cdef int rc = uv_quad_point(_vec2(p0), _vec2(control), _vec2(p1), t, &out)
    if rc != 0:
        raise ValueError(f"quad_point failed: {strerror(rc)}")
    return (out.x, out.y)


def cubic_point(p0, control1, control2, p1, float t):
    cdef uv_vec2 out
    cdef int rc = uv_cubic_point(_vec2(p0), _vec2(control1), _vec2(control2),
                                 _vec2(p1), t, &out)
    if rc != 0:
        raise ValueError(f"cubic_point failed: {strerror(rc)}")
    return (out.x, out.y)


def compute_bounds(segments):
    values = list(segments)
    cdef size_t count = len(values)
    cdef uv_segment* raw = NULL
    cdef uv_rect out
    cdef size_t i
    if count:
        raw = <uv_segment*>malloc(count * sizeof(uv_segment))
        if raw == NULL:
            raise MemoryError()
    try:
        for i in range(count):
            if len(values[i]) != 2:
                raise ValueError("a segment must contain exactly two points")
            raw[i].at = _vec2(values[i][0])
            raw[i].to = _vec2(values[i][1])
        rc = uv_segments_bounds(raw, count, &out)
        if rc != 0:
            raise ValueError(f"compute_bounds failed: {strerror(rc)}")
        return (out.x, out.y, out.w, out.h)
    finally:
        free(raw)


cdef class Path:
    """An SVG-style path. The library owns the handle; freed on GC."""
    cdef uv_path _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            uv_path_free(self._h)
            self._h = NULL

    @staticmethod
    cdef Path _wrap(uv_path h):
        # __new__ bypasses __init__ (which would uv_path_new a throwaway handle
        # and leak it); __cinit__ still runs to zero _h. Type the result so the
        # C-level `_h` field assignment stays a C store, not a Python attribute.
        cdef Path r = Path.__new__(Path)
        r._h = h
        return r

    def __init__(self):
        self._h = uv_path_new()
        if self._h == NULL:
            raise MemoryError("uv_path_new returned NULL")

    def copy(self):
        h = uv_path_copy(self._h)
        if h == NULL:
            raise MemoryError("uv_path_copy returned NULL")
        return Path._wrap(h)

    def move_to(self, float x, float y):
        _check_path_status(uv_path_move_to(self._h, x, y), "move_to")

    def line_to(self, float x, float y):
        _check_path_status(uv_path_line_to(self._h, x, y), "line_to")

    def bezier_curve_to(self, float x1, float y1, float x2, float y2,
                        float x3, float y3):
        _check_path_status(uv_path_bezier_curve_to(
            self._h, x1, y1, x2, y2, x3, y3), "bezier_curve_to")

    def quadratic_curve_to(self, float x1, float y1, float x2, float y2):
        _check_path_status(uv_path_quadratic_curve_to(
            self._h, x1, y1, x2, y2), "quadratic_curve_to")

    def elliptical_arc_to(self, float rx, float ry, float rotation,
                          bint large_arc, bint sweep, float x, float y):
        _check_path_status(uv_path_elliptical_arc_to(
            self._h, rx, ry, rotation, 1 if large_arc else 0,
            1 if sweep else 0, x, y), "elliptical_arc_to")

    def rect(self, float x, float y, float w, float h, bint clockwise=True):
        _check_path_status(uv_path_rect(
            self._h, x, y, w, h, 1 if clockwise else 0), "rect")

    def rounded_rect(self, float x, float y, float w, float h,
                     float nw, float ne, float se, float sw,
                     bint clockwise=True):
        _check_path_status(uv_path_rounded_rect(
            self._h, x, y, w, h, nw, ne, se, sw,
            1 if clockwise else 0), "rounded_rect")

    def ellipse(self, float cx, float cy, float rx, float ry):
        _check_path_status(uv_path_ellipse(self._h, cx, cy, rx, ry), "ellipse")

    def circle(self, float cx, float cy, float r):
        _check_path_status(uv_path_circle(self._h, cx, cy, r), "circle")

    def polygon(self, float x, float y, float size, int sides):
        _check_path_status(uv_path_polygon(self._h, x, y, size, sides), "polygon")

    def close_path(self):
        _check_path_status(uv_path_close_path(self._h), "close_path")

    def add_path(self, Path other not None):
        _check_path_status(uv_path_add_path(self._h, other._h), "add_path")

    def arc(self, float x, float y, float radius, float a0, float a1,
            bint counterclockwise=False):
        rc = uv_path_arc(self._h, x, y, radius, a0, a1,
                         1 if counterclockwise else 0)
        if rc != 0:
            raise ValueError(f"arc failed: {strerror(rc)}")

    def arc_to(self, float x1, float y1, float x2, float y2, float radius):
        rc = uv_path_arc_to(self._h, x1, y1, x2, y2, radius)
        if rc != 0:
            raise ValueError(f"arc_to failed: {strerror(rc)}")

    @property
    def current(self):
        cdef uv_vec2 out
        if uv_path_current(self._h, &out) != 0:
            raise ValueError("current point unavailable")
        return (out.x, out.y)

    @property
    def start(self):
        cdef uv_vec2 out
        if uv_path_start(self._h, &out) != 0:
            raise ValueError("start point unavailable")
        return (out.x, out.y)

    @property
    def commands(self):
        cdef size_t count = uv_path_command_count(self._h)
        cdef size_t i
        cdef uv_path_command command
        cdef int n
        result = []
        for i in range(count):
            if uv_path_command_get(self._h, i, &command) != 0:
                raise RuntimeError("path changed while reading commands")
            n = uv_path_command_parameter_count(command.kind)
            if n < 0:
                raise RuntimeError("path contains an invalid command kind")
            result.append((command.kind,
                           tuple(command.params[j] for j in range(n))))
        return result

    def flatten(self, float tolerance=0.0):
        cdef size_t count = 0
        cdef uv_segment* raw = NULL
        cdef size_t i
        rc = uv_path_flatten(self._h, tolerance, NULL, 0, &count)
        if rc != 0:
            raise ValueError(f"flatten failed: {strerror(rc)}")
        if count:
            raw = <uv_segment*>malloc(count * sizeof(uv_segment))
            if raw == NULL:
                raise MemoryError()
        try:
            required = count
            rc = uv_path_flatten(self._h, tolerance, raw, count, &required)
            if rc != 0:
                raise ValueError(f"flatten failed: {strerror(rc)}")
            if required != count:
                raise RuntimeError("path changed while flattening")
            return [((raw[i].at.x, raw[i].at.y),
                     (raw[i].to.x, raw[i].to.y)) for i in range(count)]
        finally:
            free(raw)

    def bounds(self, float tolerance=0.0):
        return compute_bounds(self.flatten(tolerance))

    def prepare(self, float tolerance=0.0):
        """Flatten once into immutable renderer-neutral geometry."""
        cdef uv_prepared_path h = uv_path_prepare(self._h, tolerance)
        if h == NULL:
            raise ValueError("prepare failed")
        return PreparedPath._wrap(h)

    @staticmethod
    def parse_d(str s):
        """Parse an SVG `d` string. Raises ValueError on a bad string."""
        cdef uv_path h = NULL
        cdef bytes b = s.encode("utf-8")
        rc = uv_path_parse_d(<const char*>b, &h)
        if rc != 0:
            raise ValueError(f"parse_d failed: {strerror(rc)}")
        return Path._wrap(h)

    def to_d(self):
        """Serialise to an SVG `d` string."""
        cdef char* out = NULL
        cdef size_t out_len = 0
        rc = uv_path_to_d(self._h, &out, &out_len)
        if rc != 0:
            raise ValueError(f"to_d failed: {strerror(rc)}")
        try:
            return bytes(out[:out_len]).decode("ascii")
        finally:
            uv_buffer_free(out, out_len)

    def to_svg(self, Color color not None, int width, int height):
        """Wrap this path's `d` in an <svg> document string."""
        cdef char* out = NULL
        cdef size_t out_len = 0
        rc = uv_path_to_svg(self._h, color._h, width, height, &out, &out_len)
        if rc != 0:
            raise ValueError(f"to_svg failed: {strerror(rc)}")
        try:
            return bytes(out[:out_len]).decode("ascii")
        finally:
            uv_buffer_free(out, out_len)


def marker_path(int shape, center, float size):
    """Construct one filled marker path."""
    cdef uv_path h = uv_marker_path(shape, _vec2(center), size)
    if h == NULL:
        raise ValueError("marker_path failed")
    return Path._wrap(h)


def markers_path(int shape, points, float size):
    """Combine equally sized markers into one filled path."""
    values = list(points)
    cdef size_t count = len(values)
    cdef uv_vec2* raw = NULL
    cdef size_t i
    cdef uv_path h = NULL
    if count > MAX_MARKER_COUNT:
        raise ValueError("marker limit exceeded")
    if count:
        raw = <uv_vec2*>malloc(count * sizeof(uv_vec2))
        if raw == NULL:
            raise MemoryError()
    try:
        for i in range(count):
            raw[i] = _vec2(values[i])
        h = uv_markers_path(shape, raw, count, size)
        if h == NULL:
            raise ValueError("markers_path failed")
        return Path._wrap(h)
    finally:
        free(raw)


def markers_path_sized(int shape, points, sizes):
    """Combine per-point sized markers into one filled path."""
    point_values = list(points)
    size_values = list(sizes)
    if len(point_values) != len(size_values):
        raise ValueError("point and size counts differ")
    cdef size_t count = len(point_values)
    cdef uv_vec2* raw_points = NULL
    cdef float* raw_sizes = NULL
    cdef size_t i
    cdef uv_path h = NULL
    if count > MAX_MARKER_COUNT:
        raise ValueError("marker limit exceeded")
    if count:
        raw_points = <uv_vec2*>malloc(count * sizeof(uv_vec2))
        raw_sizes = <float*>malloc(count * sizeof(float))
        if raw_points == NULL or raw_sizes == NULL:
            free(raw_points)
            free(raw_sizes)
            raise MemoryError()
    try:
        for i in range(count):
            raw_points[i] = _vec2(point_values[i])
            raw_sizes[i] = float(size_values[i])
        h = uv_markers_path_sized(shape, raw_points, raw_sizes, count)
        if h == NULL:
            raise ValueError("markers_path_sized failed")
        return Path._wrap(h)
    finally:
        free(raw_points)
        free(raw_sizes)


cdef class PreparedPath:
    """Immutable flattened path geometry owned by UniVector."""
    cdef uv_prepared_path _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            uv_prepared_path_free(self._h)
            self._h = NULL

    @staticmethod
    cdef PreparedPath _wrap(uv_prepared_path h):
        cdef PreparedPath result = PreparedPath.__new__(PreparedPath)
        result._h = h
        return result

    def __init__(self):
        raise TypeError("PreparedPath values are created by Path.prepare()")

    def __len__(self):
        return uv_prepared_path_segment_count(self._h)

    @property
    def tolerance(self):
        return uv_prepared_path_tolerance(self._h)

    @property
    def bounds(self):
        cdef uv_rect out
        cdef int rc = uv_prepared_path_bounds(self._h, &out)
        if rc != 0:
            raise ValueError(f"prepared bounds failed: {strerror(rc)}")
        return (out.x, out.y, out.w, out.h)

    @property
    def segments(self):
        cdef size_t count = uv_prepared_path_segment_count(self._h)
        cdef size_t i
        cdef uv_segment segment
        result = []
        for i in range(count):
            if uv_prepared_path_segment_get(self._h, i, &segment) != 0:
                raise RuntimeError("prepared path changed while reading")
            result.append(((segment.at.x, segment.at.y),
                           (segment.to.x, segment.to.y)))
        return tuple(result)

    def stroke(self, float width, int cap=CAP_BUTT, int join=JOIN_MITER,
               float miter_limit=DEFAULT_MITER_LIMIT, dashes=None,
               float dash_offset=0.0):
        """Expand this centerline into a filled Path."""
        cdef uv_path h = NULL
        cdef float* raw = NULL
        cdef size_t count = 0
        cdef size_t i
        if dashes is None:
            h = uv_prepared_path_stroke(
                self._h, width, cap, join, miter_limit)
        else:
            values = list(dashes)
            count = len(values)
            if count > MAX_DASH_PATTERN_ELEMENTS:
                raise ValueError("dash pattern limit exceeded")
            if count:
                raw = <float*>malloc(count * sizeof(float))
                if raw == NULL:
                    raise MemoryError()
            try:
                for i in range(count):
                    raw[i] = float(values[i])
                h = uv_prepared_path_stroke_dashed(
                    self._h, width, cap, join, miter_limit, raw, count,
                    dash_offset)
            finally:
                free(raw)
        if h == NULL:
            raise ValueError("stroke failed: invalid style or allocation")
        return Path._wrap(h)

    def tessellate_fill(self, int winding=WINDING_NON_ZERO):
        """Build a renderer-neutral indexed triangle mesh."""
        cdef uv_mesh h = uv_prepared_path_tessellate_fill(self._h, winding)
        if h == NULL:
            raise ValueError("tessellate_fill failed")
        return VectorMesh._wrap(h)

    def tessellate_stroke(self, float width, int cap=CAP_BUTT,
                          int join=JOIN_MITER,
                          float miter_limit=DEFAULT_MITER_LIMIT, dashes=None,
                          float dash_offset=0.0):
        """Expand and build an indexed triangle mesh for this stroke."""
        cdef uv_mesh h = NULL
        cdef float* raw = NULL
        cdef size_t count = 0
        cdef size_t i
        if dashes is None:
            h = uv_prepared_path_tessellate_stroke(
                self._h, width, cap, join, miter_limit)
        else:
            values = list(dashes)
            count = len(values)
            if count > MAX_DASH_PATTERN_ELEMENTS:
                raise ValueError("dash pattern limit exceeded")
            if count:
                raw = <float*>malloc(count * sizeof(float))
                if raw == NULL:
                    raise MemoryError()
            try:
                for i in range(count):
                    raw[i] = float(values[i])
                h = uv_prepared_path_tessellate_stroke_dashed(
                    self._h, width, cap, join, miter_limit, raw, count,
                    dash_offset)
            finally:
                free(raw)
        if h == NULL:
            raise ValueError("tessellate_stroke failed")
        return VectorMesh._wrap(h)


cdef class VectorMesh:
    """Immutable indexed triangles produced by UniVector."""
    cdef uv_mesh _h

    def __cinit__(self): self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            uv_mesh_free(self._h)
            self._h = NULL

    @staticmethod
    cdef VectorMesh _wrap(uv_mesh h):
        cdef VectorMesh result = VectorMesh.__new__(VectorMesh)
        result._h = h
        return result

    def __init__(self):
        raise TypeError("VectorMesh values are created by tessellation")

    @property
    def vertices(self):
        cdef size_t count = uv_mesh_vertex_count(self._h)
        cdef size_t i
        cdef uv_vector_vertex vertex
        result = []
        for i in range(count):
            if uv_mesh_vertex_get(self._h, i, &vertex) != 0:
                raise RuntimeError("mesh changed while reading vertices")
            result.append(((vertex.position.x, vertex.position.y),
                           vertex.coverage))
        return tuple(result)

    @property
    def indices(self):
        cdef size_t count = uv_mesh_index_count(self._h)
        cdef size_t i
        cdef unsigned int index
        result = []
        for i in range(count):
            if uv_mesh_index_get(self._h, i, &index) != 0:
                raise RuntimeError("mesh changed while reading indices")
            result.append(index)
        return tuple(result)

    @property
    def triangle_count(self):
        return uv_mesh_index_count(self._h) // 3

cdef class Image:
    """An RGBA8 raster surface. The library owns the handle; freed on GC."""
    cdef uv_image _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            uv_image_free(self._h)
            self._h = NULL

    @staticmethod
    cdef Image _wrap(uv_image h):
        # __new__ bypasses __init__ (which needs width/height and would
        # uv_image_new a throwaway handle, leaking it); __cinit__ zeroes _h.
        cdef Image r = Image.__new__(Image)
        r._h = h
        return r

    def __init__(self, int width, int height):
        if width <= 0 or height <= 0:
            raise ValueError("width and height must be positive")
        self._h = uv_image_new(width, height)
        if self._h == NULL:
            raise MemoryError("uv_image_new returned NULL")

    @property
    def width(self):
        return uv_image_width(self._h)

    @property
    def height(self):
        return uv_image_height(self._h)

    @property
    def channels(self):
        return uv_image_channels(self._h)

    def pixels(self):
        """The pixel buffer as bytes (a copy). RGBA8, row-major."""
        cdef unsigned char* out = NULL
        cdef size_t out_len = 0
        rc = uv_image_pixels(self._h, &out, &out_len)
        if rc != 0:
            raise ValueError(f"pixels failed: {strerror(rc)}")
        if out == NULL or out_len == 0:
            return b""
        return bytes(<unsigned char[:out_len]>out)

    def encode_png(self):
        """Encode as PNG bytes."""
        cdef unsigned char* out = NULL
        cdef size_t out_len = 0
        rc = uv_image_encode_png(self._h, &out, &out_len)
        if rc != 0:
            raise ValueError(f"encode_png failed: {strerror(rc)}")
        try:
            return bytes(<unsigned char[:out_len]>out)
        finally:
            uv_buffer_free(out, out_len)

    def fill(self, Path path not None, Color color not None,
             int winding=WINDING_NON_ZERO,
             float tol=0.0, int blend=BLEND_NORMAL):
        """Solid-fill `path` with `color` onto this image."""
        rc = uv_fill_path(self._h, path._h, color._h, winding, tol, blend)
        if rc != 0:
            raise ValueError(f"fill failed: {strerror(rc)}")

    def fill_prepared(self, PreparedPath path not None, Color color not None,
                      int winding=WINDING_NON_ZERO,
                      int blend=BLEND_NORMAL):
        """Solid-fill prepared geometry without flattening it again."""
        rc = uv_fill_prepared_path(
            self._h, path._h, color._h, winding, blend)
        if rc != 0:
            raise ValueError(f"fill_prepared failed: {strerror(rc)}")


cdef class Color:
    """A color (tagged space; the ABI exposes sRGB construction)."""
    cdef uv_color _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            uv_color_free(self._h)
            self._h = NULL

    @staticmethod
    cdef Color _wrap(uv_color h):
        # __new__ keeps the factories uniform with Path/Image and bypasses
        # Python-level initialization; Color has no public constructor.
        cdef Color r = Color.__new__(Color)
        r._h = h
        return r

    @staticmethod
    def parse(str s):
        """Parse a CSS Color 4 string (hex/rgb/oklch/...)."""
        cdef bytes b = s.encode("utf-8")
        h = uv_color_parse(<const char*>b)
        if h == NULL:
            raise ValueError(f"color parse failed: {s!r}")
        return Color._wrap(h)

    @staticmethod
    def rgba(float r, float g, float b, float a=1.0):
        """sRGB color from straight-alpha floats in [0, 1]."""
        h = uv_color_rgba(r, g, b, a)
        if h == NULL:
            raise ValueError("color rgba out of gamut / non-finite")
        return Color._wrap(h)

    def to_svg(self):
        """The SVG color string (#rrggbb[aa])."""
        cdef char* out = NULL
        cdef size_t out_len = 0
        rc = uv_color_to_svg(self._h, &out, &out_len)
        if rc != 0:
            raise ValueError(f"to_svg failed: {strerror(rc)}")
        try:
            return bytes(out[:out_len]).decode("ascii")
        finally:
            uv_buffer_free(out, out_len)
