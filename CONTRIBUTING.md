<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Contributing

## License

Apache-2.0 (`LICENSE`).

## DCO

Every commit signs off the [Developer Certificate of Origin](https://developercertificate.org/):

```bash
git commit -s
```

Commits without a `Signed-off-by` trailer are not accepted.

## Conventional commits

Commit subjects and the PR title follow [Conventional Commits 1.0](https://www.conventionalcommits.org/):

```text
<type>(scope)!: <description>
```

`type` is one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
`build`, `ci`, `chore`, `revert`, `bump`. `scope` and `!` (breaking change) are
optional. A space separates the colon from the description.

```git
feat(path): add a path operation
fix(c_api): reject a negative radius
docs: explain winding rules
feat(core)!: change a path command layout
```

The `commitizen` CI job validates the PR title. The title matters because a
squash-merge folds the whole PR into one commit whose subject is the title.

## Workflow

1. Branch from `main`, one logical change per commit.
2. Pass the local gates:

   ```bash
   nimble install -y
   nimble testAll      # Nim debug + release + C ABI
   nimble univector    # build the CLI
   nimble example
   nimble cexample
   nimble pyTest
   nimble pyWheel
   nimble pySdist
   nimble bench
   nimble coverage     # needs lcov and genhtml
   nimble docs         # needs Nim's doc tools and nimib
   nimble checkVGraph
   ```

   `nimble lint` runs via pre-commit (see below). `testAll` alone is not
   sufficient — it skips examples, Python packaging, benchmarks, the CLI,
   coverage, docs, and the layer DAG. `nimble docs` requires a complete Nim
   distribution containing `nim doc`; run `nimble docsDeps` to install nimib.
3. Open a PR; CI runs the 3-OS Nim, C ABI, and Python matrices plus lint,
   vgraph, docs, and coverage.

## Pre-commit

Some CI checks run locally via [pre-commit](https://pre-commit.com):

```bash
pip install pre-commit
pre-commit install
```

`pre-commit install` sets up the pre-commit, pre-push and commit-msg hooks at
once. Hooks: hygiene (trailing whitespace, EOF, yaml/toml, large files),
`nimble lint` on `*.nim`, `nimble checkVGraph` before push, Conventional Commits
via `cz check` on the commit message, and a DCO sign-off check. Run everything
manually:

```bash
pre-commit run --all-files
```

## Conventions

See `ADRs/0004` and `AGENTS.md`. English comments, terse, describe what is done.
NimContracts compile away under `-d:release`; the C ABI validates its own
inputs and maps failures to status codes instead of raising across the boundary.
