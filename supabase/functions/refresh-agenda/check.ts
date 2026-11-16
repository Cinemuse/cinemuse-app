type Json = Record<string, unknown>;

/** A TMDB answer: its JSON, or null when TMDB doesn't know the path.
 * Throws on any other failure. */
export type TmdbGet = (path: string) => Promise<Json | null>;

/** What one title's check found. */
export type Check =
  | {
    kind: "show";
    releaseDate: string | null;
    eventData: Json;
    nextCheckHours: number;
  }
  | { kind: "nothing"; nextCheckHours: number };

export const day = 24;
export const week = 7 * day;

/** The agenda shows what airs from 30 days ago on. */
export function cutoff(now: Date): string {
  const d = new Date(now);
  d.setUTCDate(d.getUTCDate() - 30);
  return d.toISOString().slice(0, 10);
}

/** What the agenda keeps for one title, and when to look again.
 * - A movie: its details, unless it came out before the cutoff.
 * - A series: the season of its next episode or, with none announced, the
 *   season whose last episode aired after the cutoff (the agenda and the
 *   "bring a finished show back" logic both read it).
 * Titles with nothing to show, or unknown to TMDB, are checked again in a
 * week if they can't come back (old movie, ended series), else in a day. */
export async function checkTitle(
  tmdbId: number,
  mediaType: "movie" | "tv",
  tmdb: TmdbGet,
  now: Date,
): Promise<Check> {
  const from = cutoff(now);

  if (mediaType === "movie") {
    const movie = await tmdb(`/movie/${tmdbId}`);
    if (movie === null) return { kind: "nothing", nextCheckHours: week };
    const releaseDate = text(movie.release_date);
    if (releaseDate !== null && releaseDate < from) {
      return { kind: "nothing", nextCheckHours: week };
    }
    return { kind: "show", releaseDate, eventData: movie, nextCheckHours: day };
  }

  const series = await tmdb(`/tv/${tmdbId}`);
  if (series === null) return { kind: "nothing", nextCheckHours: week };
  const last = object(series.last_episode_to_air);
  const episode = object(series.next_episode_to_air) ??
    (last !== null && (text(last.air_date) ?? "") >= from ? last : null);
  if (episode === null) {
    const over = series.status === "Ended" || series.status === "Canceled";
    return { kind: "nothing", nextCheckHours: over ? week : day };
  }

  const path = `/tv/${tmdbId}/season/${episode.season_number}`;
  const season = await tmdb(path);
  if (season === null) throw new Error(`TMDB doesn't know ${path}`);
  return {
    kind: "show",
    releaseDate: text(episode.air_date),
    eventData: {
      ...season,
      series_name: series.name,
      series_poster_path: series.poster_path,
    },
    nextCheckHours: day,
  };
}

function text(value: unknown): string | null {
  return typeof value === "string" && value !== "" ? value : null;
}

function object(value: unknown): Json | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Json
    : null;
}
