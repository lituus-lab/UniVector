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
import std/[os, strutils]
import UniVector/common
import UniVector/path
import UniVector/flatten
import UniVector/raster
import UniVector/svg
export common
export path
export flatten
export raster
export svg

func manifestVersion(text: string): string {.compileTime.} =
  for line in text.splitLines:
    let fields = line.split('=', 1)
    if fields.len == 2 and fields[0].strip == "version":
      return fields[1].strip.strip(chars = {'"'})
  raise newException(ValueError, "UniVector.nimble has no version")

const UniVectorVersion* = manifestVersion(staticRead(
  currentSourcePath.parentDir.parentDir / "UniVector.nimble"))
