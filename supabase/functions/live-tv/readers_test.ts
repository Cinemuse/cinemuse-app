// Run: deno test supabase/functions/live-tv
import assert from "node:assert/strict";
import {
  discoveryProgrammes,
  fill,
  mediasetProgrammes,
  raiProgrammes,
  readSource,
  romeDate,
  romeToUtc,
  skyProgrammes,
  xmltvProgrammes,
  xmltvTime,
} from "./readers.ts";

Deno.test("Italian time: summer, winter and the night the clocks go back", () => {
  assert.equal(
    romeToUtc(2026, 10, 24, 20, 35).toISOString(),
    "2026-10-24T18:35:00.000Z",
  );
  assert.equal(
    romeToUtc(2026, 10, 26, 20, 35).toISOString(),
    "2026-10-26T19:35:00.000Z",
  );
  // 02:30 happens twice on 25 October: the first one (still summer time).
  assert.equal(
    romeToUtc(2026, 10, 25, 2, 30).toISOString(),
    "2026-10-25T00:30:00.000Z",
  );
  assert.equal(
    romeToUtc(2026, 10, 25, 3, 0).toISOString(),
    "2026-10-25T02:00:00.000Z",
  );
  // 02:30 doesn't exist on 29 March: read as winter time.
  assert.equal(
    romeToUtc(2026, 3, 29, 2, 30).toISOString(),
    "2026-03-29T01:30:00.000Z",
  );
});

Deno.test("today's date is Italy's, not UTC's", () => {
  assert.deepEqual(romeDate(new Date("2026-10-24T22:30:00Z")), {
    y: 2026,
    m: 10,
    d: 25,
  });
});

Deno.test("Rai: Italian date and hour plus a duration; relative images", () => {
  const rows = raiProgrammes("rai-1", {
    events: [
      {
        name: "Affari tuoi",
        episode_title: "",
        description: "Gioco",
        date: "24/10/2026",
        hour: "20:35",
        duration: "00:55:00",
        image: "/dl/img/a.jpg",
      },
      // Broken rows are skipped, not fatal.
      { name: "No time", date: "24/10/2026", hour: "", duration: "00:10:00" },
      { name: "", date: "24/10/2026", hour: "21:30", duration: "00:10:00" },
    ],
  });
  assert.deepEqual(rows, [{
    ref: "rai-1",
    start: "2026-10-24T18:35:00.000Z",
    stop: "2026-10-24T19:30:00.000Z",
    title: "Affari tuoi",
    subtitle: undefined,
    description: "Gioco",
    image: "https://www.raiplay.it/dl/img/a.jpg",
  }]);
  assert.throws(() => raiProgrammes("rai-1", { error: "x" }), /no events/);
});

Deno.test("Mediaset: times in ms, the trailing dash dropped, an empty period", () => {
  const rows = mediasetProgrammes("C5", {
    response: {
      entries: [{
        listings: [{
          "mediasetlisting$epgTitle": "Forum -",
          description: "Il processo",
          startTime: Date.parse("2026-10-24T09:00:00Z"),
          endTime: Date.parse("2026-10-24T11:00:00Z"),
          program: {
            title: "Forum",
            thumbnails: {
              image_horizontal_cover: { url: "https://img/c.jpg" },
            },
          },
        }],
      }],
    },
  });
  assert.deepEqual(rows, [{
    ref: "C5",
    start: "2026-10-24T09:00:00.000Z",
    stop: "2026-10-24T11:00:00.000Z",
    title: "Forum",
    description: "Il processo",
    image: "https://img/c.jpg",
  }]);
  assert.deepEqual(
    mediasetProgrammes("EC", { response: { entryCount: 0 } }),
    [],
  );
});

Deno.test("Sky: UTC times, the date at the end of a title dropped", () => {
  const rows = skyProgrammes("6601", {
    events: [{
      starttime: "2026-10-24T09:25:00Z",
      endtime: "2026-10-24T10:00:00Z",
      eventTitle: "Linea Verde - L'anima della montagna - 24/10/2026",
      eventSynopsis: "In questa puntata",
    }],
  });
  assert.deepEqual(rows, [{
    ref: "6601",
    start: "2026-10-24T09:25:00.000Z",
    stop: "2026-10-24T10:00:00.000Z",
    title: "Linea Verde - L'anima della montagna",
    description: "In questa puntata",
  }]);
});

Deno.test("Sky: an episode is titled by its show, without '1^TV'", () => {
  const event = (eventTitle: string, epgEventTitle: string) => ({
    starttime: "2026-10-28T18:30:00Z",
    endtime: "2026-10-28T19:35:00Z",
    eventTitle,
    epgEventTitle,
  });
  const rows = skyProgrammes("8327", {
    events: [
      event("Ep.43", "S2 Ep43 - Foodish"),
      event("Foodish - Anteprima", "S2 Ep5 - Foodish 1^TV"),
      event(
        "Alessandro Borghese - 4 Ristoranti - Stag. Alessandro Borghese - 4 Ristoranti S.11 Ep.10 Modenese",
        "S11 Ep10 - Alessandro Borghese - 4 Ristoranti 1^TV",
      ),
      event("Tg8", "Tg8"),
    ],
  });
  assert.deepEqual(rows.map((r) => r.title), [
    "Foodish",
    "Foodish",
    "Alessandro Borghese - 4 Ristoranti",
    "Tg8",
  ]);
});

Deno.test("Discovery: '+00:00' times are Italian; gaps and unknown episodes", () => {
  const page = {
    included: [
      { type: "site", attributes: {} },
      {
        type: "block",
        attributes: {
          type: "epgBlock",
          channels: [{
            name: "Nove",
            days: [{
              programs: [
                {
                  start_dt: "2026-10-24T00:00:00+00:00",
                  end_dt: "2026-10-24T01:40:00+00:00",
                },
                {
                  show_name: "Nudi e crudi",
                  title: "St.10 Ep.9",
                  description: "Due sconosciuti",
                  start_dt: "2026-10-24T03:15:00+00:00",
                  end_dt: "2026-10-24T04:25:00+00:00",
                },
                {
                  show_name: "Alive",
                  title: "St. Ep.",
                  start_dt: "2026-10-24T15:30:00+00:00",
                  end_dt: "2026-10-24T18:15:00+00:00",
                },
              ],
            }],
          }],
        },
      },
    ],
  };
  assert.deepEqual(discoveryProgrammes("nove", page), [
    {
      ref: "nove",
      start: "2026-10-24T01:15:00.000Z",
      stop: "2026-10-24T02:25:00.000Z",
      title: "Nudi e crudi",
      subtitle: "St.10 Ep.9",
      description: "Due sconosciuti",
    },
    {
      ref: "nove",
      start: "2026-10-24T13:30:00.000Z",
      stop: "2026-10-24T16:15:00.000Z",
      title: "Alive",
      subtitle: undefined,
      description: undefined,
    },
  ]);
  assert.throws(
    () => discoveryProgrammes("x", { included: [] }),
    /no guide block/,
  );
});

Deno.test("XMLTV: only the wanted channels, offsets, entities", () => {
  const xml = `<tv>
<programme start="20261024203500 +0200" stop="20261024213000 +0200" channel="Rai1.it">
  <title lang="it">Affari tuoi &amp; co.</title><sub-title>P. 1</sub-title>
  <desc lang="it">Gioco &#224; premi</desc><icon src="https://img/a.jpg" />
</programme>
<programme start="20261024203500 +0200" stop="20261024213000 +0200" channel="Other.it">
  <title>Not wanted</title>
</programme>
<programme start="20261024213000" stop="20261024213000" channel="Rai1.it"><title>Zero length</title></programme>
</tv>`;
  assert.deepEqual(xmltvProgrammes(xml, new Set(["Rai1.it"])), [{
    ref: "Rai1.it",
    start: "2026-10-24T18:35:00.000Z",
    stop: "2026-10-24T19:30:00.000Z",
    title: "Affari tuoi & co.",
    subtitle: "P. 1",
    description: "Gioco à premi",
    image: "https://img/a.jpg",
  }]);
  assert.equal(
    xmltvTime("20261024203500")?.toISOString(),
    "2026-10-24T20:35:00.000Z",
  );
  assert.equal(
    xmltvTime("20261024203500 -0130")?.toISOString(),
    "2026-10-24T22:05:00.000Z",
  );
  assert.equal(xmltvTime("garbage"), null);
});

Deno.test("fill: placeholders encoded, unknown ones kept", () => {
  assert.equal(
    fill("https://x/{id}/{date}.json?a={from}&b={nope}", {
      id: "rai 1",
      date: "24-10-2026",
      from: "2026-10-24T09:00:00Z",
    }),
    "https://x/rai%201/24-10-2026.json?a=2026-10-24T09%3A00%3A00Z&b={nope}",
  );
});

Deno.test("readSource: one failing channel doesn't stop the others", async () => {
  const now = new Date("2026-10-24T10:00:00Z");
  const calls: string[] = [];
  const result = await readSource(
    { key: "discovery", reader: "discovery", address: "https://g/{id}" },
    [{ id: "nove" }, { id: "gone" }],
    {
      now: () => now,
      fetch: (input) => {
        const url = input.toString();
        calls.push(url);
        if (url.endsWith("/gone")) {
          return Promise.resolve(new Response("", { status: 404 }));
        }
        return Promise.resolve(Response.json({
          included: [{
            attributes: {
              type: "epgBlock",
              channels: [{
                days: [{
                  programs: [{
                    show_name: "Show",
                    start_dt: "2026-10-24T12:00:00+00:00",
                    end_dt: "2026-10-24T13:00:00+00:00",
                  }],
                }],
              }],
            },
          }],
        }));
      },
    },
  );
  assert.deepEqual(calls.sort(), ["https://g/gone", "https://g/nove"]);
  assert.equal(result.rows.length, 1);
  assert.deepEqual(result.failed, ["gone: status 404"]);
});

Deno.test("readSource: Rai asks 7 Italian days; later days missing are fine", async () => {
  const urls: string[] = [];
  const result = await readSource(
    { key: "rai", reader: "rai", address: "https://r/{id}/{date}.json" },
    [{ id: "rai-1" }],
    {
      // Already the 25th in Italy.
      now: () => new Date("2026-10-24T22:30:00Z"),
      fetch: (input) => {
        const url = input.toString();
        urls.push(url);
        if (!url.includes("/25-10-2026")) {
          return Promise.resolve(new Response("", { status: 404 }));
        }
        return Promise.resolve(Response.json({
          events: [{
            name: "Tg1",
            date: "25/10/2026",
            hour: "08:00",
            duration: "00:30:00",
          }],
        }));
      },
    },
  );
  assert.equal(urls.length, 7);
  assert.equal(urls[0], "https://r/rai-1/25-10-2026.json");
  assert.equal(urls[6], "https://r/rai-1/31-10-2026.json");
  assert.equal(result.rows.length, 1);
  assert.deepEqual(result.failed, []);
});

Deno.test("readSource: Sky pages until a short page, with the channel's list", async () => {
  const urls: string[] = [];
  const event = {
    starttime: "2026-10-24T09:00:00Z",
    endtime: "2026-10-24T09:30:00Z",
    eventTitle: "News",
  };
  const result = await readSource(
    {
      key: "sky",
      reader: "sky",
      address:
        "https://s/events?env={env}&channels={id}&pageSize=500&pageNum={page}",
    },
    [{ id: "9313", env: "DTT" }],
    {
      now: () => new Date("2026-10-24T10:00:00Z"),
      fetch: (input) => {
        const url = input.toString();
        urls.push(url);
        const page = Number(new URL(url).searchParams.get("pageNum"));
        return Promise.resolve(Response.json({
          events: Array(page === 0 ? 500 : 3).fill(event),
        }));
      },
    },
  );
  assert.equal(urls.length, 2);
  assert.ok(urls[0].includes("env=DTT&channels=9313"));
  assert.equal(result.rows.length, 503);
});
