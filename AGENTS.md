# asyncapi-cable

## Project Overview

An npm CLI + library that generates typed [AnyCable](https://docs.anycable.io) channel clients from an **AsyncAPI 3.0** document — the "Orval for cable". Emits a platform-agnostic core (channel classes + message types depending only on `@anycable/core`, usable on web and React Native) plus a thin framework preset (Vue composables or React hooks).

## Development

```bash
pnpm install
pnpm test          # node --test
```

Node and pnpm versions are pinned in `.tool-versions` (managed with [mise](https://mise.jdx.dev)/asdf); pnpm is also pinned via the `packageManager` field for corepack. Plain ESM, no build step and no transpile — the published files are the source.

## Architecture

Small surface, three files:

- `src/index.mjs` — the generator library and programmatic API (`generateOne`, `generateAll`, plus exported pure helpers)
- `src/index.d.mts` — hand-written type declarations for the public API (`CableConfig`, `CableTarget`, etc.)
- `bin/cli.mjs` — CLI: resolves a `cable.config.mjs` from the cwd and calls `generateAll`

Per-target pipeline (in `generateOne`, output dir is wiped then rebuilt):

1. `parseDocument` — `@asyncapi/parser` reads/validates the AsyncAPI 3.0 doc
2. `generateModels` → `models/*.ts` — `@asyncapi/modelina` emits payload interfaces + enums. `stripConditionals` drops `if`/`then`/`else` (Modelina mis-flattens the `then` branch); `tidyModelSource`/`dedupeUnions` clean the output. Wire keys are kept **snake_case** (payloads aren't transformed on the socket path)
3. `generateChannels` → `channels/*.ts` + `composables/*.ts` — one `Channel<Params, Message>` subclass per `receive` operation, plus a per-channel wrapper. Reads the `x-actioncable-channel` and `x-client-supplied` extensions
4. `renderRuntime` → `runtime.ts` — the preset's subscribe/lifecycle helper; the **only** file that imports the cable seam
5. `writeBarrel` → `index.ts` — re-exports everything

**Presets** — `output.preset` (default `vue`) selects the runtime + wrapper shape: `vue` emits composables (`onScopeDispose`), `react` emits hooks (`useEffect`). Only the runtime + wrapper differ; channel classes and models are shared across presets.

**The cable seam** — `output.cable` (`{ path, name }`) is the one configurable import inside `runtime.ts` (Orval-mutator style). It points at the consuming app's file that exports the AnyCable instance getter. Falls back to `DEFAULT_CABLE` when omitted.

## Testing

- `test/generate.test.mjs` — a `node:test` suite: unit tests for the pure helpers (`stripConditionals`, `dedupeUnions`, `clientParamsType`, `renderChannelClass`, `renderComposable`) plus an end-to-end `generateOne` into a throwaway tmp dir asserting on the emitted files
- `test/fixtures/cable_fixture.yaml` — a minimal AsyncAPI 3.0 cable doc exercising params, enums, the `x-` extensions, and an `if`/`then` conditional
- Run with `pnpm test` (`node --test`)

## Style

- Plain ESM (`.mjs`), Node >= 20 — no build/transpile step
- Formatting follows Prettier defaults: double-quoted strings, trailing commas
- Generated files always carry the AUTO-GENERATED `BANNER`
- Keep the generator dependency-light — `@asyncapi/parser` + `@asyncapi/modelina` are the only runtime deps; everything AnyCable/framework-specific is a peer dependency of the consuming app

## Commits

- Use [Conventional Commits](https://www.conventionalcommits.org/) — release-please generates the CHANGELOG from commit messages
- Prefixes: `feat:` (→ minor), `fix:` (→ patch), `docs:`, `chore:`, `refactor:`, `test:`

## Releasing

Automated with [release-please](https://github.com/googleapis/release-please) + npm [Trusted Publishing](https://docs.npmjs.com/trusted-publishers) (GitHub Actions OIDC — no stored `NPM_TOKEN`). See the "Releasing" section in the README for the flow and one-time bootstrap.

## Dependencies

- `@asyncapi/parser ~> 3.6` — parse/validate the AsyncAPI document
- `@asyncapi/modelina ~> 5.10` — TypeScript model generation
- Peer (installed by the consuming app): `@anycable/core >= 1.1`, plus `vue >= 3.4` (vue preset) or `react >= 18` (react preset)
