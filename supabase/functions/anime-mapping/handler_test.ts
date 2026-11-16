// Run: deno test supabase/functions/anime-mapping
import assert from "node:assert/strict";
import { anibridgeUrl, type Deps, fribbUrl, handle } from "./handler.ts";
import type { Row } from "./mapping.ts";
import { kitsuApi } from "./store.ts";

const base = "https://project.test";
const now = new Date("2026-10-24T12:00:00Z");

function hoursAgo(hours: number): string {
  return new Date(now.getTime() - hours * 3_600_000).toISOString();
}

// Anime 1 is in both lists, with Kitsu's id; anime 2 only in AniBridge.
const fribb = [
  {
    type: "TV",
    anilist_id: 1,
    kitsu_id: 77,
    themoviedb_id: { tv: 9 },
    season: { tmdb: 1 },
  },
];
const anibridge = {
  "anilist:1": {},
  "anilist:2": {},
  "tmdb_show:9:s1": { "anilist:1": { "1-12": "1-12" } },
  "tmdb_show:9:s2": { "anilist:2": { "1-": "1-" } },
};

/** The line of anime 1 as the refresh builds it. */
const line1: Row = {
  anilist_id: 1,
  kitsu_id: 77,
  tmdb_show_id: 9,
  tmdb_episodes: [{ season: 1, first: 1, last: 12, anime_first: 1 }],
  placed_by: "anibridge",
};

/** The database, both lists and Kitsu as the function sees them. Auth knows
 * the token "good". */
class Fake {
  rows: Row[] = [];
  status: Record<string, unknown> = {
    refreshed_at: null,
    tried_at: null,
    anibridge_count: null,
    fribb_count: null,
  };
  lists: Record<string, { body: unknown; status: number }> = {
    [fribbUrl]: { body: fribb, status: 200 },
    [anibridgeUrl]: { body: anibridge, status: 200 },
  };
  /** Kitsu's anime for an AniList id; missing = Kitsu doesn't know it. */
  kitsu: Record<number, string> = {};
  kitsuStatus = 200;
  calls: string[] = [];

  deps(): Deps {
    return {
      supabaseUrl: base,
      anonKey: "anon",
      serviceKey: "service",
      corrections: [],
      now: () => now,
      fetch: (input, init) => Promise.resolve(this.answer(input, init)),
    };
  }

  answer(input: RequestInfo | URL, init?: RequestInit): Response {
    const url = new URL(input.toString());
    const method = init?.method ?? "GET";
    const body = init?.body ? JSON.parse(init.body as string) : null;
    const path = url.pathname.replace("/rest/v1/", "");
    const params = url.searchParams;

    if (url.href === `${base}/auth/v1/user`) {
      const auth = new Headers(init?.headers).get("Authorization");
      return new Response("{}", { status: auth === "Bearer good" ? 200 : 401 });
    }
    const list = this.lists[url.href];
    if (list != null) {
      this.calls.push(url.href === fribbUrl ? "fribb" : "anibridge");
      const text = typeof list.body === "string"
        ? list.body
        : JSON.stringify(list.body);
      return new Response(text, { status: list.status });
    }
    if (url.href.startsWith(`${kitsuApi}/mappings`)) {
      const id = Number(params.get("filter[external_id]"));
      this.calls.push(`kitsu ${id}`);
      assert.match(
        new Headers(init?.headers).get("User-Agent") ?? "",
        /Mozilla/,
      );
      if (this.kitsuStatus !== 200) {
        return new Response("", { status: this.kitsuStatus });
      }
      const k = this.kitsu[id];
      return Response.json(
        k == null ? { data: [] } : {
          data: [{
            relationships: { item: { data: { type: "anime", id: k } } },
          }],
        },
      );
    }
    assert.equal(new Headers(init?.headers).get("apikey"), "service");
    if (path === "anime_mapping_status") {
      if (method === "PATCH") Object.assign(this.status, body);
      return Response.json(method === "GET" ? [this.status] : null);
    }
    if (path === "rpc/replace_anime_mapping") {
      this.rows = body.p_rows;
      Object.assign(this.status, {
        refreshed_at: now.toISOString(),
        tried_at: now.toISOString(),
        anibridge_count: body.p_anibridge_count,
        fribb_count: body.p_fribb_count,
        last_error: null,
      });
      return Response.json(this.rows.length);
    }
    if (path === "rpc/anime_mapping_rows") return Response.json(this.rows);
    if (path === "anime_mapping") {
      const asked = params.get("anilist_id");
      if (asked != null) {
        // The Kitsu ids saved by an earlier refresh.
        const ids = asked.replace(/^in\.\(|\)$/g, "").split(",").map(Number);
        return Response.json(
          this.rows
            .filter((r) => ids.includes(r.anilist_id) && r.kitsu_id != null)
            .map((r) => ({ anilist_id: r.anilist_id, kitsu_id: r.kitsu_id })),
        );
      }
      const [column, value] = [...params].find(([k]) => k.startsWith("tmdb_"))!;
      const id = Number(value.replace("eq.", ""));
      const found = this.rows
        .filter((r) => (r as unknown as Record<string, unknown>)[column] === id)
        .sort((a, b) => a.anilist_id - b.anilist_id)
        // The REST API sends empty columns as null.
        .map((r) => ({
          anidb_id: null,
          kitsu_id: null,
          tmdb_movie_id: null,
          tvdb_id: null,
          ...r,
        }));
      return Response.json(found);
    }
    throw new Error(`unexpected ${method} ${url.href}`);
  }
}

/** A fake whose list was refreshed an hour ago. */
function filled(): Fake {
  const fake = new Fake();
  fake.rows = [line1];
  fake.status = {
    refreshed_at: hoursAgo(1),
    tried_at: hoursAgo(1),
    anibridge_count: 2,
    fribb_count: 1,
  };
  return fake;
}

/** A fake whose list is due for a refresh. */
function due(): Fake {
  const fake = filled();
  fake.status.refreshed_at = hoursAgo(25);
  fake.status.tried_at = hoursAgo(2);
  return fake;
}

function get(query = "", headers: Record<string, string> = {}) {
  return new Request(`${base}/functions/v1/anime-mapping${query}`, {
    headers: { Authorization: "Bearer good", ...headers },
  });
}

function post() {
  return new Request(`${base}/functions/v1/anime-mapping`, { method: "POST" });
}

Deno.test("refuses callers who are not signed in", async () => {
  const fake = filled();
  for (const auth of [undefined, "Bearer bad"]) {
    const headers: Record<string, string> = auth == null
      ? {}
      : { Authorization: auth };
    const req = new Request(`${base}/functions/v1/anime-mapping`, { headers });
    const res = await handle(req, fake.deps());
    assert.equal(res.status, 401);
    await res.body?.cancel();
  }
});

Deno.test("serves the stored lines to a signed-in user", async () => {
  const fake = filled();
  const res = await handle(get(), fake.deps());

  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { rows: [line1] });
  assert.deepEqual(fake.calls, []);
});

Deno.test("gzips the lines when the caller accepts it", async () => {
  const res = await handle(
    get("", { "Accept-Encoding": "gzip, deflate" }),
    filled().deps(),
  );

  assert.equal(res.headers.get("Content-Encoding"), "gzip");
  const unzipped = res.body!.pipeThrough(new DecompressionStream("gzip"));
  const body = JSON.parse(await new Response(unzipped).text());
  assert.equal(body.rows.length, 1);
});

Deno.test("a list never filled is filled from both lists first", async () => {
  const fake = new Fake();
  fake.kitsu = { 2: "88" };
  const res = await handle(get(), fake.deps());

  assert.equal(res.status, 200);
  assert.deepEqual((await res.json()).rows, [line1, {
    anilist_id: 2,
    kitsu_id: 88,
    tmdb_show_id: 9,
    tmdb_episodes: [{ season: 2, first: 1, anime_first: 1 }],
    placed_by: "anibridge",
  }]);
  assert.deepEqual(fake.calls, ["fribb", "anibridge", "kitsu 2"]);
  assert.equal(fake.status.anibridge_count, 2);
  assert.equal(fake.status.fribb_count, 1);
});

Deno.test("a list never filled and a broken list is an error", async () => {
  const broken: [string, unknown, number][] = [
    [fribbUrl, fribb, 500],
    [fribbUrl, [], 200],
    [fribbUrl, "junk", 200],
    [anibridgeUrl, anibridge, 404],
    [anibridgeUrl, {}, 200],
  ];
  for (const [url, body, status] of broken) {
    const fake = new Fake();
    fake.lists[url] = { body, status };
    const res = await handle(get(), fake.deps());
    assert.equal(res.status, 502, `${url} ${status}`);
    await res.body?.cancel();
    assert.equal(fake.status.tried_at, now.toISOString());
    assert.ok(fake.status.last_error);
  }
});

Deno.test("answers which anime an episode is, without Kitsu", async () => {
  const fake = filled();
  const res = await handle(
    get("?tmdb_id=9&type=tv&season=1&episode=5"),
    fake.deps(),
  );

  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {
    is_anime: true,
    match: { anilist_id: 1, kitsu_id: 77, episode: 5 },
  });
  assert.deepEqual(fake.calls, []);
});

Deno.test("a title with no lines is not anime", async () => {
  const res = await handle(get("?tmdb_id=10&type=tv"), filled().deps());

  assert.deepEqual(await res.json(), { is_anime: false, match: null });
});

Deno.test("a lookup with bad parameters is refused", async () => {
  for (
    const query of [
      "?tmdb_id=abc&type=tv",
      "?tmdb_id=9",
      "?tmdb_id=9&type=show",
      "?tmdb_id=9&type=tv&season=one&episode=1",
    ]
  ) {
    const res = await handle(get(query), filled().deps());
    assert.equal(res.status, 400, query);
    await res.body?.cancel();
  }
});

Deno.test("a Kitsu id asked before is kept, not asked again", async () => {
  const fake = due();
  fake.rows = [line1, { anilist_id: 2, kitsu_id: 88, tmdb_show_id: 9 }];

  const res = await handle(post(), fake.deps());

  assert.deepEqual(await res.json(), { refreshed: true, rows: 2 });
  assert.equal(fake.rows.find((r) => r.anilist_id === 2)?.kitsu_id, 88);
  assert.deepEqual(fake.calls, ["fribb", "anibridge"]);
});

Deno.test("when Kitsu fails, the line is saved without its id", async () => {
  const fake = due();
  fake.kitsuStatus = 503;

  const res = await handle(post(), fake.deps());

  assert.deepEqual(await res.json(), { refreshed: true, rows: 2 });
  assert.equal(fake.rows.find((r) => r.anilist_id === 2)?.kitsu_id, undefined);
});

Deno.test("POST refreshes a list older than 20 hours", async () => {
  const fake = filled();
  fake.status.refreshed_at = hoursAgo(21);
  fake.status.tried_at = hoursAgo(21);
  fake.lists[fribbUrl].body = [...fribb, {
    type: "MOVIE",
    anilist_id: 3,
    themoviedb_id: { movie: 10 },
  }];

  const res = await handle(post(), fake.deps());

  assert.deepEqual(await res.json(), { refreshed: true, rows: 3 });
  assert.equal(fake.rows.length, 3);
});

Deno.test("POST leaves a fresh list or one tried in the last hour", async () => {
  for (
    const status of [
      { refreshed_at: hoursAgo(19), tried_at: hoursAgo(19) },
      { refreshed_at: hoursAgo(30), tried_at: hoursAgo(0.5) },
    ]
  ) {
    const fake = filled();
    Object.assign(fake.status, status);
    const res = await handle(post(), fake.deps());
    assert.deepEqual(await res.json(), { refreshed: false });
    assert.deepEqual(fake.calls, []);
  }
});

Deno.test("a failed refresh keeps the old list and saves the error", async () => {
  const fake = due();
  fake.lists[anibridgeUrl].status = 500;

  const res = await handle(post(), fake.deps());

  assert.equal(res.status, 502);
  await res.body?.cancel();
  assert.deepEqual(fake.rows, [line1]);
  assert.equal(fake.status.refreshed_at, hoursAgo(25));
  assert.equal(fake.status.tried_at, now.toISOString());
  assert.match(String(fake.status.last_error), /AniBridge's list: status 500/);
});

Deno.test("a list with under 90% of last time's anime keeps the old list", async () => {
  const shrunk: [Record<string, number>, RegExp][] = [
    [{ anibridge_count: 3 }, /AniBridge's list has 2 anime, 3 last time/],
    [{ fribb_count: 2 }, /Fribb's list has 1 anime, 2 last time/],
  ];
  for (const [counts, error] of shrunk) {
    const fake = due();
    Object.assign(fake.status, counts);

    const res = await handle(post(), fake.deps());

    assert.equal(res.status, 502);
    await res.body?.cancel();
    assert.deepEqual(fake.rows, [line1]);
    assert.match(String(fake.status.last_error), error);
  }
});

Deno.test("only GET or POST", async () => {
  const req = new Request(`${base}/functions/v1/anime-mapping`, {
    method: "PUT",
    headers: { Authorization: "Bearer good" },
  });
  const res = await handle(req, filled().deps());
  assert.equal(res.status, 405);
  await res.body?.cancel();
});
