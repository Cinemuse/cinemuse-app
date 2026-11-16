import type { Row } from "./mapping.ts";

/** Kitsu's API; the same mappings call as the app. */
export const kitsuApi = "https://kitsu.app/api/edge";

/** Kitsu refuses requests that don't look like a browser's. */
const browserAgent =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/130.0 Safari/537.36";

/** The database as the service role, plus Kitsu. */
export interface StoreDeps {
  supabaseUrl: string;
  serviceKey: string;
  fetch: typeof fetch;
  now: () => Date;
}

export interface Status {
  refreshed_at: string | null;
  tried_at: string | null;
  /** How many anime each list had at the last good refresh. */
  anibridge_count: number | null;
  fribb_count: number | null;
}

export async function readStatus(deps: StoreDeps): Promise<Status> {
  const rows = await rest(
    deps,
    "anime_mapping_status?select=refreshed_at,tried_at,anibridge_count," +
      "fribb_count&id=eq.true",
  ) as Status[];
  return rows[0] ?? {
    refreshed_at: null,
    tried_at: null,
    anibridge_count: null,
    fribb_count: null,
  };
}

/** Saves a failed refresh: the old list stays. */
export async function saveFailure(deps: StoreDeps, error: string) {
  await rest(deps, "anime_mapping_status?id=eq.true", {
    method: "PATCH",
    body: { tried_at: deps.now().toISOString(), last_error: error },
  });
}

/** Replaces the whole list and saves the lists' sizes; returns how many
 * lines it has. */
export async function replaceRows(
  deps: StoreDeps,
  rows: Row[],
  counts: { anibridge: number; fribb: number },
) {
  return await rest(deps, "rpc/replace_anime_mapping", {
    method: "POST",
    body: {
      p_rows: rows,
      p_anibridge_count: counts.anibridge,
      p_fribb_count: counts.fribb,
    },
  }) as number;
}

/** The whole list, as the app downloads it. */
export async function allRows(deps: StoreDeps): Promise<Row[]> {
  return await rest(deps, "rpc/anime_mapping_rows", {
    method: "POST",
    body: {},
  }) as Row[];
}

const columns = "anilist_id,anidb_id,kitsu_id,tmdb_show_id,tmdb_movie_id," +
  "tvdb_id,tmdb_episodes,placed_by";

/** The lines of one TMDB title, by AniList id (the app's copy keeps the
 * same order). */
export async function titleRows(
  deps: StoreDeps,
  tmdbId: number,
  type: "tv" | "movie",
): Promise<Row[]> {
  const column = type === "movie" ? "tmdb_movie_id" : "tmdb_show_id";
  const rows = await rest(
    deps,
    `anime_mapping?select=${columns}&${column}=eq.${tmdbId}&order=anilist_id`,
  ) as Record<string, unknown>[];
  // Drop the empty fields, like the app's rows.
  return rows.map((r) =>
    Object.fromEntries(
      Object.entries(r).filter(([, v]) => v != null),
    ) as unknown as Row
  );
}

/** The Kitsu ids the list already has for these AniList ids (asked of
 * Kitsu on an earlier refresh). */
export async function storedKitsuIds(
  deps: StoreDeps,
  anilistIds: number[],
): Promise<Map<number, number>> {
  const found = new Map<number, number>();
  if (anilistIds.length === 0) return found;
  const rows = await rest(
    deps,
    "anime_mapping?select=anilist_id,kitsu_id&kitsu_id=not.is.null" +
      `&anilist_id=in.(${anilistIds.join(",")})`,
  ) as { anilist_id: number; kitsu_id: number }[];
  for (const r of rows) found.set(r.anilist_id, r.kitsu_id);
  return found;
}

/** Kitsu's id for an AniList id; null when Kitsu doesn't know it. */
export async function askKitsu(
  deps: StoreDeps,
  anilistId: number,
): Promise<number | null> {
  const url = `${kitsuApi}/mappings?filter[external_id]=${anilistId}` +
    "&filter[external_site]=anilist/anime&include=item";
  const res = await deps.fetch(url, {
    headers: { "User-Agent": browserAgent },
  });
  if (!res.ok) {
    await res.body?.cancel();
    throw new Error(`Kitsu answered ${res.status}`);
  }
  const body = await res.json();
  const id = body?.data?.[0]?.relationships?.item?.data?.id;
  return id != null && /^\d+$/.test(String(id)) ? Number(id) : null;
}

/** Calls the database's REST API as the service role. */
async function rest(
  deps: StoreDeps,
  path: string,
  options: { method?: string; body?: unknown } = {},
): Promise<unknown> {
  const res = await deps.fetch(`${deps.supabaseUrl}/rest/v1/${path}`, {
    method: options.method ?? "GET",
    headers: {
      apikey: deps.serviceKey,
      Authorization: `Bearer ${deps.serviceKey}`,
      "Content-Type": "application/json",
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  if (!res.ok) {
    throw new Error(`${path.split("?")[0]}: ${res.status} ${await res.text()}`);
  }
  const text = await res.text();
  return text === "" ? null : JSON.parse(text);
}
