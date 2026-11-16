// Run: deno test supabase/functions/refresh-agenda
import assert from "node:assert/strict";
import { checkTitle, cutoff, day, type TmdbGet, week } from "./check.ts";

const now = new Date("2026-10-20T12:00:00Z");

/** TMDB knowing only `answers`; every path asked is kept in `asked`. */
function tmdb(answers: Record<string, Record<string, unknown>>) {
  const asked: string[] = [];
  const get: TmdbGet = (path) => {
    asked.push(path);
    return Promise.resolve(answers[path] ?? null);
  };
  return { get, asked };
}

Deno.test("the cutoff is 30 days back", () => {
  assert.equal(cutoff(now), "2026-09-20");
});

Deno.test("a movie coming out or out in the last 30 days is shown", async () => {
  for (const date of ["2027-01-01", "2026-09-20", null]) {
    const movie = { title: "M", release_date: date ?? "" };
    const check = await checkTitle(
      1,
      "movie",
      tmdb({ "/movie/1": movie }).get,
      now,
    );
    assert.deepEqual(check, {
      kind: "show",
      releaseDate: date,
      eventData: movie,
      nextCheckHours: day,
    });
  }
});

Deno.test("an older movie or an unknown one is checked weekly", async () => {
  const old = tmdb({ "/movie/1": { release_date: "2026-09-19" } });
  assert.deepEqual(await checkTitle(1, "movie", old.get, now), {
    kind: "nothing",
    nextCheckHours: week,
  });
  assert.deepEqual(await checkTitle(2, "movie", old.get, now), {
    kind: "nothing",
    nextCheckHours: week,
  });
});

Deno.test("a series shows the season of its next episode", async () => {
  const t = tmdb({
    "/tv/7": {
      name: "Show",
      poster_path: "/p.jpg",
      next_episode_to_air: { season_number: 3, air_date: "2026-11-02" },
      last_episode_to_air: { season_number: 2, air_date: "2026-10-01" },
    },
    "/tv/7/season/3": { season_number: 3, episodes: [{ episode_number: 1 }] },
  });
  assert.deepEqual(await checkTitle(7, "tv", t.get, now), {
    kind: "show",
    releaseDate: "2026-11-02",
    eventData: {
      season_number: 3,
      episodes: [{ episode_number: 1 }],
      series_name: "Show",
      series_poster_path: "/p.jpg",
    },
    nextCheckHours: day,
  });
});

Deno.test("with no next episode, a season that just ended stays", async () => {
  // A whole season out at once: TMDB lists no next episode the day after.
  const t = tmdb({
    "/tv/7": {
      name: "Show",
      status: "Ended",
      next_episode_to_air: null,
      last_episode_to_air: { season_number: 2, air_date: "2026-10-01" },
    },
    "/tv/7/season/2": { season_number: 2 },
  });
  const check = await checkTitle(7, "tv", t.get, now);
  assert.equal(check.kind, "show");
  assert.deepEqual(t.asked, ["/tv/7", "/tv/7/season/2"]);
  if (check.kind === "show") assert.equal(check.releaseDate, "2026-10-01");
});

Deno.test("with nothing recent or coming, a series shows nothing", async () => {
  // Like Silo: a date TMDB no longer lists must not stay in the agenda.
  const series = (status: string) =>
    tmdb({
      "/tv/7": {
        status,
        next_episode_to_air: null,
        last_episode_to_air: { season_number: 2, air_date: "2025-06-01" },
      },
    }).get;
  assert.deepEqual(await checkTitle(7, "tv", series("Returning Series"), now), {
    kind: "nothing",
    nextCheckHours: day,
  });
  for (const status of ["Ended", "Canceled"]) {
    assert.deepEqual(await checkTitle(7, "tv", series(status), now), {
      kind: "nothing",
      nextCheckHours: week,
    });
  }
  assert.deepEqual(await checkTitle(8, "tv", series("Ended"), now), {
    kind: "nothing",
    nextCheckHours: week,
  });
});

Deno.test("a season TMDB doesn't know is a failure", async () => {
  const t = tmdb({
    "/tv/7": {
      next_episode_to_air: { season_number: 3, air_date: "2026-11-02" },
    },
  });
  await assert.rejects(
    checkTitle(7, "tv", t.get, now),
    /TMDB doesn't know \/tv\/7\/season\/3/,
  );
});
