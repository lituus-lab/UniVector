# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniVector

nbInit(theme = useNimibook)
useLituus()
nb.title = "C and Python"

nbText: """
## C and Python

The C ABI exposes the same path commands, command inspection, curve
evaluation, flattening, bounds, fill, SVG, and PNG operations. C callers must
invoke `uv_init()` exactly once before any other ABI function. Python owns the
native handles automatically and converts returned buffers into Python strings,
bytes, tuples, and lists.
"""

nbSave
