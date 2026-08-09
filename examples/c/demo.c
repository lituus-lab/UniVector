// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 lituus-lab
/* demo.c — minimal C consumer of the uv_* ABI. Build a rect path, solid-fill
 * it onto an RGBA8 image, encode PNG, and print the version, image dims, PNG
 * byte count, the SVG color string, and the path's `d` string. A demo prints;
 * it does not assert. Build/run via `nimble cexample`. */
#include <stdio.h>
#include "UniVector.h"

int main(void) {
  uv_init();

  printf("UniVector %s (ABI v%d)\n", uv_version(), uv_abi_version());

  uv_path p = uv_path_new();
  if (p == NULL) {
    fprintf(stderr, "uv_path_new failed\n");
    return 1;
  }
  if (uv_path_rect(p, 10.0f, 10.0f, 80.0f, 80.0f, 0) != UV_OK) {
    fprintf(stderr, "uv_path_rect failed\n");
    uv_path_free(p);
    return 1;
  }

  uv_color col = uv_color_parse("#3366cc");
  if (col == NULL) {
    fprintf(stderr, "uv_color_parse failed\n");
    uv_path_free(p);
    return 1;
  }

  uv_image img = uv_image_new(64, 64);
  if (img == NULL) {
    fprintf(stderr, "uv_image_new failed\n");
    uv_color_free(col);
    uv_path_free(p);
    return 1;
  }
  printf("image  %dx%d, %d channels\n", uv_image_width(img),
         uv_image_height(img), uv_image_channels(img));

  if (uv_fill_path(img, p, col, UV_WINDING_NON_ZERO, 0,
                   UV_BLEND_NORMAL) != UV_OK) {
    fprintf(stderr, "uv_fill_path failed\n");
    uv_image_free(img);
    uv_color_free(col);
    uv_path_free(p);
    return 1;
  }

  int rc = 0;

  unsigned char* png = NULL;
  size_t png_len = 0;
  if (uv_image_encode_png(img, &png, &png_len) == UV_OK && png != NULL) {
    printf("png    %zu bytes, signature %02x%02x%02x%02x\n", png_len,
           png[0], png[1], png[2], png[3]);
    uv_buffer_free(png, png_len);
  } else {
    fprintf(stderr, "uv_image_encode_png failed\n");
    rc = 1;
  }

  char* svgcol = NULL;
  size_t svgcol_len = 0;
  if (uv_color_to_svg(col, &svgcol, &svgcol_len) == UV_OK && svgcol != NULL) {
    printf("svg    color %s\n", svgcol);
    uv_buffer_free(svgcol, svgcol_len);
  } else {
    fprintf(stderr, "uv_color_to_svg failed\n");
    rc = 1;
  }

  char* d = NULL;
  size_t d_len = 0;
  if (uv_path_to_d(p, &d, &d_len) == UV_OK && d != NULL) {
    printf("d      %s\n", d);
    uv_buffer_free(d, d_len);
  } else {
    fprintf(stderr, "uv_path_to_d failed\n");
    rc = 1;
  }

  uv_image_free(img);
  uv_color_free(col);
  uv_path_free(p);
  return rc;
}
