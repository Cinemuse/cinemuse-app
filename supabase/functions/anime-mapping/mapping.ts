/** A run of TMDB episodes of one season that is one run of the anime's own
 * episodes: `{season: 1, first: 25, last: 37, anime_first: 1}` is TMDB S1
 * E25-E37 = the anime's episodes 1-13. No `last`: open at the end (still
 * airing). */
export interface Piece {
  season: number;
  first: number;
  last?: number;
  anime_first: number;
}

/** Who placed an anime's TMDB episodes. */
export type PlacedBy = "anibridge" | "fribb" | "fix";

/** One line of the list: one anime with its numbers on every site and,
 * when a list states them, its exact TMDB episodes. */
export interface Row {
  anilist_id: number;
  anidb_id?: number;
  kitsu_id?: number;
  tmdb_show_id?: number;
  tmdb_movie_id?: number;
  tvdb_id?: number;
  tmdb_episodes?: Piece[];
  placed_by?: PlacedBy;
}

/** Our fix to both lists: where an anime really is on TMDB. */
export interface Correction {
  anilistId: number;
  tmdbShowId: number;
  episodes: Piece[];
  why: string;
}

/** One anime of Fribb's list. */
export interface FribbEntry {
  anilistId: number;
  anidbId: number | null;
  kitsuId: number | null;
  tmdbShowId: number | null;
  tmdbMovieId: number | null;
  tvdbId: number | null;
  tmdbSeason: number | null;
  /** TMDB episodes of the season before this anime starts. */
  tmdbOffset: number;
}

/** An anime's TMDB episodes in AniBridge's list, all in one show. */
export interface Placement {
  tmdbShowId: number;
  episodes: Piece[];
}

/** What the build keeps of AniBridge's list. */
export interface AniBridge {
  /** By AniList id, and by AniDB id for the links AniBridge makes only
   * through AniDB (Tokyo Revengers' fourth anime). Pieces of several TMDB
   * shows stay apart here; `buildRows` drops such an anime. */
  byAnilist: Map<number, Map<number, Piece[]>>;
  byAnidb: Map<number, Map<number, Piece[]>>;
  /** AniBridge's own AniDB → AniList links. */
  anilistOfAnidb: Map<number, number>;
  /** How many anime (AniList ids) the list has. */
  animeCount: number;
  /** Links left out: double episodes, lists of episodes, runs of another
   * length on each side. */
  skipped: number;
}

/** Reads Fribb's `anime-list-full.json`: the anime with an AniList id. */
export function readFribb(data: unknown): Map<number, FribbEntry> {
  const entries = new Map<number, FribbEntry>();
  for (const value of Array.isArray(data) ? data : []) {
    if (!isObject(value)) continue;
    const anilistId = toInt(value.anilist_id);
    if (anilistId == null) continue;

    const tmdb = isObject(value.themoviedb_id) ? value.themoviedb_id : {};
    const season = isObject(value.season) ? value.season : {};
    const offset = isObject(value.episode_offset) ? value.episode_offset : {};
    entries.set(anilistId, {
      anilistId,
      anidbId: toInt(value.anidb_id),
      kitsuId: toInt(value.kitsu_id),
      tmdbShowId: toInt(tmdb.tv),
      tmdbMovieId: toInt(tmdb.movie),
      tvdbId: toInt(value.tvdb_id),
      tmdbSeason: toInt(season.tmdb),
      tmdbOffset: toInt(offset.tmdb) ?? 0,
    });
  }
  return entries;
}

/** Reads AniBridge's `mappings.min.json` (schema v3). Its TMDB side reads
 * `"tmdb_show:105009:s1": {"anilist:142853": {"25-37": "1-13"}}`: TMDB S1
 * E25-E37 are that anime's episodes 1-13. */
export function readAniBridge(data: unknown): AniBridge {
  const result: AniBridge = {
    byAnilist: new Map(),
    byAnidb: new Map(),
    anilistOfAnidb: new Map(),
    animeCount: 0,
    skipped: 0,
  };
  if (!isObject(data)) return result;

  for (const [source, targets] of Object.entries(data)) {
    if (!isObject(targets)) continue;
    if (/^anilist:\d+$/.test(source)) result.animeCount++;

    const anidb = /^anidb:(\d+):R$/.exec(source);
    if (anidb) {
      for (const target of Object.keys(targets)) {
        const anilist = /^anilist:(\d+)$/.exec(target);
        if (anilist) {
          result.anilistOfAnidb.set(Number(anidb[1]), Number(anilist[1]));
        }
      }
      continue;
    }

    const tmdb = /^tmdb_show:(\d+):s(\d+)$/.exec(source);
    if (!tmdb) continue;
    const show = Number(tmdb[1]);
    const season = Number(tmdb[2]);
    for (const [target, ranges] of Object.entries(targets)) {
      const anilist = /^anilist:(\d+)$/.exec(target);
      const anidb = /^anidb:(\d+):R$/.exec(target);
      const into = anilist ? result.byAnilist : anidb ? result.byAnidb : null;
      if (into == null || !isObject(ranges)) continue;
      const id = Number((anilist ?? anidb)![1]);

      for (const [tmdbRun, animeRun] of Object.entries(ranges)) {
        const piece = typeof animeRun === "string"
          ? readPiece(season, tmdbRun, animeRun)
          : null;
        if (piece == null) {
          result.skipped++;
          continue;
        }
        const shows = into.get(id) ?? new Map<number, Piece[]>();
        const pieces = shows.get(show) ?? [];
        pieces.push(piece);
        shows.set(show, pieces);
        into.set(id, shows);
      }
    }
  }
  return result;
}

/** `"25-37"`, `"1-13"` → a piece; `"41-"`, `"1-"` → an open one; `"36"`,
 * `"1"` → one episode. Null for what a piece can't say: double episodes
 * (`|`), lists (`,`), or runs of another length on each side. */
function readPiece(
  season: number,
  tmdbRun: string,
  animeRun: string,
): Piece | null {
  const tmdb = readRun(tmdbRun);
  const anime = readRun(animeRun);
  if (tmdb == null || anime == null) return null;
  if ((tmdb.last == null) !== (anime.last == null)) return null;
  if (
    tmdb.last != null && anime.last != null &&
    tmdb.last - tmdb.first !== anime.last - anime.first
  ) {
    return null;
  }
  const piece: Piece = { season, first: tmdb.first, anime_first: anime.first };
  if (tmdb.last != null) piece.last = tmdb.last;
  return piece;
}

function readRun(run: string): { first: number; last?: number } | null {
  const m = /^(\d+)(?:(-)(\d*))?$/.exec(run);
  if (!m) return null;
  const first = Number(m[1]);
  if (m[2] == null) return { first, last: first };
  if (m[3] === "") return { first };
  const last = Number(m[3]);
  return last < first ? null : { first, last };
}

/** What the build did besides the rows, for the refresh's log. */
export interface BuildNotes {
  /** Fixes that now say the same as the lists: they can go. */
  agreed: number[];
  /** Anime AniBridge puts in more than one TMDB show: not placed. */
  manyShows: number[];
}

/** Builds the list's lines. Nothing is worked out: the TMDB episodes are
 * AniBridge's as they are (by AniList id; through the AniDB id only when
 * AniBridge links the AniList id to no TMDB show), our fixes win over it,
 * and an anime AniBridge doesn't place takes Fribb's start only when it is
 * alone in its TMDB season (open at the end). A line holds every anime
 * with a TMDB show, a TMDB film or a TheTVDB id. */
export function buildRows(
  fribb: Map<number, FribbEntry>,
  anibridge: AniBridge,
  fixes: Correction[],
): { rows: Row[]; notes: BuildNotes } {
  const notes: BuildNotes = { agreed: [], manyShows: [] };

  // 1. AniBridge's places.
  const placed = new Map<number, Placement & { by: PlacedBy }>();
  const fribbAnilistOfAnidb = new Map<number, number>();
  for (const e of fribb.values()) {
    if (e.anidbId != null && !fribbAnilistOfAnidb.has(e.anidbId)) {
      fribbAnilistOfAnidb.set(e.anidbId, e.anilistId);
    }
  }
  const throughAnidb = new Map<number, Map<number, Piece[]>>();
  for (const [anidbId, shows] of anibridge.byAnidb) {
    const anilistId = anibridge.anilistOfAnidb.get(anidbId) ??
      fribbAnilistOfAnidb.get(anidbId);
    if (anilistId == null || anibridge.byAnilist.has(anilistId)) continue;
    throughAnidb.set(anilistId, shows);
  }
  for (const source of [anibridge.byAnilist, throughAnidb]) {
    for (const [anilistId, shows] of source) {
      if (shows.size > 1) {
        notes.manyShows.push(anilistId);
        continue;
      }
      const [[tmdbShowId, episodes]] = [...shows];
      placed.set(anilistId, {
        tmdbShowId,
        episodes: [...episodes].sort(byPlace),
        by: "anibridge",
      });
    }
  }

  // 2. Our fixes win.
  for (const fix of fixes) {
    const listed = placed.get(fix.anilistId);
    const episodes = [...fix.episodes].sort(byPlace);
    if (
      listed != null && listed.tmdbShowId === fix.tmdbShowId &&
      listed.episodes.length === episodes.length &&
      listed.episodes.every((p, i) => samePiece(p, episodes[i]))
    ) {
      notes.agreed.push(fix.anilistId);
    }
    placed.set(fix.anilistId, {
      tmdbShowId: fix.tmdbShowId,
      episodes,
      by: "fix",
    });
  }

  // 3. Fribb's start, for an anime alone in its TMDB season.
  const inSeason = new Map<string, number>();
  const count = (key: string) =>
    inSeason.set(key, (inSeason.get(key) ?? 0) + 1);
  for (const e of fribb.values()) {
    if (
      e.tmdbShowId != null && e.tmdbSeason != null && !placed.has(e.anilistId)
    ) {
      count(`${e.tmdbShowId}:${e.tmdbSeason}`);
    }
  }
  for (const p of placed.values()) {
    for (const s of new Set(p.episodes.map((e) => e.season))) {
      count(`${p.tmdbShowId}:${s}`);
    }
  }
  for (const e of fribb.values()) {
    if (
      e.tmdbShowId == null || e.tmdbSeason == null || placed.has(e.anilistId)
    ) {
      continue;
    }
    if (inSeason.get(`${e.tmdbShowId}:${e.tmdbSeason}`) !== 1) continue;
    placed.set(e.anilistId, {
      tmdbShowId: e.tmdbShowId,
      episodes: [{
        season: e.tmdbSeason,
        first: e.tmdbOffset + 1,
        anime_first: 1,
      }],
      by: "fribb",
    });
  }

  // 4. The lines.
  const anidbOfAnilist = new Map<number, number>();
  for (const [anidbId, anilistId] of anibridge.anilistOfAnidb) {
    if (!anidbOfAnilist.has(anilistId)) anidbOfAnilist.set(anilistId, anidbId);
  }
  const ids = new Set([...fribb.keys(), ...placed.keys()]);
  const rows: Row[] = [];
  for (const anilistId of [...ids].sort((a, b) => a - b)) {
    const e = fribb.get(anilistId);
    const p = placed.get(anilistId);
    const tmdbShowId = p?.tmdbShowId ?? e?.tmdbShowId ?? null;
    if (tmdbShowId == null && e?.tmdbMovieId == null && e?.tvdbId == null) {
      continue;
    }

    const row: Row = { anilist_id: anilistId };
    const anidbId = e?.anidbId ?? anidbOfAnilist.get(anilistId);
    if (anidbId != null) row.anidb_id = anidbId;
    if (e?.kitsuId != null) row.kitsu_id = e.kitsuId;
    if (tmdbShowId != null) row.tmdb_show_id = tmdbShowId;
    if (e?.tmdbMovieId != null) row.tmdb_movie_id = e.tmdbMovieId;
    if (e?.tvdbId != null) row.tvdb_id = e.tvdbId;
    if (p != null) {
      row.tmdb_episodes = p.episodes;
      row.placed_by = p.by;
    }
    rows.push(row);
  }
  return { rows, notes };
}

function samePiece(a: Piece, b: Piece): boolean {
  return a.season === b.season && a.first === b.first &&
    a.last === b.last && a.anime_first === b.anime_first;
}

/** Season first, then the first TMDB episode. */
function byPlace(a: Piece, b: Piece): number {
  return a.season - b.season || a.first - b.first;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Fribb writes ids as numbers, strings or lists (the first one counts). */
function toInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isInteger(value)) return value;
  if (typeof value === "string" && /^\d+$/.test(value)) return Number(value);
  if (Array.isArray(value) && value.length > 0) return toInt(value[0]);
  return null;
}
