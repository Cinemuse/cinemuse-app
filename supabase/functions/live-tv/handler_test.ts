// Run: deno test supabase/functions/live-tv
import assert from "node:assert/strict";
import {
  browserUserAgent,
  type Channel,
  channels,
  guideSources,
  linkServices,
} from "./channels.ts";
import { buildM3u, type Deps, handle } from "./handler.ts";
import type { Guide } from "./guide.ts";

const base = "https://project.test";
const now = new Date("2026-10-24T12:00:00Z");

const testChannels: Channel[] = [
  {
    key: "rai1",
    name: "Rai 1",
    lcn: 1,
    category: "Nazionali",
    logo: "rai1.png",
    streams: [
      ["rai", "2606803"],
      ["rai_backup", "2606803"],
      ["url", "https://relay.test/rai1.m3u8", "Relay"],
    ],
    guide: [["iptv_epg", "Rai1.it"]],
  },
  {
    key: "c5",
    name: 'Canale "5"',
    lcn: 5,
    category: "",
    logo: "canale 5.png",
    streams: [["mediaset", "c5"]],
    guide: [],
  },
  {
    key: "tv2000",
    name: "TV2000",
    lcn: null,
    category: "Nazionali",
    logo: "",
    streams: [["url", "https://tv2000.test/master.m3u8", "TV2000"]],
    guide: [],
  },
  {
    key: "la7cinema",
    name: "La7 Cinema",
    lcn: 29,
    category: "Cinema",
    logo: "",
    streams: [],
    guide: [],
  },
];

/** Every source but iptv_epg read an hour ago: only iptv_epg is due. */
function onlyFeedDue(): Guide {
  const fresh = new Date(now.getTime() - 3_600_000).toISOString();
  const sources: Record<string, { tried: string; refreshed: string }> = {};
  for (const key of Object.keys(guideSources)) {
    if (key !== "iptv_epg") sources[key] = { tried: fresh, refreshed: fresh };
  }
  return { status: { sources } };
}

/** The bucket and the feed as the function sees them. */
class Fake {
  files = new Map<string, string>();
  written: { name: string; type: string; cache: string }[] = [];
  readStatus = 200;
  feed =
    `<tv><programme start="20261024110000 +0000" stop="20261024120000 +0000" channel="Rai1.it"><title>Tg1</title></programme>` +
    `<programme start="20261024120000 +0000" stop="20261026150000 +0000" channel="Rai1.it"><title>Long show</title></programme></tv>`;

  deps(): Deps {
    return {
      supabaseUrl: base,
      serviceKey: "service",
      now: () => now,
      channels: testChannels,
      fetch: (input, init) => Promise.resolve(this.answer(input, init)),
    };
  }

  answer(input: RequestInfo | URL, init?: RequestInit): Response {
    const url = new URL(input.toString());
    if (url.href === guideSources.iptv_epg.address) {
      return new Response(this.feed);
    }
    assert.equal(url.origin, base);
    const headers = new Headers(init?.headers);
    assert.equal(headers.get("Authorization"), "Bearer service");
    const name = url.pathname.replace("/storage/v1/object/livetv/", "");
    if ((init?.method ?? "GET") === "GET") {
      if (this.readStatus !== 200) {
        return new Response("boom", { status: this.readStatus });
      }
      const file = this.files.get(name);
      return file == null
        ? Response.json({
          statusCode: "404",
          error: "not_found",
          message: "Object not found",
        }, { status: 400 })
        : new Response(file);
    }
    assert.equal(headers.get("x-upsert"), "true");
    this.files.set(name, init!.body as string);
    this.written.push({
      name,
      type: headers.get("Content-Type")!,
      cache: headers.get("Cache-Control")!,
    });
    return Response.json({ Key: `livetv/${name}` });
  }
}

function post(): Request {
  return new Request(`${base}/functions/v1/live-tv`, { method: "POST" });
}

Deno.test("only POST", async () => {
  const fake = new Fake();
  const res = await handle(
    new Request(`${base}/functions/v1/live-tv/epg.json`),
    fake.deps(),
  );
  assert.equal(res.status, 405);
  assert.equal(fake.written.length, 0);
});

Deno.test("POST: writes the playlist when it changed and the due source into the guide", async () => {
  const fake = new Fake();
  fake.files.set("epg.json", JSON.stringify(onlyFeedDue()));
  const res = await handle(post(), fake.deps());
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), {
    playlist: "written",
    source: "iptv_epg",
    programmes: 2,
    failed: [],
  });
  assert.deepEqual(fake.written, [
    {
      name: "playlist.m3u",
      type: "application/vnd.apple.mpegurl; charset=utf-8",
      cache: "max-age=300",
    },
    {
      name: "epg.json",
      type: "application/json; charset=utf-8",
      cache: "max-age=1800",
    },
  ]);
  const guide = JSON.parse(fake.files.get("epg.json")!);
  assert.deepEqual(guide.rai1.map((p: { name: string }) => p.name), [
    "Tg1",
    "Long show",
  ]);
  assert.equal(guide.channels.rai1.source, "iptv_epg");
  assert.equal(guide.status.sources.iptv_epg.refreshed, now.toISOString());
  assert.ok(guide.status.sources.rai.refreshed);

  // The same list again: the playlist isn't rewritten; nothing is due.
  fake.written = [];
  const again = await handle(post(), fake.deps());
  assert.deepEqual(await again.json(), { playlist: "same", source: null });
  assert.deepEqual(fake.written, []);
});

Deno.test("POST: an empty bucket starts from the first source", async () => {
  const fake = new Fake();
  const res = await handle(post(), fake.deps());
  // `rai` comes first; no test channel uses it, so it reads nothing.
  assert.deepEqual(await res.json(), {
    playlist: "written",
    source: "rai",
    programmes: 0,
    failed: [],
  });
  const guide = JSON.parse(fake.files.get("epg.json")!);
  assert.equal(guide.status.sources.rai.error, "no programmes");
  assert.equal(guide.status.sources.rai.refreshed, undefined);
});

Deno.test("POST: an old guide that isn't JSON is started again", async () => {
  const fake = new Fake();
  fake.files.set("epg.json", "{broken");
  const res = await handle(post(), fake.deps());
  assert.equal((await res.json()).source, "rai");
});

Deno.test("POST: a bucket that can't be read writes nothing", async () => {
  const fake = new Fake();
  fake.readStatus = 500;
  const res = await handle(post(), fake.deps());
  assert.equal(res.status, 502);
  assert.deepEqual(fake.written, []);
});

Deno.test("the playlist: by number, one line per stream in order, sources and ask labels, player names, logos in the bucket, guide-only channels left out", () => {
  const rai1 =
    `#EXTINF:-1 tvg-id="rai1" tvg-chno="1" tvg-name="Rai 1" tvg-logo="${base}/storage/v1/object/public/livetv/logos/rai1.png" group-title="Nazionali"`;
  assert.equal(
    buildM3u(testChannels, base),
    [
      "#EXTM3U",
      `${rai1} provider="Rai" cinemuse-ask="rai",Rai 1`,
      "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=2606803&output=63&forceUserAgent=raiplayappletv",
      `${rai1} provider="Rai (backup)" cinemuse-ask="rai",Rai 1`,
      "https://mediapolisevent.rai.it/relinker/relinkerServlet.htm?cont=2606803&output=63&forceUserAgent=raiplayappletv",
      `${rai1} provider="Relay",Rai 1`,
      "https://relay.test/rai1.m3u8",
      `#EXTINF:-1 tvg-id="c5" tvg-chno="5" tvg-name="Canale '5'" tvg-logo="${base}/storage/v1/object/public/livetv/logos/canale%205.png" provider="Mediaset",Canale "5"`,
      `#EXTVLCOPT:http-user-agent=${browserUserAgent}`,
      "https://live02-seg.msf.cdn.mediaset.net/live/ch-c5/c5-clr.isml/index.m3u8",
      `#EXTINF:-1 tvg-id="tv2000" tvg-name="TV2000" group-title="Nazionali" provider="TV2000",TV2000`,
      "https://tv2000.test/master.m3u8",
      "",
    ].join("\n"),
  );
});

Deno.test("the channel list: unique keys, none named like the guide's extra entries, known sources", () => {
  const keys = channels.map((c) => c.key);
  assert.equal(new Set(keys).size, keys.length);
  for (const c of channels) {
    assert.match(c.key, /^[a-z0-9_]+$/);
    assert.ok(!["channels", "status"].includes(c.key), c.key);
    const providers = new Set<string>();
    for (const stream of c.streams) {
      if (stream[0] === "url") {
        assert.equal(stream.length, 3, c.key);
        assert.match(stream[1], /^https:\/\/\S+$/, c.key);
        assert.ok(stream[2] !== "", c.key);
        providers.add(stream[2]);
      } else {
        assert.equal(stream.length, 2, c.key);
        assert.ok(stream[0] in linkServices, `${c.key}: ${stream[0]}`);
        providers.add(linkServices[stream[0]].provider);
      }
    }
    // The Source list tells them apart.
    assert.equal(providers.size, c.streams.length, c.key);
    for (const [source] of c.guide) {
      assert.ok(source in guideSources, `${c.key}: ${source}`);
    }
  }
  // Mediaset turns the app's VLC name away; no other service needs a name.
  for (const [key, service] of Object.entries(linkServices)) {
    const wanted = key.startsWith("mediaset") ? browserUserAgent : null;
    assert.equal(service.userAgent, wanted, key);
  }
  assert.equal(channels.filter((c) => c.streams.length > 0).length, 63);
  assert.equal(channels.flatMap((c) => c.streams).length, 94);
});
