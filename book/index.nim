# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniVector

nbInit(theme = useNimibook)
useLituus()
nb.title = "UniVector"

nbText: """
# UniVector: paths, curves, and pixels

Vector graphics describe *geometry* rather than storing one color per pixel.
A path says “move here, draw a line there, then follow this curve.” UniVector
keeps that description as long as possible, and turns it into pixels only when
asked to rasterize.

Every Nim block in this guide is compiled and executed by `nimble book`. The
guide therefore tests the API it teaches.
"""

nbSave
