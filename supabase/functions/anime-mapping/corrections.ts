import type { Correction } from "./mapping.ts";

/** Our fixes to both lists: they win over AniBridge and Fribb. Each one
 * names the anime (AniList id), its TMDB show, all its TMDB episodes, and
 * why, with a test in `mapping_test.ts`. The refresh logs a fix the lists
 * now agree with, so it can go. For example:
 *
 *   {
 *     anilistId: 163329,
 *     tmdbShowId: 105009,
 *     episodes: [{ season: 1, first: 38, last: 50, anime_first: 1 }],
 *     why: "Tokyo Revengers: Tenjiku-hen starts at TMDB S1 E38 (2023-10).",
 *   }
 */
export const corrections: Correction[] = [];
