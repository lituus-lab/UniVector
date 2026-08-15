// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/*
 * test_univector.c — self-contained C ABI smoke test (no external fixture).
 * Exercises path construction + fill, parse_d/to_d round-trip, SVG output,
 * PNG encode, NULL-safety, and bad input. Build/run via `nimble ctest`.
 */
/* Keep the asserts active even if this TU is built with -DNDEBUG (a copied
 * Makefile, a CI matrix variant, or a downstream consumer). A test that prints
 * "OK" without exercising the ABI is worse than no test. */
#undef NDEBUG
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include "UniVector.h"

int main(void) {
  uv_init();

  assert(uv_abi_version() == UNIVECTOR_ABI_VERSION);
  assert(strcmp(uv_version(), UNIVECTOR_VERSION) == 0);
  assert(strcmp(uv_strerror(UV_OK), "ok") == 0);

  /* NULL-safety: benign returns, no crash. */
  uv_path_free(NULL);
  uv_prepared_path_free(NULL);
  uv_mesh_free(NULL);
  uv_image_free(NULL);
  uv_color_free(NULL);
  uv_buffer_free(NULL, 0);
  assert(uv_image_width(NULL) == 0);
  assert(uv_image_height(NULL) == 0);
  assert(uv_image_channels(NULL) == 0);
  assert(uv_path_copy(NULL) == NULL);
  assert(uv_image_new(0, 4) == NULL);
  assert(uv_image_new(4, 0) == NULL);
  assert(uv_color_parse(NULL) == NULL);

  /* Bad arguments: rejected, out-handle cleared. */
  uv_path bad = (uv_path)1;
  assert(uv_path_parse_d(NULL, &bad) == UV_ERR_FORMAT);
  assert(bad == NULL);
  assert(uv_fill_path(NULL, NULL, NULL, 0, 0, UV_BLEND_NORMAL) ==
         UV_ERR_FORMAT);

  /* Build a 4x4 rect path, fill with #3366cc, and check a covered pixel. */
  uv_path p = uv_path_new();
  assert(p != NULL);
  assert(uv_path_rect(p, 0, 0, 4, 4, 1) == UV_OK);
  assert(uv_path_move_to(NULL, 0, 0) == UV_ERR_FORMAT);
  assert(uv_path_command_count(p) == 5);
  uv_path_command first = {0};
  assert(uv_path_command_get(p, 0, &first) == UV_OK);
  assert(first.kind == UV_PATH_MOVE);
  assert(first.params[0] == 0.0f && first.params[1] == 0.0f);
  assert(uv_path_command_is_relative(UV_PATH_REL_LINE) == 1);
  assert(uv_path_command_parameter_count(UV_PATH_CUBIC) == 6);
  uv_vec2 current = {0};
  assert(uv_path_current(p, &current) == UV_OK);
  assert(current.x == 0.0f && current.y == 0.0f);

  size_t segment_count = 0;
  assert(uv_path_flatten(p, 0.0f, NULL, 0, &segment_count) == UV_OK);
  assert(segment_count == 4);
  uv_segment segments[4];
  uv_segment short_segments[2] = {0};
  size_t required = 0;
  assert(uv_path_flatten(p, 0.0f, short_segments, 2, &required) == UV_OK);
  assert(required == 4);
  assert(uv_path_flatten(p, 0.0f, segments, 4, &segment_count) == UV_OK);
  uv_rect bounds = {0};
  assert(uv_segments_bounds(segments, segment_count, &bounds) == UV_OK);
  assert(bounds.x == 0.0f && bounds.y == 0.0f);
  assert(bounds.w == 4.0f && bounds.h == 4.0f);
  uv_prepared_path prepared = uv_path_prepare(p, 0.25f);
  assert(prepared != NULL);
  assert(uv_prepared_path_segment_count(prepared) == 4);
  assert(uv_prepared_path_tolerance(prepared) == 0.25f);
  uv_segment prepared_segment = {0};
  assert(uv_prepared_path_segment_get(prepared, 0, &prepared_segment) == UV_OK);
  uv_rect prepared_bounds = {0};
  assert(uv_prepared_path_bounds(prepared, &prepared_bounds) == UV_OK);
  assert(prepared_bounds.w == 4.0f && prepared_bounds.h == 4.0f);
  uv_path stroked = uv_prepared_path_stroke(
      prepared, 2.0f, UV_CAP_ROUND, UV_JOIN_BEVEL,
      UNIVECTOR_DEFAULT_MITER_LIMIT);
  assert(stroked != NULL);
  assert(uv_path_command_count(stroked) > 0);
  uv_path_free(stroked);
  uv_mesh mesh = uv_prepared_path_tessellate_fill(
      prepared, UV_WINDING_NON_ZERO);
  assert(mesh != NULL);
  assert(uv_mesh_vertex_count(mesh) == 4);
  assert(uv_mesh_index_count(mesh) == 6);
  uv_vector_vertex mesh_vertex = {0};
  assert(uv_mesh_vertex_get(mesh, 0, &mesh_vertex) == UV_OK);
  assert(mesh_vertex.coverage == 1.0f);
  uint32_t mesh_index = UINT32_MAX;
  assert(uv_mesh_index_get(mesh, 0, &mesh_index) == UV_OK);
  assert(mesh_index < uv_mesh_vertex_count(mesh));
  uv_mesh_free(mesh);
  uv_mesh stroke_mesh = uv_prepared_path_tessellate_stroke(
      prepared, 2.0f, UV_CAP_BUTT, UV_JOIN_MITER,
      UNIVECTOR_DEFAULT_MITER_LIMIT);
  assert(stroke_mesh != NULL);
  assert(uv_mesh_index_count(stroke_mesh) > 0);
  uv_mesh_free(stroke_mesh);
  uv_prepared_path_free(prepared);

  uv_vec2 midpoint = {0};
  uv_vec2 p0 = {0.0f, 0.0f};
  uv_vec2 pc = {1.0f, 1.0f};
  uv_vec2 p1 = {2.0f, 0.0f};
  assert(uv_quad_point(p0, pc, p1, 0.5f, &midpoint) == UV_OK);
  assert(midpoint.x == 1.0f && midpoint.y == 0.5f);
  assert(uv_quad_point(p0, pc, p1, NAN, &midpoint) == UV_ERR_FORMAT);
  uv_color col = uv_color_parse("#3366cc");
  assert(col != NULL);
  uv_image img = uv_image_new(4, 4);
  assert(img != NULL);
  assert(uv_image_width(img) == 4);
  assert(uv_image_height(img) == 4);
  assert(uv_image_channels(img) == 4);
  assert(uv_fill_path(img, p, col, UV_WINDING_NON_ZERO, 0,
                      UV_BLEND_NORMAL) == UV_OK);
  /* An out-of-range winding is rejected, not silently treated as NonZero. */
  assert(uv_fill_path(img, p, col, 999, 0, UV_BLEND_NORMAL) == UV_ERR_FORMAT);
  assert(uv_fill_path(img, p, col, UV_WINDING_NON_ZERO, 0, 999) ==
         UV_ERR_FORMAT);

  unsigned char* px = NULL;
  size_t px_len = 0;
  assert(uv_image_pixels(img, &px, &px_len) == UV_OK);
  assert(px != NULL && px_len == 4 * 4 * 4);
  /* Interior pixel (1,1): full coverage -> exact solid sRGB, opaque. */
  unsigned char* c11 = px + ((1 * 4) + 1) * 4;
  assert(c11[0] == 0x33);
  assert(c11[1] == 0x66);
  assert(c11[2] == 0xcc);
  assert(c11[3] == 0xff);

  /* Encode to PNG: a non-empty buffer with the PNG signature. */
  unsigned char* png = NULL;
  size_t png_len = 0;
  assert(uv_image_encode_png(img, &png, &png_len) == UV_OK);
  assert(png != NULL && png_len > 8);
  assert(png[0] == 0x89 && png[1] == 'P' && png[2] == 'N' && png[3] == 'G');
  uv_buffer_free(png, png_len);

  /* The SVG color string for #3366cc is upper-case 6-digit. */
  char* svgcol = NULL;
  size_t svgcol_len = 0;
  assert(uv_color_to_svg(col, &svgcol, &svgcol_len) == UV_OK);
  assert(svgcol != NULL);
  assert(strcmp(svgcol, "#3366CC") == 0);
  uv_buffer_free(svgcol, svgcol_len);

  /* The full SVG document wraps the path's `d` string. */
  char* svg = NULL;
  size_t svg_len = 0;
  assert(uv_path_to_svg(p, col, 4, 4, &svg, &svg_len) == UV_OK);
  assert(svg != NULL && svg_len > 0);
  assert(strncmp(svg, "<svg", 4) == 0);
  assert(strstr(svg, "<path d=\"") != NULL);
  assert(strstr(svg, "fill=\"#3366CC\"") != NULL);
  uv_buffer_free(svg, svg_len);

  uv_image_free(img);
  uv_color_free(col);

  /* parse_d / to_d round-trip a representative `d` string. */
  uv_path q = NULL;
  assert(uv_path_parse_d("M 0 0 L 10 0 L 10 10 Z", &q) == UV_OK);
  assert(q != NULL);
  char* d = NULL;
  size_t d_len = 0;
  assert(uv_path_to_d(q, &d, &d_len) == UV_OK);
  assert(d != NULL && d_len > 0);
  assert(strncmp(d, "M 0 0", 5) == 0);
  assert(strstr(d, "L 10 0") != NULL);
  assert(d[d_len] == '\0'); /* NUL-terminated */
  uv_buffer_free(d, d_len);

  /* Unparseable `d` is rejected with the out-handle cleared. */
  uv_path bad2 = (uv_path)1;
  assert(uv_path_parse_d("M 0 0 X 1 2", &bad2) == UV_ERR_FORMAT);
  assert(bad2 == NULL);

  /* uv_color_rgba builds an opaque sRGB color and fills with it. */
  uv_color red = uv_color_rgba(1.0f, 0.0f, 0.0f, 1.0f);
  assert(red != NULL);
  assert(uv_color_rgba(NAN, 0.0f, 0.0f, 1.0f) == NULL);
  assert(uv_color_rgba(-0.1f, 0.0f, 0.0f, 1.0f) == NULL);
  assert(uv_color_rgba(1.1f, 0.0f, 0.0f, 1.0f) == NULL);
  uv_image tiny = uv_image_new(2, 2);
  assert(tiny != NULL);
  uv_path rp = uv_path_new();
  assert(rp != NULL);
  assert(uv_path_rect(rp, 0, 0, 2, 2, 1) == UV_OK);
  assert(uv_fill_path(tiny, rp, red, UV_WINDING_EVEN_ODD, 0,
                      UV_BLEND_NORMAL) == UV_OK);
  unsigned char* tpx = NULL;
  size_t tpx_len = 0;
  assert(uv_image_pixels(tiny, &tpx, &tpx_len) == UV_OK);
  assert(tpx[0] == 0xff && tpx[1] == 0x00 && tpx[2] == 0x00 && tpx[3] == 0xff);
  uv_path_free(rp);
  uv_color_free(red);
  uv_image_free(tiny);

  uv_path_free(p);
  uv_path_free(q);

  uv_path curves = uv_path_new();
  assert(curves != NULL);
  assert(uv_path_arc(curves, 0, 0, 10, 0, 3.14159265f, 0) == UV_OK);
  assert(uv_path_arc_to(curves, 10, 0, 10, 10, 2) == UV_OK);
  assert(uv_path_arc(curves, 0, 0, -1, 0, 1, 0) == UV_ERR_FORMAT);
  assert(uv_path_circle(curves, 0, 0, -1) == UV_ERR_FORMAT);
  assert(uv_path_polygon(curves, 0, 0, 1, 2) == UV_ERR_FORMAT);
  uv_path_free(curves);

  printf("test_univector: OK\n");
  return 0;
}
