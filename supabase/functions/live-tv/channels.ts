/** The "Cinemuse IPTV" channels, how each plays and where its guide comes
 * from. A change here reaches the playlist within an hour of the deploy.
 * Never rename a channel's `key`: apps match the guide on it. */

/** How a stream's id becomes its address (`{id}`), and the name the
 * player's Source list shows. An "ask" address answers with the real
 * stream address, valid a few minutes and only to Italian devices, so the
 * device asks it at play time: the playlist line says so with
 * `cinemuse-ask="<ask>"`, the broadcaster whose answer it reads. */
export const linkServices = {
  // Answers JSON, the stream address in `video[0]`.
  rai: {
    address:
      "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont={id}&output=63&forceUserAgent=raiplayappletv",
    ask: "rai",
    provider: "Rai",
  },
  // Rai's second link service: same answer, same video servers.
  rai_backup: {
    address:
      "https://mediapolisevent.rai.it/relinker/relinkerServlet.htm?cont={id}&output=63&forceUserAgent=raiplayappletv",
    ask: "rai",
    provider: "Rai (backup)",
  },
  // TV8, Cielo, Sky TG24: answers JSON, the stream address in `streaming_url`.
  sky: {
    address: "https://video.sky.it/api/v1/getLivestream?id={id}&isMobile=false",
    ask: "sky",
    provider: "Sky",
  },
  // By call sign.
  mediaset: {
    address:
      "https://live02-seg.msf.cdn.mediaset.net/live/ch-{id}/{id}-clr.isml/index.m3u8",
    ask: null,
    provider: "Mediaset",
  },
  mediaset_radio: {
    address:
      "https://live02-seg.msr.cdn.mediaset.net/live/ch-{id}/{id}-clr.isml/index.m3u8",
    ask: null,
    provider: "Mediaset",
  },
  // Warner Bros. Discovery Italy, by name.
  discovery: {
    address:
      "https://streaming.aurora.enhanced.live/live/mpc/enl0eG1mLmVncmVzcy5mZDJ2eHI=/out/v1/IT_SIMULCAST/{id}/CMAF/index.m3u8",
    ask: null,
    provider: "Discovery",
  },
  // An unofficial copy (owner unknown) of some channels, by name.
  relay: {
    address: "https://d3k8wzt41aflvx.cloudfront.net/{id}/Live.m3u8",
    ask: null,
    provider: "Relay",
  },
};

export type LinkKey = keyof typeof linkServices;

/** One of a channel's streams: a link service and the id it puts in its
 * address, or a plain address and the name the Source list shows. */
export type Stream = [LinkKey, string] | ["url", string, string];

// TODO: Sky's pass in these addresses ends on 22 December 2027; then drop
// the "Sky (direct)" streams or find new addresses.
const skyPass =
  "?hdnts=st=1764666351~exp=1829466206~acl=/*~hmac=b0e9165b6c55027903ad103c8219f363d8765eb300c0d9a339e9767fc3509556";
const skyDirect = "https://hlslive-web-gcdn-skycdn-it.akamaized.net/TACT";

/** The guide sources: which reader understands each, and its address
 * (`{id}`, `{date}`, `{from}`, `{to}`, `{env}`, `{page}` filled by the
 * reader). */
export const guideSources = {
  // One channel, one day ({date} = DD-MM-YYYY); 7 days.
  rai: {
    reader: "rai",
    address: "https://www.raiplay.it/palinsesto/app/{id}/{date}.json",
  },
  // One channel, at most 39 hours per call ({from}, {to} in ms).
  mediaset: {
    reader: "mediaset",
    address:
      "https://api-ott-prod-fe.mediaset.net/PROD/play/feed/allListingFeedEpg/v2.0?byListingTime={from}~{to}&byCallSign={id}",
  },
  // One channel per call ({env} DTT or DTH, the list it is in).
  sky: {
    reader: "sky",
    address:
      "https://apid.sky.it/gtv/v1/events?from={from}&to={to}&env={env}&channels={id}&pageSize=500&pageNum={page}",
  },
  // One channel, 7 days.
  discovery: {
    reader: "discovery",
    address:
      "https://public.aurora.enhanced.live/site/page/guida-tv/?include=default&filter[environment]={id}",
  },
  // Community feeds (XMLTV).
  iptv_epg: {
    reader: "xmltv",
    address: "https://iptv-epg.org/files/epg-it.xml.gz",
  },
  // About 2 days ahead.
  open_epg_3: {
    reader: "xmltv",
    address: "https://www.open-epg.com/files/italy3.xml.gz",
  },
  open_epg_8: {
    reader: "xmltv",
    address: "https://www.open-epg.com/files/italy8.xml.gz",
  },
};

export type SourceKey = keyof typeof guideSources;

/** One of a channel's guide sources: the source, the channel's id there,
 * and (Sky only) the list it is in, `DTT` or `DTH`. */
export type GuideRef = [SourceKey, string] | [SourceKey, string, string];

export interface Channel {
  /** Its id in the playlist and the guide (`tvg-id`). */
  key: string;
  name: string;
  /** The channel number; null when it has none. */
  lcn: number | null;
  category: string;
  /** A file of `livetv/logos/`, or empty. */
  logo: string;
  /** Best first: the player moves to the next when one fails. Empty: in
   * the guide only. */
  streams: Stream[];
  /** In order: the first that covers the next 48 hours wins. */
  guide: GuideRef[];
}

// One channel per entry, kept short to read.
// deno-fmt-ignore
export const channels: Channel[] = [
  { key: "rai1", name: "Rai 1", lcn: 1, category: "Nazionali", logo: "rai1.png", streams: [["rai", "2606803"], ["rai_backup", "2606803"], ["relay", "RAI1"]],
    guide: [["rai", "rai-1"], ["sky", "6601", "DTT"], ["iptv_epg", "Rai1.it"], ["open_epg_3", "Rai 1.it"]] },
  { key: "rai2", name: "Rai 2", lcn: 2, category: "Nazionali", logo: "rai2.png", streams: [["rai", "308718"], ["rai_backup", "308718"], ["relay", "RAI2"]],
    guide: [["rai", "rai-2"], ["sky", "6621", "DTT"], ["iptv_epg", "Rai2.it"], ["open_epg_3", "Rai 2.it"]] },
  { key: "rai3", name: "Rai 3", lcn: 3, category: "Nazionali", logo: "rai3.png", streams: [["rai", "308709"], ["rai_backup", "308709"], ["relay", "RAI3"]],
    guide: [["rai", "rai-3"], ["sky", "6602", "DTT"], ["iptv_epg", "Rai3.it"], ["open_epg_3", "Rai 3.it"]] },
  { key: "r4", name: "Rete 4", lcn: 4, category: "Nazionali", logo: "rete4.png", streams: [["mediaset", "r4"]],
    guide: [["mediaset", "R4"], ["sky", "10464", "DTH"], ["iptv_epg", "Rete4.it"], ["open_epg_3", "Rete 4.it"]] },
  { key: "c5", name: "Canale 5", lcn: 5, category: "Nazionali", logo: "canale5.png", streams: [["mediaset", "c5"]],
    guide: [["mediaset", "C5"], ["sky", "10354", "DTH"], ["iptv_epg", "Canale5.it"], ["open_epg_3", "Canale 5.it"]] },
  { key: "i1", name: "Italia 1", lcn: 6, category: "Nazionali", logo: "italia1.png", streams: [["mediaset", "i1"]],
    guide: [["mediaset", "I1"], ["sky", "10454", "DTH"], ["iptv_epg", "Italia1.it"], ["open_epg_3", "Italia 1.it"]] },
  { key: "la7", name: "La7", lcn: 7, category: "Nazionali", logo: "la7.png", streams: [["relay", "LA7HD"],
      ["url", "https://d1chghleocc9sm.cloudfront.net/v1/master/3722c60a815c199d9c0ef36c5b73da68a62b09d1/cc-evfku205gqrtf/Live.m3u8", "Relay (ads)"]],
    guide: [["sky", "8329", "DTT"], ["iptv_epg", "La7.it"], ["open_epg_3", "La7.it"]] },
  { key: "tv8", name: "TV8", lcn: 8, category: "Nazionali", logo: "tv8.png", streams: [["sky", "7"], ["url", `${skyDirect}/11223/tv8web/master.m3u8${skyPass}`, "Sky (direct)"]],
    guide: [["sky", "8327", "DTT"], ["iptv_epg", "TV8.it"], ["open_epg_3", "TV8.it"]] },
  { key: "nove", name: "Nove", lcn: 9, category: "Nazionali", logo: "nove.png", streams: [["discovery", "NOVE"]],
    guide: [["discovery", "nove"], ["sky", "12115", "DTT"], ["iptv_epg", "NOVE.it"], ["open_epg_3", "Nove.it"]] },
  { key: "c20", name: "20 Mediaset", lcn: 20, category: "Nazionali", logo: "20.png", streams: [["mediaset", "lb"]],
    guide: [["mediaset", "LB"], ["sky", "10458", "DTH"], ["iptv_epg", "Mediaset20.it"], ["open_epg_3", "20.it"]] },
  { key: "rai4", name: "Rai 4", lcn: 21, category: "Nazionali", logo: "rai4.png", streams: [["rai", "746966"], ["rai_backup", "746966"]],
    guide: [["rai", "rai-4"], ["sky", "6622", "DTT"], ["iptv_epg", "Rai4.it"], ["open_epg_3", "Rai 4.it"]] },
  { key: "iris", name: "Iris", lcn: 22, category: "Cinema", logo: "iris.png", streams: [["mediaset", "ki"]],
    guide: [["mediaset", "KI"], ["sky", "10467", "DTH"], ["iptv_epg", "Iris.it"], ["open_epg_3", "Iris.it"]] },
  { key: "rai5", name: "Rai 5", lcn: 23, category: "Nazionali", logo: "rai5.png", streams: [["rai", "395276"], ["rai_backup", "395276"]],
    guide: [["rai", "rai-5"], ["sky", "6607", "DTT"], ["iptv_epg", "Rai5.it"], ["open_epg_3", "Rai 5.it"]] },
  { key: "raimovie", name: "Rai Movie", lcn: 24, category: "Cinema", logo: "raimovie.png", streams: [["rai", "747002"], ["rai_backup", "747002"]],
    guide: [["rai", "rai-movie"], ["sky", "6608", "DTT"], ["iptv_epg", "RaiMovie.it"], ["open_epg_3", "Rai Movie.it"]] },
  { key: "raipremium", name: "Rai Premium", lcn: 25, category: "Cinema", logo: "raipremium.png", streams: [["rai", "746992"], ["rai_backup", "746992"]],
    guide: [["rai", "rai-premium"], ["sky", "6623", "DTT"], ["iptv_epg", "RaiPremium.it"], ["open_epg_3", "Rai Premium.it"]] },
  { key: "cielo", name: "Cielo", lcn: 26, category: "Nazionali", logo: "cielo.png", streams: [["sky", "2"], ["url", `${skyDirect}/11219/cieloweb/master.m3u8${skyPass}`, "Sky (direct)"]],
    guide: [["sky", "8773", "DTT"], ["iptv_epg", "cielo.it"], ["open_epg_3", "Cielo.it"]] },
  { key: "c27", name: "Twentyseven", lcn: 27, category: "Nazionali", logo: "twentyseven.png", streams: [["mediaset", "ts"]],
    guide: [["mediaset", "TS"], ["sky", "11342", "DTH"], ["open_epg_3", "Twenty Seven.it"]] },
  { key: "tv2000", name: "TV2000", lcn: 28, category: "Nazionali", logo: "tv2000.png", streams: [["url", "https://hls-live-tv2000.akamaized.net/hls/live/2028510/tv2000/master.m3u8", "TV2000"]],
    guide: [["sky", "8325", "DTT"], ["iptv_epg", "TV2000.it"], ["open_epg_3", "TV2000.it"]] },
  // No online stream: in the guide only.
  { key: "la7cinema", name: "La7 Cinema", lcn: 29, category: "Cinema", logo: "la7cinema.png", streams: [],
    guide: [["sky", "6624", "DTT"], ["iptv_epg", "La7D.it"], ["open_epg_3", "La7 Cinema.it"]] },
  { key: "la5", name: "La5", lcn: 30, category: "Nazionali", logo: "la5.png", streams: [["mediaset", "ka"]],
    guide: [["mediaset", "KA"], ["sky", "6625", "DTT"], ["iptv_epg", "La5.it"], ["open_epg_3", "La 5.it"]] },
  { key: "realtime", name: "Real Time", lcn: 31, category: "Intrattenimento", logo: "realtime.png", streams: [["discovery", "REALTIME"]],
    guide: [["discovery", "realtime"], ["sky", "12122", "DTT"], ["open_epg_3", "Real Time.it"], ["iptv_epg", "RealTime.it"]] },
  { key: "qvc", name: "QVC", lcn: 32, category: "Intrattenimento", logo: "qvc.png", streams: [["url", "https://qrg.akamaized.net/hls/live/2017383/lsqvc1it/master.m3u8", "QVC"]],
    guide: [["open_epg_3", "QVC.it"], ["open_epg_8", "QVC.it"], ["iptv_epg", "QVC.it"]] },
  { key: "foodnetwork", name: "Food Network", lcn: 33, category: "Intrattenimento", logo: "foodnetwork.png", streams: [["discovery", "FOODNETWORK"]],
    guide: [["discovery", "foodnetwork"], ["sky", "12123", "DTH"], ["iptv_epg", "FoodNetwork.it"], ["open_epg_3", "FoodNetwork.it"]] },
  { key: "cine34", name: "Cine34", lcn: 34, category: "Cinema", logo: "cine34.png", streams: [["mediaset", "b6"]],
    guide: [["mediaset", "B6"], ["sky", "10893", "DTH"], ["iptv_epg", "Cine34.it"], ["open_epg_3", "Cine34.it"]] },
  { key: "focus", name: "Focus", lcn: 35, category: "Documentari", logo: "focus.png", streams: [["mediaset", "fu"]],
    guide: [["mediaset", "FU"], ["sky", "10470", "DTH"], ["iptv_epg", "Focus.it"], ["open_epg_3", "Focus.it"]] },
  { key: "rtl1025", name: "RTL 102.5", lcn: 36, category: "Musica", logo: "rtl.png", streams: [["url", "https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S97044836/tbbP8T1ZRPBL/playlist_video.m3u8", "RTL 102.5"]],
    guide: [["sky", "8320", "DTT"], ["iptv_epg", "RTL1025.it"], ["open_epg_3", "RTL 102.5 TV.it"]] },
  { key: "discovery", name: "Discovery", lcn: 37, category: "Documentari", logo: "discovery.png", streams: [["discovery", "DISCOVERYCHANNEL"]],
    guide: [["open_epg_3", "Discovery.it"], ["iptv_epg", "Discovery.it"], ["sky", "12124", "DTH"]] },
  { key: "giallo", name: "Giallo", lcn: 38, category: "Cinema", logo: "giallo.png", streams: [["discovery", "GIALLO"]],
    guide: [["sky", "12535", "DTT"], ["iptv_epg", "GIALLO.it"], ["open_epg_3", "Giallo.it"]] },
  { key: "topcrime", name: "Top Crime", lcn: 39, category: "Cinema", logo: "topcrime.png", streams: [["mediaset", "lt"]],
    guide: [["mediaset", "LT"], ["sky", "10468", "DTH"], ["iptv_epg", "TOPcrime.it"], ["open_epg_3", "Top Crime.it"]] },
  { key: "boing", name: "Boing", lcn: 40, category: "Bambini", logo: "boing.png", streams: [["mediaset", "kb"],
      ["url", "https://boing.akamaized.net/6380392800112/eu-central-1/6284318116001/eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJob3N0Ijoib3dwbnN1LmVncmVzcy5haGc3NmwiLCJhY2NvdW50X2lkIjoiNjI4NDMxODExNjAwMSIsImVobiI6ImJvaW5nLmFrYW1haXplZC5uZXQiLCJpc3MiOiJibGl2ZS1wbGF5YmFjay1zb3VyY2UtYXBpIiwic3ViIjoicGF0aG1hcHRva2VuIiwiYXVkIjpbIjYyODQzMTgxMTYwMDEiXSwianRpIjoiNjM4MDM5MjgwMDExMiJ9.0RWQ0yZrauU0cHSnbpBYhgyRPeq1Lyw6nOn_fo7_cg0/playlist-hls.m3u8", "Boing"]],
    guide: [["mediaset", "KB"], ["iptv_epg", "Boing.it"], ["open_epg_3", "Boing.it"]] },
  { key: "raigulp", name: "Rai Gulp", lcn: 42, category: "Bambini", logo: "raigulp.png", streams: [["rai", "746953"], ["rai_backup", "746953"]],
    guide: [["rai", "rai-gulp"], ["sky", "6629", "DTT"], ["iptv_epg", "RaiGulp.it"], ["open_epg_3", "Rai Gulp.it"]] },
  { key: "raiyoyo", name: "Rai Yoyo", lcn: 43, category: "Bambini", logo: "raiyoyo.png", streams: [["rai", "746899"], ["rai_backup", "746899"]],
    guide: [["rai", "rai-yoyo"], ["sky", "6609", "DTT"], ["iptv_epg", "RaiYoyo.it"], ["open_epg_3", "Rai Yoyo.it"]] },
  { key: "cartoonito", name: "Cartoonito", lcn: 46, category: "Bambini", logo: "cartoonito.png", streams: [["mediaset", "la"]],
    guide: [["mediaset", "LA"], ["iptv_epg", "CARTOONITO.it"], ["open_epg_3", "Cartoonito.it"]] },
  { key: "super", name: "Super!", lcn: 47, category: "Bambini", logo: "super.png", streams: [["url", "https://495c5a85d9074f29acffeaea9e0215eb.msvdn.net/super/super_main/super_main_hbbtv/playlist.m3u8", "Super!"]],
    guide: [["sky", "8314", "DTT"], ["iptv_epg", "Super!.it"], ["open_epg_3", "Super!.it"]] },
  { key: "rainews24", name: "Rai News 24", lcn: 48, category: "News", logo: "rainews24.png", streams: [["rai", "1"], ["rai_backup", "1"], ["relay", "RAINEWS24"]],
    guide: [["rai", "rai-news-24"], ["sky", "895", "DTH"], ["iptv_epg", "RaiNews.it"], ["open_epg_3", "RaiNews24.it"]] },
  { key: "italia2", name: "Italia 2", lcn: 49, category: "Nazionali", logo: "italia2.png", streams: [["mediaset", "i2"]],
    guide: [["mediaset", "I2"], ["sky", "10469", "DTH"], ["iptv_epg", "Italia2.it"], ["open_epg_3", "Italia 2.it"]] },
  { key: "skytg24", name: "Sky TG24", lcn: 50, category: "News", logo: "skytg24.png", streams: [["sky", "1"], ["url", `${skyDirect}/12221/web/master.m3u8${skyPass}`, "Sky (direct)"]],
    guide: [["sky", "9313", "DTT"], ["iptv_epg", "SkyTG24.it"], ["open_epg_3", "Sky Tg24.it"]] },
  { key: "tgcom24", name: "TGCOM24", lcn: 51, category: "News", logo: "tgcom24.png", streams: [["mediaset", "kf"], ["relay", "TGCOM24"]],
    guide: [["mediaset", "KF"], ["sky", "10473", "DTT"], ["iptv_epg", "TgCom24.it"], ["open_epg_3", "Tgcom24.it"]] },
  { key: "dmax", name: "DMAX", lcn: 52, category: "Intrattenimento", logo: "dmax.png", streams: [["discovery", "DMAX"]],
    guide: [["discovery", "dmaxit"], ["sky", "12540", "DTT"], ["iptv_epg", "DMAX.it"], ["open_epg_3", "DMAX.it"]] },
  { key: "casaitalia53", name: "Casa Italia 53", lcn: 53, category: "Intrattenimento", logo: "casaitalia53.png", streams: [["url", "https://ovp-live.akamaized.net/ac115_live/canale3.smil/playlist.m3u8", "Casa Italia"]],
    guide: [] },
  { key: "raistoria", name: "Rai Storia", lcn: 54, category: "Documentari", logo: "raistoria.png", streams: [["rai", "746990"], ["rai_backup", "746990"], ["relay", "RAIStoria"]],
    guide: [["rai", "rai-storia"], ["sky", "6630", "DTT"], ["iptv_epg", "RaiStoria.it"], ["open_epg_3", "Rai Storia.it"]] },
  { key: "mediasetextra", name: "Mediaset Extra", lcn: 55, category: "Nazionali", logo: "mediasetextra.png", streams: [["mediaset", "kq"]],
    guide: [["mediaset", "KQ"], ["sky", "6627", "DTT"], ["iptv_epg", "MediasetExtra.it"], ["open_epg_3", "Mediaset Extra.it"]] },
  { key: "hgtv", name: "HGTV", lcn: 56, category: "Intrattenimento", logo: "hgtv.png", streams: [["discovery", "HGTV"]],
    guide: [["discovery", "hgtvit"], ["sky", "12127", "DTH"], ["iptv_epg", "HGTV.it"]] },
  // Rai Scuola is now Italiana; the key stays.
  { key: "raiscuola", name: "Italiana", lcn: 57, category: "Documentari", logo: "raiscuola.png", streams: [["rai", "747011"], ["rai_backup", "747011"], ["relay", "RAIScuola"]],
    guide: [["rai", "italiana"], ["open_epg_3", "Italiana.it"], ["iptv_epg", "RaiScuola.it"]] },
  { key: "raisport", name: "Rai Sport", lcn: 58, category: "Sport", logo: "raisport.png", streams: [["rai", "358025"], ["rai_backup", "358025"]],
    guide: [["rai", "rai-sport"], ["sky", "8317", "DTT"], ["iptv_epg", "RAISport.it"], ["open_epg_8", "Rai Sport.it"]] },
  { key: "discoveryturbo", name: "Discovery Turbo", lcn: 59, category: "Intrattenimento", logo: "discoveryturbo.png", streams: [["discovery", "TURBO"]],
    guide: [["discovery", "motortrend"], ["sky", "12131", "DTH"], ["open_epg_3", "Discovery Turbo.it"], ["iptv_epg", "MotorTrend.it"]] },
  { key: "sportitalia", name: "Sportitalia", lcn: 60, category: "Sport", logo: "sportitalia.png", streams: [["url", "https://edge-001.streamup.eu/sportitalia/sihd_abr/playlist.m3u8", "Sportitalia"]],
    guide: [["open_epg_3", "Sportitalia.it"], ["iptv_epg", "Sportitalia.it"], ["open_epg_8", "Sportitalia.it"]] },
  { key: "solocalcio", name: "Solocalcio", lcn: 61, category: "Sport", logo: "", streams: [["url", "https://distribution.sportitalialive.it/sportitalia/sisolocalcio_abr/playlist.m3u8", "Sportitalia"],
      ["url", "https://edge-001.streamup.eu/sportitalia/sisolocalcio_abr/playlist.m3u8", "Sportitalia (backup)"],
      ["url", "https://italiansport-solocalcio-samsung.amagi.tv/playlist.m3u8", "Samsung TV Plus"]],
    guide: [] },
  { key: "supertennis", name: "SuperTennis", lcn: 64, category: "Sport", logo: "supertennis.png", streams: [["url", "https://live-embed.supertennix.hiway.media/restreamer/supertennix_client/gpu-a-c0-16/restreamer/outgest/aa3673f1-e178-44a9-a947-ef41db73211a/manifest.m3u8", "SuperTennis"]],
    guide: [["sky", "8322", "DTT"], ["iptv_epg", "SuperTennis.it"], ["open_epg_3", "SuperTennis.it"]] },
  { key: "radio105", name: "Radio 105 TV", lcn: 66, category: "Musica", logo: "radio105.png", streams: [["mediaset_radio", "ec"]],
    guide: [["mediaset", "EC"], ["open_epg_3", "Radio 105.it"]] },
  { key: "r101", name: "R101 TV", lcn: 67, category: "Musica", logo: "r101.png", streams: [["mediaset_radio", "er"]],
    guide: [["mediaset", "ER"], ["open_epg_3", "R101.it"]] },
  { key: "bomchannel", name: "Bom Channel", lcn: 68, category: "Intrattenimento", logo: "bomchannel.png", streams: [["url", "https://5f22d76e220e1.streamlock.net/canale6/canale6/playlist.m3u8", "Bom Channel"]],
    guide: [] },
  { key: "deejaytv", name: "Deejay TV", lcn: 69, category: "Musica", logo: "deejay.png", streams: [["url", "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/live/S85984808/sMO0tz9Sr2Rk/playlist.m3u8", "Deejay"]],
    guide: [["sky", "462", "DTT"], ["iptv_epg", "DeejayTV.it"], ["open_epg_3", "Deejay TV.it"]] },
  { key: "radioitalia", name: "Radio Italia TV", lcn: 70, category: "Musica", logo: "radioitalia.png", streams: [["url", "https://radioitaliatv.akamaized.net/hls/live/2093117/RadioitaliaTV/master.m3u8", "Radio Italia"]],
    guide: [["sky", "9833", "DTH"], ["iptv_epg", "RadioItaliaTV.it"], ["open_epg_3", "Radio Italia Tv.it"]] },
  { key: "rai4k", name: "Rai 4K", lcn: 101, category: "Nazionali", logo: "rai4k.png", streams: [["rai", "4465258"], ["rai_backup", "4465258"], ["url", "https://raievent10-elem-live.akamaized.net/hls/live/619189/raievent10/raievent10/playlist.m3u8", "Rai (direct)"]],
    guide: [["rai", "rai-4k"]] },
  { key: "kisskiss", name: "Kiss Kiss TV", lcn: 158, category: "Musica", logo: "kisskiss.png", streams: [["url", "https://58f12ffd2447a.streamlock.net/KKMulti/livestream/playlist.m3u8", "Kiss Kiss"],
      ["url", "https://59253971be783.streamlock.net/KissKissTV/KissKissTV.stream/playlist.m3u8", "Kiss Kiss (backup)"]],
    guide: [] },
  { key: "rairadio2", name: "Rai Radio 2", lcn: 202, category: "Musica", logo: "rairadio2.png", streams: [["rai", "5674080"], ["rai_backup", "5674080"]],
    guide: [["rai", "rai-radio-2"]] },
  { key: "virginradiotv", name: "Virgin Radio TV", lcn: 257, category: "Musica", logo: "virginradiotv.png", streams: [["mediaset_radio", "ew"]],
    guide: [["mediaset", "EW"], ["open_epg_3", "Virgin Radio.it"]] },
  { key: "radiofreccia", name: "Radio Freccia", lcn: 258, category: "Musica", logo: "radiofreccia.png", streams: [["url", "https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S3160845/0tuSetc8UFkF/playlist_video.m3u8", "RTL 102.5"]],
    guide: [["sky", "10853", "DTT"], ["iptv_epg", "RADIOFRECCIA.it"], ["open_epg_8", "radiofreccia.it"]] },
  { key: "rds", name: "RDS Social TV", lcn: 265, category: "Musica", logo: "rdssocialtv.png", streams: [["url", "https://stream.rdstv.radio/out/v1/ec85f72b87f04555aa41d616d5be41dc/index.m3u8", "RDS"]],
    guide: [] },
  { key: "radiozeta", name: "Radio Zeta", lcn: 266, category: "Musica", logo: "radiozeta.png", streams: [["url", "https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S9346184/XEx1LqlYbNic/playlist_video.m3u8", "RTL 102.5"]],
    guide: [] },
  { key: "m2o", name: "m2o TV", lcn: null, category: "Musica", logo: "m2otv.png", streams: [["url", "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/live/S62628868/uhdWBlkC1AoO/playlist.m3u8", "m2o"]],
    guide: [] },
  { key: "radiocapital", name: "Radio Capital TV", lcn: null, category: "Musica", logo: "radiocapital.png", streams: [["url", "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/live/S35394734/Z6U2wGoDYANk/playlist.m3u8", "Radio Capital"]],
    guide: [] },
  { key: "rmctv", name: "Radio Monte Carlo TV", lcn: null, category: "Musica", logo: "radiomontecarlo.png", streams: [["mediaset_radio", "bb"]],
    guide: [["mediaset", "BB"], ["iptv_epg", "RadioMonteCarlo.it"], ["open_epg_3", "Radio Monte Carlo.it"]] },
];
