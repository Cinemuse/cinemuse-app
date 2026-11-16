import { checkTitle, type TmdbGet } from "./check.ts";

/** Titles checked per run (one run a minute while titles are due). */
export const batchSize = 50;

/** A failed check is tried again after this many hours. */
export const retryHours = 1;

export interface Deps {
  supabaseUrl: string;
  serviceKey: string;
  fetch: typeof fetch;
  now: () => Date;
}

export function defaultDeps(): Deps {
  return {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    serviceKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    fetch: globalThis.fetch,
    now: () => new Date(),
  };
}

interface Title {
  tmdb_id: number;
  media_type: "movie" | "tv";
}

/** Checks the titles that are due on TMDB and saves what the agenda shows.
 * Takes no input: a caller can only make it do work already due, so it
 * needs no sign-in (`verify_jwt = false`, like the other functions). */
export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method !== "POST") return json(405, { error: "Only POST" });

  // Read on every run, so a new key in the table is used a minute later.
  let tmdbKey: string;
  try {
    tmdbKey = await readTmdbKey(deps);
  } catch (e) {
    console.error("TMDB key not read", e);
    return json(500, { error: "No TMDB key" });
  }

  let titles: Title[];
  try {
    titles = await rpc(deps, "claim_due_agenda_titles", {
      max_titles: batchSize,
    }) as Title[];
  } catch (e) {
    console.error("Due titles not read", e);
    return json(500, { error: "Due titles not read" });
  }

  const tmdb = tmdbGet(deps, tmdbKey);
  let shown = 0, empty = 0, failed = 0;
  for (const title of titles) {
    const params = {
      p_tmdb_id: title.tmdb_id,
      p_media_type: title.media_type,
      p_release_date: null as string | null,
      p_event_data: null as unknown,
      p_next_check_hours: retryHours,
      p_error: null as string | null,
    };
    try {
      const check = await checkTitle(
        title.tmdb_id,
        title.media_type,
        tmdb,
        deps.now(),
      );
      params.p_next_check_hours = check.nextCheckHours;
      if (check.kind === "show") {
        params.p_release_date = check.releaseDate;
        params.p_event_data = check.eventData;
        shown++;
      } else {
        empty++;
      }
    } catch (e) {
      params.p_error = e instanceof Error ? e.message : String(e);
      console.error(`${title.media_type} ${title.tmdb_id}: ${params.p_error}`);
      failed++;
    }
    try {
      await rpc(deps, "finish_agenda_check", params);
    } catch (e) {
      // The title stays held and comes back in 10 minutes.
      console.error(`${title.media_type} ${title.tmdb_id} not saved`, e);
    }
  }

  return json(200, { checked: titles.length, shown, empty, failed });
}

/** Calls a database function as the service role. */
async function rpc(deps: Deps, name: string, body: unknown): Promise<unknown> {
  const res = await deps.fetch(`${deps.supabaseUrl}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { ...serviceHeaders(deps), "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`${name}: ${res.status} ${await res.text()}`);
  const text = await res.text();
  return text === "" ? null : JSON.parse(text);
}

/** The `tmdb` row of `api_keys`, the key the app uses too. */
async function readTmdbKey(deps: Deps): Promise<string> {
  const res = await deps.fetch(
    `${deps.supabaseUrl}/rest/v1/api_keys?name=eq.tmdb&select=value`,
    { headers: serviceHeaders(deps) },
  );
  if (!res.ok) throw new Error(`api_keys: ${res.status} ${await res.text()}`);
  const rows = await res.json() as { value?: unknown }[];
  const value = rows[0]?.value;
  if (typeof value !== "string" || value === "") {
    throw new Error("No tmdb row in api_keys");
  }
  return value;
}

function serviceHeaders(deps: Deps): Record<string, string> {
  return {
    apikey: deps.serviceKey,
    Authorization: `Bearer ${deps.serviceKey}`,
  };
}

/** TMDB in English; error messages never contain the key. */
function tmdbGet(deps: Deps, key: string): TmdbGet {
  return async (path) => {
    const url = `https://api.themoviedb.org/3${path}` +
      `?api_key=${key}&language=en-US`;
    const res = await deps.fetch(url);
    if (res.status === 404) {
      await res.body?.cancel();
      return null;
    }
    if (!res.ok) {
      await res.body?.cancel();
      throw new Error(`TMDB answered ${res.status} for ${path}`);
    }
    return await res.json();
  };
}

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
