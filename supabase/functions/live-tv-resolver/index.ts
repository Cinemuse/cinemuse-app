import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import aesjs from "https://esm.sh/aes-js@3.1.2";
const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
const PUBLIC_BASE_URL = "https://enfaqgwmuytoxkxgqqvp.supabase.co/functions/v1/live-tv-resolver";
const THEGROOVE_SERVER = "https://thegroove360.org/";
// 375 item_parser lines for dynamic key extraction
const PARSER_LINES = [
  "import logging",
  "import xbmcaddon",
  "import re",
  "",
  "from resources.lib import kodilogging",
  "from resources.modules.thegroove.thegroove_item import ThegrooveItem",
  "from resources.modules.thegroove.thegroove_regexes import ThegrooveRegexes",
  "from resources.modules.httpclient import HttpClient",
  "from resources.lib import kodiutils",
  "",
  "import resources.modules.thegroove.tmdb_wrapper as tmdbapi",
  "",
  "try:",
  "    import queue as mQueue",
  "except ImportError:",
  "    import Queue as mQueue",
  "",
  "from resources.modules.thegroove import support",
  "",
  "ADDON = xbmcaddon.Addon()",
  "logger = logging.getLogger(ADDON.getAddonInfo('id'))",
  "kodilogging.config()",
  "",
  "",
  "class ItemParser:",
  "",
  "    def __init__(self):",
  "        self.page_list = mQueue.Queue()",
  "        self.regex_mode = None",
  "        self.repeat_mode = None",
  "",
  "    def parse_page(self, xml):",
  "        try:",
  "            logger.debug(\"______ parse page ______\")",
  "            regex = r'(<item>(?:.*?)</item>|<dir>(?:.*?)</dir>|<plugin>(?:.*?)</plugin>)'",
  "            matches = re.compile(regex, re.MULTILINE | re.S).findall(xml)",
  "            # queue = mQueue.Queue()",
  "            for match in matches:",
  "                self.page_list.put(match)",
  "",
  "            self.parse_item_mt(self.page_list, use_lock=True)",
  "",
  "        except Exception as e:",
  "            raise e",
  "",
  "    def parse_item(self, xml_item, parent_xml=\"\", regexes=None):",
  "        logger.debug(\"____________ PARSE ITEM ______________\")",
  "",
  "        # logger.debug(xml_item)",
  "",
  "        li = ThegrooveItem()",
  "        if regexes:",
  "            # li.regexes.append(regexes)",
  "            for rex in regexes:",
  "                if type(rex) == dict:",
  "                    rex = ThegrooveRegexes.dict_to_obj(rex)",
  "                li.regexes.append(rex)",
  "",
  "        li.parent_xml = parent_xml",
  "        li._raw = xml_item",
  "",
  "        xml_stripped = re.sub(r\"<regex>(.*?)</regex>\", \"\", xml_item, 0, re.MULTILINE | re.DOTALL)",
  "",
  "        meta = re.compile(r'<meta>(.*?)</meta>', re.S).findall(xml_stripped)",
  "",
  "        xml_stripped = re.sub(r\"<meta>(.*?)</meta>\", \"\", xml_stripped, 0, re.S)",
  "",
  "        matches = re.compile(r'<([^/>]+)>', re.MULTILINE).findall(xml_stripped)",
  "",
  "        # logger.debug(matches)",
  "",
  "        for tag in matches:",
  "            closure = tag.split(\" \")[0]",
  "            regex = '<' + tag + '>(.*?)</' + closure + '>'",
  "            try:",
  "                value = re.compile(regex, re.S).findall(xml_stripped)[0]",
  "            except:",
  "                value = \"\"",
  "",
  "            # logger.debug(value)",
  "            if tag == \"name\" or tag == \"title\":",
  "                li.label = value  # u''.join(value).encode(\"utf-8\").strip()",
  "",
  "            if tag.startswith(\"link\"): ",
  "                from resources.modules.thegroove.thegroove_httpclient import ThegrooveHttpClient as TGClient",
  "                tg_cli = TGClient()",
  "                if value.strip().startswith(\"/thegroove/\") or value.strip().startswith(tg_cli.server_url):",
  "                    is_thegroove_link = True",
  "                else:",
  "                    is_thegroove_link = False",
  "",
  "                if is_thegroove_link or value.strip().startswith(\"$doregex[\"):",
  "                    li.url = value",
  "",
  "                    rxml = li.parent_xml if li.parent_xml != \"\" else li._raw",
  "                    is_repeat_regex = ItemParser.is_repeat_regex(value, rxml)",
  "",
  "                    if is_thegroove_link or is_repeat_regex:",
  "                        li.is_folder = True",
  "                    else:",
  "                        li.is_folder = False",
  "                        li.is_playable = True",
  "",
  "                elif \"<sublink\" in value:",
  "                    subls = re.compile(r'(<sublink(.*?)>(.*?)</sublink>)', re.MULTILINE).findall(value)",
  "                    resolver_type = \"\"",
  "                    for subxml, subpar, subl in subls:",
  "                        name = \"\"",
  "                        if subpar:",
  "                            try:",
  "                                name = re.compile(r'name=\\\"([^\\\"]+)\\\"', re.MULTILINE | re.DOTALL).findall(subpar)[0]",
  "                            except:",
  "                                name = \"\"",
  "                            resolver_type = ThegrooveItem.get_thegroove_resolver(subxml, subl)",
  "                        li.sublinks.append((name, subl, resolver_type))",
  "                    li.is_folder = False",
  "                    li.url = \"\"",
  "                else:",
  "                    # logger.debug(\"EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\")",
  "                    li.tg_resolver = ThegrooveItem.get_thegroove_resolver(tag, value)",
  "                    # logger.debug(li.tg_resolver)",
  "                    try:",
  "                        is_url = (value.index(\"://\") or (value.startswith(\"plugin\") or value.startswith(",
  "                            \"http\")) or li.tg_resolver != \"\") >= 0",
  "                        if is_url:",
  "                            li.is_folder = False",
  "",
  "                            if value.startswith(\"http\"): ",
  "                                if li.tg_resolver == \"extsrc\":",
  "                                    li.is_folder = True",
  "",
  "                            li.url = value.strip()",
  "                    except:",
  "                        if li.tg_resolver == \"\" or not li.tg_resolver:",
  "                            li.is_folder = True",
  "                        else:",
  "                            li.url = value.strip()",
  "                            li.is_folder = False",
  "",
  "            if tag == \"thumbnail\":",
  "                li.arts[\"thumb\"] = value",
  "",
  "            if tag == \"fanart\":",
  "                li.arts[\"fanart\"] = value",
  "",
  "            if tag == \"plot\":",
  "                li.info[\"plot\"] = value  # u''.join(value).encode(\"utf-8\").strip().decode(\"utf-8\", \"ignore\")",
  "",
  "        if xml_item.startswith(\"<plugin>\"):",
  "            li.is_folder = False",
  "            li.is_plugin = True",
  "",
  "        if meta:",
  "            try:",
  "                if \"makelist\" not in meta and kodiutils.get_setting_as_bool(\"is_tmdb\"):",
  "                    li = tmdbapi.tmdb(meta[0], li)",
  "            except:",
  "                pass",
  "",
  "        from resources.lib import plugin",
  "        plugin.show_item(li)",
  "        # self.page_list.append(li)",
  "",
  "    def parse_regex(self, item):",
  "        logger.debug(\"_________ PARSE REGEX ___________\")",
  "        # regex_name = re.compile(r'<link>\\$doregex\\[(.*?)\\]</link>', re.MULTILINE).findall(xml_item)[0]",
  "        regex_name = re.compile(r'\\$doregex\\[(.*?)\\]', re.MULTILINE).findall(item.url)[0]",
  "",
  "        # logger.debug(regex_name)",
  "        # logger.debug(item.params)",
  "",
  "        xml_item = item._raw if item.parent_xml == \"\" else item.parent_xml",
  "",
  "        # logger.debug(xml_item)",
  "",
  "        regex = r'<regex>(\\s+<name>' + regex_name + '</name>.*?)</regex>'",
  "        regex_tag = re.compile(regex, re.DOTALL).findall(xml_item)[0]",
  "",
  "        # logger.debug(regex_tag)",
  "",
  "        try:",
  "            listrepeat = re.compile(r'<listrepeat>(.*?)</listrepeat>', re.DOTALL).findall(regex_tag)[0]",
  "            # logger.debug(listrepeat)",
  "        except:",
  "            listrepeat = \"\"",
  "        try:",
  "            expres = re.compile(r'<expres>(.*?)</expres>', re.DOTALL).findall(regex_tag)[0]",
  "            # logger.debug(expres)",
  "        except:",
  "            expres = \"\"",
  "        try:",
  "            page = re.compile(r'<page>(.*?)</page>', re.DOTALL).findall(regex_tag)[0]",
  "            # logger.debug(page)",
  "        except:",
  "            page = \"\"",
  "",
  "        repeat_mode_check = re.search('<.*?>.*?</.*?>', listrepeat, re.DOTALL)",
  "        if repeat_mode_check:",
  "            self.repeat_mode = \"repeat\"",
  "        else:",
  "            self.repeat_mode = \"single\"",
  "",
  "        regex_mode_check = re.search(r'#\\$pyFunction', expres, re.DOTALL)",
  "        if regex_mode_check:",
  "            self.regex_mode = \"python\"",
  "        else:",
  "            self.regex_mode = \"regex\"",
  "",
  "        regex_param = re.compile(r'\\$doregex\\[.*?\\]\\s*\\((.*?)\\)', re.MULTILINE).findall(item.url)",
  "        if regex_param:",
  "            page = regex_param[0]",
  "",
  "        if self.repeat_mode == \"single\" and self.regex_mode == \"python\":",
  "            return ItemParser.parse_py_regex(expres, item, page)",
  "",
  "        if self.repeat_mode == \"repeat\" and self.regex_mode == \"python\":",
  "            self.build_item_py(listrepeat, expres, regex_name, page, xml_item, item)",
  "",
  "        if self.repeat_mode == \"repeat\" and self.regex_mode == \"regex\":",
  "            self.build_item_re(listrepeat, expres, regex_name, page, xml_item, item)",
  "",
  "        return \"\"",
  "",
  "    def build_item_re(self, schema, expres, regex_name, page, parent_xml, item):",
  "        logger.debug(\"________________ BUILD ITEM RE ________________\")",
  "        page = page.replace(\"<![CDATA[\", \"\").replace(\"]]>\", \"\")",
  "        page = support.get_zeronet_page(page)",
  "        r = HttpClient().get_request(page)",
  "        expres = expres.replace(\"<![CDATA[\", \"\").replace(\"]]>\", \"\")",
  "        res = re.compile(expres, re.MULTILINE).findall(r.text)",
  "",
  "        self.build_item(res, regex_name, schema, parent_xml, item)",
  "",
  "    def build_item_py(self, schema, fn, regex_name, page, parent_xml, item):",
  "        logger.debug(\"________________ BUILD ITEM PY ________________\")",
  "        page = page.replace(\"<![CDATA[\", \"\").replace(\"]]>\", \"\")",
  "        res = ItemParser.parse_py_regex(fn, item, page)",
  "        self.build_item(res, regex_name, schema, parent_xml, item)",
  "",
  "    def build_item(self, res, regex_name, schema, parent_xml, item):",
  "        logger.debug(\"________________ BUILD ITEM ________________\")",
  "",
  "        outschema = \"<item>\" + schema + \"</item>\"",
  "        outschema = outschema.replace(\"<![CDATA[\", \"\").replace(\"]]>\", \"\")",
  "",
  "        self.page_list = mQueue.Queue()",
  "",
  "        extra = None",
  "        if type(res) is dict:",
  "            extra = res[\"extra\"]",
  "            res = res[\"list\"]",
  "",
  "        self.item_builder(res, outschema, item, regex_name, parent_xml)",
  "",
  "        if extra:",
  "            extra_schema = re.compile(r'<extra>(.*?)</extra>', re.DOTALL).findall(parent_xml)[0]",
  "            outschema = \"<item>\" + extra_schema + \"</item>\"",
  "            outschema = outschema.replace(\"<![CDATA[\", \"\").replace(\"]]>\", \"\")",
  "            self.item_builder(extra, outschema, item, regex_name, parent_xml)",
  "",
  "        self.parse_item_mt(self.page_list, show_progress=True)",
  "",
  "    def item_builder(self, res, outschema, item, regex_name, parent_xml):",
  "        logger.debug(\"________________ ITEM BUILDER ________________\")",
  "        for r in res:",
  "            out = outschema",
  "            regexes = []",
  "",
  "            if len(item.regexes) > 0:",
  "                for regexp in item.regexes:",
  "                    if type(regexp) == dict:",
  "                        regexp = ThegrooveRegexes.dict_to_obj(regexp)",
  "                    if regexp.name == regex_name:",
  "                        continue",
  "                    for j, p in enumerate(regexp.params):",
  "                        out = out.replace(\"[\" + regexp.name + \".param\" + str((j + 1)) + \"]\", p.strip())",
  "                    regexes.append(ThegrooveRegexes(name=regexp.name, params=regexp.params))",
  "",
  "            for i, rparam in enumerate(r):",
  "                to_replace = \"[\" + regex_name + \".param\" + str((i + 1)) + \"]\"",
  "                if to_replace in out:",
  "                    rp = u''.join(rparam).encode(\"utf-8\").strip()",
  "                    out = out.replace(to_replace, rp.decode('utf-8', 'ignore'))",
  "            regexes.append(ThegrooveRegexes(name=regex_name, params=r))",
  "",
  "            self.page_list.put((out, parent_xml, regexes))",
  "",
  "    def parse_item_mt(self, queue, use_lock=True, show_progress=False):",
  "        from resources.modules.mt_worker import MTWorker",
  "        MTWorker.set_jobs(queue, self.parse_item, use_lock=use_lock, show_progress=show_progress)",
  "",
  "    @staticmethod",
  "    def is_repeat_regex(name, xml):",
  "        logger.debug(\"________________ IS REPEAT REGEX ________________\")",
  "        try:",
  "            name = re.compile(r'\\$doregex\\[(.*?)\\]').findall(name)[0]",
  "        except IndexError:",
  "            return False",
  "",
  "        reg = r'<regex>.*?(<name>' + name + '</name>.*?)</regex>'",
  "        matches = re.compile(reg, re.S).findall(xml)",
  "",
  "        if len(matches) > 0:",
  "            r = matches[0]",
  "            lrms = re.compile(r'<listrepeat>(.*?)</listrepeat>', re.DOTALL).findall(r)",
  "            if len(lrms) > 0:",
  "                lrm = lrms[0]",
  "                lrm = lrm.replace(\"<![CDATA[\", \"\").replace(\"]]>\", \"\")",
  "                if lrm != \"\":",
  "                    return True",
  "",
  "        return False",
  "",
  "    @staticmethod",
  "    def replacer(fn, item):",
  "        logger.debug(\"_____________REPLACER_________________\")",
  "        repl = re.compile(r'(\\[(.*?)\\.param(\\d+)\\])').findall(fn)",
  "        functions = fn",
  "",
  "        for rex in repl:",
  "            rr = rex[0]",
  "            rname = rex[1]",
  "            rpar = rex[2]",
  "            for p in item.regexes:",
  "                if p[\"name\"] == rname:",
  "                    opar = \"\"",
  "                    if p[\"name\"] == rname:",
  "                        try:",
  "                            opar = p[\"params\"][(int(rpar) - 1)]",
  "                        except IndexError:",
  "                            opar = \"\"",
  "                    functions = functions.replace(rr, opar)",
  "",
  "        return functions",
  "",
  "    @staticmethod",
  "    def parse_py_regex(fn, item, page):",
  "        logger.debug(\"________________ PARSE PY REGEX ________________\")",
  "        try:",
  "            functions = re.compile(r'<!\\[CDATA\\[#\\$pyFunction(.*?)]]>', re.DOTALL).findall(fn)[0]",
  "        except:",
  "            raise",
  "",
  "        functions = ItemParser.replacer(functions, item)",
  "        page = support.get_zeronet_page(page)",
  "",
  "        xml_py_res = \"\"",
  "        if functions != \"\":",
  "            functions += \"\\nxml_py_res = get_thegroove_xml_fn('\" + page + \"')\"",
  "            try:",
  "                loc = {}",
  "                exec(functions, globals(), loc)",
  "                xml_py_res = loc[\"xml_py_res\"]",
  "            except Exception as e:",
  "                if kodiutils.get_setting_as_bool(\"debug\"):",
  "                    import traceback",
  "                    traceback.print_stack()",
  "                    logger.debug(str(e))",
  "                raise e",
  "",
  "        return xml_py_res",
  "",
  "    @staticmethod",
  "    def get_thegroove_resolver(tag, value):",
  "        return \"\"",
  "}"
];
// Helper: SHA256 hex string
async function sha256Hex(str) {
  const buf = new TextEncoder().encode(str);
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(hash)).map((b)=>b.toString(16).padStart(2, "0")).join("");
}
// Helper: base64 url-safe decode
function b64UrlDecode(input) {
  let b64 = input.replaceAll("-", "+").replaceAll("_", "/");
  while(b64.length % 4 !== 0){
    b64 += "=";
  }
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for(let i = 0; i < bin.length; i++){
    bytes[i] = bin.charCodeAt(i);
  }
  return bytes;
}
// TheGroove Token & Decryption Engine
async function fetchThegroovePage(page) {
  try {
    const totalLines = PARSER_LINES.length > 0 ? PARSER_LINES.length : 375;
    const nowTimestamp = Math.floor(Date.now() / 1000);
    const lineIdx = nowTimestamp % totalLines;
    const lineIdxStr = lineIdx.toString();
    const prefix = lineIdxStr.length.toString() + lineIdxStr;
    const n = 6 - prefix.length;
    const low = Math.pow(10, n - 1);
    const high = Math.pow(10, n) - 1;
    const r = Math.floor(Math.random() * (high - low + 1)) + low;
    const rawToken = `${nowTimestamp}.${prefix}${r}`;
    const token = btoa(rawToken).replaceAll("+", "-").replaceAll("/", "_").replace(new RegExp("=+$"), "");
    let keyLine = (PARSER_LINES[lineIdx] || "import logging").trim();
    if (keyLine.length < 32) {
      keyLine = keyLine.padEnd(32, " ");
    } else if (keyLine.length > 32) {
      keyLine = keyLine.substring(0, 32);
    }
    const ivHex = (await sha256Hex(keyLine)).substring(0, 16);
    const keyBytes = new TextEncoder().encode(keyLine);
    const ivBytes = new TextEncoder().encode(ivHex);
    let compPage = page;
    if (page.includes("/thegroove/scripters/") && page.includes("path=")) {
      const parts = page.replace("/thegroove/scripters/", "").split("/");
      const scripter = parts[0];
      const p = parts[1];
      const params = `scripter=${scripter}&${p}`;
      const paramsB64 = btoa(params).replaceAll("+", "-").replaceAll("/", "_").replace(new RegExp("=+$"), "");
      compPage = `php_script_loader&page_params=${paramsB64}`;
    } else if (page.startsWith("/thegroove/")) {
      compPage = page.replace("/thegroove/", "");
      if (compPage.includes("?")) {
        const [base, params] = compPage.split("?", 2);
        if (params) {
          const paramsB64 = btoa(params).replaceAll("+", "-").replaceAll("/", "_").replace(new RegExp("=+$"), "");
          compPage = `${base}&page_params=${paramsB64}`;
        }
      }
    }
    const targetUrl = `${THEGROOVE_SERVER}loader.php?page=${compPage}&token=${token}`;
    const res = await fetch(targetUrl, {
      headers: {
        "User-Agent": "Mozilla/5.0"
      }
    });
    if (!res.ok) return null;
    const cipherText = await res.text();
    const cipherBytes = b64UrlDecode(cipherText);
    const aesCfb = new aesjs.ModeOfOperation.cfb(keyBytes, ivBytes, 1);
    const decryptedBytes = aesCfb.decrypt(cipherBytes);
    return new TextDecoder("utf-8").decode(decryptedBytes);
  } catch (err) {
    console.error("TheGroove fetch error:", err);
    return null;
  }
}
const CHANNELS = [
  // --- NAZIONALI (Rai: 1-3, 21, 23-25, 42-43, 48, 54, 57-58) ---
  {
    id: "rai1",
    name: "Rai 1 HD",
    lcn: 1,
    group: "Nazionali",
    logo: "http://www.rai.it/dl/img/2016/09/1473429803381logo-rai1-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=2606803&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai 1(?! \+1| hd)/i
  },
  {
    id: "rai2",
    name: "Rai 2 HD",
    lcn: 2,
    group: "Nazionali",
    logo: "http://www.rai.it/dl/img/2016/09/1473149101555logo-rai2-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=308718&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai 2/i
  },
  {
    id: "rai3",
    name: "Rai 3 HD",
    lcn: 3,
    group: "Nazionali",
    logo: "http://www.rai.it/dl/img/2016/09/1473429907779logo-rai3-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=308709&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai 3/i
  },
  {
    id: "rai4",
    name: "Rai 4 HD",
    lcn: 21,
    group: "Nazionali",
    logo: "http://www.rai.it/dl/img/2016/09/1473430030588logo-rai4-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=746966&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai 4/i
  },
  {
    id: "rai5",
    name: "Rai 5 HD",
    lcn: 23,
    group: "Nazionali",
    logo: "http://www.rai.it/dl/img/2016/09/1473430154943logo-rai5-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=395276&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai 5/i
  },
  {
    id: "raimovie",
    name: "Rai Movie HD",
    lcn: 24,
    group: "Cinema",
    logo: "http://www.rai.it/dl/img/2016/09/1473430349071logo-raimovie-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=747002&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai movie/i
  },
  {
    id: "raipremium",
    name: "Rai Premium HD",
    lcn: 25,
    group: "Cinema",
    logo: "http://www.rai.it/dl/img/2016/09/1473430263643logo-raipremium-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=746992&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai premium/i
  },
  {
    id: "raigulp",
    name: "Rai Gulp",
    lcn: 42,
    group: "Bambini",
    logo: "http://www.rai.it/dl/img/2016/09/1473430630740logo-raigulp-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=746953&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai gulp/i
  },
  {
    id: "raiyoyo",
    name: "Rai Yoyo",
    lcn: 43,
    group: "Bambini",
    logo: "http://www.rai.it/dl/img/2016/09/1473430730310logo-raiyoyo-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=746899&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai yoyo/i
  },
  {
    id: "rainews24",
    name: "Rai News 24",
    lcn: 48,
    group: "News",
    logo: "http://www.rai.it/dl/img/2016/09/1473430541703logo-rainews24-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=1&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai news 24/i
  },
  {
    id: "raistoria",
    name: "Rai Storia",
    lcn: 54,
    group: "Documentari",
    logo: "http://www.rai.it/dl/img/2016/09/1473430829871logo-raistoria-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=746990&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai storia/i
  },
  {
    id: "raiscuola",
    name: "Rai Scuola",
    lcn: 57,
    group: "Documentari",
    logo: "http://www.rai.it/dl/img/2016/09/1473430919747logo-raiscuola-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=747011&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai scuola/i
  },
  {
    id: "raisport",
    name: "Rai Sport HD",
    lcn: 58,
    group: "Sport",
    logo: "http://www.rai.it/dl/img/2016/09/1473430441416logo-raisport-2016.png",
    type: "rai",
    target: "https://mediapolis.rai.it/relinker/relinkerServlet.htm?cont=358025&output=63&forceUserAgent=raiplayappletv",
    iptvPattern: /^rai sport/i
  },
  // --- NAZIONALI (Mediaset: 4-6, 20, 22, 27, 30, 34-35, 39, 49, 51, 55) ---
  {
    id: "r4",
    name: "Rete 4 HD",
    lcn: 4,
    group: "Nazionali",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/r4.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-r4/r4-clr.isml/index.m3u8",
    iptvPattern: /^rete 4/i
  },
  {
    id: "c5",
    name: "Canale 5 HD",
    lcn: 5,
    group: "Nazionali",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/c5.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-c5/c5-clr.isml/index.m3u8",
    iptvPattern: /^canale 5/i
  },
  {
    id: "i1",
    name: "Italia 1 HD",
    lcn: 6,
    group: "Nazionali",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/i1.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-i1/i1-clr.isml/index.m3u8",
    iptvPattern: /^italia 1(?! 2)/i
  },
  {
    id: "c20",
    name: "Canale 20 HD",
    lcn: 20,
    group: "Nazionali",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/lb.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-lb/lb-clr.isml/index.m3u8",
    iptvPattern: /^20 mediaset|^canale 20/i
  },
  {
    id: "iris",
    name: "Iris HD",
    lcn: 22,
    group: "Cinema",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/ki.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-ki/ki-clr.isml/index.m3u8",
    iptvPattern: /^iris/i
  },
  {
    id: "c27",
    name: "Twentyseven HD",
    lcn: 27,
    group: "Nazionali",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/ts.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-ts/ts-clr.isml/index.m3u8",
    iptvPattern: /^twentyseven|^27 mediaset/i
  },
  {
    id: "la5",
    name: "La 5",
    lcn: 30,
    group: "Nazionali",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/ka.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-ka/ka-clr.isml/index.m3u8",
    iptvPattern: /^la 5/i
  },
  {
    id: "cine34",
    name: "Cine34 HD",
    lcn: 34,
    group: "Cinema",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/b6.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-b6/b6-clr.isml/index.m3u8",
    iptvPattern: /^cine 34|^cine34/i
  },
  {
    id: "focus",
    name: "Focus",
    lcn: 35,
    group: "Documentari",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/fu.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-fu/fu-clr.isml/index.m3u8",
    iptvPattern: /^focus/i
  },
  {
    id: "topcrime",
    name: "Top Crime",
    lcn: 39,
    group: "Cinema",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/lt.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-lt/lt-clr.isml/index.m3u8",
    iptvPattern: /^top crime/i
  },
  {
    id: "italia2",
    name: "Italia 2",
    lcn: 49,
    group: "Nazionali",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/i2.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-i2/i2-clr.isml/index.m3u8",
    iptvPattern: /^italia 2/i
  },
  {
    id: "tgcom24",
    name: "TGCOM24",
    lcn: 51,
    group: "News",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/kf.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-kf/kf-clr.isml/index.m3u8",
    iptvPattern: /^tgcom24|^tgcom 24/i
  },
  {
    id: "mediasetextra",
    name: "Mediaset Extra",
    lcn: 55,
    group: "Nazionali",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/kq.png",
    type: "direct",
    target: "https://live02-seg.msf.cdn.mediaset.net/live/ch-kq/kq-clr.isml/index.m3u8",
    iptvPattern: /^mediaset extra/i
  },
  // --- NAZIONALI & FREE-TO-AIR (7, 8, 26, 50) ---
  {
    id: "la7",
    name: "La7 HD",
    lcn: 7,
    group: "Nazionali",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/0/02/LA7_logo.svg/1280px-LA7_logo.svg.png",
    type: "daddylive",
    target: "",
    channelId: 855,
    iptvPattern: /^la7(?!d)/i
  },
  {
    id: "tv8",
    name: "TV8 HD",
    lcn: 8,
    group: "Nazionali",
    logo: "https://static.sky.it/images/sky/logo-tv8.png",
    type: "sky_fta",
    target: "https://apid.sky.it/vdp/v1/getLivestream?id=7&isMobile=false",
    iptvPattern: /^tv8/i
  },
  {
    id: "cielo",
    name: "Cielo HD",
    lcn: 26,
    group: "Nazionali",
    logo: "https://static.sky.it/images/sky/logo-cielo.png",
    type: "sky_fta",
    target: "https://apid.sky.it/vdp/v1/getLivestream?id=2&isMobile=false",
    iptvPattern: /^cielo/i
  },
  {
    id: "skytg24",
    name: "Sky TG24 HD",
    lcn: 50,
    group: "News",
    logo: "https://static.sky.it/images/sky/logo-skytg24.png",
    type: "sky_fta",
    target: "https://apid.sky.it/vdp/v1/getLivestream?id=1&isMobile=false",
    iptvPattern: /^sky tg24|^sky tg 24/i
  },
  // --- SPORT & FREE-TO-AIR SPORT (60, 61, 64) ---
  {
    id: "sportitalia",
    name: "Sportitalia HD",
    lcn: 60,
    group: "Sport",
    logo: "https://www.tvdream.net/img/sportitalia.png",
    type: "direct",
    target: "https://di-g7ij0rwh.vo.lswcdn.net/sportitalia/sihd/chunklist.m3u8",
    iptvPattern: /^sportitalia/i
  },
  {
    id: "solocalcio",
    name: "Solo Calcio",
    lcn: 61,
    group: "Sport",
    logo: "https://www.tvdream.net/img/solocalcio.png",
    type: "direct",
    target: "https://di-g7ij0rwh.vo.lswcdn.net/sportitalia/sisolocalcio.smil/chunklist_b4096000.m3u8",
    iptvPattern: /^solo calcio/i
  },
  {
    id: "supertennis",
    name: "Supertennis HD",
    lcn: 64,
    group: "Sport",
    logo: "https://www.supertennis.tv/images/logo.png",
    type: "direct",
    target: "https://live-embed.supertennix.hiway.media/restreamer/supertennix_client/gpu-a-c0-16/restreamer/rtmp/hls/h24_supertennix/manifest.m3u8",
    iptvPattern: /^supertennis/i
  },
  // --- SKY INTRATTENIMENTO & SERIE (108, 112) ---
  {
    id: "dlhd_881",
    name: "Sky Uno HD",
    lcn: 108,
    group: "Intrattenimento",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Sky_Uno_-_Logo_2020.svg/2560px-Sky_Uno_-_Logo_2020.svg.png",
    type: "daddylive",
    target: "",
    channelId: 881,
    iptvPattern: /^sky uno(?! \+1)/i
  },
  {
    id: "dlhd_880",
    name: "Sky Serie HD",
    lcn: 112,
    group: "Serie TV",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d7/Sky_Serie_logo_2021.svg/2560px-Sky_Serie_logo_2021.svg.png",
    type: "daddylive",
    target: "",
    channelId: 880,
    iptvPattern: /^sky serie/i
  },
  // --- SKY SPORT & EUROSPORT (200-211) ---
  {
    id: "dlhd_869",
    name: "Sky Sport 24 HD",
    lcn: 200,
    group: "Sky Sport",
    logo: "https://leccezionale.it/wp-content/uploads/2013/10/skysport.jpg",
    type: "daddylive",
    target: "",
    channelId: 869,
    iptvPattern: /^sky sport 24/i
  },
  {
    id: "dlhd_461",
    name: "Sky Sport Uno HD",
    lcn: 201,
    group: "Sky Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Sky_Sport_Uno_-_Logo_2020.svg/2560px-Sky_Sport_Uno_-_Logo_2020.svg.png",
    type: "daddylive",
    target: "",
    channelId: 461,
    iptvPattern: /^sky sport uno/i
  },
  {
    id: "dlhd_870",
    name: "Sky Sport Calcio HD",
    lcn: 202,
    group: "Sky Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Sky_Sport_Calcio_-_Logo_2021.svg/2560px-Sky_Sport_Calcio_-_Logo_2021.svg.png",
    type: "daddylive",
    target: "",
    channelId: 870,
    iptvPattern: /^sky sport calcio(?! \d)/i
  },
  {
    id: "dlhd_576",
    name: "Sky Sport Tennis HD",
    lcn: 203,
    group: "Sky Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Sky_Sport_Tennis.svg/1280px-Sky_Sport_Tennis.svg.png",
    type: "daddylive",
    target: "",
    channelId: 576,
    iptvPattern: /^sky sport tennis/i
  },
  {
    id: "dlhd_462",
    name: "Sky Sport Arena HD",
    lcn: 204,
    group: "Sky Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/68/Sky_Sport_Arena_-_Logo_2020.svg/2560px-Sky_Sport_Arena_-_Logo_2020.svg.png",
    type: "daddylive",
    target: "",
    channelId: 462,
    iptvPattern: /^sky sport arena/i
  },
  {
    id: "dlhd_460",
    name: "Sky Sport Max HD",
    lcn: 205,
    group: "Sky Sport",
    logo: "https://www.legavolleyfemminile.it/img/tv/sky_sport_action.png",
    type: "daddylive",
    target: "",
    channelId: 460,
    iptvPattern: /^sky sport max|^sky sport action/i
  },
  {
    id: "dlhd_574",
    name: "Sky Sport Golf HD",
    lcn: 206,
    group: "Sky Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fa/Sky_Sport_Golf_-_Logo_2018.svg/2560px-Sky_Sport_Golf_-_Logo_2018.svg.png",
    type: "daddylive",
    target: "",
    channelId: 574,
    iptvPattern: /^sky sport golf/i
  },
  {
    id: "dlhd_577",
    name: "Sky Sport F1 HD",
    lcn: 207,
    group: "Sky Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/28/Sky_Sport_F1_-_Logo_2015.svg/2560px-Sky_Sport_F1_-_Logo_2015.svg.png",
    type: "daddylive",
    target: "",
    channelId: 577,
    iptvPattern: /^sky sport f1/i
  },
  {
    id: "dlhd_575",
    name: "Sky Sport MotoGP HD",
    lcn: 208,
    group: "Sky Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/91/Sky_Sport_MotoGP_-_Logo_2020.svg/2560px-Sky_Sport_MotoGP_-_Logo_2020.svg.png",
    type: "daddylive",
    target: "",
    channelId: 575,
    iptvPattern: /^sky sport motogp/i
  },
  {
    id: "dlhd_875",
    name: "Sky Sport Basket HD",
    lcn: 209,
    group: "Sky Sport",
    logo: "https://images.contentstack.io/v3/assets/blta6c52b9cd5519be3/blteb5a8dbd6477491f/68629b6b9c34ed1f4538288d/skysport-basket-200x200.png",
    type: "daddylive",
    target: "",
    channelId: 875,
    iptvPattern: /^sky sport basket/i
  },
  {
    id: "dlhd_878",
    name: "Eurosport 1 Italy HD",
    lcn: 210,
    group: "Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/92/Eurosport_1_logo_2015.svg/2560px-Eurosport_1_logo_2015.svg.png",
    type: "daddylive",
    target: "",
    channelId: 878,
    iptvPattern: /^eurosport 1/i
  },
  {
    id: "dlhd_879",
    name: "Eurosport 2 Italy HD",
    lcn: 211,
    group: "Sport",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/Eurosport_2_logo_2015.svg/2560px-Eurosport_2_logo_2015.svg.png",
    type: "daddylive",
    target: "",
    channelId: 879,
    iptvPattern: /^eurosport 2/i
  },
  // --- DAZN (214-223) ---
  {
    id: "dlhd_877",
    name: "DAZN 1 Italy (Zona DAZN) HD",
    lcn: 214,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 877,
    iptvPattern: /zona dazn|^dazn 1(?! bar| sp)/i
  },
  {
    id: "dlhd_426",
    name: "DAZN 1 Bar DE HD",
    lcn: 215,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 426
  },
  {
    id: "dlhd_445",
    name: "DAZN 1 Spain HD",
    lcn: 216,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 445
  },
  {
    id: "dlhd_446",
    name: "DAZN 2 Spain HD",
    lcn: 217,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 446
  },
  {
    id: "dlhd_447",
    name: "DAZN 3 Spain HD",
    lcn: 218,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 447
  },
  {
    id: "dlhd_448",
    name: "DAZN 4 Spain HD",
    lcn: 219,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 448
  },
  {
    id: "dlhd_537",
    name: "DAZN F1 Spain HD",
    lcn: 220,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 537
  },
  {
    id: "dlhd_538",
    name: "DAZN LaLiga HD",
    lcn: 221,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 538
  },
  {
    id: "dlhd_960",
    name: "DAZN Ligue 1 France HD",
    lcn: 222,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 960
  },
  {
    id: "dlhd_918",
    name: "DAZN Portugal FIFA HD",
    lcn: 223,
    group: "DAZN",
    logo: "https://www.digital-news.it/img/palinsesti//2019/09/1568967638-dazn1.jpg",
    type: "daddylive",
    target: "",
    channelId: 918
  },
  // --- SKY CINEMA (301-309) ---
  {
    id: "dlhd_860",
    name: "Sky Cinema Uno HD",
    lcn: 301,
    group: "Cinema",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Sky_Cinema_Uno_logo_2021.svg/2560px-Sky_Cinema_Uno_logo_2021.svg.png",
    type: "daddylive",
    target: "",
    channelId: 860,
    iptvPattern: /^sky cinema uno(?! \+24)/i
  },
  {
    id: "dlhd_859",
    name: "Sky Cinema Collection HD",
    lcn: 303,
    group: "Cinema",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Sky_Cinema_Collection_logo_2021.svg/2560px-Sky_Cinema_Collection_logo_2021.svg.png",
    type: "daddylive",
    target: "",
    channelId: 859,
    iptvPattern: /^sky cinema collection/i
  },
  {
    id: "dlhd_865",
    name: "Sky Cinema Family HD",
    lcn: 304,
    group: "Cinema",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/Sky_Cinema_Family_logo_2021.svg/2560px-Sky_Cinema_Family_logo_2021.svg.png",
    type: "daddylive",
    target: "",
    channelId: 865,
    iptvPattern: /^sky cinema family/i
  },
  {
    id: "dlhd_861",
    name: "Sky Cinema Action HD",
    lcn: 305,
    group: "Cinema",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/62/Sky_Cinema_Action_logo_2021.svg/2560px-Sky_Cinema_Action_logo_2021.svg.png",
    type: "daddylive",
    target: "",
    channelId: 861,
    iptvPattern: /^sky cinema action/i
  },
  {
    id: "dlhd_867",
    name: "Sky Cinema Drama HD",
    lcn: 308,
    group: "Cinema",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/Sky_Cinema_Drama_logo_2021.svg/2560px-Sky_Cinema_Drama_logo_2021.svg.png",
    type: "daddylive",
    target: "",
    channelId: 867,
    iptvPattern: /^sky cinema drama|^sky cinema romance/i
  },
  {
    id: "dlhd_862",
    name: "Sky Cinema Comedy HD",
    lcn: 309,
    group: "Cinema",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/Sky_Cinema_Comedy_logo_2021.svg/2560px-Sky_Cinema_Comedy_logo_2021.svg.png",
    type: "daddylive",
    target: "",
    channelId: 862,
    iptvPattern: /^sky cinema comedy/i
  },
  // --- MUSICA & RADIO TV (36, 66, 69, 70, 257, 713) ---
  {
    id: "rtl1025",
    name: "RTL 102.5 News",
    lcn: 36,
    group: "Musica",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/65/RTL_102.5_logo_2016.svg/1200px-RTL_102.5_logo_2016.svg.png",
    type: "direct",
    target: "https://dd782ed59e2a4e86aabf6fc508674b59.msvdn.net/live/S38122967/2lyQRIAAGgRR/playlist_video.m3u8"
  },
  {
    id: "radio105",
    name: "Radio 105 TV",
    lcn: 66,
    group: "Musica",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/ec.png",
    type: "direct",
    target: "https://live02-seg.msr.cdn.mediaset.net/live/ch-ec/ec-clr.isml/index.m3u8"
  },
  {
    id: "deejaytv",
    name: "Deejay TV HD",
    lcn: 69,
    group: "Musica",
    logo: "https://upload.wikimedia.org/wikipedia/it/thumb/2/29/Logo_Deejay_TV_%282018%29.svg/1200px-Logo_Deejay_TV_%282018%29.svg.png",
    type: "direct",
    target: "https://4c4b867c89244861ac216426883d1ad0.msvdn.net/live/S85984808/sMO0tz9Sr2Rk/playlist.m3u8"
  },
  {
    id: "radioitalia",
    name: "Radio Italia TV HD",
    lcn: 70,
    group: "Musica",
    logo: "https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/Radio_Italia_TV_-_Logo_2017.svg/1280px-Radio_Italia_TV_-_Logo_2017.svg.png",
    type: "direct",
    target: "https://radioitaliatv.akamaized.net/hls/live/2093117/RadioitaliaTV/master.m3u8"
  },
  {
    id: "virginradiotv",
    name: "Virgin Radio TV",
    lcn: 257,
    group: "Musica",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/ew.png",
    type: "direct",
    target: "https://live02-seg.msr.cdn.mediaset.net/live/ch-ew/ew-clr.isml/index.m3u8"
  },
  {
    id: "rmctv",
    name: "Radio Monte Carlo TV",
    lcn: 713,
    group: "Musica",
    logo: "https://static2.mediasetplay.mediaset.it/Mediaset_Italia_Production_-_Main/bb.png",
    type: "direct",
    target: "https://live02-seg.msr.cdn.mediaset.net/live/ch-bb/bb-clr.isml/index.m3u8"
  }
];
async function resolveDaddyLive(channelId) {
  try {
    const r1 = await fetch(`https://dlhd.st/watch.php?id=${channelId}`, {
      headers: {
        "User-Agent": UA
      }
    });
    if (!r1.ok) return null;
    const t1 = await r1.text();
    const m1 = t1.match(/iframe src=["']([^"']+)/i);
    if (!m1) return null;
    const ifr1 = m1[1];
    const r2 = await fetch(ifr1, {
      headers: {
        "User-Agent": UA,
        "Referer": "https://dlhd.st/"
      }
    });
    if (!r2.ok) return null;
    const t2 = await r2.text();
    const m2 = t2.match(/iframe src=["']([^"']+)/i);
    if (!m2) return null;
    const ifr2 = m2[1];
    const r3 = await fetch(ifr2, {
      headers: {
        "User-Agent": UA,
        "Referer": ifr1,
        "Origin": new URL(ifr1).origin
      }
    });
    if (!r3.ok) return null;
    const t3 = await r3.text();
    const m3 = t3.match(/source\s*:\s*window\.atob\(['"]([^'"]+)/);
    if (!m3) return null;
    const streamUrl = atob(m3[1]);
    const referer = ifr2;
    return {
      streamUrl,
      referer
    };
  } catch (err) {
    console.error(`DaddyLive resolve error for id ${channelId}:`, err);
    return null;
  }
}
function generateOriginalM3u() {
  let m3u = `#EXTM3U url-tvg="${PUBLIC_BASE_URL}/epg.xml" x-tvg-url="${PUBLIC_BASE_URL}/epg.xml"\n`;
  const sortedChannels = [
    ...CHANNELS
  ].sort((a, b)=>a.lcn - b.lcn);
  for (const ch of sortedChannels){
    const streamUrl = ch.type === "daddylive" ? `${PUBLIC_BASE_URL}/stream?channel=${ch.id}` : ch.target;
    m3u += `#EXTINF:-1 tvg-id="${ch.id}" tvg-chno="${ch.lcn}" tvg-name="${ch.name}" tvg-logo="${ch.logo}" group-title="${ch.group}" quality="HD" provider="CDN Fallback",${ch.name}\n${streamUrl}\n`;
  }
  return m3u;
}
function generateOriginalChannelsJson() {
  const sortedChannels = [
    ...CHANNELS
  ].sort((a, b)=>a.lcn - b.lcn);
  return sortedChannels.map((ch)=>({
      id: ch.id,
      lcn: ch.lcn,
      name: ch.name,
      group: ch.group,
      logo: ch.logo,
      links: [
        {
          url: ch.type === "daddylive" ? `${PUBLIC_BASE_URL}/stream?channel=${ch.id}` : ch.target,
          quality: "HD",
          provider: "CDN Fallback"
        }
      ]
    }));
}
const DEFAULT_PORTAL_CANDIDATES = [
  {
    baseUrl: "http://maxgold.xyz:80/",
    user: "se75Qe1N",
    pass: "aYyzFMK",
    name: "IPTV 1 (MaxGold)"
  },
  {
    baseUrl: "http://0g7h1ljf4wx.sasa24.xyz:80/",
    user: "n1o2hju198d9sall12",
    pass: "u70uank81ni17h",
    name: "IPTV 2 (Sasa24)"
  }
];
const SLOT_CACHES = {
  1: null,
  2: null,
  3: null
};
const M3U_CACHES = {
  1: null,
  2: null,
  3: null
};
const JSON_CACHES = {
  1: null,
  2: null,
  3: null
};
async function testAndLoadPortal(cfg) {
  try {
    const streamsApi = `${cfg.baseUrl}player_api.php?username=${cfg.user}&password=${cfg.pass}&action=get_live_streams`;
    const catApi = `${cfg.baseUrl}player_api.php?username=${cfg.user}&password=${cfg.pass}&action=get_live_categories`;
    const [streamsRes, catRes] = await Promise.all([
      fetch(streamsApi, {
        headers: {
          "User-Agent": "VLC/3.0.21 LibVLC/3.0.21"
        },
        signal: AbortSignal.timeout(5000)
      }),
      fetch(catApi, {
        headers: {
          "User-Agent": "VLC/3.0.21 LibVLC/3.0.21"
        },
        signal: AbortSignal.timeout(4000)
      }).catch(()=>null)
    ]);
    if (!streamsRes.ok) return null;
    const streamsData = await streamsRes.json();
    if (!Array.isArray(streamsData) || streamsData.length < 500) return null;
    const categories = {};
    if (catRes && catRes.ok) {
      try {
        const catData = await catRes.json();
        if (Array.isArray(catData)) {
          for (const c of catData){
            if (c.category_id && c.category_name) {
              categories[c.category_id] = c.category_name;
            }
          }
        }
      } catch (_) {}
    }
    return {
      timestamp: Date.now(),
      portal: cfg,
      streams: streamsData.map((s)=>({
          stream_id: s.stream_id,
          name: s.name,
          stream_icon: s.stream_icon,
          category_id: s.category_id
        })),
      categories
    };
  } catch (err) {
    console.error(`Error loading portal ${cfg.baseUrl}:`, err);
    return null;
  }
}
async function discoverAllPortalsFromSoter() {
  const discovered = [];
  const seenUrls = new Set();
  try {
    const soterM3u = await fetchThegroovePage("/thegroove/scripters/Soter/path=ilchimico_M3U.php");
    if (!soterM3u) return discovered;
    const urlMatches = soterM3u.match(/https?:\/\/[^\s<>'"\`]+/g) || [];
    for (const u of urlMatches){
      const cleanUrl = u.replace(/[\]>]+$/, "");
      if (seenUrls.has(cleanUrl)) continue;
      seenUrls.add(cleanUrl);
      // 1. Direct get.php credentials
      if (cleanUrl.includes("get.php")) {
        try {
          const parsed = new URL(cleanUrl);
          const base = `${parsed.protocol}//${parsed.host}/`;
          const user = parsed.searchParams.get("username") || "";
          const pass = parsed.searchParams.get("password") || "";
          if (user && pass && !discovered.some((d)=>d.baseUrl === base && d.user === user)) {
            const label = base.includes("sasa24") ? "IPTV (Sasa24)" : base.includes("maxgold") ? "IPTV (MaxGold)" : "IPTV XC";
            discovered.push({
              baseUrl: base,
              user,
              pass,
              name: label
            });
          }
        } catch (_) {}
      } else if (/bit\.ly|rebrand\.ly|pastebin|dropbox/i.test(cleanUrl)) {
        try {
          const resp = await fetch(cleanUrl, {
            headers: {
              "User-Agent": UA
            },
            redirect: "follow",
            signal: AbortSignal.timeout(4000)
          });
          if (resp.ok) {
            const body = await resp.text();
            // Regex match /live/<user>/<pass>/<id>.ts
            const liveMatch = body.match(/(https?:\/\/[^\/]+(?:80)?)\/live\/([^\/]+)\/([^\/]+)\/\d+\.ts/);
            if (liveMatch) {
              const base = liveMatch[1].endsWith("/") ? liveMatch[1] : `${liveMatch[1]}/`;
              const user = liveMatch[2];
              const pass = liveMatch[3];
              if (!discovered.some((d)=>d.baseUrl === base && d.user === user)) {
                const label = base.includes("sasa24") ? "IPTV (Sasa24)" : base.includes("maxgold") ? "IPTV (MaxGold)" : "IPTV XC";
                discovered.push({
                  baseUrl: base,
                  user,
                  pass,
                  name: label
                });
              }
            }
          }
        } catch (_) {}
      }
    }
  } catch (err) {
    console.error("Soter deep scanner error:", err);
  }
  return discovered;
}
async function getOrRefreshSlot(slotNumber) {
  const now = Date.now();
  const cached = SLOT_CACHES[slotNumber];
  if (cached && now - cached.timestamp < 20 * 60 * 1000) {
    return cached;
  }
  // Fast-path: try primary candidate for slot
  const defaultCandidate = DEFAULT_PORTAL_CANDIDATES[slotNumber - 1];
  if (defaultCandidate) {
    const loaded = await testAndLoadPortal(defaultCandidate);
    if (loaded) {
      SLOT_CACHES[slotNumber] = loaded;
      return loaded;
    }
  }
  // If slot 3 and no default candidate, don't waste time unless fallover discovery finds one
  if (slotNumber === 3 && !defaultCandidate) {
    SLOT_CACHES[3] = null;
    return null;
  }
  // Fallover: Run Soter Deep Scanner
  const freshList = await discoverAllPortalsFromSoter();
  const alreadyAssigned = new Set();
  for(let s = 1; s <= 3; s++){
    if (s !== slotNumber && SLOT_CACHES[s]) {
      alreadyAssigned.add(`${SLOT_CACHES[s].portal.baseUrl}:${SLOT_CACHES[s].portal.user}`);
    }
  }
  for (const cand of freshList){
    const key = `${cand.baseUrl}:${cand.user}`;
    if (alreadyAssigned.has(key)) continue;
    const loaded = await testAndLoadPortal({
      ...cand,
      name: `IPTV ${slotNumber} (${cand.name})`
    });
    if (loaded) {
      SLOT_CACHES[slotNumber] = loaded;
      return loaded;
    }
  }
  SLOT_CACHES[slotNumber] = null;
  return null;
}
function parseStreamQualityAndProvider(rawName, slotBaseName) {
  let quality = "HD";
  let isBuffering = false;
  let isHevc = false;
  if (/fhd\s*\(buffering\)/i.test(rawName)) {
    quality = "FHD";
    isBuffering = true;
  } else if (/\b(4k|uhd)\b/i.test(rawName)) {
    quality = "4K";
  } else if (/\b(hevc)\b/i.test(rawName) || /\b(1080p?)\b/i.test(rawName) || /\bfhd\b/i.test(rawName)) {
    quality = "FHD";
    if (/\bhevc\b/i.test(rawName)) isHevc = true;
  } else if (/\b(hd|720p?)\b/i.test(rawName)) {
    quality = "HD";
  } else if (/\b(sd|576p?|480p?|lq)\b/i.test(rawName)) {
    quality = "SD";
  }
  let provider = slotBaseName;
  if (isBuffering) {
    provider = `${slotBaseName} (Buffering)`;
  } else if (isHevc) {
    provider = `${slotBaseName} (HEVC)`;
  }
  let baseName = rawName.replace(/^[a-z]{2}[:|]\s*/i, "").replace(/\[.*?\]/g, "").replace(/\s*\(buffering\)/gi, "").replace(/\b(fhd|hd|sd|4k|uhd|hevc|lq)\s*(\([a-z0-9_\s]+\))?/gi, "").replace(/\s+/g, " ").trim();
  return {
    quality,
    provider,
    baseName
  };
}
function isAdultContent(catName, streamName, catId) {
  if (catId === "398") return true; // MaxGold ADULTI LIVE
  const c = (catName || "").toLowerCase();
  const s = (streamName || "").toLowerCase();
  // Non-adult radio / music exceptions
  if (c.includes("radio") || s.includes("pop adult") || s.includes("adult contemporary")) {
    return false;
  }
  // Adult category keywords
  if (c.includes("adult") || c.includes("xxx") || c.includes("porn") || c.includes("erotic") || c.includes("redlight") || c.includes("red light") || c.includes("hot club") || c.includes("hardcore") || c.includes("18+")) {
    return true;
  }
  // Adult stream name keywords
  return /(\b|\*|_)xxx\b|hot\s*club|\badulti?(\s|$)|porn[a-z]*|erotic[a-z]*|red\s*light|playboy|penthouse|hustler|brazzers|dorcel|evil\s*angel|puretaboo|hardcore|gangbang|blowjob|cuckold|squirted|eroxxx|venus\s*xxx|sexstream|babes\s*xxx|\b18\+\b|blacked|fake\s*taxi|czech\s*streets|tiny4k|livecam|centoxcento|exxxtasy|starseller|teleclotto|man-x|passie\s*xxx/i.test(s);
}
function resolveChannelLcnAndId(baseName, streamId) {
  for (const ch of CHANNELS){
    if (ch.iptvPattern && ch.iptvPattern.test(baseName)) {
      return {
        id: ch.id,
        name: ch.name,
        lcn: ch.lcn
      };
    }
  }
  // Sky Sport Calcio feeds: 251-260
  const skySportCalcioMatch = baseName.match(/sky sport (?:calcio )?(\d{3})/i);
  if (skySportCalcioMatch) {
    const num = parseInt(skySportCalcioMatch[1], 10);
    if (num >= 251 && num <= 260) {
      return {
        id: `skysport_${num}`,
        name: `Sky Sport ${num}`,
        lcn: num
      };
    }
  }
  // DAZN feeds: 1-10
  const daznMatch = baseName.match(/(?:zona )?dazn\s*(\d+)/i);
  if (daznMatch) {
    const num = parseInt(daznMatch[1], 10);
    if (num >= 1 && num <= 10) {
      return {
        id: `dazn_${num}`,
        name: `DAZN ${num}`,
        lcn: 214 + num - 1
      };
    }
  }
  // Primafila feeds: 1-30
  const primafilaMatch = baseName.match(/primafila\s*(\d+)/i);
  if (primafilaMatch) {
    const num = parseInt(primafilaMatch[1], 10);
    if (num >= 1 && num <= 30) {
      return {
        id: `primafila_${num}`,
        name: `Primafila ${num}`,
        lcn: 350 + num
      };
    }
  }
  const fallbackId = baseName.toLowerCase().replace(/[^a-z0-9]+/g, "") || `stream${streamId}`;
  return {
    id: fallbackId,
    name: baseName,
    lcn: 0
  };
}
async function generateSlotM3u(slotNumber) {
  const now = Date.now();
  const cached = M3U_CACHES[slotNumber];
  if (cached && now - cached.timestamp < 15 * 60 * 1000) {
    return cached.data;
  }
  const slotData = await getOrRefreshSlot(slotNumber);
  let m3u = `#EXTM3U url-tvg="${PUBLIC_BASE_URL}/epg.xml" x-tvg-url="${PUBLIC_BASE_URL}/epg.xml"\n`;
  if (!slotData || !slotData.streams || slotData.streams.length === 0) {
    M3U_CACHES[slotNumber] = {
      timestamp: now,
      data: m3u
    };
    return m3u;
  }
  const { portal, streams, categories } = slotData;
  const channelMap = new Map();
  let fallbackLcn = 1000;
  for (const s of streams){
    const rawName = (s.name || "").trim();
    const streamId = s.stream_id;
    const catId = s.category_id || "";
    const group = categories[catId] || "Sport & TV";
    if (catId === "12" || rawName.startsWith("---") || rawName.endsWith("---") || isAdultContent(group, rawName, catId)) {
      continue;
    }
    const { quality, provider, baseName } = parseStreamQualityAndProvider(rawName, portal.name);
    const resolved = resolveChannelLcnAndId(baseName, streamId);
    const channelId = resolved.id;
    const logo = s.stream_icon || "";
    const streamUrl = `${portal.baseUrl}live/${portal.user}/${portal.pass}/${streamId}.ts`;
    if (!channelMap.has(channelId)) {
      channelMap.set(channelId, {
        id: channelId,
        lcn: resolved.lcn,
        name: resolved.name || baseName,
        logo: logo,
        group: group,
        links: []
      });
    }
    channelMap.get(channelId).links.push({
      quality,
      provider,
      url: streamUrl
    });
  }
  const sortedList = Array.from(channelMap.values()).map((ch)=>{
    if (ch.lcn === 0) {
      return {
        ...ch,
        lcn: fallbackLcn++
      };
    }
    return ch;
  });
  sortedList.sort((a, b)=>a.lcn - b.lcn);
  for (const ch of sortedList){
    for (const lk of ch.links){
      m3u += `#EXTINF:-1 tvg-id="${ch.id}" tvg-chno="${ch.lcn}" tvg-name="${ch.name}" tvg-logo="${ch.logo}" group-title="${ch.group}" quality="${lk.quality}" provider="${lk.provider}",${ch.name}\n${lk.url}\n`;
    }
  }
  M3U_CACHES[slotNumber] = {
    timestamp: now,
    data: m3u
  };
  return m3u;
}
async function generateSlotChannelsJson(slotNumber) {
  const now = Date.now();
  const cached = JSON_CACHES[slotNumber];
  if (cached && now - cached.timestamp < 15 * 60 * 1000) {
    return cached.data;
  }
  const slotData = await getOrRefreshSlot(slotNumber);
  if (!slotData || !slotData.streams || slotData.streams.length === 0) {
    JSON_CACHES[slotNumber] = {
      timestamp: now,
      data: []
    };
    return [];
  }
  const { portal, streams, categories } = slotData;
  const channelMap = new Map();
  let fallbackLcn = 1000;
  for (const s of streams){
    const rawName = (s.name || "").trim();
    const streamId = s.stream_id;
    const catId = s.category_id || "";
    const group = categories[catId] || "Sport & TV";
    if (catId === "12" || rawName.startsWith("---") || rawName.endsWith("---") || isAdultContent(group, rawName, catId)) {
      continue;
    }
    const { quality, provider, baseName } = parseStreamQualityAndProvider(rawName, portal.name);
    const resolved = resolveChannelLcnAndId(baseName, streamId);
    const channelId = resolved.id;
    const logo = s.stream_icon || "";
    const streamUrl = `${portal.baseUrl}live/${portal.user}/${portal.pass}/${streamId}.ts`;
    if (!channelMap.has(channelId)) {
      channelMap.set(channelId, {
        id: channelId,
        lcn: resolved.lcn,
        name: resolved.name || baseName,
        group: group,
        logo: logo,
        links: []
      });
    }
    channelMap.get(channelId).links.push({
      url: streamUrl,
      quality: quality,
      provider: provider
    });
  }
  const list = Array.from(channelMap.values()).map((ch)=>{
    if (ch.lcn === 0) {
      return {
        ...ch,
        lcn: fallbackLcn++
      };
    }
    return ch;
  });
  list.sort((a, b)=>a.lcn - b.lcn);
  JSON_CACHES[slotNumber] = {
    timestamp: now,
    data: list
  };
  return list;
}
let EPG_CACHE = null;
const EPG_ID_MAPPING = {
  // Rai
  "Rai1.it": "rai1",
  "Rai2.it": "rai2",
  "Rai3.it": "rai3",
  "Rai4.it": "rai4",
  "Rai5.it": "rai5",
  "RaiMovie.it": "raimovie",
  "RaiPremium.it": "raipremium",
  "RaiGulp.it": "raigulp",
  "RaiYoyo.it": "raiyoyo",
  "RaiNews24.it": "rainews24",
  "RaiStoria.it": "raistoria",
  "RaiScuola.it": "raiscuola",
  "RaiSport.it": "raisport",
  // Mediaset
  "Rete.4.it": "r4",
  "Canale.5.it": "c5",
  "Italia.1.it": "i1",
  "20.it": "c20",
  "Iris.it": "iris",
  "27.Twentyseven.it": "c27",
  "La.5.it": "la5",
  "Cine34.it": "cine34",
  "Focus.it": "focus",
  "Top.Crime.it": "topcrime",
  "Italia.2.it": "italia2",
  "TGCom.it": "tgcom24",
  "Mediaset.Extra.it": "mediasetextra",
  // FTA & Sports
  "LA7.HD.it": "la7",
  "TV8.HD.it": "tv8",
  "cielo.it": "cielo",
  "Sky.TG24.it": "skytg24",
  "Solocalcio.it.it": "solocalcio",
  "SuperTennis.HD.it": "supertennis",
  "SPORTITALIA.ch": "sportitalia",
  // Sky Intrattenimento & Serie
  "Sky.Uno.it": "dlhd_881",
  "Sky.Serie.it": "dlhd_880",
  // Sky Sport
  "Sky.Sport.24.it": "dlhd_869",
  "Sky.Sport.Uno.it": "dlhd_461",
  "Sky.Sport.Calcio.it": "dlhd_870",
  "Sky.Sport.Tennis.it": "dlhd_576",
  "Sky.Sport.Arena.it": "dlhd_462",
  "Sky.Sport.Max.it": "dlhd_460",
  "Sky.Sport.Golf.it": "dlhd_574",
  "Sky.Sport.F1.it": "dlhd_577",
  "Sky.Sport.MotoGP.it": "dlhd_575",
  "Sky.Sport.NBA.it": "dlhd_875",
  // Eurosport
  "Eurosport.1.I.ch": "dlhd_878",
  "Eurosport.2.I.ch": "dlhd_879",
  // DAZN
  "DAZN.1.it.it": "dlhd_877",
  "DAZN.2.it.it": "dlhd_446",
  "DAZN4.it": "dlhd_447",
  "DAZN5.it": "dlhd_448",
  // Sky Cinema
  "Sky.Cinema.Uno.it": "dlhd_860",
  "Sky.Cinema.Collection.it": "dlhd_859",
  "Sky.Cinema.Family.it": "dlhd_865",
  "Sky.Cinema.Action.it": "dlhd_861",
  "Sky.Cinema.Drama.it": "dlhd_867",
  "Sky.Cinema.Comedy.it": "dlhd_862",
  // Music & Radio
  "RTL.102.5.HD.it": "rtl1025",
  "Radio.105.it": "radio105",
  "Deejay.TV.it": "deejaytv",
  "Radio.Italia.TV.HD.it": "radioitalia",
  "Virgin.Radio.it": "virginradiotv",
  "RMC.it": "rmctv",
  // Sky Sport Calcio Feeds (251-260)
  "Sky.Sport..251.it": "skysport_251",
  "Sky.Sport..252.it": "skysport_252",
  "Sky.Sport..253.it": "skysport_253",
  "Sky.Sport..254.it": "skysport_254",
  "Sky.Sport..255.it": "skysport_255",
  "Sky.Sport..256.it": "skysport_256",
  "Sky.Sport..257.it": "skysport_257",
  "Sky.Sport..258.it": "skysport_258",
  "Sky.Sport..259.it": "skysport_259",
  "Sky.Calcio.10..260.it": "skysport_260"
};
function parseXmltvDate(dStr) {
  if (!dStr) return null;
  const m = dStr.match(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\s*([+-]\d{4})?/);
  if (!m) return null;
  const iso = `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}${m[7] ? m[7].slice(0, 3) + ":" + m[7].slice(3) : "Z"}`;
  const time = new Date(iso).getTime();
  return isNaN(time) ? null : time;
}
function escapeXml(unsafe) {
  return unsafe.replace(/[<>&'"]/g, (c)=>{
    switch(c){
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case "&":
        return "&amp;";
      case "'":
        return "&apos;";
      case '"':
        return "&quot;";
      default:
        return c;
    }
  });
}
async function getOrRefreshEpg() {
  const now = Date.now();
  if (EPG_CACHE && now - EPG_CACHE.timestamp < 4 * 60 * 60 * 1000) {
    return EPG_CACHE;
  }
  try {
    const [it1Res, ch1Res] = await Promise.all([
      fetch("https://epgshare01.online/epgshare01/epg_ripper_IT1.xml.gz", {
        headers: {
          "User-Agent": UA
        },
        signal: AbortSignal.timeout(12000)
      }),
      fetch("https://epgshare01.online/epgshare01/epg_ripper_CH1.xml.gz", {
        headers: {
          "User-Agent": UA
        },
        signal: AbortSignal.timeout(12000)
      }).catch(()=>null)
    ]);
    if (!it1Res.ok) {
      console.error("Failed to fetch IT1 EPG:", it1Res.status);
      return EPG_CACHE;
    }
    const it1Stream = it1Res.body.pipeThrough(new DecompressionStream("gzip"));
    const it1Text = await new Response(it1Stream).text();
    let ch1Text = "";
    if (ch1Res && ch1Res.ok) {
      try {
        const ch1Stream = ch1Res.body.pipeThrough(new DecompressionStream("gzip"));
        ch1Text = await new Response(ch1Stream).text();
      } catch (err) {
        console.error("Error decompressing CH1 EPG:", err);
      }
    }
    const jsonMap = {};
    const programmeXmlChunks = [];
    const processXml = (xml, allowedMap)=>{
      const regex = /<programme\s+([^>]+)>([\s\S]*?)<\/programme>/g;
      let match;
      while((match = regex.exec(xml)) !== null){
        const attrStr = match[1];
        const body = match[2];
        const chMatch = attrStr.match(/channel="([^"]+)"/);
        if (!chMatch) continue;
        const upstreamCh = chMatch[1];
        const canonicalId = allowedMap[upstreamCh];
        if (!canonicalId) continue;
        const startM = attrStr.match(/start="([^"]+)"/);
        const stopM = attrStr.match(/stop="([^"]+)"/);
        const startStr = startM ? startM[1] : "";
        const stopStr = stopM ? stopM[1] : "";
        const rewritten = attrStr.replace(/channel="[^"]+"/, `channel="${canonicalId}"`);
        programmeXmlChunks.push(`  <programme ${rewritten}>${body}</programme>`);
        const tM = body.match(/<title[^>]*>([^<]+)<\/title>/);
        const subM = body.match(/<sub-title[^>]*>([^<]+)<\/sub-title>/);
        const dM = body.match(/<desc[^>]*>([^<]+)<\/desc>/);
        const iM = body.match(/<icon[^>]*src="([^"]+)"/);
        const startMs = parseXmltvDate(startStr);
        const stopMs = parseXmltvDate(stopStr);
        if (tM && startMs && stopMs) {
          if (!jsonMap[canonicalId]) jsonMap[canonicalId] = [];
          jsonMap[canonicalId].push({
            name: tM[1].trim(),
            subtitle: subM ? subM[1].trim() : null,
            description: dM ? dM[1].trim() : null,
            startTime: {
              unix: startMs
            },
            endTime: {
              unix: stopMs
            },
            image: iM ? iM[1].trim() : null
          });
        }
      }
    };
    const ch1Allowed = {
      "SPORTITALIA.ch": "sportitalia",
      "Eurosport.1.I.ch": "dlhd_878",
      "Eurosport.2.I.ch": "dlhd_879"
    };
    const it1Allowed = {};
    for (const [k, v] of Object.entries(EPG_ID_MAPPING)){
      if (!ch1Allowed[k]) it1Allowed[k] = v;
    }
    processXml(it1Text, it1Allowed);
    if (ch1Text) {
      processXml(ch1Text, ch1Allowed);
    }
    let channelsXml = "";
    for (const ch of CHANNELS){
      channelsXml += `  <channel id="${ch.id}">\n    <display-name lang="it">${escapeXml(ch.name)}</display-name>\n    <display-name lang="it">${ch.lcn}</display-name>\n    <icon src="${escapeXml(ch.logo)}" />\n  </channel>\n`;
    }
    const fullXml = `<?xml version="1.0" encoding="UTF-8"?>\n<tv generator-info-name="Cinemuse Unified EPG" generator-info-url="${PUBLIC_BASE_URL}/epg">\n${channelsXml}${programmeXmlChunks.join("\n")}\n</tv>`;
    const cs = new CompressionStream("gzip");
    const writer = cs.writable.getWriter();
    writer.write(new TextEncoder().encode(fullXml));
    writer.close();
    const gzipBuf = new Uint8Array(await new Response(cs.readable).arrayBuffer());
    EPG_CACHE = {
      timestamp: now,
      xml: fullXml,
      gzip: gzipBuf,
      json: jsonMap
    };
    return EPG_CACHE;
  } catch (err) {
    console.error("EPG refresh error:", err);
    return EPG_CACHE;
  }
}
serve(async (req)=>{
  const url = new URL(req.url);
  const path = url.pathname;
  const headers = new Headers({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
    "Access-Control-Allow-Headers": "*"
  });
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers
    });
  }
  // --- 1. /playlist.m3u (Original Clean Playlist) ---
  if (path.endsWith("/playlist.m3u") || path.endsWith("/playlist") || path.endsWith("/playlist_standard.m3u")) {
    headers.set("Content-Type", "application/vnd.apple.mpegurl; charset=utf-8");
    headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const m3u = generateOriginalM3u();
    return new Response(m3u, {
      headers
    });
  }
  // --- 2. /channels.json (Original Clean JSON) ---
  if (path.endsWith("/channels.json") || path.endsWith("/channels")) {
    headers.set("Content-Type", "application/json; charset=utf-8");
    headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const jsonList = generateOriginalChannelsJson();
    return new Response(JSON.stringify({
      channels: jsonList
    }, null, 2), {
      headers
    });
  }
  // --- 3. Multi-Slot IPTV Playlists (/iptv/1, /iptv/2, /iptv/3) ---
  // Slot 1 (Primary - MaxGold, defaults for /iptv.m3u)
  if (path.endsWith("/iptv/1") || path.endsWith("/iptv/1.m3u") || path.endsWith("/iptv1.m3u") || path.endsWith("/iptv1") || path.endsWith("/iptv.m3u") || path.endsWith("/iptv/playlist.m3u") || path.endsWith("/iptv")) {
    headers.set("Content-Type", "application/vnd.apple.mpegurl; charset=utf-8");
    headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const m3u = await generateSlotM3u(1);
    return new Response(m3u, {
      headers
    });
  }
  // Slot 2 (Secondary - Sasa24)
  if (path.endsWith("/iptv/2") || path.endsWith("/iptv/2.m3u") || path.endsWith("/iptv2.m3u") || path.endsWith("/iptv2")) {
    headers.set("Content-Type", "application/vnd.apple.mpegurl; charset=utf-8");
    headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const m3u = await generateSlotM3u(2);
    return new Response(m3u, {
      headers
    });
  }
  // Slot 3 (Tertiary - Empty placeholder if no 3rd provider)
  if (path.endsWith("/iptv/3") || path.endsWith("/iptv/3.m3u") || path.endsWith("/iptv3.m3u") || path.endsWith("/iptv3")) {
    headers.set("Content-Type", "application/vnd.apple.mpegurl; charset=utf-8");
    headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const m3u = await generateSlotM3u(3);
    return new Response(m3u, {
      headers
    });
  }
  // --- 4. Multi-Slot IPTV JSON Channels ---
  // Slot 1 JSON
  if (path.endsWith("/iptv_channels/1.json") || path.endsWith("/iptv_channels/1") || path.endsWith("/iptv1.json") || path.endsWith("/iptv_channels.json") || path.endsWith("/iptv/channels.json")) {
    headers.set("Content-Type", "application/json; charset=utf-8");
    headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const jsonList = await generateSlotChannelsJson(1);
    return new Response(JSON.stringify({
      channels: jsonList
    }, null, 2), {
      headers
    });
  }
  // Slot 2 JSON
  if (path.endsWith("/iptv_channels/2.json") || path.endsWith("/iptv_channels/2") || path.endsWith("/iptv2.json")) {
    headers.set("Content-Type", "application/json; charset=utf-8");
    headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const jsonList = await generateSlotChannelsJson(2);
    return new Response(JSON.stringify({
      channels: jsonList
    }, null, 2), {
      headers
    });
  }
  // Slot 3 JSON
  if (path.endsWith("/iptv_channels/3.json") || path.endsWith("/iptv_channels/3") || path.endsWith("/iptv3.json")) {
    headers.set("Content-Type", "application/json; charset=utf-8");
    headers.set("Cache-Control", "no-cache, no-store, must-revalidate");
    const jsonList = await generateSlotChannelsJson(3);
    return new Response(JSON.stringify({
      channels: jsonList
    }, null, 2), {
      headers
    });
  }
  // --- 5. /proxy?url=...&ref=... ---
  if (path.endsWith("/proxy")) {
    const targetUrl = url.searchParams.get("url");
    const ref = url.searchParams.get("ref") || "https://hamis.romponalis.st/";
    if (!targetUrl) {
      return new Response("Missing url param", {
        status: 400,
        headers
      });
    }
    try {
      const origin = new URL(ref).origin;
      const resp = await fetch(targetUrl, {
        headers: {
          "User-Agent": UA,
          "Referer": ref,
          "Origin": origin
        }
      });
      if (!resp.ok) {
        return new Response(`Upstream error: ${resp.status}`, {
          status: resp.status,
          headers
        });
      }
      const contentType = resp.headers.get("content-type") || "application/octet-stream";
      headers.set("Content-Type", contentType);
      headers.set("Cache-Control", "no-cache");
      if (contentType.includes("mpegurl") || targetUrl.includes(".m3u8")) {
        const text = await resp.text();
        const base = targetUrl.substring(0, targetUrl.lastIndexOf("/") + 1);
        const rewritten = text.split("\n").map((line)=>{
          const trimmed = line.trim();
          if (trimmed && !trimmed.startsWith("#")) {
            const absoluteUrl = trimmed.startsWith("http") ? trimmed : base + trimmed;
            return `${PUBLIC_BASE_URL}/proxy?url=${encodeURIComponent(absoluteUrl)}&ref=${encodeURIComponent(ref)}`;
          }
          return line;
        }).join("\n");
        return new Response(rewritten, {
          headers
        });
      }
      return new Response(resp.body, {
        headers,
        status: resp.status
      });
    } catch (err) {
      return new Response(`Proxy error: ${err}`, {
        status: 502,
        headers
      });
    }
  }
  // --- 6. /stream?channel=... ---
  if (path.endsWith("/stream")) {
    const chId = url.searchParams.get("channel");
    const ch = CHANNELS.find((c)=>c.id === chId);
    if (!ch) {
      return new Response("Channel not found", {
        status: 404,
        headers
      });
    }
    if (ch.type === "daddylive" && ch.channelId) {
      const res = await resolveDaddyLive(ch.channelId);
      if (!res) {
        return new Response("DaddyLive stream temporarily unavailable", {
          status: 503,
          headers
        });
      }
      const proxyUrl = `${PUBLIC_BASE_URL}/proxy?url=${encodeURIComponent(res.streamUrl)}&ref=${encodeURIComponent(res.referer)}`;
      return Response.redirect(proxyUrl, 302);
    }
    return Response.redirect(ch.target, 302);
  }
  // --- 7. EPG Endpoints (/epg.xml, /epg.xml.gz, /epg.json, /epg) ---
  if (path.endsWith("/epg.xml") || path.endsWith("/epg.xml.gz") || path.endsWith("/epg.json") || path.endsWith("/epg")) {
    const epg = await getOrRefreshEpg();
    if (!epg) {
      return new Response("EPG unavailable", {
        status: 503,
        headers
      });
    }
    const format = url.searchParams.get("format");
    const accept = req.headers.get("accept") || "";
    if (path.endsWith("/epg.json") || format === "json" || accept.includes("application/json")) {
      headers.set("Content-Type", "application/json; charset=utf-8");
      headers.set("Cache-Control", "public, max-age=14400");
      return new Response(JSON.stringify(epg.json), {
        headers
      });
    }
    if (path.endsWith("/epg.xml.gz") || format === "gz") {
      headers.set("Content-Type", "application/gzip");
      headers.set("Content-Encoding", "gzip");
      headers.set("Cache-Control", "public, max-age=14400");
      return new Response(epg.gzip, {
        headers
      });
    }
    headers.set("Content-Type", "application/xml; charset=utf-8");
    headers.set("Cache-Control", "public, max-age=14400");
    return new Response(epg.xml, {
      headers
    });
  }
  headers.set("Content-Type", "text/plain");
  return new Response("Cinemuse Live TV Resolver is Active.\nAvailable Playlists:\n - /playlist.m3u (Original Clean)\n - /iptv/1.m3u (MaxGold)\n - /iptv/2.m3u (Sasa24)\n - /iptv/3.m3u (Backup/Empty)\nAvailable EPG:\n - /epg.xml (Unified XMLTV)\n - /epg.xml.gz (Gzipped XMLTV)\n - /epg.json (JSON Guide)", {
    headers
  });
});
