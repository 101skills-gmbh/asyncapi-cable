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
const SERVER_FIXTURE = join(import.meta.dirname, "fixtures", "server_param_fixture.yaml");

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

test("clientParamsType treats a channel with no parameters as empty", () => {
  assert.equal(clientParamsType({}), "Record<string, never>");
  assert.equal(clientParamsType({ parameters: {} }), "Record<string, never>");
  assert.equal(clientParamsType(undefined), "Record<string, never>");
});

test("clientParamsType joins multiple client params", () => {
  assert.equal(
    clientParamsType({ parameters: { board_id: {}, tab_id: { description: "x" } } }),
    "{ board_id: string; tab_id: string }"
  );
});

test("clientParamsType keeps only client params when mixed with server-derived", () => {
  assert.equal(
    clientParamsType({
      parameters: {
        user_id: { "x-client-supplied": false },
        board_id: { description: "client picks the board" },
      },
    }),
    "{ board_id: string }"
  );
});

test("renderChannelClass emits Record<string, never> for a server-derived channel", () => {
  const { source, paramsName } = renderChannelClass({
    channelName: "UserPing",
    identifier: "UserPingChannel",
    paramsType: "Record<string, never>",
    messageNames: ["UserPingMessage"],
  });
  assert.equal(paramsName, "UserPingParams");
  assert.ok(source.includes("export type UserPingParams = Record<string, never>;"));
  assert.ok(source.includes("export class UserPingChannel extends Channel<UserPingParams, UserPingData>"));
});

test("renderComposable (vue) omits the params arg when a channel has none", () => {
  const { source } = renderComposable({
    channelName: "UserPing",
    className: "UserPingChannel",
    dataType: "UserPingData",
    paramsName: "UserPingParams",
    hasParams: false,
    preset: "vue",
  });
  assert.ok(!source.includes("params:"));
  assert.ok(source.includes("subscribeChannel(new UserPingChannel(), handlers)"));
});

test("renderComposable (react) omits the params arg when a channel has none", () => {
  const { source } = renderComposable({
    channelName: "UserPing",
    className: "UserPingChannel",
    dataType: "UserPingData",
    paramsName: "UserPingParams",
    hasParams: false,
    preset: "react",
  });
  assert.ok(!source.includes("params:"));
  assert.ok(source.includes("useChannelSubscription(() => new UserPingChannel(), handlers)"));
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

test("server-derived channel generates a param-free composable end to end", async () => {
  await withGenerated({ input: SERVER_FIXTURE }, (read) => {
    const channel = read("channels/UserPingChannel.ts");
    assert.ok(channel.includes("export type UserPingParams = Record<string, never>;"));
    assert.ok(channel.includes('static identifier = "UserPingChannel";'));

    const composable = read("composables/useUserPingChannel.ts");
    assert.ok(!composable.includes("params:"));
    assert.ok(composable.includes("subscribeChannel(new UserPingChannel(), handlers)"));
  });
});
