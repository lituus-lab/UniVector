<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: Contracts, errors, and generated artifacts

- Status: Accepted
- Date: 2026-08-10
- Scope: UniVector

## Contracts

Domain restrictions in the Nim core use NimContracts `require` and `ensure`
clauses. Preconditions document caller obligations and are checked in debug
builds; the implementation still validates untrusted values at the C boundary
because contract checks compile away under `-d:release`. Postconditions are
cheaper than their bodies and do not call the routine under contract.

The C ABI catches `CatchableError` and `Defect` and maps failures to status
codes, null handles, or documented sentinel values. Python turns those results
into `ValueError`, `MemoryError`, or `RuntimeError`.

## Generated artifacts

Compiled libraries, extension modules, coverage output, generated HTML, wheel
contents, and `_nimsrc` are ignored. `setup.py sdist` generates `_nimsrc` and a
Cython C source while assembling the source archive; neither is a maintained
source file in Git.
