import { corrections as ourCorrections } from "./corrections.ts";
import { pick, type Query } from "./lookup.ts";
import {
  buildRows,
  type Correction,
  readAniBridge,
  readFribb,
  type Row,
} from "./mapping.ts";
import {
  allRows,
  askKitsu,
  readStatus,
  replaceRows,
  saveFailure,
  type Status,
  type StoreDeps,
  storedKitsuIds,
  titleRows,
} from "./store.ts";

/** Fribb's list, updated daily: the numbers on every site, the films, and
 * where an anime starts on TMDB. */
export const fribbUrl =
  "https://raw.githubusercontent.com/Fribb/anime-lists/master/anime-list-full.json";

/** AniBridge's list (schema v3), rebuilt daily: each anime's exact TMDB
 * episodes. */
export const anibridgeUrl =
  "https://github.com/anibridge/anibridge-mappings/releases/download/v3/mappings.min.json";

/** A list with fewer anime than this share of last time's is taken as
 * broken: the old list stays. */
const minShareOfLast = 0.9;

/** Kitsu is asked about this many anime at once. */
const kitsuAtOnce = 5;

/** The list is refreshed when older than this, and a failed refresh is
 * tried again after `retryHours` (the cron job in the migration checks the
 * same two numbers before calling). */
export const refreshHours = 20;
export const retryHours = 1;

export interface Deps extends StoreDeps {
  anonKey: string;
  corrections: Correction[];
}

export function defaultDeps(): Deps {
  return {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    anonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    fetch: globalThis.fetch,
    now: () => new Date(),
    corrections: ourCorrections,
  };
}

/** GET, signed-in users only: with `tmdb_id` the anime of one title or
 * episode, without it the whole list (`{"rows": [...]}`, gzipped when
 * asked). POST refreshes the list when it is due: it takes no input, so it
 * needs no sign-in (`verify_jwt = false`, like the other functions). */
export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "POST") return await refreshWhenDue(deps);
  if (req.method !== "GET") return text(405, "Only GET or POST");
  if (!(await isSignedIn(req, deps))) return text(401, "Sign in first");

  try {
    const status = await readStatus(deps);
    // Never filled yet (just deployed): fill it now.
    if (status.refreshed_at == null) await refresh(deps, status);
  } catch (e) {
    console.error("Anime mapping not ready", e);
    return text(502, "Anime mapping not ready");
  }

  const params = new URL(req.url).searchParams;
  if (params.has("tmdb_id")) return await lookUp(params, deps);
  return await serveList(req, deps);
}

/** `?tmdb_id=105009&type=tv&season=1&episode=37` →
 * `{"is_anime": true, "match": {..., "episode": 13}}` (`match` null when no
 * anime covers it). */
async function lookUp(params: URLSearchParams, deps: Deps): Promise<Response> {
  const tmdbId = toInt(params.get("tmdb_id"));
  const type = params.get("type");
  const season = toInt(params.get("season"));
  const episode = toInt(params.get("episode"));
  if (
    tmdbId == null || (type !== "tv" && type !== "movie") ||
    (params.has("season") && season == null) ||
    (params.has("episode") && episode == null)
  ) {
    return text(400, "Expected tmdb_id, type (tv or movie), season, episode");
  }

  const query: Query = { tmdbId, type, season, episode };
  try {
    const rows = await titleRows(deps, tmdbId, type);
    return json(200, pick(query, rows));
  } catch (e) {
    console.error(`Lookup failed for ${type} ${tmdbId}`, e);
    return text(502, "Lookup failed");
  }
}

async function serveList(req: Request, deps: Deps): Promise<Response> {
  let rows;
  try {
    rows = await allRows(deps);
  } catch (e) {
    console.error("Anime mapping not read", e);
    return text(502, "Anime mapping not read");
  }
  if (rows.length === 0) return text(502, "Anime mapping is empty");

  const body = JSON.stringify({ rows });
  const headers = { "Content-Type": "application/json" };
  if (!(req.headers.get("Accept-Encoding") ?? "").includes("gzip")) {
    return new Response(body, { headers });
  }
  // About 1.6 MB of JSON: gzip makes it about 190 KB.
  const gzipped = new Blob([body]).stream()
    .pipeThrough(new CompressionStream("gzip"));
  return new Response(gzipped, {
    headers: { ...headers, "Content-Encoding": "gzip" },
  });
}

async function refreshWhenDue(deps: Deps): Promise<Response> {
  try {
    const status = await readStatus(deps);
    const now = deps.now().getTime();
    const hoursSince = (at: string | null) =>
      at == null ? Infinity : (now - Date.parse(at)) / 3_600_000;
    if (
      hoursSince(status.refreshed_at) < refreshHours ||
      hoursSince(status.tried_at) < retryHours
    ) {
      return json(200, { refreshed: false });
    }
    return json(200, { refreshed: true, rows: await refresh(deps, status) });
  } catch (e) {
    console.error("Refresh failed", e);
    return text(502, e instanceof Error ? e.message : String(e));
  }
}

/** Downloads both lists, builds the lines with our fixes, fills in the
 * Kitsu ids Fribb lacks and saves the result. A list that fails, or has
 * under 90% of last time's anime, is saved as a failure and the last good
 * list stays. */
async function refresh(deps: Deps, status: Status): Promise<number> {
  let rows;
  let counts;
  try {
    // One after the other, so only one big list is in memory at a time.
    const fribb = readFribb(await download(deps, fribbUrl, "Fribb's list"));
    checkSize("Fribb's list", fribb.size, status.fribb_count);
    const anibridge = readAniBridge(
      await download(deps, anibridgeUrl, "AniBridge's list"),
    );
    checkSize("AniBridge's list", anibridge.animeCount, status.anibridge_count);
    counts = { anibridge: anibridge.animeCount, fribb: fribb.size };

    const built = buildRows(fribb, anibridge, deps.corrections);
    rows = built.rows;
    if (built.notes.agreed.length > 0) {
      console.warn(
        "Fixes the lists now agree with (they can go)",
        built.notes.agreed,
      );
    }
    if (built.notes.manyShows.length > 0) {
      console.warn(
        "Anime in several TMDB shows, not placed",
        built.notes.manyShows,
      );
    }
    console.log(
      `Built ${rows.length} lines; ${anibridge.skipped} AniBridge links ` +
        "left out (double episodes, lists, uneven runs)",
    );
    await fillKitsuIds(deps, rows);
  } catch (e) {
    const error = e instanceof Error ? e.message : String(e);
    await saveFailure(deps, error);
    throw new Error(error);
  }
  return await replaceRows(deps, rows, counts);
}

async function download(deps: Deps, url: string, name: string) {
  const res = await deps.fetch(url);
  if (!res.ok) {
    await res.body?.cancel();
    throw new Error(`${name}: status ${res.status}`);
  }
  try {
    return await res.json();
  } catch {
    throw new Error(`${name}: not JSON`);
  }
}

function checkSize(name: string, size: number, last: number | null) {
  if (size === 0) throw new Error(`${name} is empty`);
  if (last != null && size < last * minShareOfLast) {
    throw new Error(`${name} has ${size} anime, ${last} last time`);
  }
}

/** The placed anime Fribb has no Kitsu id for: the id from the last refresh,
 * else Kitsu's answer. Kitsu failing only leaves the id empty until the next
 * refresh. */
async function fillKitsuIds(deps: Deps, rows: Row[]) {
  const missing = rows.filter((r) => r.placed_by != null && r.kitsu_id == null);
  const stored = await storedKitsuIds(deps, missing.map((r) => r.anilist_id));
  const ask: Row[] = [];
  for (const row of missing) {
    const id = stored.get(row.anilist_id);
    if (id != null) row.kitsu_id = id;
    else ask.push(row);
  }

  for (let i = 0; i < ask.length; i += kitsuAtOnce) {
    await Promise.all(
      ask.slice(i, i + kitsuAtOnce).map(async (row) => {
        try {
          const id = await askKitsu(deps, row.anilist_id);
          if (id != null) row.kitsu_id = id;
        } catch (e) {
          console.error(`Kitsu not read for AniList ${row.anilist_id}`, e);
        }
      }),
    );
  }
}

/** Asks Supabase Auth whether the caller's token belongs to a user. */
async function isSignedIn(req: Request, deps: Deps): Promise<boolean> {
  const auth = req.headers.get("Authorization");
  if (!auth?.startsWith("Bearer ")) return false;
  try {
    const res = await deps.fetch(`${deps.supabaseUrl}/auth/v1/user`, {
      headers: { Authorization: auth, apikey: deps.anonKey },
    });
    await res.body?.cancel();
    return res.ok;
  } catch (e) {
    console.error("Auth check failed", e);
    return false;
  }
}

function toInt(value: string | null): number | null {
  return value != null && /^\d+$/.test(value) ? Number(value) : null;
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
