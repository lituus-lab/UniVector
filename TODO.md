<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniVector roadmap

This roadmap extends the 1.0 path and raster engine toward SVG 2 document
support and additional 2D and 3D vector formats. Format modules must share
scene primitives and reuse the existing Uni* engines rather than duplicate
geometry, color, image, compression, or typography code.

## Current boundary

UniVector 1.0 reads and writes SVG path data (`d`) and can emit a minimal
standalone document containing one solid-filled path. It does not currently
read SVG XML or represent a complete vector scene.

## Shared scene model

Build the format-independent representation before adding document parsers.

- [ ] Define document and scene roots with dimensions, units, coordinate
  systems, metadata, resources, and an explicit 2D or 3D domain.
- [ ] Define 2D nodes for groups, paths, rectangles, circles, ellipses, lines,
  polylines, polygons, images, text, definitions, and reusable nodes.
- [ ] Define 3D primitives separately: points, curves, surfaces, meshes,
  cameras, lights, materials, instances, and scene hierarchy.
- [ ] Use UniLinalg for 2D and 3D transformations, projections, and transformed
  geometry.
- [ ] Use UniColor for colors, interpolation, gradients, gamut mapping, and
  color serialization.
- [ ] Use UniImage for embedded raster images and image encoding/decoding.
- [ ] Integrate text and glyph outlines through UniGlyph when that engine is
  available; do not implement a second font engine here.
- [ ] Represent fills, strokes, opacity, clipping, masks, compositing, and
  winding rules independently of any file format.
- [ ] Define a timeline model for animated properties, keyframes, easing,
  repetition, synchronization, and motion paths.
- [ ] Define explicit unsupported-feature errors instead of silently dropping
  scene content.
- [ ] Expose every public scene operation consistently through Nim, C, and
  Python.

## SVG document reading

- [ ] Select or implement a bounded XML reader suitable for untrusted input.
- [ ] Reject DTDs and external entities; do not access files or the network
  while parsing.
- [ ] Parse the root viewport: `width`, `height`, units, `viewBox`, and
  `preserveAspectRatio`.
- [ ] Parse path and basic-shape elements: `path`, `rect`, `circle`, `ellipse`,
  `line`, `polyline`, and `polygon`.
- [ ] Parse nested groups and affine `transform` lists in the specified order.
- [ ] Resolve presentation attributes, inline style, inherited properties, and
  the supported CSS cascade.
- [ ] Parse solid fills, strokes, line caps, joins, miter limits, dash arrays,
  fill rules, paint order, and opacity.
- [ ] Parse `defs`, `use`, fragment references, and detect reference cycles.
- [ ] Parse linear and radial gradients, spread methods, gradient transforms,
  and inherited gradient definitions.
- [ ] Parse clipping paths, masks, markers, patterns, and filter primitives.
- [ ] Parse declarative SVG animation: `animate`, `animateTransform`,
  `animateMotion`, `set`, timing attributes, key times, spline easing, repeats,
  and synchronization references.
- [ ] Parse CSS transitions, keyframes, and animated presentation properties
  covered by the selected SVG 2/CSS profile.
- [ ] Preserve scripts and event attributes only as inert document data when
  round-trip mode requests it; never execute them in the parser or renderer.
- [ ] Parse embedded and linked images under an explicit resource-loading
  policy with byte and dimension limits.
- [ ] Parse text only after UniGlyph provides shaping, font selection, and
  glyph outlines with deterministic fallback behavior.
- [ ] Preserve unknown elements and attributes when round-trip fidelity is
  requested, or reject them in strict mode.
- [ ] Bound XML depth, node count, attribute size, path commands, references,
  decoded resources, and flattened geometry.

## SVG document writing

- [ ] Serialize the shared scene tree, not hand-built XML fragments.
- [ ] Escape XML text and attributes correctly and emit deterministic UTF-8.
- [ ] Write canonical path data without losing finite numeric precision.
- [ ] Serialize shapes, groups, transforms, styles, strokes, gradients,
  definitions, clipping, masks, patterns, images, and text supported by the
  scene model.
- [ ] Serialize declarative animation and CSS animation from the shared
  timeline model without converting timing units or easing curves implicitly.
- [ ] Generate stable identifiers and deduplicate reusable definitions.
- [ ] Support compact and pretty-printed output without semantic differences.
- [ ] Support standalone documents and embeddable SVG fragments.
- [ ] Define semantic round trips: `read(write(scene))` must preserve the scene;
  `write(read(svg))` need not preserve whitespace or attribute order.
- [ ] Add SVGZ read/write by wrapping the same SVG reader and writer with a
  gzip layer that enforces compressed- and expanded-size limits.

## Rendering and conformance

- [ ] Cache flattened segments and bounds in immutable prepared paths.
- [x] Expand strokes with butt, round, and square caps and miter, round, and
  bevel joins.
- [x] Tessellate fills and strokes into validated renderer-neutral indexed
  triangle meshes.
- [ ] Expose prepared paths and meshes consistently through Nim, C, and Python.
- [ ] Benchmark preparation reuse, stroke expansion, fill tessellation, stroke
  tessellation, and prepared raster filling with deterministic workloads.
- [ ] Apply transforms before flattening without losing the requested error
  tolerance.
- [ ] Add stroke dash arrays and marker placement.
- [ ] Add gradient and pattern sampling with explicit color-space behavior.
- [ ] Add clipping, masking, group opacity, and compositing in the correct
  order.
- [ ] Render a document at an explicit time and test interpolation before,
  during, and after each animation interval.
- [ ] Publish an SVG 2 support matrix covering elements, attributes, CSS,
  animation, linking, filters, scripting preservation, and rendering.
- [ ] Keep scripts, DOM events, and active external content disabled during
  decoding and rendering. Any executable-script feature requires its own ADR,
  threat model, sandbox, and opt-in API.
- [ ] Build conformance fixtures from the SVG specification and permitted W3C
  test material, with provenance recorded for every fixture.
- [ ] Add semantic round-trip tests and pixel comparisons against independent
  renderers with documented tolerances.
- [ ] Add fuzzing for XML, path data, styles, transforms, references, and
  resource limits across Nim, C, and Python entry points.

## Other vector formats

Add formats only after the shared scene model can express their semantics.

### Initial interchange formats

- [ ] **TinyVG** — implement its bounded binary reader and writer against the
  shared 2D scene model.
- [ ] **PDF output** — deterministic single-page vector output first, followed
  by multiple pages, fonts, images, transparency, and archival profiles.
- [ ] **SVGZ** — compressed SVG using the same reader and writer, with strict
  decompression limits.
- [ ] **EPS/PostScript output** — implement paths, fills, strokes, affine
  transforms, clipping, text outlines, and embedded raster images.

### 2D and animated interchange formats

- [ ] **HP-GL/2** — import and export pen-plotter geometry, with an explicit
  mapping from pens to UniColor.
- [ ] **CGM** — write an ADR selecting the required ISO profile and mapping its
  graphical primitives before implementation.
- [ ] **Lottie** — map layers, transforms, keyframes, easing, masks, and shape
  animations to the shared timeline model; reject unsupported After Effects
  extensions explicitly.

### 3D and CAD formats

- [ ] **DXF** — define a versioned import/export profile covering units, layers,
  blocks, 2D entities, 3D entities, and unsupported records, then implement it
  against the corresponding scene primitives.
- [ ] **glTF/GLB** — map scene hierarchy, meshes, materials, textures, cameras,
  skins, and animation to the 3D scene and timeline models.
- [ ] **OBJ/MTL** — support indexed polygon meshes, normals, texture
  coordinates, materials, and deterministic triangulation where required.
- [ ] **STL and PLY** — support bounded mesh import/export with explicit unit,
  color, normal, and metadata policies.
- [ ] **3MF** — map units, meshes, components, materials, textures, and build
  items while applying archive and decompression limits.
- [ ] **STEP and IGES** — define a CAD geometry layer for curves, NURBS,
  surfaces, topology, assemblies, and units before implementing either parser.

### Formats requiring a scoped decision

- [ ] **PDF input** — write an ADR defining supported page objects, fonts,
  transparency, forms, annotations, and embedded resources separately from the
  PDF writer.
- [ ] **WMF/EMF** — require portable specifications, bounded record parsing,
  and malicious-file fixtures before accepting an implementation plan.
- [ ] **AI/CDR** — require a documented, legally usable format specification;
  otherwise document conversion through an open interchange format instead of
  claiming native support.

## Release criteria for each format

- [ ] Nim implementation is the only engine; C and Python are complete façades.
- [ ] Contracts describe public preconditions and inexpensive postconditions.
- [ ] Malformed input returns documented errors without partial success.
- [ ] Resource limits are enforced before allocation or decompression.
- [ ] Reader, writer, semantic round-trip, interoperability, animation, and
  fuzz tests pass for the features declared in the format support matrix.
- [ ] The book teaches supported behavior without presenting planned features
  as available.
- [ ] Format scope and known exclusions are explicit in the README and API docs.
