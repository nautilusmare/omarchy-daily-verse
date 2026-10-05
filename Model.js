// Pure logic for the daily-verse plugin. Qt-free so it stays testable under
// node (functions + var only; no ES modules, no arrow functions).
// Commentary policy: Reformed / Lutheran / adjacent ONLY.
// Preferred order: Matthew Henry -> JFB -> Gill -> Calvin -> Keil-Delitzsch.
// Never query adam-clarke or tyndale.

var API_BASE = "https://bible.helloao.org/api";

// Curated translations, all available on helloao. Geneva 1599 keeps its
// original spelling ("loued", "hee") — that is the source text, not a bug.
var TRANSLATIONS = [
  { id: "BSB", label: "BSB" },
  { id: "eng_web", label: "WEB" },
  { id: "eng_kjv", label: "KJV" },
  { id: "eng_gnv", label: "Geneva 1599" },
  { id: "eng_asv", label: "ASV" },
  { id: "eng_ylt", label: "YLT" }
];

function translationIds() {
  var ids = [];
  for (var i = 0; i < TRANSLATIONS.length; i++) ids.push(TRANSLATIONS[i].id);
  return ids;
}

function translationLabel(id) {
  for (var i = 0; i < TRANSLATIONS.length; i++) {
    if (TRANSLATIONS[i].id === id) return TRANSLATIONS[i].label;
  }
  return String(id || "BSB");
}

function nextTranslation(current) {
  var ids = translationIds();
  var i = ids.indexOf(String(current || "BSB"));
  if (i < 0) return ids[0];
  return ids[(i + 1) % ids.length];
}

// [{ value, label }] for the shell Dropdown component.
function translationOptions() {
  var out = [];
  for (var i = 0; i < TRANSLATIONS.length; i++) {
    out.push({ value: TRANSLATIONS[i].id, label: TRANSLATIONS[i].label });
  }
  return out;
}

// Order matters: MH first per user preference, then JFB for coverage.
var COMMENTARY_ORDER = [
  "matthew-henry",
  "jamieson-fausset-brown",
  "john-gill",
  "john-calvin",
  "keil-delitzsch"
];

var COMMENTARY_NAMES = {
  "matthew-henry": "Matthew Henry",
  "jamieson-fausset-brown": "Jamieson-Fausset-Brown",
  "john-gill": "John Gill",
  "john-calvin": "John Calvin",
  "keil-delitzsch": "Keil & Delitzsch"
};

// Short labels for the in-panel switcher button.
var COMMENTARY_SHORT = {
  "matthew-henry": "Henry",
  "jamieson-fausset-brown": "JFB",
  "john-gill": "Gill",
  "john-calvin": "Calvin",
  "keil-delitzsch": "K&D"
};

function commentaryName(id) {
  return COMMENTARY_NAMES[id] || String(id || "");
}

function commentaryShort(id) {
  return COMMENTARY_SHORT[id] || commentaryName(id);
}

function nextCommentary(current) {
  var i = COMMENTARY_ORDER.indexOf(String(current || "matthew-henry"));
  if (i < 0) return COMMENTARY_ORDER[0];
  return COMMENTARY_ORDER[(i + 1) % COMMENTARY_ORDER.length];
}

// [{ value, label }] for the shell Dropdown component, MH-first order.
function commentaryOptions() {
  var out = [];
  for (var i = 0; i < COMMENTARY_ORDER.length; i++) {
    out.push({ value: COMMENTARY_ORDER[i], label: commentaryName(COMMENTARY_ORDER[i]) });
  }
  return out;
}

// Books Calvin never wrote on (no 2JN/3JN/REV, partial EZK, no wisdom/history
// middle books). Used to skip a doomed request fast.
var CALVIN_BOOKS = {
  GEN: 1, EXO: 1, LEV: 1, NUM: 1, DEU: 1, JOS: 1, PSA: 1, ISA: 1,
  JER: 1, LAM: 1, EZK: 1, DAN: 1, HOS: 1, JOL: 1, AMO: 1, OBA: 1,
  JON: 1, MIC: 1, NAM: 1, HAB: 1, ZEP: 1, HAG: 1, ZEC: 1, MAL: 1,
  MAT: 1, MRK: 1, LUK: 1, JHN: 1, ACT: 1, ROM: 1, "1CO": 1, "2CO": 1,
  GAL: 1, EPH: 1, PHP: 1, COL: 1, "1TH": 1, "2TH": 1, "1TI": 1,
  "2TI": 1, TIT: 1, PHM: 1, HEB: 1, JAS: 1, "1PE": 1, "2PE": 1,
  "1JN": 1, JUD: 1
};

// Keil & Delitzsch is Old Testament only. Rough gate: allow anything that
// is not a known NT book.
var NT_BOOKS = {
  MAT: 1, MRK: 1, LUK: 1, JHN: 1, ACT: 1, ROM: 1, "1CO": 1, "2CO": 1,
  GAL: 1, EPH: 1, PHP: 1, COL: 1, "1TH": 1, "2TH": 1, "1TI": 1,
  "2TI": 1, TIT: 1, PHM: 1, HEB: 1, JAS: 1, "1PE": 1, "2PE": 1,
  "1JN": 1, "2JN": 1, "3JN": 1, JUD: 1, REV: 1
};

function commentaryAvailable(id, book) {
  if (id === "john-calvin") return !!CALVIN_BOOKS[book];
  if (id === "keil-delitzsch") return !NT_BOOKS[book];
  return true;
}

// Build the fallback chain starting from the user's preference, keeping
// MH-first default but never leaving the allow-list.
function fallbackChain(preferred) {
  var chain = [];
  if (preferred && COMMENTARY_ORDER.indexOf(preferred) !== -1) chain.push(preferred);
  for (var i = 0; i < COMMENTARY_ORDER.length; i++) {
    if (chain.indexOf(COMMENTARY_ORDER[i]) === -1) chain.push(COMMENTARY_ORDER[i]);
  }
  return chain;
}

function verseUrl(translation, book, chapter) {
  return API_BASE + "/" + translation + "/" + book + "/" + chapter + ".simple.json";
}

function commentaryUrl(id, book, chapter) {
  return API_BASE + "/c/" + id + "/" + book + "/" + chapter + ".json";
}

// --- full commentary in the browser ---
// bible.helloao.org is API-only (its site is just docs, no reader page), so
// "read the whole commentary" links out to Bible Hub, which renders all five
// public-domain commentaries with readable typography. Every slug and book
// path below was verified to return HTTP 200.
var WEB_COMMENTARY_SLUG = {
  "matthew-henry": "mhc",
  "jamieson-fausset-brown": "jfb",
  "john-gill": "gill",
  "john-calvin": "calvin",
  "keil-delitzsch": "kad"
};

// OSIS -> Bible Hub book slug. Numbered books use an underscore, not a hyphen
// (1_corinthians, not 1-corinthians) -- verified against the live site.
var WEB_BOOK_SLUG = {
  GEN: "genesis", EXO: "exodus", DEU: "deuteronomy", JOS: "joshua",
  PSA: "psalms", ISA: "isaiah", JER: "jeremiah", LAM: "lamentations",
  HAB: "habakkuk", ZEP: "zephaniah", PRO: "proverbs", MIC: "micah",
  MAT: "matthew", MRK: "mark", LUK: "luke", JHN: "john", ACT: "acts",
  ROM: "romans", "1CO": "1_corinthians", GAL: "galatians", EPH: "ephesians",
  PHP: "philippians", HEB: "hebrews"
};

// Empty string when the commentary or book is unknown, so the panel can hide
// the button instead of opening a dead link.
function webCommentaryUrl(id, book, chapter) {
  var slug = WEB_COMMENTARY_SLUG[id];
  var b = WEB_BOOK_SLUG[String(book || "").toUpperCase()];
  if (!slug || !b) return "";
  return "https://biblehub.com/commentaries/" + slug + "/" + b + "/" + chapter + ".htm";
}

// In-panel preview: collapse to about `limit` characters, preferring to stop
// at a sentence boundary so it reads as a finished thought rather than a
// mid-sentence cut. Whitespace is flattened to keep the panel compact.
function summarize(text, limit) {
  var s = String(text || "").replace(/\s+/g, " ").trim();
  var max = Number(limit) || 0;
  if (max <= 0 || s.length <= max) return s;
  var slice = s.slice(0, max + 1);
  var sentence = slice.match(/^(.*[.!?](?:["'\u2019\u201d)\]])?)\s/);
  if (sentence && sentence[1].length >= Math.floor(max * 0.4)) {
    return sentence[1] + "\u2026";
  }
  var sp = slice.lastIndexOf(" ");
  if (sp > 0) return slice.slice(0, sp) + "\u2026";
  return slice + "\u2026";
}

// Single-quote shell escaping for wl-copy.
function shellEscape(s) {
  return "'" + String(s).split("'").join("'\\''") + "'";
}

function copyText(ref, verseText, translationId) {
  return shellEscape(ref + " (" + translationLabel(translationId) + ")\n" + verseText);
}

// --- date-seeded random: stable all day, different across days ---
function dateKey(d) {
  return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
}

function xfnv1a(str) {
  var h = 2166136261;
  for (var i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function mulberry32(seed) {
  var a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    var t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function pickDaily(verses, key) {
  if (!verses || verses.length === 0) return null;
  var rand = mulberry32(xfnv1a("daily-verse:" + key));
  return verses[Math.floor(rand() * verses.length)];
}

function pickRandom(verses, exclude) {
  if (!verses || verses.length === 0) return null;
  if (verses.length === 1) return verses[0];
  var v = verses[Math.floor(Math.random() * verses.length)];
  var guard = 0;
  while (exclude && v.book === exclude.book && v.chapter === exclude.chapter
    && v.verse === exclude.verse && guard < 10) {
    v = verses[Math.floor(Math.random() * verses.length)];
    guard++;
  }
  return v;
}

function shortRef(v) {
  if (!v) return "";
  return v.book + " " + v.chapter + ":" + v.verse;
}

// --- parsing helloao payloads ---

function findVerseText(payload, verseNum) {
  try {
    var content = payload.chapter.content;
    for (var i = 0; i < content.length; i++) {
      var c = content[i];
      if (c.type === "verse" && Number(c.number) === Number(verseNum)) return String(c.text || "");
    }
  } catch (e) {}
  return "";
}

// Commentary chapters group verses: entries like [{number:1,...},{number:22,...}]
// means entry 1 covers 1-21. Return the entry covering verseNum. Full text is
// returned; the panel collapses long entries itself with Show more/less.
function findCommentary(payload, verseNum) {
  try {
    var content = payload.chapter.content;
    var best = null;
    for (var i = 0; i < content.length; i++) {
      var c = content[i];
      if (c.type !== "verse") continue;
      if (Number(c.number) <= Number(verseNum)) best = c;
      else break;
    }
    if (!best) return "";
    var parts = best.content || [];
    return parts.join("\n").trim();
  } catch (e) {
    return "";
  }
}

function bookName(payload, fallback) {
  try {
    if (payload.book && payload.book.name) {
      var n = String(payload.book.name);
      if (payload.chapter && payload.chapter.number) return n + " " + payload.chapter.number;
      return n;
    }
  } catch (e) {}
  return fallback || "";
}
