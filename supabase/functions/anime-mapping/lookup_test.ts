// Run: deno test supabase/functions/anime-mapping
import assert from "node:assert/strict";
import known from "./known_cases.json" with { type: "json" };
import { pick, type Query } from "./lookup.ts";
import type { Row } from "./mapping.ts";

const fixtures = known.fixtures as unknown as Record<string, { rows: Row[] }>;

for (const c of known.cases) {
  Deno.test(`known case: ${c.name}`, () => {
    const ask = c.ask as {
      tmdb_id: number;
      type: "tv" | "movie";
      season?: number;
      episode?: number;
    };
    const query: Query = {
      tmdbId: ask.tmdb_id,
      type: ask.type,
      season: ask.season ?? null,
      episode: ask.episode ?? null,
    };

    assert.deepEqual(pick(query, fixtures[c.fixture].rows), c.answer);
  });
}

Deno.test("every known case names a fixture that exists", () => {
  for (const c of known.cases) assert.ok(fixtures[c.fixture], c.name);
});
