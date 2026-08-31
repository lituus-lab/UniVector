# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import nimib, nimibook
import lituus_theme
import UniVector

nbInit(theme = useNimibook)
useLituus()
nb.title = "Exercises"

nbText: """
## Exercises

1. Reverse the inner rectangle of the ring and compare NonZero with EvenOdd.
2. Flatten the same cubic with tolerances `4`, `1`, and `0.1`; count the
   segments and explain the difference.
3. Build a circle from four cubic curves, inspect its bounds, and compare it
   with `Path.circle`.
4. Parse a path containing relative commands, append a line, and predict the
   final current point before printing it.
"""

nbSave

nbSave
