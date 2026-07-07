import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

import {
  clientParamsType,
  dedupeUnions,
  generateOne,
  renderChannelClass,
  renderComposable,
  stripConditionals,
  tidyModelSource,
} from "../src/index.mjs";

const FIXTURE = join(import.meta.dirname, "fixtures", "cable_fixture.yaml");

/** Run the generator into a throwaway dir and hand the reader to `fn`. */
async function withGenerated(opts, fn) {
  const outDir = mkdtempSync(join(tmpdir(), "asyncapi-cable-"));
  try {
    await generateOne({ input: FIXTURE, outDir, ...opts });
    await fn((rel) => readFileSync(join(outDir, rel), "utf8"));
  } finally {
    rmSync(outDir, { recursive: true, force: true });
  }
}

test("stripConditionals removes if/then so status stays a plain string", () => {
  const doc = {
    components: {
      schemas: {
        Msg: {
          type: "object",
          allOf: [
            {
              if: { required: ["exception"] },
              then: { properties: { status: { const: "failed" } } },
            },
          ],
        },
      },
    },
  };
  assert.equal(stripConditionals(doc).components.schemas.Msg.allOf, undefined);
});

test("dedupeUnions collapses repeated union members", () => {
  assert.equal(
    dedupeUnions("  record_id?: string | null | number | null | null;"),
    "  record_id?: string | null | number;"
  );
});

test("tidyModelSource rewrites additionalProperties + type-only exports", () => {
  const tidied = tidyModelSource(
    "interface X {\n  additionalProperties?: Record<string, any>;\n}\nexport { X };"
  );
  assert.ok(tidied.includes("[key: string]: unknown;"));
  assert.ok(tidied.includes("export type { X };"));
});

test("clientParamsType excludes server-derived params", () => {
  assert.equal(
    clientParamsType({ parameters: { widget_id: { description: "x" } } }),
    "{ widget_id: string }"
  );
  assert.equal(
    clientParamsType({ parameters: { user_id: { "x-client-supplied": false } } }),
    "Record<string, never>"
  );
});

test("renderChannelClass emits a portable @anycable/core class", () => {
  const { source } = renderChannelClass({
    channelName: "WidgetStatus",
    identifier: "Widgets::WidgetStatusChannel",
    paramsType: "{ widget_id: string }",
    messageNames: ["WidgetStatusMessage", "WidgetActionMessage"],
  });
  assert.ok(source.includes('import { Channel } from "@anycable/core";'));
  assert.ok(
    source.includes(
      "export class WidgetStatusChannel extends Channel<WidgetStatusParams, WidgetStatusData>"
    )
  );
  assert.ok(source.includes('static identifier = "Widgets::WidgetStatusChannel";'));
  assert.ok(!source.includes("@/"));
});

test("renderComposable (vue) delegates to subscribeChannel", () => {
  const { source } = renderComposable({
    channelName: "WidgetStatus",
    className: "WidgetStatusChannel",
    dataType: "WidgetStatusData",
    paramsName: "WidgetStatusParams",
    hasParams: true,
    preset: "vue",
  });
  assert.ok(source.includes('from "../runtime";'));
  assert.ok(source.includes("subscribeChannel(new WidgetStatusChannel(params), handlers)"));
});

test("vue preset: snake_case types, portable class, seam only in runtime", async () => {
  await withGenerated({}, (read) => {
    const message = read("models/WidgetStatusMessage.ts");
    assert.ok(message.includes("widget_id: string;"));
    assert.ok(message.includes("status: string;"));
    assert.ok(!message.includes("'failed'"));

    const channel = read("channels/WidgetStatusChannel.ts");
    assert.ok(channel.includes('import { Channel } from "@anycable/core";'));
    assert.ok(channel.includes('static identifier = "Widgets::WidgetStatusChannel";'));

    const runtime = read("runtime.ts");
    assert.ok(runtime.includes('import { getCable } from "../internalCableClient";'));

    const composable = read("composables/useWidgetStatusChannel.ts");
    assert.ok(!composable.includes("getCable"));
  });
});

test("configured cable mutator drives runtime.ts", async () => {
  await withGenerated(
    { cable: { path: "@/some/customCable", name: "acquireCable" } },
    (read) => {
      const runtime = read("runtime.ts");
      assert.ok(runtime.includes('import { acquireCable } from "@/some/customCable";'));
      assert.ok(runtime.includes("acquireCable().subscribe(channel)"));
    }
  );
});

test("react preset: React hook runtime + shared portable class", async () => {
  await withGenerated({ preset: "react" }, (read) => {
    const runtime = read("runtime.ts");
    assert.ok(runtime.includes('import { useEffect, useRef } from "react";'));
    assert.ok(runtime.includes("export function useChannelSubscription<C extends Channel>("));
    assert.ok(runtime.includes('import type { Channel } from "@anycable/core";'));
    assert.ok(!runtime.includes("onScopeDispose"));

    const hook = read("composables/useWidgetStatusChannel.ts");
    assert.ok(hook.includes('import { useChannelSubscription, type ChannelHandlers } from "../runtime";'));
    assert.ok(hook.includes("useChannelSubscription(() => new WidgetStatusChannel(params), handlers);"));

    // The channel class is identical to the vue preset.
    assert.ok(
      read("channels/WidgetStatusChannel.ts").includes('import { Channel } from "@anycable/core";')
    );
  });
});
