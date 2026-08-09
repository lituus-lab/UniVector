// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/*
 * UniVector.h — C ABI for the UniVector vector-graphics engine
 *
 * A pure-Nim vector-graphics engine exposed to C: build a Path (or parse an
 * SVG `d` string), solid-fill it with a Color onto an RGBA8 image, and emit
 * SVG output. PNG encoding rides UniImage.
 *
 * Lifecycle:
 *   - Call uv_init() before any other function. Repeated calls are harmless;
 *     externally synchronise the first call.
 *   - Handles are opaque. The library owns them; release with the matching
 *     uv_path_free / uv_image_free / uv_color_free (NULL is a no-op).
 *   - uv_path_to_d / uv_path_to_svg / uv_color_to_svg / uv_image_encode_png
 *     allocate a buffer the caller frees with uv_buffer_free. uv_image_pixels
 *     *borrows* the image buffer (valid until uv_image_free) and must NOT be
 *     freed with uv_buffer_free.
 *
 * Thread-safety:
 *   - uv_init() is required once before use. A single handle must not be used
 *     concurrently from multiple threads without external synchronisation.
 *
 * Error model:
 *   - Functions returning int return a uv_status. No exception or fault from
 *     the Nim core crosses this boundary.
 *
 * ABI stability:
 *   - UNIVECTOR_ABI_VERSION is bumped on incompatible changes; check it at
 *     runtime with uv_abi_version().
 */
#ifndef UNIVECTOR_H
#define UNIVECTOR_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define UNIVECTOR_VERSION_MAJOR 1
#define UNIVECTOR_VERSION_MINOR 0
#define UNIVECTOR_VERSION_PATCH 0
#define UNIVECTOR_VERSION "1.0.0"

#define UNIVECTOR_VERSION_AT_LEAST(ma, mi, pa) \
  ((UNIVECTOR_VERSION_MAJOR > (ma)) || \
   (UNIVECTOR_VERSION_MAJOR == (ma) && UNIVECTOR_VERSION_MINOR > (mi)) || \
   (UNIVECTOR_VERSION_MAJOR == (ma) && UNIVECTOR_VERSION_MINOR == (mi) && \
    UNIVECTOR_VERSION_PATCH >= (pa)))

#define UNIVECTOR_ABI_VERSION 1

typedef enum {
  UV_OK         = 0, /* success */
  UV_ERR_FORMAT = 2, /* bad arg / nil handle / unparseable `d` / bad color */
  UV_ERR_UNSUP  = 4, /* unsupported operation (reserved) */
  UV_ERR_MEM    = 8  /* allocation failed */
} uv_status;

/* Fill winding rule. */
typedef enum {
  UV_WINDING_NON_ZERO = 0, /* default */
  UV_WINDING_EVEN_ODD = 1
} uv_winding;

typedef enum {
  UV_BLEND_NORMAL = 0,
  UV_BLEND_OVERWRITE = 1
} uv_blend_mode;

typedef enum {
  UV_PATH_CLOSE = 0,
  UV_PATH_MOVE,
  UV_PATH_LINE,
  UV_PATH_HLINE,
  UV_PATH_VLINE,
  UV_PATH_CUBIC,
  UV_PATH_SMOOTH_CUBIC,
  UV_PATH_QUADRATIC,
  UV_PATH_SMOOTH_QUADRATIC,
  UV_PATH_ARC,
  UV_PATH_REL_MOVE,
  UV_PATH_REL_LINE,
  UV_PATH_REL_HLINE,
  UV_PATH_REL_VLINE,
  UV_PATH_REL_CUBIC,
  UV_PATH_REL_SMOOTH_CUBIC,
  UV_PATH_REL_QUADRATIC,
  UV_PATH_REL_SMOOTH_QUADRATIC,
  UV_PATH_REL_ARC
} uv_path_command_kind;

typedef struct { float x, y; } uv_vec2;
typedef struct { float x, y, w, h; } uv_rect;
typedef struct { uv_vec2 at, to; } uv_segment;
typedef struct {
  int kind;
  float params[7];
} uv_path_command;

/* uv_path_command.params layout:
 * CLOSE: none; MOVE/LINE and relative variants: x,y; HLINE/VLINE and relative
 * variants: value; CUBIC variants: x1,y1,x2,y2,x3,y3; SMOOTH_CUBIC and
 * QUADRATIC variants: x1,y1,x2,y2; SMOOTH_QUADRATIC variants: x,y; ARC and
 * REL_ARC: rx,ry,rotation,large_arc,sweep,x,y. Arc rotation is in radians;
 * large_arc and sweep are stored as 0.0f or 1.0f.
 */

#define UNIVECTOR_FLATTEN_TOLERANCE 0.5f
#define UNIVECTOR_MAX_FLATTEN_DEPTH 18
#define UNIVECTOR_MAX_FLATTEN_SEGMENTS 1048576
#define UNIVECTOR_SUPERSAMPLE 4
#define UNIVECTOR_GEOMETRIC_EPSILON 0.00031415927f

/* Opaque handles. */
typedef struct uv_path_handle* uv_path;
typedef struct uv_image_handle* uv_image;
typedef struct uv_color_handle* uv_color;

/* --- lifecycle --- */
void        uv_init(void);
int         uv_abi_version(void);
const char* uv_strerror(int code);
const char* uv_version(void);

/* --- path --- */
uv_path uv_path_new(void);
uv_path uv_path_copy(uv_path src);
int     uv_path_move_to(uv_path h, float x, float y);
int     uv_path_line_to(uv_path h, float x, float y);
int     uv_path_bezier_curve_to(uv_path h, float x1, float y1,
                                float x2, float y2, float x3, float y3);
int     uv_path_quadratic_curve_to(uv_path h, float x1, float y1,
                                   float x2, float y2);
/* rotation is in radians. */
int     uv_path_elliptical_arc_to(uv_path h, float rx, float ry, float rotation,
                                  int large_arc, int sweep, float x, float y);
int     uv_path_rect(uv_path h, float x, float y, float w, float hgt,
                     int clockwise);
int     uv_path_rounded_rect(uv_path h, float x, float y, float w, float hgt,
                             float nw, float ne, float se, float sw,
                             int clockwise);
int     uv_path_ellipse(uv_path h, float cx, float cy, float rx, float ry);
int     uv_path_circle(uv_path h, float cx, float cy, float r);
int     uv_path_polygon(uv_path h, float x, float y, float size, int sides);
int     uv_path_close_path(uv_path h);
int     uv_path_add_path(uv_path h, uv_path other);
/* Canvas-style circular arc and tangent arc. a0/a1 are radians; negative
 * radii are rejected. */
int     uv_path_arc(uv_path h, float x, float y, float radius,
                    float a0, float a1, int counterclockwise);
int     uv_path_arc_to(uv_path h, float x1, float y1, float x2, float y2,
                       float radius);
int     uv_path_current(uv_path h, uv_vec2* out_point);
int     uv_path_start(uv_path h, uv_vec2* out_point);
size_t  uv_path_command_count(uv_path h);
int     uv_path_command_get(uv_path h, size_t index,
                            uv_path_command* out_command);
/* Return -1 for an invalid command kind. */
int     uv_path_command_is_relative(int kind);
int     uv_path_command_parameter_count(int kind);
/* Parse an SVG `d` string. On success stores a handle in *out_handle (free
 * with uv_path_free); on failure clears it and returns UV_ERR_FORMAT. */
int     uv_path_parse_d(const char* s, uv_path* out_handle);
/* Serialise to an SVG `d` string (NUL-terminated; free with uv_buffer_free).
 * *out_len is the string length (excludes the NUL). */
int     uv_path_to_d(uv_path h, char** out_str, size_t* out_len);
void    uv_path_free(uv_path h);

/* Evaluate a Bézier at t in [0, 1]. */
int     uv_quad_point(uv_vec2 p0, uv_vec2 control, uv_vec2 p1, float t,
                      uv_vec2* out_point);
int     uv_cubic_point(uv_vec2 p0, uv_vec2 control1, uv_vec2 control2,
                       uv_vec2 p1, float t, uv_vec2* out_point);
/* Writes at most capacity segments and always returns the full required count.
 * Call first with out_segments=NULL and capacity=0 to size the buffer. */
int     uv_path_flatten(uv_path h, float tolerance, uv_segment* out_segments,
                        size_t capacity, size_t* out_count);
int     uv_segments_bounds(const uv_segment* segments, size_t count,
                           uv_rect* out_bounds);

/* --- image --- */
/* A zeroed (transparent) RGBA8 image. NULL on bad dimensions or allocation
 * failure. */
uv_image uv_image_new(int width, int height);
int      uv_image_width(uv_image h);
int      uv_image_height(uv_image h);
int      uv_image_channels(uv_image h);
/* Borrow the pixel buffer (no copy). *out_ptr is valid until uv_image_free;
 * do NOT free it with uv_buffer_free. Empty image -> *out_ptr = NULL,
 * *out_len = 0, UV_OK. */
int      uv_image_pixels(uv_image h, unsigned char** out_ptr, size_t* out_len);
/* Encode as PNG. On success allocates *out_data (free with uv_buffer_free). */
int      uv_image_encode_png(uv_image h, unsigned char** out_data,
                             size_t* out_len);
void     uv_image_free(uv_image h);

/* --- color --- */
/* Parse a CSS Color 4 string (hex/rgb/oklch/...). NULL on a nil string or
 * unparseable input. */
uv_color uv_color_parse(const char* s);
/* sRGB color from straight-alpha floats in [0, 1]. NULL on out-of-gamut /
 * non-finite input. */
uv_color uv_color_rgba(float r, float g, float b, float a);
void     uv_color_free(uv_color h);

/* --- raster --- */
/* Solid-fill `path` with `color` onto `img` (RGBA8 straight alpha). `winding`
 * is UV_WINDING_*, `blend` is UV_BLEND_*, and `tol <= 0` uses the default
 * flattening tolerance. */
int      uv_fill_path(uv_image img, uv_path path, uv_color color,
                      int winding, float tol, int blend);

/* --- svg --- */
/* Wrap the path's `d` string in an <svg> document with `color` and the canvas
 * size (NUL-terminated; free with uv_buffer_free). */
int      uv_path_to_svg(uv_path path, uv_color color, int width, int height,
                        char** out_str, size_t* out_len);
/* The SVG color string for `color` (#rrggbb[aa]; NUL-terminated; free with
 * uv_buffer_free). */
int      uv_color_to_svg(uv_color color, char** out_str, size_t* out_len);

/* --- buffer --- */
/* Free a buffer from uv_path_to_d / uv_path_to_svg / uv_color_to_svg /
 * uv_image_encode_png. NULL is a no-op. `len` is ignored. Do NOT use on
 * uv_image_pixels. */
void     uv_buffer_free(void* buffer, size_t len);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* UNIVECTOR_H */
