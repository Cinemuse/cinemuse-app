// Run: deno test supabase/functions/anime-mapping
import assert from "node:assert/strict";
import { corrections } from "./corrections.ts";
import {
  buildRows,
  type Correction,
  readAniBridge,
  readFribb,
  type Row,
} from "./mapping.ts";

// Tokyo Revengers (TMDB 105009) as the two lists had it on 2026-10-27:
// Fribb says only where each anime starts (the third one off by one),
// AniBridge says the exact episodes, the fourth anime's only through its
// AniDB id.
const fribb = [
  {
    type: "TV",
    anilist_id: 120120,
    anidb_id: 15601,
    kitsu_id: 43321,
    themoviedb_id: { tv: 105009 },
    tvdb_id: 393478,
    season: { tvdb: 1, tmdb: 1 },
  },
  {
    type: "TV",
    anilist_id: 142853,
    anidb_id: 17064,
    kitsu_id: 45607,
    themoviedb_id: { tv: 105009 },
    season: { tmdb: 1 },
    episode_offset: { tmdb: 24 },
  },
  {
    type: "TV",
    anilist_id: 163329,
    anidb_id: 17969,
    themoviedb_id: { tv: 105009 },
    season: { tmdb: 1 },
    episode_offset: { tmdb: 36 },
  },
  {
    type: "TV",
    anilist_id: 178083,
    anidb_id: 18693,
    themoviedb_id: { tv: 105009 },
    season: { tmdb: 1 },
    episode_offset: { tmdb: 50 },
  },
  { type: "MOVIE", anilist_id: 5, themoviedb_id: { movie: [77, 78] } },
  { type: "OVA", anidb_id: 1 },
  { type: "TV", anilist_id: 6, anidb_id: 2 },
];

const anibridge = {
  $meta: { schema_version: "3.0.3" },
  "anilist:120120": {},
  "anilist:142853": {},
  "anilist:163329": {},
  "anilist:178083": { "anidb:18693:R": { "1-13": "1-13" } },
  "anidb:18693:R": { "anilist:178083": { "1-13": "1-13" } },
  "tmdb_show:105009:s1": {
    "anilist:120120": { "1-24": "1-24" },
    "anilist:142853": { "25-37": "1-13" },
    "anilist:163329": { "38-50": "1-13" },
    "anidb:18693:R": { "51-55": "1-5" },
    "mal:42249": { "1-24": "1-24" },
    "tvdb_show:393478:s1": { "1-24": "1-24" },
  },
};

function build(
  fribbData: unknown,
  anibridgeData: unknown,
  fixes: Correction[] = [],
) {
  return buildRows(readFribb(fribbData), readAniBridge(anibridgeData), fixes);
}

function line(rows: Row[], anilistId: number) {
  return rows.find((r) => r.anilist_id === anilistId);
}

Deno.test("AniBridge's episodes are kept as they are", () => {
  const { rows } = build(fribb, anibridge);

  assert.deepEqual(line(rows, 163329), {
    anilist_id: 163329,
    anidb_id: 17969,
    tmdb_show_id: 105009,
    tmdb_episodes: [{ season: 1, first: 38, last: 50, anime_first: 1 }],
    placed_by: "anibridge",
  });
  assert.deepEqual(line(rows, 120120), {
    anilist_id: 120120,
    anidb_id: 15601,
    kitsu_id: 43321,
    tmdb_show_id: 105009,
    tvdb_id: 393478,
    tmdb_episodes: [{ season: 1, first: 1, last: 24, anime_first: 1 }],
    placed_by: "anibridge",
  });
});

Deno.test("an anime AniBridge links only through AniDB is found by it", () => {
  const { rows } = build(fribb, anibridge);

  assert.deepEqual(line(rows, 178083)?.tmdb_episodes, [
    { season: 1, first: 51, last: 55, anime_first: 1 },
  ]);
});

Deno.test("an AniDB link counts only when the AniList id has none", () => {
  const data = {
    "anilist:7": {},
    "anidb:70:R": { "anilist:7": { "1-12": "1-12" } },
    "tmdb_show:9:s1": {
      "anilist:7": { "1-12": "1-12" },
      "anidb:70:R": { "2-13": "1-12" },
    },
  };
  const { rows } = build([], data);

  assert.deepEqual(line(rows, 7)?.tmdb_episodes, [
    { season: 1, first: 1, last: 12, anime_first: 1 },
  ]);
  // The AniDB id comes from AniBridge when Fribb has none.
  assert.equal(line(rows, 7)?.anidb_id, 70);
});

Deno.test("an AniDB link finds its AniList id in Fribb too", () => {
  const data = { "tmdb_show:9:s1": { "anidb:2:R": { "1-12": "1-12" } } };
  const { rows } = build(fribb, data);

  assert.equal(line(rows, 6)?.tmdb_show_id, 9);
  assert.equal(line(rows, 6)?.placed_by, "anibridge");
});

Deno.test("pieces, open ends, single episodes and late starts", () => {
  const data = {
    "anilist:1": {},
    "tmdb_show:9:s1": { "anilist:1": { "3-22": "3-22" } },
    "tmdb_show:9:s0": { "anilist:1": { "2-3": "1-2" } },
    "tmdb_show:9:s2": { "anilist:2": { "41-": "1-" } },
    "tmdb_show:9:s3": { "anilist:3": { "36": "1" } },
  };
  const { rows } = build([], data);

  assert.deepEqual(line(rows, 1)?.tmdb_episodes, [
    { season: 0, first: 2, last: 3, anime_first: 1 },
    { season: 1, first: 3, last: 22, anime_first: 3 },
  ]);
  assert.deepEqual(line(rows, 2)?.tmdb_episodes, [
    { season: 2, first: 41, anime_first: 1 },
  ]);
  assert.deepEqual(line(rows, 3)?.tmdb_episodes, [
    { season: 3, first: 36, last: 36, anime_first: 1 },
  ]);
});

Deno.test("double episodes, lists and uneven runs are left out", () => {
  const data = {
    "tmdb_show:9:s1": {
      "anilist:1": { "1-26": "1-52|-2" },
      "anilist:2": { "1-6,8-13": "1-12" },
      "anilist:3": { "1-12": "1-13" },
      "anilist:4": { "1-": "1-12" },
      "anilist:5": { "1-12": "1-12" },
    },
  };
  const ab = readAniBridge(data);

  assert.equal(ab.skipped, 4);
  assert.deepEqual([...ab.byAnilist.keys()], [5]);
});

Deno.test("an anime in two TMDB shows is not placed", () => {
  const data = {
    "tmdb_show:9:s1": { "anilist:142853": { "1-13": "1-13" } },
    "tmdb_show:10:s1": { "anilist:142853": { "1-13": "1-13" } },
  };
  const { rows, notes } = build(fribb, data);

  assert.deepEqual(notes.manyShows, [142853]);
  // Its line keeps Fribb's show, with no episodes.
  assert.equal(line(rows, 142853)?.tmdb_show_id, 105009);
  assert.equal(line(rows, 142853)?.tmdb_episodes, undefined);
});

Deno.test("AniBridge's show wins over Fribb's", () => {
  const data = {
    "tmdb_show:105248:s2": { "anilist:142853": { "1-13": "1-13" } },
  };
  const { rows } = build(fribb, data);

  assert.equal(line(rows, 142853)?.tmdb_show_id, 105248);
});

Deno.test("Fribb places an anime only when it is alone in its season", () => {
  const alone = [
    {
      anilist_id: 1,
      themoviedb_id: { tv: 9 },
      season: { tmdb: 2 },
      episode_offset: { tmdb: 3 },
    },
    { anilist_id: 2, themoviedb_id: { tv: 9 }, season: { tmdb: 1 } },
    { anilist_id: 3, themoviedb_id: { tv: 9 }, season: { tmdb: 1 } },
    { anilist_id: 4, themoviedb_id: { tv: 9 }, season: { tmdb: 3 } },
    { anilist_id: 5, themoviedb_id: { tv: 9 } },
  ];
  // AniBridge places another anime in season 3.
  const data = { "tmdb_show:9:s3": { "anilist:6": { "1-12": "1-12" } } };
  const { rows } = build(alone, data);

  assert.deepEqual(line(rows, 1), {
    anilist_id: 1,
    tmdb_show_id: 9,
    tmdb_episodes: [{ season: 2, first: 4, anime_first: 1 }],
    placed_by: "fribb",
  });
  for (const id of [2, 3, 4, 5]) {
    assert.deepEqual(line(rows, id), { anilist_id: id, tmdb_show_id: 9 });
  }
});

Deno.test("a fix wins over both lists and is logged when they agree", () => {
  const fixes: Correction[] = [
    {
      anilistId: 163329,
      tmdbShowId: 105009,
      episodes: [{ season: 1, first: 38, last: 50, anime_first: 1 }],
      why: "agrees",
    },
    {
      anilistId: 142853,
      tmdbShowId: 105009,
      episodes: [{ season: 1, first: 26, last: 37, anime_first: 2 }],
      why: "made up",
    },
  ];
  const { rows, notes } = build(fribb, anibridge, fixes);

  assert.deepEqual(notes.agreed, [163329]);
  assert.equal(line(rows, 163329)?.placed_by, "fix");
  assert.deepEqual(line(rows, 142853)?.tmdb_episodes, fixes[1].episodes);
});

Deno.test("a fix's place keeps a Fribb anime from being alone", () => {
  const data = [
    { anilist_id: 1, themoviedb_id: { tv: 9 }, season: { tmdb: 1 } },
  ];
  const fixes: Correction[] = [{
    anilistId: 2,
    tmdbShowId: 9,
    episodes: [{ season: 1, first: 1, last: 12, anime_first: 1 }],
    why: "made up",
  }];
  const { rows } = build(data, {}, fixes);

  assert.equal(line(rows, 1)?.placed_by, undefined);
  assert.equal(line(rows, 2)?.placed_by, "fix");
});

Deno.test("lines: every anime with a TMDB or TheTVDB id, with Fribb's numbers", () => {
  const { rows } = build(fribb, anibridge);

  assert.deepEqual(rows.map((r) => r.anilist_id), [
    5,
    120120,
    142853,
    163329,
    178083,
  ]);
  assert.deepEqual(line(rows, 5), { anilist_id: 5, tmdb_movie_id: 77 });
  assert.equal(line(rows, 142853)?.kitsu_id, 45607);
});

Deno.test("ids written as strings or lists count, junk is skipped", () => {
  const data = [
    null,
    "junk",
    { anilist_id: "12", kitsu_id: "34", themoviedb_id: { tv: ["9", "10"] } },
    { anilist_id: "abc", themoviedb_id: { tv: 11 } },
  ];

  assert.deepEqual(build(data, "junk").rows, [
    { anilist_id: 12, kitsu_id: 34, tmdb_show_id: 9 },
  ]);
});

Deno.test("AniBridge's anime are counted by AniList id", () => {
  assert.equal(readAniBridge(anibridge).animeCount, 4);
  assert.equal(readFribb(fribb).size, 6);
});

Deno.test("every fix says why and where", () => {
  for (const c of corrections) {
    assert.ok(c.why.length > 20, `fix for ${c.anilistId} says why`);
    assert.ok(c.episodes.length > 0, `fix for ${c.anilistId} has episodes`);
  }
});
