import type { Row } from "./mapping.ts";

/** What the app asks: a TMDB title and, for a show, the episode. */
export interface Query {
  tmdbId: number;
  type: "tv" | "movie";
  season: number | null;
  episode: number | null;
}

/** The anime a TMDB title (or episode) is. */
export interface Match {
  anilist_id: number;
  anidb_id?: number;
  kitsu_id?: number;
  /** The anime's own episode; absent for a film or a show with no episode
   * asked. */
  episode?: number;
}

/** The answer to a query: whether the title is anime at all (it has lines,
 * even when none covers the episode) and the anime it is, if any. */
export interface Answer {
  is_anime: boolean;
  match: Match | null;
}

/** Picks the anime for a query among the title's lines (`candidates`, the
 * lines with its `tmdb_show_id` or `tmdb_movie_id`, by AniList id). The app's
 * own copy picks the same way when the server can't be reached; the shared
 * cases in `known_cases.json` keep the two the same.
 *
 * The rule: the first line whose TMDB episodes cover the episode. Nothing
 * is worked out: when no line covers it, there is no match, as a wrong
 * episode is worse than none. */
export function pick(query: Query, candidates: Row[]): Answer {
  if (candidates.length === 0) return { is_anime: false, match: null };
  return { is_anime: true, match: pickMatch(query, candidates) };
}

function pickMatch(
  { type, season, episode }: Query,
  candidates: Row[],
): Match | null {
  // A film (or a show with no episode picked) has no episode to get wrong.
  if (type === "movie" || season == null || episode == null) {
    return match(candidates[0]);
  }

  for (const row of candidates) {
    for (const p of row.tmdb_episodes ?? []) {
      if (
        p.season === season && episode >= p.first &&
        (p.last == null || episode <= p.last)
      ) {
        return match(row, episode - p.first + p.anime_first);
      }
    }
  }
  return null;
}

function match(row: Row, episode?: number): Match {
  const m: Match = { anilist_id: row.anilist_id };
  if (row.anidb_id != null) m.anidb_id = row.anidb_id;
  if (row.kitsu_id != null) m.kitsu_id = row.kitsu_id;
  if (episode != null) m.episode = episode;
  return m;
}
