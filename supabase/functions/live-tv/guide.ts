import {
  type Channel,
  channels as allChannels,
  guideSources,
  type SourceKey,
} from "./channels.ts";
import type { Programme, ReadResult } from "./readers.ts";

/** One programme as `epg.json` serves it (the format apps already read). */
export interface Shown {
  name: string;
  subtitle?: string;
  description?: string;
  image?: string;
  startTime: { unix: number };
  endTime: { unix: number };
}

export interface SourceStatus {
  /** ISO times: the last call that read it, the last that got programmes. */
  tried?: string;
  refreshed?: string;
  /** The last call's error, or the channels it couldn't read; null: none. */
  error?: string | null;
}

/** `epg.json`: channel key -> programmes, plus "channels" (each key's name,
 * number and the source its programmes came from) and "status" (each
 * source's last read). Neither is a list, so readers of the plain map skip
 * them. The file is the memory: a call reads one source and keeps the rest
 * from the previous file. */
export type Guide = Record<string, unknown> & {
  channels?: Record<string, { name: string; lcn?: number; source?: string }>;
  status?: { sources?: Record<string, SourceStatus> };
};

const hour = 3_600_000;

/** A source not read for this long is due. */
export const refreshHours = 20;

/** The due source tried longest ago (never tried first); null when none is
 * due. */
export function dueSource(old: Guide | null, now: Date): SourceKey | null {
  const statuses = old?.status?.sources ?? {};
  let best: SourceKey | null = null;
  let bestTried = Infinity;
  for (const key of Object.keys(guideSources) as SourceKey[]) {
    const s = statuses[key] ?? {};
    const refreshed = s.refreshed == null ? -Infinity : Date.parse(s.refreshed);
    if (refreshed > now.getTime() - refreshHours * hour) continue;
    const tried = s.tried == null ? -Infinity : Date.parse(s.tried);
    if (best == null || tried < bestTried) {
      best = key;
      bestTried = tried;
    }
  }
  return best;
}

/** The channel ids one source is asked for. */
export function sourceChannels(
  source: SourceKey,
  channels: Channel[] = allChannels,
): { id: string; env?: string }[] {
  const byId = new Map<string, { id: string; env?: string }>();
  for (const ch of channels) {
    for (const [src, id, env] of ch.guide) {
      if (src === source) byId.set(id, { id, env });
    }
  }
  return [...byId.values()];
}

/** The new guide after reading `source`: for each channel, the first source
 * (in the channel's order) whose copy covers now and reaches 48 hours
 * ahead; if none, the one reaching furthest. A copy made mostly of one-hour
 * blocks on the hour is a placeholder, never used. The whole channel comes
 * from one source. The copies: `source`'s fresh programmes (with the old
 * file's earlier ones before them, when it was already the channel's
 * source), and the old file's programmes for the source they came from. */
export function buildGuide(
  old: Guide | null,
  source: SourceKey,
  result: ReadResult,
  now: Date,
  channels: Channel[] = allChannels,
): Guide {
  const fresh = new Map<string, Shown[]>();
  for (const [ref, rows] of groupByRef(result.rows)) fresh.set(ref, rows);

  const t = now.getTime();
  const guide: Guide = {};
  const info: NonNullable<Guide["channels"]> = {};
  for (const ch of channels) {
    const oldSource = old?.channels?.[ch.key]?.source;
    const oldCopy = oldSource == null ? [] : shownList(old?.[ch.key]);

    let chosen: { source: string; copy: Shown[] } | null = null;
    let chosenGood = false;
    let chosenReach = -Infinity;
    for (const [src, id] of ch.guide) {
      // In order: a good copy beats any later one; else the furthest.
      if (chosenGood) break;
      let copy: Shown[] | undefined;
      if (src === source && fresh.has(id)) {
        const rows = fresh.get(id)!;
        const first = rows[0].startTime.unix;
        copy = src === oldSource
          ? [...oldCopy.filter((p) => p.startTime.unix < first), ...rows]
          : rows;
      } else if (src === oldSource) {
        copy = oldCopy;
      }
      if (copy == null) continue;

      const future = copy.filter((p) => p.endTime.unix > t);
      if (future.length === 0 || isPlaceholder(future)) continue;
      const reach = Math.max(...future.map((p) => p.endTime.unix));
      const good = reach >= t + 48 * hour &&
        future.some((p) => p.startTime.unix <= t && p.endTime.unix > t);
      if (chosen == null || good || reach > chosenReach) {
        chosen = { source: src, copy };
        chosenGood = good;
        chosenReach = reach;
      }
    }

    info[ch.key] = { name: ch.name };
    if (ch.lcn != null) info[ch.key].lcn = ch.lcn;
    if (chosen == null) continue;
    const shown = chosen.copy.filter((p) =>
      p.endTime.unix > t - 24 * hour && p.startTime.unix < t + 8 * 24 * hour
    );
    if (shown.length === 0) continue;
    guide[ch.key] = shown;
    info[ch.key].source = chosen.source;
  }
  guide.channels = info;

  const statuses = { ...(old?.status?.sources ?? {}) };
  const error = result.failed.length === 0
    ? null
    : result.failed.join("; ").slice(0, 2000);
  statuses[source] = result.rows.length > 0
    ? { tried: now.toISOString(), refreshed: now.toISOString(), error }
    : {
      ...statuses[source],
      tried: now.toISOString(),
      error: error ?? "no programmes",
    };
  guide.status = { sources: statuses };
  return guide;
}

/** A source's programmes per channel id, in the served format: sorted, no
 * empty titles or times, one programme per start (the longest). */
function groupByRef(rows: Programme[]): Map<string, Shown[]> {
  const byRef = new Map<string, Map<number, Shown>>();
  for (const r of rows) {
    const start = Date.parse(r.start);
    const stop = Date.parse(r.stop);
    if (r.title == null || r.title === "" || !(stop > start)) continue;
    let starts = byRef.get(r.ref);
    if (starts == null) byRef.set(r.ref, starts = new Map());
    const before = starts.get(start);
    if (before != null && before.endTime.unix >= stop) continue;
    starts.set(start, {
      name: r.title,
      subtitle: r.subtitle || undefined,
      description: r.description || undefined,
      image: r.image || undefined,
      startTime: { unix: start },
      endTime: { unix: stop },
    });
  }
  const out = new Map<string, Shown[]>();
  for (const [ref, starts] of byRef) {
    out.set(
      ref,
      [...starts.values()].sort((a, b) => a.startTime.unix - b.startTime.unix),
    );
  }
  return out;
}

/** Mostly one-hour blocks on the hour: a feed's filler, not a guide. */
function isPlaceholder(future: Shown[]): boolean {
  const blocks =
    future.filter((p) =>
      p.endTime.unix - p.startTime.unix === hour &&
      p.startTime.unix % hour === 0
    ).length;
  return blocks / future.length > 0.8;
}

/** The old file's programmes of a channel (anything else is skipped). */
function shownList(value: unknown): Shown[] {
  if (!Array.isArray(value)) return [];
  return value.filter((p): p is Shown =>
    typeof p?.startTime?.unix === "number" &&
    typeof p?.endTime?.unix === "number"
  );
}
