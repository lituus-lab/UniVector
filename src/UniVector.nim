# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniVector — vector-graphics engine for the lituus-lab Uni* family.
##
## Nim surface: leaf types (`common`), path construction + parse/$
## (`path`), curve flattening (`flatten`), solid-fill anti-aliased rasterizer
## onto `UniImage`'s `Image[uint8]` (`raster`), and minimal SVG *output*
## (`svg`). The `uv_*` C ABI (`c_api`) exposes this surface to C and Python.
## The public surface is paths, curve flattening, solid-fill rasterization,
## and SVG output.
import UniVector/common
import UniVector/path
import UniVector/flatten
import UniVector/prepared
import UniVector/stroke
import UniVector/mesh
import UniVector/raster
import UniVector/svg
export common
export path
export flatten
export prepared
export stroke
export mesh
export raster
export svg

const UniVectorVersion* = "1.0.0"
