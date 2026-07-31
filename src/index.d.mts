// Type declarations for the plain-JS cable client generator, so TS consumers
// get a typed public API.

export type CablePreset = "vue" | "react";

export interface CableMutator {
  path: string;
  name: string;
}

export interface CableTarget {
  /** Path to a local AsyncAPI 3.0 document, or an http(s) URL to fetch it from. */
  input: string;
  output: { target: string; cable?: CableMutator; preset?: CablePreset };
}

export type CableConfig = Record<string, CableTarget>;

export interface AsyncapiDocumentJson {
  components?: { schemas?: Record<string, unknown> };
  [key: string]: unknown;
}

export interface ChannelParametersJson {
  parameters?: Record<
    string,
    { "x-client-supplied"?: boolean; [key: string]: unknown }
  >;
  [key: string]: unknown;
}

export function isRemoteInput(input: string): boolean;
export function stripConditionals<T extends AsyncapiDocumentJson>(json: T): T;
export function dedupeUnions(source: string): string;
export function tidyModelSource(source: string): string;
export function clientParamsType(channelJson: ChannelParametersJson): string;

export function renderChannelClass(opts: {
  channelName: string;
  identifier: string;
  paramsType: string;
  messageNames: string[];
}): { className: string; dataType: string; paramsName: string; source: string };

export function renderComposable(opts: {
  channelName: string;
  className: string;
  dataType: string;
  paramsName: string;
  hasParams: boolean;
}): { composableName: string; source: string };

export function generateOne(opts: {
  input: string;
  outDir: string;
  cable?: CableMutator;
  preset?: CablePreset;
  cwd?: string;
}): Promise<void>;

export function generateAll(config: CableConfig, cwd?: string): Promise<void>;
