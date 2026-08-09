<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniVector book

The executable book introduces 2D coordinates, SVG path commands, Bézier
curves, adaptive flattening, winding rules, antialiasing, and alpha
compositing. It targets a motivated secondary-school student or an early
university reader: each idea is connected to a small Nim example before the C
and Python façades are introduced.

Build and execute every example from the repository root:

```text
nimble book
```

The generated page is `book/index.html`. `nimble docs` combines it with the
API reference under `pages/`.
