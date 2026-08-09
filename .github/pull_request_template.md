<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
## What changes, and why

<!-- The problem, then the fix. Link the issue if there is one. -->

## AI assistance

<!-- Optional disclosure — not a gate. The DCO sign-off is the accountability
     mechanism; the human contributor owns the change either way. -->
- [ ] I used AI/LLM assistance for this change

If yes, I have reviewed the output, ensured it introduces no third-party code
without a compatible license/attribution, and can stand behind it.

## Checks

- [ ] Every commit carries `Signed-off-by:` (`git commit -s`) — the DCO job blocks otherwise
- [ ] Commits and this PR title follow Conventional Commits — the `commitizen` job blocks otherwise
- [ ] Commits are atomic (one logical change each; several per PR is fine, but not one monolithic commit)
- [ ] `nimble install -y` passes (deps resolve)
- [ ] `nimble testAll` passes
- [ ] `nimble univector` builds the CLI
- [ ] `nimble example` and `nimble cexample` pass
- [ ] `nimble pyTest`, `nimble pyWheel`, and `nimble pySdist` pass
- [ ] `nimble bench` passes
- [ ] `nimble lint` and `nimble checkVGraph` pass
- [ ] `nimble coverage` passes (when sources changed)
- [ ] `nimble docs` passes (when public API/book changed)
- [ ] C ABI touched → `include/UniVector.h` updated in the same commit (1b)
- [ ] Public API touched → `book/index.nim` still builds and describes it
