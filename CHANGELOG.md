# Changelog

## 0.2.0

Design refresh plus a new commentary source.

- **Sources are now compact inline chips.** The two full-width `Translation` and
  `Commentary` dropdowns are replaced by a single wrapping row of half-width
  chips under a `Sources` header, so the panel spends less space on chrome.
- **Typography and hierarchy.** Scripture is promoted to the heading size with a
  roomier line height; the reference is now a quiet, letter-spaced accent kicker
  above an italic verse. Expanded commentary reads at a capped measure (~60
  characters) with a more comfortable line height.
- **Expand/collapse animates** instead of snapping, so the panel grows smoothly
  when the reading box opens.
- **Contrast.** Caption opacities raised so meta text clears the 4.5:1 body-text
  threshold more comfortably.
- **New commentary: Tyndale Open Study Notes.** Selectable directly and appended
  to the end of the automatic fallback chain, so it only appears when every
  Reformed source misses the verse. Concise verse-level notes, and a good fit for
  short verses. Its entries carry a redundant verse-reference prefix, which is now
  stripped.
- `Read full commentary ↗` now resolves for every source: Bible Hub for the
  public-domain commentaries, and STEPBible's TNotes module for Tyndale, which
  Bible Hub does not carry.
- Summaries no longer end in a four-dot run (`word....`) when the cut happens to
  land on a sentence boundary.
- Attribution line in the panel and a new licences section in the README, since
  Tyndale OSN is CC BY-SA 4.0 rather than public domain.

## 0.1.0

Initial release: daily verse in the bar, commentary panel with an automatic
fallback chain across five public-domain Reformed sources, translation picker,
copy to clipboard, and a link to the full commentary on Bible Hub.
