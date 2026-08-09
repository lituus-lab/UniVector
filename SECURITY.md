<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Security Policy

Report vulnerabilities via GitHub private vulnerability reporting (Security
tab → "Report a vulnerability"), not via a public issue. Include: description
+ impact, minimal reproducer, affected version (`UniVectorVersion`).

Only the latest released line is supported.

## Surface

- `parsePath`, `uv_path_parse_d`, and `Path.parse_d` accept untrusted SVG path
  data. Malformed commands, invalid arc flags/radii, and non-finite numbers are
  rejected. These functions do not parse XML or arbitrary SVG documents.
- Flattening rejects output beyond `MaxFlattenSegments`, including through the
  C and Python façades, to bound amplification from untrusted path data.
- The rasterizer writes only through a validated RGBA8 `UniImage` surface.
- C callers must call `uv_init()` exactly once before any other ABI function.
- Handles are not safe for concurrent mutation; callers provide external
  synchronization when sharing an object across threads.
- Native builds use `-d:release`, not `-d:danger`, so bounds and overflow checks
  remain available as a boundary backstop.
