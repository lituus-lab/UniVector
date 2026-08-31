<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# The Book

A nimibook table of contents, one chapter per file. Every code block is
compiled and run when the book is built, so prose that outlives its API breaks
the build rather than quietly misleading a reader.

| File | What it is |
|---|---|
| `nbook.nim` | the table of contents and the theme selection — the driver |
| `nimib.toml` | nimib's own configuration, read from this directory |
| `config.nims` | the paths each chapter's own compilation needs |
| `index.nim` | what the library is, and coordinates |
| `paths.nim` | the command stream, Bézier curves, and flattening |
| `prepared.nim` | preparing geometry once, and expanding strokes |
| `raster.nim` | tessellation, crossings, winding, and compositing |
| `surfaces.nim` | C and Python |
| `exercises.nim` | problems to work through |

Each chapter is its own program, so nothing carries between them: `prepared.nim`
and `raster.nim` rebuild the curve `paths.nim` introduced rather than reaching
for a name no longer in scope.

## Building it

```bash
build/unigate book     # the book alone
build/unigate docs     # book + generated API reference, into pages/
```

Through the gate, never `nimble book` directly: nimble exits 0 even when an
`exec` inside a task fails, so a green run that went through it proves nothing.

`book` runs nimibook's `init` before `build`. `init` is what creates
`__site/assets`, which is not tracked: without it every page ships referencing
a stylesheet and a script that are not there.

## Adding a chapter

Add the entry to `nbook.nim`'s table of contents, then `nimble bookInit`
scaffolds the missing source.

Each chapter calls `nbInit(theme = useNimibook)` itself and then `useLituus()`.
`nbInit` cannot be wrapped: it reads `instantiationInfo(-1)` to learn which
file it is documenting. A Markdown entry never runs any Nim, so it never gets
the theme — keep every chapter a `.nim`.
