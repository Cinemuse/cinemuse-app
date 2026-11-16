import { bucket, type BucketDeps, readFile, writeFile } from "./bucket.ts";
import {
  type Channel,
  channels,
  guideSources,
  linkServices,
  type Stream,
} from "./channels.ts";
import { buildGuide, dueSource, type Guide, sourceChannels } from "./guide.ts";
import { type ReadDeps, type ReadResult, readSource } from "./readers.ts";

export interface Deps extends BucketDeps, ReadDeps {
  channels?: Channel[];
}

export function defaultDeps(): Deps {
  return {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    fetch: globalThis.fetch,
    now: () => new Date(),
  };
}

const playlistFile = "playlist.m3u";
const guideFile = "epg.json";

/** POST (the hourly `refresh-live-tv` job): writes `livetv/playlist.m3u`
 * when the channel list changed, and refreshes the guide source most
 * overdue, if any, into `livetv/epg.json`. One source per call keeps it
 * inside a call's CPU limit. It takes no input, so it needs no sign-in
 * (`verify_jwt = false`): a caller can only make it do work already due.
 * Apps read the files at their public bucket addresses. */
export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return text(405, "Only POST");
  try {
    const playlist = await refreshPlaylist(deps);
    const guide = await refreshGuide(deps);
    return json(200, { playlist, ...guide });
  } catch (e) {
    console.error("Live TV refresh failed", e);
    return text(502, e instanceof Error ? e.message : String(e));
  }
}

async function refreshPlaylist(deps: Deps): Promise<"written" | "same"> {
  const body = buildM3u(deps.channels ?? channels, deps.supabaseUrl);
  if (await readFile(deps, playlistFile) === body) return "same";
  await writeFile(
    deps,
    playlistFile,
    body,
    "application/vnd.apple.mpegurl; charset=utf-8",
    300,
  );
  return "written";
}

async function refreshGuide(deps: Deps) {
  const now = deps.now();
  const oldBody = await readFile(deps, guideFile);
  let old: Guide | null = null;
  if (oldBody != null) {
    try {
      old = JSON.parse(oldBody);
    } catch (e) {
      // Started again from nothing: it fills back in a day.
      console.warn("The old guide isn't JSON", e);
    }
  }
  const source = dueSource(old, now);
  if (source == null) return { source: null };

  const list = deps.channels ?? channels;
  let result: ReadResult;
  try {
    result = await readSource(
      { key: source, ...guideSources[source] },
      sourceChannels(source, list),
      deps,
    );
  } catch (e) {
    // The whole source failed: its channels keep what the file has.
    result = { rows: [], failed: [e instanceof Error ? e.message : String(e)] };
  }
  if (result.failed.length > 0) {
    console.warn(`Guide source ${source}: ${result.failed.join("; ")}`);
  }
  const guide = buildGuide(old, source, result, now, list);
  await writeFile(
    deps,
    guideFile,
    JSON.stringify(guide),
    "application/json; charset=utf-8",
    1800,
  );
  return { source, programmes: result.rows.length, failed: result.failed };
}

/** The playlist: standard M3U, by channel number, one line per stream,
 * best first: apps merge lines with the same name into one channel and
 * move to the next stream when one fails. Each line names its source
 * (`provider`); a stream from an "ask" link service gets
 * `cinemuse-ask="<broadcaster>"`: its address answers with the real stream
 * address, which the device asks for at play time. Channels with no stream
 * are in the guide only. */
export function buildM3u(list: Channel[], supabaseUrl: string): string {
  const lines = ["#EXTM3U"];
  const sorted = list.filter((ch) => ch.streams.length > 0).sort((a, b) =>
    (a.lcn ?? Infinity) - (b.lcn ?? Infinity) || a.name.localeCompare(b.name)
  );
  for (const ch of sorted) {
    const attrs = [`tvg-id="${ch.key}"`];
    if (ch.lcn != null) attrs.push(`tvg-chno="${ch.lcn}"`);
    attrs.push(`tvg-name="${attr(ch.name)}"`);
    if (ch.logo !== "") {
      attrs.push(
        `tvg-logo="${supabaseUrl}/storage/v1/object/public/${bucket}/logos/` +
          `${encodeURIComponent(ch.logo)}"`,
      );
    }
    if (ch.category !== "") attrs.push(`group-title="${attr(ch.category)}"`);
    for (const stream of ch.streams) {
      const { url, provider, ask } = streamLine(stream);
      const own = [`provider="${attr(provider)}"`];
      if (ask != null) own.push(`cinemuse-ask="${ask}"`);
      lines.push(`#EXTINF:-1 ${[...attrs, ...own].join(" ")},${ch.name}`, url);
    }
  }
  return lines.join("\n") + "\n";
}

function streamLine(stream: Stream) {
  if (stream[0] === "url") {
    return { url: stream[1], provider: stream[2], ask: null };
  }
  const service = linkServices[stream[0]];
  return {
    url: service.address.replaceAll("{id}", encodeURIComponent(stream[1])),
    provider: service.provider,
    ask: service.ask,
  };
}

function attr(value: string): string {
  return value.replaceAll('"', "'");
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function text(status: number, message: string): Response {
  return new Response(message, { status });
}
