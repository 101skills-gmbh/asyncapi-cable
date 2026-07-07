// Type declarations for the plain-JS cable client generator, so TS consumers
// get a typed public API.

export type CablePreset = "vue" | "react";

export interface CableMutator {
  path: string;
  name: string;
}

export interface CableTarget {
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
