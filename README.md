# asyncapi-cable

Generate typed [AnyCable](https://docs.anycable.io) channel clients from an
**AsyncAPI 3.0** document — the "Orval for cable". Produces platform-agnostic
channel classes + message types (usable on web *and* React Native) plus a thin,
framework-specific wrapper (Vue composables or React hooks).

## Install

```bash
npm i -D asyncapi-cable
# the generated code imports these in the consuming app:
npm i @anycable/core        # + vue (vue preset) or react (react preset)
```

## Usage

Add a `cable.config.mjs` (analog of `orval.config.ts`):

```js
export default {
  cableInternalV1: {
    input: "asyncapi/cable_internal.yaml",
    output: {
      target: "src/services/cableInternalV1",
      // the "mutator": a file exporting your AnyCable instance getter
      cable: { path: "../cableClient", name: "getCable" },
      preset: "vue", // or "react"
    },
  },
};
```

Then run:

```bash
npx asyncapi-cable -c cable.config.mjs
```

## What it emits

```
<output.target>/
  models/*.ts        message payload types + enums (via @asyncapi/modelina)
  channels/*.ts      class XChannel extends Channel<Params, Message>
                     — depends ONLY on @anycable/core (web + React Native)
  runtime.ts         the preset's subscribe/lifecycle helper — the ONLY file
                     importing your cable mutator (output.cable)
  composables/*.ts   per-channel useXChannel(handlers)  (Vue composable / React hook)
  index.ts           barrel
```

The channel classes and message types are **shared across presets**; only
`runtime.ts` and the per-channel wrapper differ (`vue` → composable with
`onScopeDispose`; `react` → hook with `useEffect`).

### The cable mutator

`output.cable` points at a file in your app that exports the AnyCable instance
(the one seam the generated code imports), e.g.:

```ts
// src/cableClient.ts
import { createCable } from "@anycable/web"; // or @anycable/core in React Native
let cable;
export function getCable() {
  return (cable ??= createCable(/* url */));
}
```

## Document extensions

The generator reads two vendor extensions from the AsyncAPI document:

- `x-actioncable-channel` on a channel → the Rails channel class name used as
  the AnyCable `static identifier`.
- `x-client-supplied: false` on a parameter → server-derived, so it's omitted
  from the channel's client-supplied params.

## Programmatic API

```js
import { generateAll, generateOne } from "asyncapi-cable";
await generateAll(config, process.cwd());
```

## Requirements

Node >= 20. AsyncAPI 3.0 input.
