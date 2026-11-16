// Run: deno test supabase/functions/live-tv
import assert from "node:assert/strict";
import type { Channel } from "./channels.ts";
import {
  buildGuide,
  dueSource,
  type Guide,
  type Shown,
  sourceChannels,
} from "./guide.ts";
import type { Programme } from "./readers.ts";

const now = new Date("2026-10-24T12:00:00Z");
const t = now.getTime();
const hour = 3_600_000;

const rai1: Channel = {
  key: "rai1",
  name: "Rai 1",
  lcn: 1,
  category: "",
  logo: "",
  streams: [["rai", "1"]],
  guide: [["rai", "rai-1"], ["sky", "6601", "DTT"], ["iptv_epg", "Rai1.it"]],
};
const tv8: Channel = {
  key: "tv8",
  name: "TV8",
  lcn: null,
  category: "",
  logo: "",
  streams: [["sky", "7"]],
  guide: [["sky", "8327", "DTT"]],
};

/** Back-to-back programmes on `ref`, from `fromHours` to `toHours` from
 * now, each `lengthMinutes` long (default 50: not a placeholder). */
function rows(
  ref: string,
  fromHours: number,
  toHours: number,
  title = "Show",
  lengthMinutes = 50,
): Programme[] {
  const out: Programme[] = [];
  for (
    let s = t + fromHours * hour;
    s < t + toHours * hour;
    s += lengthMinutes * 60_000
  ) {
    out.push({
      ref,
      start: new Date(s).toISOString(),
      stop: new Date(s + lengthMinutes * 60_000).toISOString(),
      title,
    });
  }
  return out;
}

function shown(fromHours: number, toHours: number, title: string): Shown[] {
  return rows("x", fromHours, toHours, title).map((r) => ({
    name: r.title,
    startTime: { unix: Date.parse(r.start) },
    endTime: { unix: Date.parse(r.stop) },
  }));
}

function titles(guide: Guide, key: string): string[] {
  return [...new Set((guide[key] as Shown[]).map((p) => p.name))];
}

Deno.test("dueSource: never tried first, then the one tried longest ago; recent ones skipped", () => {
  assert.equal(dueSource(null, now), "rai");

  const fresh = new Date(t - hour).toISOString();
  const sources: Record<string, unknown> = {};
  for (
    const key of [
      "rai",
      "mediaset",
      "sky",
      "discovery",
      "iptv_epg",
      "open_epg_3",
      "open_epg_8",
    ]
  ) {
    sources[key] = { tried: fresh, refreshed: fresh };
  }
  const old = { status: { sources } } as Guide;
  assert.equal(dueSource(old, now), null);

  // Two due: the one tried longest ago; one failing (tried, never refreshed).
  sources.sky = {
    tried: new Date(t - 30 * hour).toISOString(),
    refreshed: new Date(t - 30 * hour).toISOString(),
  };
  sources.rai = {
    tried: new Date(t - 2 * hour).toISOString(),
    error: "status 500",
  };
  assert.equal(dueSource(old, now), "sky");
  sources.sky = {
    tried: new Date(t - hour).toISOString(),
    refreshed: new Date(t - 30 * hour).toISOString(),
  };
  assert.equal(dueSource(old, now), "rai");
});

Deno.test("sourceChannels: each id once, with Sky's list", () => {
  assert.deepEqual(
    sourceChannels("sky", [rai1, tv8, { ...tv8, key: "tv8b" }]),
    [
      { id: "6601", env: "DTT" },
      { id: "8327", env: "DTT" },
    ],
  );
  assert.deepEqual(sourceChannels("rai", [rai1, tv8]), [{
    id: "rai-1",
    env: undefined,
  }]);
});

Deno.test("a channel's first good source wins; names, numbers and sources in 'channels'", () => {
  const guide = buildGuide(
    null,
    "sky",
    {
      rows: [
        ...rows("6601", -1, 72, "Sky show"),
        ...rows("8327", -1, 72, "TV8 show"),
      ],
      failed: [],
    },
    now,
    [rai1, tv8],
  );
  assert.deepEqual(titles(guide, "rai1"), ["Sky show"]);
  assert.deepEqual(guide.channels, {
    rai1: { name: "Rai 1", lcn: 1, source: "sky" },
    tv8: { name: "TV8", source: "sky" },
  });
  assert.deepEqual(guide.status, {
    sources: {
      sky: {
        tried: now.toISOString(),
        refreshed: now.toISOString(),
        error: null,
      },
    },
  });

  // Rai (first) read the next call: it takes over.
  const next = buildGuide(
    guide,
    "rai",
    { rows: rows("rai-1", -1, 100, "Rai show"), failed: [] },
    now,
    [rai1, tv8],
  );
  assert.deepEqual(titles(next, "rai1"), ["Rai show"]);
  assert.equal(next.channels!.rai1.source, "rai");
  // TV8 keeps its programmes from the file.
  assert.deepEqual(titles(next, "tv8"), ["TV8 show"]);
  assert.equal(next.channels!.tv8.source, "sky");
  assert.ok(next.status!.sources!.sky.refreshed);
});

Deno.test("a later source doesn't replace a good first one kept in the file", () => {
  const old: Guide = {
    rai1: shown(-1, 100, "Rai show"),
    channels: { rai1: { name: "Rai 1", source: "rai" } },
  };
  const guide = buildGuide(
    old,
    "iptv_epg",
    { rows: rows("Rai1.it", -1, 200, "Feed"), failed: [] },
    now,
    [rai1],
  );
  assert.deepEqual(titles(guide, "rai1"), ["Rai show"]);
});

Deno.test("no good source: the one reaching furthest; a placeholder never", () => {
  const guide = buildGuide(
    {
      rai1: shown(-1, 20, "Rai short"),
      channels: { rai1: { name: "Rai 1", source: "rai" } },
    },
    "sky",
    { rows: rows("6601", -1, 30, "Sky longer"), failed: [] },
    now,
    [rai1],
  );
  assert.deepEqual(titles(guide, "rai1"), ["Sky longer"]);

  // One-hour blocks on the hour: filler, even if it reaches furthest.
  const filler = buildGuide(
    {
      rai1: shown(-1, 20, "Rai short"),
      channels: { rai1: { name: "Rai 1", source: "rai" } },
    },
    "iptv_epg",
    { rows: rows("Rai1.it", -12, 200, "Filler", 60), failed: [] },
    now,
    [rai1],
  );
  assert.deepEqual(titles(filler, "rai1"), ["Rai short"]);
});

Deno.test("a failed source keeps its part of the file; the error is in 'status'", () => {
  const old: Guide = {
    rai1: shown(-1, 100, "Rai show"),
    channels: { rai1: { name: "Rai 1", source: "rai" } },
    status: {
      sources: {
        rai: {
          tried: "2026-10-23T12:00:00.000Z",
          refreshed: "2026-10-23T12:00:00.000Z",
          error: null,
        },
      },
    },
  };
  const guide = buildGuide(
    old,
    "rai",
    { rows: [], failed: ["status 503"] },
    now,
    [rai1],
  );
  assert.deepEqual(titles(guide, "rai1"), ["Rai show"]);
  assert.deepEqual(guide.status!.sources!.rai, {
    tried: now.toISOString(),
    refreshed: "2026-10-23T12:00:00.000Z",
    error: "status 503",
  });

  // Some channels read: refreshed, the others named in the error.
  const some = buildGuide(
    old,
    "rai",
    { rows: rows("rai-1", -1, 100), failed: ["rai-2: status 404"] },
    now,
    [rai1],
  );
  assert.deepEqual(some.status!.sources!.rai, {
    tried: now.toISOString(),
    refreshed: now.toISOString(),
    error: "rai-2: status 404",
  });
});

Deno.test("a fresh copy keeps the file's earlier programmes from the same source", () => {
  const old: Guide = {
    rai1: [...shown(-20, -2, "Yesterday"), ...shown(-2, 100, "Old plan")],
    channels: { rai1: { name: "Rai 1", source: "rai" } },
  };
  const guide = buildGuide(
    old,
    "rai",
    { rows: rows("rai-1", -2, 100, "New plan"), failed: [] },
    now,
    [rai1],
  );
  assert.deepEqual(titles(guide, "rai1"), ["Yesterday", "New plan"]);

  // From another source: nothing of the old one is mixed in.
  const other = buildGuide(
    {
      ...old,
      rai1: [...shown(-20, -2, "Yesterday"), ...shown(-2, 10, "Old plan")],
    },
    "sky",
    { rows: rows("6601", -2, 100, "Sky plan"), failed: [] },
    now,
    [rai1],
  );
  assert.deepEqual(titles(other, "rai1"), ["Sky plan"]);
});

Deno.test("served: a day back to 8 days ahead, sorted, one per start, no empty titles", () => {
  const guide = buildGuide(
    null,
    "rai",
    {
      rows: [
        ...rows("rai-1", 0, 72, "Show"),
        {
          ref: "rai-1",
          start: new Date(t - 30 * hour).toISOString(),
          stop: new Date(t - 29 * hour).toISOString(),
          title: "Too old",
        },
        {
          ref: "rai-1",
          start: new Date(t + 9 * 24 * hour).toISOString(),
          stop: new Date(t + 9 * 24 * hour + hour).toISOString(),
          title: "Too far",
        },
        {
          ref: "rai-1",
          start: new Date(t - hour).toISOString(),
          stop: new Date(t).toISOString(),
          title: "",
        },
        {
          ref: "rai-1",
          start: new Date(t).toISOString(),
          stop: new Date(t + 10 * 60_000).toISOString(),
          title: "Shorter twin",
        },
      ],
      failed: [],
    },
    now,
    [rai1],
  );
  const list = guide.rai1 as Shown[];
  assert.deepEqual(titles(guide, "rai1"), ["Show"]);
  assert.equal(list[0].startTime.unix, t);
  assert.ok(
    list.every((p, i) =>
      i === 0 || p.startTime.unix > list[i - 1].startTime.unix
    ),
  );
  // Empty fields aren't written.
  assert.deepEqual(Object.keys(JSON.parse(JSON.stringify(list[0]))).sort(), [
    "endTime",
    "name",
    "startTime",
  ]);
});

Deno.test("a channel with no source: in 'channels', no programmes", () => {
  const guide = buildGuide(
    null,
    "rai",
    { rows: [], failed: ["status 500"] },
    now,
    [rai1],
  );
  assert.equal(guide.rai1, undefined);
  assert.deepEqual(guide.channels, { rai1: { name: "Rai 1", lcn: 1 } });
});
