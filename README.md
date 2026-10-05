# Daily Verse

A daily Bible verse in the [Omarchy](https://omarchy.org) bar, with a
Reformed / Lutheran commentary. Click the bar icon to read the verse and its
commentary.

- Verse text: [Free Use Bible API](https://bible.helloao.org) (default BSB)
- Commentary preference: **Matthew Henry → Jamieson-Fausset-Brown → John Gill → John Calvin → Keil & Delitzsch**
- Only Reformed / Lutheran / adjacent sources. `adam-clarke` and `tyndale` are never queried.

## Install

```sh
omarchy plugin add https://github.com/nautilusmare/omarchy-daily-verse.git --enable
```

## Use

- The bar shows a cross icon; hover it for the reference and verse text. Click to open the panel.
- Middle-click the bar icon, or press `↻ New verse`, for a new random verse.
- **Translation** and **Commentary** dropdowns in the panel pick sources directly. Choices persist.
- `⧉ Copy` copies `REF (Translation)\nverse text` to your clipboard via `wl-copy`.
- The panel shows a short commentary summary (cut at a sentence boundary, ~240 characters).
- `Show more ▾` opens the full commentary in a height-capped reading box (~300px) with its own slim scrollbar, so the panel grows by a fixed amount rather than by the length of the text. Clicking the text — or `Show less ▴` — collapses it back to the summary.
- `Read full commentary ↗` opens the complete chapter commentary in your browser on [Bible Hub](https://biblehub.com), which renders all five sources with readable typography.
- When the panel itself overflows, a slim scrollbar appears on the right. Click the strip to jump, or drag the pill to scroll.
- `omarchy-shell shell summon maurice.daily-verse '{}'` opens the panel;
  `omarchy-shell shell hide maurice.daily-verse` closes it.

## Configure

Settings live in your `shell.json` layout entry, or you can just use the
dropdowns in the panel:

- `translation`: `BSB` (default), `eng_web` (World English Bible),
  `eng_kjv` (King James), `eng_gnv` (Geneva 1599, original spelling),
  `eng_asv` (American Standard), `eng_ylt` (Young's Literal).
- `commentary`: preferred source, one of `matthew-henry` (default),
  `jamieson-fausset-brown`, `john-gill`, `john-calvin`, `keil-delitzsch`.
  The plugin automatically falls through the chain in that order when a verse
  has no entry (e.g. Calvin never wrote on Revelation).

## Develop locally

```sh
omarchy plugin validate ~/.config/omarchy/plugins/maurice.daily-verse
omarchy-shell shell rescanPlugins
```

Plugin code under `~/.config/omarchy/plugins/` hot-reloads on save.

## Remove

```sh
omarchy plugin remove maurice.daily-verse
```

## License

MIT — see [LICENSE](LICENSE).