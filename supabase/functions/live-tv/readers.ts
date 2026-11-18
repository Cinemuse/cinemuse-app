/** The guide readers: each turns one kind of source into programmes. The
 * addresses come from `guideSources` (`channels.ts`), with `{id}`, `{date}`,
 * `{from}`, `{to}`, `{env}` and `{page}` filled here. */

import { browserUserAgent } from "./channels.ts";

export interface Programme {
  /** The source's own channel id. */
  ref: string;
  /** ISO times. */
  start: string;
  stop: string;
  title: string;
  subtitle?: string;
  description?: string;
  image?: string;
}

/** A channel as one source knows it (a channel's `guide`, `channels.ts`). */
export interface SourceChannel {
  id: string;
  /** Sky only: the channel list it is in, `DTT` or `DTH`. */
  env?: string;
}

export interface GuideSource {
  key: string;
  reader: string;
  address: string;
}

export interface ReadDeps {
  fetch: typeof fetch;
  now: () => Date;
}

/** The programmes read, and the channels that failed (with why). */
export interface ReadResult {
  rows: Programme[];
  failed: string[];
}

/** Calls at once per source: enough to finish well inside a function call,
 * few enough not to look like an attack. */
const parallelCalls = 6;

const hour = 3_600_000;

export async function readSource(
  source: GuideSource,
  channels: SourceChannel[],
  deps: ReadDeps,
): Promise<ReadResult> {
  if (source.reader === "xmltv") return await readXmltv(source, channels, deps);
  const read = channelReaders[source.reader];
  if (read == null) throw new Error(`Unknown reader ${source.reader}`);

  const result: ReadResult = { rows: [], failed: [] };
  await eachLimited(channels, parallelCalls, async (channel) => {
    try {
      const rows = await read(source.address, channel, deps);
      if (rows.length === 0) throw new Error("no programmes");
      result.rows.push(...rows);
    } catch (e) {
      result.failed.push(
        `${channel.id}: ${e instanceof Error ? e.message : e}`,
      );
    }
  });
  return result;
}

type ChannelReader = (
  address: string,
  channel: SourceChannel,
  deps: ReadDeps,
) => Promise<Programme[]>;

const channelReaders: Record<string, ChannelReader> = {
  rai: readRai,
  mediaset: readMediaset,
  sky: readSky,
  discovery: readDiscovery,
};

// --- RaiPlay: one call per channel per day, today + 6 days (Italian dates).

const raiDays = 7;

async function readRai(
  address: string,
  channel: SourceChannel,
  deps: ReadDeps,
): Promise<Programme[]> {
  const today = romeDate(deps.now());
  const rows: Programme[] = [];
  let lastError: unknown;
  for (let i = 0; i < raiDays; i++) {
    const day = new Date(Date.UTC(today.y, today.m - 1, today.d + i));
    const date = `${pad(day.getUTCDate())}-${pad(day.getUTCMonth() + 1)}-` +
      `${day.getUTCFullYear()}`;
    try {
      const body = await getJson(
        fill(address, { id: channel.id, date }),
        deps,
      );
      rows.push(...raiProgrammes(channel.id, body));
    } catch (e) {
      // The last days are often not out yet: what came before still counts.
      lastError = e;
    }
  }
  if (rows.length === 0 && lastError != null) throw lastError;
  return rows;
}

/** One RaiPlay day file: Italian date and time, and a duration. */
export function raiProgrammes(ref: string, body: unknown): Programme[] {
  const events = (body as { events?: unknown[] })?.events;
  if (!Array.isArray(events)) throw new Error("no events list");
  const rows: Programme[] = [];
  for (const e of events as Record<string, unknown>[]) {
    const date = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(String(e.date ?? ""));
    const time = /^(\d{2}):(\d{2})$/.exec(String(e.hour ?? ""));
    const length = /^(\d{2}):(\d{2}):(\d{2})$/.exec(String(e.duration ?? ""));
    const title = text(e.name);
    if (date == null || time == null || length == null || title == null) {
      continue;
    }
    const start = romeToUtc(
      Number(date[3]),
      Number(date[2]),
      Number(date[1]),
      Number(time[1]),
      Number(time[2]),
    );
    const seconds = Number(length[1]) * 3600 + Number(length[2]) * 60 +
      Number(length[3]);
    if (seconds <= 0) continue;
    const image = text(e.image);
    rows.push({
      ref,
      start: start.toISOString(),
      stop: new Date(start.getTime() + seconds * 1000).toISOString(),
      title,
      subtitle: text(e.episode_title),
      description: text(e.description),
      image: image == null
        ? undefined
        : image.startsWith("/")
        ? `https://www.raiplay.it${image}`
        : image,
    });
  }
  return rows;
}

// --- Mediaset: one channel, at most 39 hours per call.

const mediasetWindowHours = 36;
const mediasetWindows = 5;

async function readMediaset(
  address: string,
  channel: SourceChannel,
  deps: ReadDeps,
): Promise<Programme[]> {
  // From a few hours ago, so the programme on now is included.
  const first = deps.now().getTime() - 6 * hour;
  const rows: Programme[] = [];
  for (let i = 0; i < mediasetWindows; i++) {
    const from = first + i * mediasetWindowHours * hour;
    const to = from + mediasetWindowHours * hour;
    const body = await getJson(
      fill(address, { id: channel.id, from: String(from), to: String(to) }),
      deps,
    );
    rows.push(...mediasetProgrammes(channel.id, body));
  }
  return rows;
}

/** One Mediaset answer: times in milliseconds (UTC). A period with nothing
 * planned yet comes without an entries list. */
export function mediasetProgrammes(ref: string, body: unknown): Programme[] {
  const entries = (body as { response?: { entries?: unknown[] } })?.response
    ?.entries ?? [];
  const rows: Programme[] = [];
  for (const entry of entries as { listings?: unknown[] }[]) {
    for (const l of (entry.listings ?? []) as Record<string, unknown>[]) {
      const program = (l.program ?? {}) as Record<string, unknown>;
      const thumbs = (program.thumbnails ?? {}) as Record<
        string,
        { url?: unknown }
      >;
      // Mediaset ends some titles with " -".
      const title = text(l["mediasetlisting$epgTitle"] ?? program.title)
        ?.replace(/\s*-$/, "");
      const start = Number(l.startTime);
      const stop = Number(l.endTime);
      if (!title || !(stop > start)) continue;
      rows.push({
        ref,
        start: new Date(start).toISOString(),
        stop: new Date(stop).toISOString(),
        title,
        description: text(l.description ?? program.description),
        image: text(
          thumbs.image_horizontal_cover?.url ??
            thumbs.image_keyframe_poster?.url,
        ),
      });
    }
  }
  return rows;
}

// --- Sky's guide: one channel per call, in pages.

const skyDays = 9;
const skyPageSize = 500;
const skyMaxPages = 5;

async function readSky(
  address: string,
  channel: SourceChannel,
  deps: ReadDeps,
): Promise<Programme[]> {
  const now = deps.now().getTime();
  const from = new Date(now - 6 * hour).toISOString().slice(0, 19) + "Z";
  const to = new Date(now + skyDays * 24 * hour).toISOString().slice(0, 19) +
    "Z";
  const rows: Programme[] = [];
  for (let page = 0; page < skyMaxPages; page++) {
    const body = await getJson(
      fill(address, {
        id: channel.id,
        env: channel.env ?? "DTH",
        from,
        to,
        page: String(page),
      }),
      deps,
    );
    const events = (body as { events?: unknown[] })?.events;
    if (!Array.isArray(events)) throw new Error("no events list");
    rows.push(...skyProgrammes(channel.id, body));
    if (events.length < skyPageSize) break;
  }
  return rows;
}

/** One page of Sky's guide: times in UTC. An episode's `eventTitle` often
 * lacks the show ("Ep.43", "Malta"); its `epgEventTitle` ("S2 Ep43 -
 * Foodish 1^TV") always names it, so an episode is titled by its show. */
export function skyProgrammes(ref: string, body: unknown): Programme[] {
  const events = (body as { events?: unknown[] })?.events ?? [];
  const rows: Programme[] = [];
  for (const e of events as Record<string, unknown>[]) {
    const show = text(e.epgEventTitle)
      ?.match(/^S\d+\s*Ep\d+\s*-\s*(.+?)(?:\s*1\^TV)?$/)?.[1];
    // Sky ends some titles with the date: "... - 24/10/2026".
    const title = show ??
      text(e.eventTitle ?? e.epgEventTitle)
        ?.replace(/\s*-\s*\d{2}\/\d{2}\/\d{4}$/, "");
    const start = Date.parse(String(e.starttime ?? ""));
    const stop = Date.parse(String(e.endtime ?? ""));
    if (!title || !(stop > start)) continue;
    rows.push({
      ref,
      start: new Date(start).toISOString(),
      stop: new Date(stop).toISOString(),
      title,
      description: text(e.eventSynopsis),
    });
  }
  return rows;
}

// --- Discovery's Italian sites: one channel, 7 days.

async function readDiscovery(
  address: string,
  channel: SourceChannel,
  deps: ReadDeps,
): Promise<Programme[]> {
  return discoveryProgrammes(
    channel.id,
    await getJson(fill(address, { id: channel.id }), deps),
  );
}

/** One Discovery guide page. Its times say "+00:00" but are Italian time
 * (checked against Sky's guide on 2026-10-24). */
export function discoveryProgrammes(ref: string, body: unknown): Programme[] {
  const included = (body as { included?: unknown[] })?.included;
  const block = (Array.isArray(included) ? included : [])
    .map((i) => (i as { attributes?: Record<string, unknown> }).attributes)
    .find((a) => a?.type === "epgBlock");
  const channels = block?.channels;
  if (!Array.isArray(channels) || channels.length === 0) {
    throw new Error("no guide block");
  }
  const rows: Programme[] = [];
  for (const day of (channels[0].days ?? []) as { programs?: unknown[] }[]) {
    for (const p of (day.programs ?? []) as Record<string, unknown>[]) {
      // Gaps between programmes come without a show.
      const title = text(p.show_name);
      const start = romeWallTime(p.start_dt);
      const stop = romeWallTime(p.end_dt);
      if (!title || start == null || stop == null || stop <= start) continue;
      const episode = text(p.title);
      rows.push({
        ref,
        start: start.toISOString(),
        stop: stop.toISOString(),
        title,
        // "St. Ep." when the episode is unknown.
        subtitle: episode != null && !/^St\.\s*Ep\.$/.test(episode)
          ? episode
          : undefined,
        description: text(p.description),
      });
    }
  }
  return rows;
}

function romeWallTime(value: unknown): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/.exec(String(value));
  if (m == null) return null;
  return romeToUtc(
    Number(m[1]),
    Number(m[2]),
    Number(m[3]),
    Number(m[4]),
    Number(m[5]),
  );
}

// --- XMLTV feeds: one file, every channel.

async function readXmltv(
  source: GuideSource,
  channels: SourceChannel[],
  deps: ReadDeps,
): Promise<ReadResult> {
  const res = await deps.fetch(source.address, {
    headers: { "User-Agent": browserUserAgent },
    signal: AbortSignal.timeout(60_000),
  });
  if (!res.ok || res.body == null) {
    await res.body?.cancel();
    throw new Error(`status ${res.status}`);
  }
  const bytes = new Uint8Array(await res.arrayBuffer());
  // gzip files start with 1f 8b.
  const xml = bytes[0] === 0x1f && bytes[1] === 0x8b
    ? await new Response(
      new Blob([bytes]).stream().pipeThrough(
        new DecompressionStream("gzip"),
      ),
    ).text()
    : new TextDecoder().decode(bytes);

  const wanted = new Set(channels.map((c) => c.id));
  const rows = xmltvProgrammes(xml, wanted);
  const found = new Set(rows.map((r) => r.ref));
  return {
    rows,
    failed: [...wanted].filter((id) => !found.has(id)).map((id) =>
      `${id}: not in the feed`
    ),
  };
}

/** The programmes of the wanted channels in an XMLTV file. */
export function xmltvProgrammes(xml: string, wanted: Set<string>): Programme[] {
  const rows: Programme[] = [];
  const programme = /<programme\s([^>]*)>([\s\S]*?)<\/programme>/g;
  for (const m of xml.matchAll(programme)) {
    const attrs = m[1];
    const ref = decodeXml(/channel="([^"]*)"/.exec(attrs)?.[1] ?? "");
    if (!wanted.has(ref)) continue;
    const start = xmltvTime(/start="([^"]*)"/.exec(attrs)?.[1]);
    const stop = xmltvTime(/stop="([^"]*)"/.exec(attrs)?.[1]);
    const body = m[2];
    const title = xmlElement(body, "title");
    if (start == null || stop == null || stop <= start || !title) continue;
    rows.push({
      ref,
      start: start.toISOString(),
      stop: stop.toISOString(),
      title,
      subtitle: xmlElement(body, "sub-title"),
      description: xmlElement(body, "desc"),
      image: /<icon[^>]*\ssrc="([^"]+)"/.exec(body)?.[1],
    });
  }
  return rows;
}

/** `20261024003500 +0200` (the offset may be missing: UTC). */
export function xmltvTime(value: string | undefined): Date | null {
  const m =
    /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-])?(\d{2})?:?(\d{2})?/
      .exec(value ?? "");
  if (m == null) return null;
  const utc = Date.UTC(
    Number(m[1]),
    Number(m[2]) - 1,
    Number(m[3]),
    Number(m[4]),
    Number(m[5]),
    Number(m[6] ?? 0),
  );
  const offset = m[7] == null ? 0 : (m[7] === "-" ? -1 : 1) *
    (Number(m[8] ?? 0) * 60 + Number(m[9] ?? 0)) * 60_000;
  return new Date(utc - offset);
}

function xmlElement(body: string, name: string): string | undefined {
  const m = new RegExp(`<${name}[^>]*>([\\s\\S]*?)</${name}>`).exec(body);
  return m == null ? undefined : text(decodeXml(m[1]));
}

const entities: Record<string, string> = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
};

function decodeXml(value: string): string {
  return value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(
      /&(?:#x([0-9a-fA-F]+)|#(\d+)|(amp|lt|gt|quot|apos));/g,
      (_, hex, dec, name) =>
        hex != null
          ? String.fromCodePoint(parseInt(hex, 16))
          : dec != null
          ? String.fromCodePoint(Number(dec))
          : entities[name],
    );
}

// --- Italian time.

const romeParts = new Intl.DateTimeFormat("en-GB", {
  timeZone: "Europe/Rome",
  hourCycle: "h23",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
});

function romeFields(date: Date): Record<string, number> {
  return Object.fromEntries(
    romeParts.formatToParts(date)
      .filter((p) => p.type !== "literal")
      .map((p) => [p.type, Number(p.value)]),
  );
}

/** Today's date in Italy. */
export function romeDate(now: Date): { y: number; m: number; d: number } {
  const f = romeFields(now);
  return { y: f.year, m: f.month, d: f.day };
}

/** How far Italy is ahead of UTC at that moment, in ms. */
function romeOffset(at: number): number {
  const f = romeFields(new Date(at));
  const asUtc = Date.UTC(
    f.year,
    f.month - 1,
    f.day,
    f.hour,
    f.minute,
    f.second,
  );
  return asUtc - Math.floor(at / 1000) * 1000;
}

/** An Italian date and time as a moment, minding summer time. In the hour
 * that happens twice (the last Sunday of October) the first one is taken. */
export function romeToUtc(
  y: number,
  m: number,
  d: number,
  h: number,
  min: number,
): Date {
  const wall = Date.UTC(y, m - 1, d, h, min);
  // Try both offsets Italy uses: the larger first (summer time).
  for (const offset of [2 * hour, hour]) {
    if (romeOffset(wall - offset) === offset) return new Date(wall - offset);
  }
  // A time skipped by the spring change: read it as winter time.
  return new Date(wall - hour);
}

// --- Helpers.

async function getJson(url: string, deps: ReadDeps): Promise<unknown> {
  const res = await deps.fetch(url, {
    headers: { "User-Agent": browserUserAgent, Accept: "application/json" },
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) {
    await res.body?.cancel();
    throw new Error(`status ${res.status}`);
  }
  return await res.json();
}

/** Fills `{name}` placeholders. */
export function fill(address: string, values: Record<string, string>): string {
  return address.replace(
    /\{(\w+)\}/g,
    (all, name) =>
      values[name] == null ? all : encodeURIComponent(values[name]),
  );
}

function text(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed === "" ? undefined : trimmed;
}

function pad(n: number): string {
  return String(n).padStart(2, "0");
}

async function eachLimited<T>(
  items: T[],
  limit: number,
  run: (item: T) => Promise<void>,
): Promise<void> {
  let next = 0;
  const workers = Array.from(
    { length: Math.min(limit, items.length) },
    async () => {
      while (next < items.length) await run(items[next++]);
    },
  );
  await Promise.all(workers);
}
