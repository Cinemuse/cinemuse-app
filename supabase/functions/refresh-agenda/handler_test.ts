// Run: deno test supabase/functions/refresh-agenda
import assert from "node:assert/strict";
import { batchSize, type Deps, handle, retryHours } from "./handler.ts";
import { day } from "./check.ts";

const project = "https://project.test";

interface Call {
  url: string;
  headers: Headers;
  body: Record<string, unknown> | null;
}

/** `api_keys` answers `keyRows` with `keyStatus`; the database claims
 * `due`; TMDB knows movie 1 (coming out) and fails every other path with
 * `tmdbStatus`. */
function fake(
  due: unknown[] = [],
  {
    claimStatus = 200,
    tmdbStatus = 500,
    keyStatus = 200,
    keyRows = [{ value: "secret-key" }] as unknown[],
  } = {},
) {
  const calls: Call[] = [];
  const deps: Deps = {
    supabaseUrl: project,
    serviceKey: "service",
    now: () => new Date("2026-10-20T12:00:00Z"),
    fetch: (input, init) => {
      const url = input.toString();
      const body = init?.body ? JSON.parse(init.body as string) : null;
      calls.push({ url, headers: new Headers(init?.headers), body });
      if (url === `${project}/rest/v1/api_keys?name=eq.tmdb&select=value`) {
        return Promise.resolve(
          new Response(JSON.stringify(keyRows), { status: keyStatus }),
        );
      }
      if (url === `${project}/rest/v1/rpc/claim_due_agenda_titles`) {
        return Promise.resolve(
          new Response(JSON.stringify(due), { status: claimStatus }),
        );
      }
      if (url === `${project}/rest/v1/rpc/finish_agenda_check`) {
        return Promise.resolve(new Response(null, { status: 204 }));
      }
      if (url.startsWith("https://api.themoviedb.org/3/movie/1?")) {
        return Promise.resolve(
          new Response(JSON.stringify({ release_date: "2026-12-01" })),
        );
      }
      if (url.startsWith("https://api.themoviedb.org/3/")) {
        return Promise.resolve(new Response("", { status: tmdbStatus }));
      }
      return Promise.reject(new Error(`unexpected ${url}`));
    },
  };
  return { deps, calls };
}

const post = () =>
  new Request(`${project}/functions/v1/refresh-agenda`, { method: "POST" });

const finishes = (calls: Call[]) =>
  calls.filter((c) => c.url.endsWith("/rpc/finish_agenda_check"))
    .map((c) => c.body);

const claims = (calls: Call[]) =>
  calls.filter((c) => c.url.endsWith("/rpc/claim_due_agenda_titles"));

Deno.test("checks the due titles and saves each result", async () => {
  const { deps, calls } = fake([
    { tmdb_id: 1, media_type: "movie" },
    { tmdb_id: 2, media_type: "tv" },
  ]);

  const res = await handle(post(), deps);

  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {
    checked: 2,
    shown: 1,
    empty: 0,
    failed: 1,
  });
  assert.equal(calls[0].headers.get("Authorization"), "Bearer service");
  assert.deepEqual(claims(calls)[0].body, { max_titles: batchSize });
  assert.equal(claims(calls)[0].headers.get("Authorization"), "Bearer service");
  // TMDB is called with the key from api_keys.
  assert.ok(
    calls.some((c) =>
      c.url.startsWith("https://api.themoviedb.org/3/movie/1?") &&
      c.url.includes("api_key=secret-key")
    ),
  );
  assert.deepEqual(finishes(calls), [
    {
      p_tmdb_id: 1,
      p_media_type: "movie",
      p_release_date: "2026-12-01",
      p_event_data: { release_date: "2026-12-01" },
      p_next_check_hours: day,
      p_error: null,
    },
    {
      // Tried again in an hour; the error never shows the TMDB key.
      p_tmdb_id: 2,
      p_media_type: "tv",
      p_release_date: null,
      p_event_data: null,
      p_next_check_hours: retryHours,
      p_error: "TMDB answered 500 for /tv/2",
    },
  ]);
});

Deno.test("a title TMDB doesn't know is saved as nothing to show", async () => {
  const { deps, calls } = fake([{ tmdb_id: 2, media_type: "tv" }], {
    tmdbStatus: 404,
  });

  const res = await handle(post(), deps);

  assert.deepEqual(await res.json(), {
    checked: 1,
    shown: 0,
    empty: 1,
    failed: 0,
  });
  assert.equal(finishes(calls)[0]?.p_event_data, null);
  assert.equal(finishes(calls)[0]?.p_error, null);
});

Deno.test("nothing due: no TMDB call", async () => {
  const { deps, calls } = fake([]);

  const res = await handle(post(), deps);

  assert.deepEqual(await res.json(), {
    checked: 0,
    shown: 0,
    empty: 0,
    failed: 0,
  });
  // Only the key and the due titles are read.
  assert.equal(calls.length, 2);
});

Deno.test("refuses anything but POST without reading anything", async () => {
  const get = fake([{ tmdb_id: 1, media_type: "movie" }]);
  const res = await handle(
    new Request(`${project}/functions/v1/refresh-agenda`),
    get.deps,
  );
  assert.equal(res.status, 405);
  await res.body?.cancel();

  assert.equal(get.calls.length, 0);
});

Deno.test("no TMDB key in api_keys: 500 without claiming titles", async () => {
  const due = [{ tmdb_id: 1, media_type: "movie" }];
  for (
    const options of [
      { keyRows: [] },
      { keyRows: [{ value: "" }] },
      { keyStatus: 503 },
    ]
  ) {
    const { deps, calls } = fake(due, options);

    const res = await handle(post(), deps);

    assert.equal(res.status, 500);
    assert.deepEqual(await res.json(), { error: "No TMDB key" });
    assert.equal(claims(calls).length, 0);
  }
});

Deno.test("answers 500 when the due titles can't be read", async () => {
  const { deps } = fake([], { claimStatus: 503 });

  const res = await handle(post(), deps);

  assert.equal(res.status, 500);
  await res.body?.cancel();
});
