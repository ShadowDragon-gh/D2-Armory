# Plan: Clarity "Community Insights" in equipment & perk displays

## Goal

Show Clarity's community-authored insight text on every perk / mod / catalyst /
fragment row the app renders, starting in the item detail panel. Success
criteria:

- Opening an exotic (e.g. a weapon with a well-documented trait) shows a
  **Community Insight** control on perk rows that Clarity covers; expanding it
  renders Clarity's formatted text (colored PvE/PvP spans, dividers, links).
- Rows Clarity does **not** cover show no control and look exactly as today.
- The database is fetched once, cached locally, and only re-downloaded when
  Clarity's version number changes — no fetch on every launch.
- Attribution to Clarity is present and correct (required by their terms).
- No regression to the existing panel when Clarity data is unavailable
  (offline, download failed): rows fall back to the manifest one-liner.

## Decisions locked in

- **Display style:** expandable inline. Each covered row gets a subtle
  "Community Insight" toggle; expanding reveals the full formatted text in
  place. Panel stays compact by default. (Not always-inline, not hover tooltip.)
- **Scope:** all Clarity-covered types — weapon traits/enhanced/origin, exotic
  frames & catalysts, exotic armor perks, weapon & armor mods, subclass
  fragments. A single resolver keyed by inventory-item hash covers them all,
  so "all types" is barely more work than "weapon perks only."

---

## Background: what Clarity is (verified)

Clarity is the community database DIM uses for its "Community Insight" tooltips.
Confirmed against DIM source, the live endpoints, and Clarity's published types.

**Hosting / endpoints** (GitHub Pages, not raw.githubusercontent):

| Purpose | URL |
|---|---|
| Version manifest | `https://database-clarity.github.io/Live-Clarity-Database/versions.json` |
| Descriptions (DIM shape) | `https://database-clarity.github.io/Live-Clarity-Database/descriptions/dim.json` |

`versions.json` is tiny: `{ "descriptions": 2.0577 }`. Poll it; the big
`dim.json` (~1.6 MB) is re-downloaded only when that number changes.

**Data shape.** `dim.json` is a **flat object keyed by the perk's
`DestinyInventoryItemDefinition` hash** (unsigned, as a string). This is the
same hash space the app already uses for plug `plugHash` lookups — so the join
is direct, no new hash mapping needed. Each entry:

```jsonc
{
  "hash": 75282108,          // = the key; perk's inventory-item hash
  "name": "Weighted Edge",
  "itemHash": 3118061004,    // optional: parent exotic (weapon/armor) hash
  "itemName": "Winterbite",
  "descriptions": {
    "en": [ /* Line[] */ ]   // structured document, NOT a plain string
  }
}
```

`descriptions.en` is an array of **Line** nodes; each Line has optional
`classNames: string[]` and `linesContent: LinesContent[]`. Each LinesContent is
an inline span: optional `text`, `classNames`, `link` (URL), and `title`
(a nested `Line[]` — a tooltip-in-tooltip). **Nodes have no `type` field**; role
is inferred from which fields are set, and `classNames` carries all styling.

`classNames` vocabulary we must handle: `bold`, `link`, `center`, `spacer`
(divider), `title`, colors (`blue green purple yellow`), `pve`, `pvp`, damage
types (`kinetic arc solar stasis void strand`), ammo, champions, classes.

**Coverage** (by Clarity's `type` field): weapon `Trait`/`Trait Enhanced`/
`Trait Origin`/`Perk`/`Frame`/`Mod`, exotic `Frame`/`Catalyst`/`Trait`/`Perk`,
`Armor Trait Exotic`, `Armor Mod General`, `Subclass Fragment`, `Subclass
Class`. **Not covered:** subclass aspects, artifact perks, weapons-as-entries
(a weapon appears only as a parent `itemHash`).

**Licensing.** No open-source license on the data — governed by Clarity's
[Partnerships terms](https://www.d2clarity.com/partnerships). Free for projects
under ~150 users if we meet their attribution requirements. This personal
desktop app is well under that; we just satisfy the requirements (see
[§7](#7-attribution-required)).

---

## Architecture fit

The app is Clean-Architecture-ish: `data/local` + `data/remote` →
`data/repositories` → `presentation/providers` → widgets. The existing manifest
pipeline is the exact template to mirror:

- `ManifestDownloader` downloads a versioned file to app-support dir, keyed by
  version, presence-of-file = version check. → **Clarity downloader mirrors this.**
- `ManifestRepository.ensureLoaded()` is an idempotent bootstrap that reports
  `ManifestProgress` phases and is awaited by `manifestBootstrapProvider`. →
  **Clarity bootstrap is a sibling, run in parallel (not blocking).**
- `InventoryRepository.resolveDetail()` builds `ItemDetail` from manifest
  lookups; the panel reads it via `selectedItemDetailProvider`. → **Clarity text
  attaches onto the resolved plugs.**

> **Convention note (Rule 7/11 — surface conflicts, don't average):** the
> `README.md` describes drift + hive + freezed, but the **actual** code uses
> `sqlite3` directly, plain immutable classes, and hand-written Riverpod
> providers with no codegen. This plan follows the **real code**, not the
> README. If you want the README stack instead, that's a separate decision to
> raise before starting.

---

## Implementation phases

Ordered so each phase is independently verifiable. Checkpoint after each.

### Phase 1 — Fetch & cache the database

**New: `lib/data/local/clarity_downloader.dart`**
Mirror `ManifestDownloader`. Uses `DioClient.unauthenticated()` (no Bungie API
key or auth needed — it's a public GitHub Pages file; the `X-API-Key` header the
manifest download sends is Bungie-specific and must be omitted here).

- `Future<double?> fetchVersion()` — GET `versions.json`, return `descriptions`.
- `Future<String> localPath()` — `<appSupport>/clarity_descriptions.json`
  (single file; unlike the manifest we overwrite in place rather than
  version-suffixing, since we key freshness off the stored version number).
- `Future<void> download()` — GET `dim.json`, write bytes to `localPath()`.

**New: `lib/data/local/clarity_store.dart`** (or fold into the repo)
Reads the cached JSON file and exposes `Map<int, ClarityPerk>` in memory. The
file is ~1.6 MB → decode once at open, hold the parsed map for the session.
Key the in-memory map by the **int** hash (parse the string keys once).

**Version persistence.** DIM stores its version in `localStorage`. This app has
no such store yet. Simplest matching-the-codebase option: write the version to a
tiny sidecar file `<appSupport>/clarity_version.txt` next to the JSON. (Avoid
introducing `shared_preferences`/`hive` just for one number — Rule 2.)

**Freshness flow (deterministic — Rule 5, this is `if/else`, not judgment):**
```
version = fetchVersion()            // cheap
stored  = read sidecar file
if (cache file missing || version != stored) {
   download(); write sidecar = version
}
open cache file → parse map
```
If `fetchVersion()` or `download()` throws (offline), and a cache file exists →
use it (log a warning, Rule 12: visible, not silent). If no cache exists →
Clarity is simply unavailable this session; the app works without it.

**Checkpoint:** unit test that given a fake Dio returning a known `versions.json`
+ `dim.json`, the store parses N entries and a known hash resolves.

### Phase 2 — Domain model for a Clarity entry

**New: `lib/domain/models/clarity_insight.dart`**
Plain immutable classes mirroring `item_detail.dart`'s style (no freezed):

```dart
class ClarityInsight {
  final int hash;
  final String name;
  final List<ClarityLine> lines;   // the "en" document
}
class ClarityLine {
  final List<String> classNames;   // e.g. ['spacer'], ['center']
  final List<ClaritySpan> content;
}
class ClaritySpan {
  final String text;
  final List<String> classNames;   // 'bold','pve','pvp','arc',...
  final String? link;
  final List<ClarityLine>? title;  // nested tooltip; render lazily/optional
}
```

Parsing lives in a `fromJson` (matching how DTOs are parsed elsewhere) or in the
store. Language: read `descriptions['en']`; fall back to first available key if
`en` is absent (rare). **Do not** try to render `table`/`formula` fields in v1 —
they're filtered out of `dim.json` anyway; ignore unknown fields.

**Checkpoint:** test that the verbatim Winterbite sample entry parses into the
right span structure (text + `stasis`/`pve`/`pvp` classNames + a `spacer` line +
a `link` span).

### Phase 3 — Wire the repository & providers

**New: `lib/data/repositories/clarity_repository.dart`**
Owns a `ClarityDownloader` + `ClarityStore`. Exposes:
- `Future<void> ensureLoaded({onProgress})` — the bootstrap (Phase 1 flow).
- `ClarityInsight? insightFor(int plugHash)` — the O(1) map lookup.
- `bool get isReady`.

**New: `lib/presentation/providers/clarity_provider.dart`**
- `clarityRepositoryProvider` — constructs the repo (Dio from `DioClient`).
- `clarityBootstrapProvider` — `FutureProvider<void>` calling `ensureLoaded()`.
  **Run in parallel with the manifest bootstrap, and do not block the UI on
  it.** Manifest is required to render; Clarity is enrichment. The loading
  screen should gate on manifest only; Clarity can resolve slightly later and
  the panel updates when it does.

**Checkpoint:** with both providers wired, `clarityRepositoryProvider` resolves
a known hash after bootstrap; app still boots if the Clarity fetch fails.

### Phase 4 — Attach insights to resolved plugs

Two viable attachment points — **pick one, don't do both**:

- **(A) Extend `ItemPlug`** with `List<ClarityLine>? insight` and populate it in
  `InventoryRepository.resolveDetail()` (inject `ClarityRepository` into
  `InventoryRepository`). Pro: the panel just reads `plug.insight`. Con:
  `resolveDetail` is currently synchronous and pure over the manifest; it would
  gain a Clarity dependency, and `selectedItemDetailProvider` would need to
  re-resolve when Clarity finishes loading (add `ref.watch(clarityBootstrap)`).

- **(B) Look up in the widget.** The panel's `_Row` (or `_PlugSection`) reads
  `ref.watch(clarityRepositoryProvider).insightFor(plug.hash)` directly. Pro:
  keeps `InventoryRepository` untouched (Rule 3 — surgical); naturally reactive
  to Clarity load timing. Con: `ItemPlug` currently carries `iconPath` but
  **not the plug hash** — we'd need to add `final int hash` to `ItemPlug` (it's
  already available at construction in `_resolvePlugs`, `_catalystOptionFrom`,
  `_emptyCatalystPlug`).

**Recommendation: (B).** It's the more surgical change and matches the panel's
existing "widget reads a provider" pattern. Either way, **`ItemPlug` gains a
`hash` field** — that's the one model change, and it's needed to join to Clarity
regardless of A/B.

For the **catalyst** section (`CatalystEffect`/`CatalystOption`), the join hash
is the catalyst plug's inventory-item hash — thread it through the same way
(`_catalystOptionFrom` already has `plugHash`).

**Checkpoint:** for a known exotic, `insightFor(traitHash)` returns non-null in
the widget tree.

### Phase 5 — Render the formatted document

**New: `lib/presentation/widgets/clarity_insight.dart`**
A widget that takes `List<ClarityLine>` and renders it, plus the expand/collapse
control. Rendering rules (port DIM's `ClarityDescriptions.tsx` semantics):

- Each `ClarityLine` → a block. `spacer` className → a thin divider / gap.
  `center` → center-align. Build with `Text.rich`/`RichText` so spans flow.
- Each `ClaritySpan` → a `TextSpan`. Map `classNames` to `TextStyle`:
  - `bold` → `FontWeight.bold`
  - `pve` / `pvp` → distinct accent colors (label them; PvE vs PvP values)
  - damage types → the app already has `DamageType.color` in
    `core/destiny/destiny_enums.dart`; reuse it for `arc/solar/void/stasis/…`
    (Rule: reuse existing color source, don't hardcode a second palette)
  - `blue/green/purple/yellow` → theme-consistent accents
  - `link` → tappable, opens via `url_launcher` (already a dependency)
- **Security (Rule 12 + untrusted input):** the data is community-authored.
  Only render a `link` as tappable if it passes an `http(s)` scheme check
  (mirror DIM's `isAllowedLink`). Never launch a non-http scheme.
- `title` (nested tooltip): v1 can render the `text` and show the nested
  `title` lines in a Flutter `Tooltip`/`showDialog`, or simply omit the nested
  layer and render just the visible text. Keep v1 simple; note the omission
  visibly in a code TODO if skipped (Rule 14).

**Expand/collapse UI** (the chosen "expandable inline" style):
- Add a small `_Row`-level control under the manifest description: a tappable
  "▸ Community Insight" label (collapsed) / "▾ Community Insight" (expanded).
- Expanded state is local widget state (an `ExpansionTile`-like `StatefulWidget`
  or an `AnimatedSize`). Only shown when `insightFor(hash) != null`.
- Keep the existing manifest one-liner as the always-visible summary; Clarity
  text is the expansion. (Don't remove the manifest description — Rule 3.)

**Checkpoint (Rule 9 — test real behavior):** widget test that a row with a
Clarity insight shows the toggle; tapping it reveals text containing a known
phrase from the fixture; a row without an insight shows no toggle and is
byte-for-byte the prior layout.

### Phase 6 — Attribution (required)

See [§7](#7-attribution-required). Add a persistent, discoverable credit. This
is not optional polish — it's a condition of the license.

---

## 7. Attribution (required)

Clarity's terms require (verbatim from their Partnerships page):

1. Credit **"Clarity"** as the source, or label the tooltip **"Community
   Insights"** / **"Community Research"** if branding is awkward. → We already
   label the control "Community Insight" ✓.
2. Link to **https://d2clarity.com** in credits, ideally near the tooltips.
3. Make clear it's an external source, not us.
4. Provide a feedback path — link their Discord (**https://d2clarity.com/discord**).
5. Don't modify the data without marking it. (We render as-is ✓.)
6. Keep local copies current via `versions.json` polling. (Phase 1 ✓.)

**Minimum implementation:** a small "Community Insights courtesy of Clarity"
line with links to the site + Discord — either as a one-line footer under the
expanded insight, and/or in an app About/Settings section. DIM's exact wording
is a good reference:

> "Community Insights for Perks courtesy of [Clarity](https://d2clarity.com).
> If you notice inaccuracies or have questions, join the
> [Clarity Discord](https://d2clarity.com/discord)."

---

## Files touched (summary)

**New**
- `lib/data/local/clarity_downloader.dart`
- `lib/data/local/clarity_store.dart` *(or fold into repository)*
- `lib/domain/models/clarity_insight.dart`
- `lib/data/repositories/clarity_repository.dart`
- `lib/presentation/providers/clarity_provider.dart`
- `lib/presentation/widgets/clarity_insight.dart`
- tests: downloader/store parse, model parse, insight widget

**Modified**
- `lib/domain/models/item_detail.dart` — add `final int hash` to `ItemPlug`.
- `lib/data/repositories/inventory_repository.dart` — pass `plugHash` into the
  `ItemPlug`s it already builds (`_resolvePlugs`, `_catalystOptionFrom`,
  `_emptyCatalystPlug`). No behavioral change beyond carrying the hash.
- `lib/presentation/screens/inventory/item_detail_panel.dart` — `_Row` /
  `_PlugSection` render the insight control; `_CatalystSection` likewise.
- attribution surface (panel footer and/or an About/Settings entry).

**Not modified**
- `item_tile.dart` — the grid tile has no room for insight text; insights live
  in the detail panel only. (If you later want a per-perk hover on the tile,
  that's a separate, smaller follow-up.)

---

## Risks & open questions

- **Panel re-resolve timing.** If attachment approach (A) is chosen,
  `selectedItemDetailProvider` must `ref.watch` the Clarity bootstrap so an item
  opened before Clarity finished loading updates once it does. Approach (B)
  sidesteps this. — *resolved by recommending (B).*
- **File size / parse cost.** 1.6 MB JSON parsed on the main isolate could jank
  startup. If profiling shows it, move the decode to a `compute()`/isolate.
  Don't pre-optimize (Rule 2) — measure first.
- **Version sidecar vs. a real KV store.** Using a `.txt` sidecar avoids a new
  dependency. If the app later needs general preferences persistence, revisit
  and consolidate — but don't add a KV package for this alone now.
- **User-count threshold.** Free tier is ~150 users. A personal desktop app is
  fine; if this is ever distributed widely, a (free-for-hobbyists) Clarity
  partnership must be arranged via their Discord first.
- **`en` only.** v1 renders English. The data has other languages; add language
  selection only if/when the app gets a locale setting.

## Explicitly out of scope for v1

- Clarity's separate `Character-Stats` repo (ability cooldowns / character
  stats) — a different dataset, different endpoint, different UI. Note as a
  possible follow-up.
- Subclass aspects and artifact perks (Clarity doesn't cover them).
- Rendering `table` / `formula` nodes (stripped from `dim.json`).
- Grid-tile hover insights.

---

# Part 2 — Weapon/gear acquisition source (d2-additional-info)

Clarity does **not** carry "how you get this weapon" — its `dim.json` is keyed
by perk/mod hashes and holds gameplay effect text; weapons appear only as a
parent `itemHash` reference (see [§Background](#background-what-clarity-is-verified)).
The acquisition source lives in **two** places, and this part wires both:

1. **The manifest itself** — already on disk. `DestinyInventoryItemDefinition.collectibleHash`
   → `DestinyCollectibleDefinition`, whose `sourceString` is *"a human readable
   string for a hint about how to acquire the item"* (e.g. *"Source: Complete
   the raid 'Salvation's Edge'"*). Zero new download.
2. **DIM's [d2-additional-info](https://github.com/DestinyItemManager/d2-additional-info)
   (d2ai)** — a curated, cleaner `sourceHash → description` map (`sources.json`)
   plus a `weaponHash → quest step` map (`weapon-from-quest.json`). MIT-licensed,
   so it can be redistributed/bundled.

> **Distribution decision (locked):** d2ai ships as a **bundled Flutter asset
> only — no runtime download, no GitHub refresh.** Destiny 2 is no longer
> receiving content updates, so the source data is effectively final and
> snapshot staleness is not a concern. This removes the downloader, ETag
> handling, and the async bootstrap entirely: the asset *is* the data, loaded
> synchronously at startup. (This is the one place Part 2 deliberately diverges
> from the Clarity Part 1 pattern.)

## Goal

Show a **Source** row in the item detail panel stating how the selected weapon
(or armor) is obtained. Success criteria:

- Opening a weapon with a known source (a raid drop, a vendor item, a quest
  reward) shows a **Source** line with readable acquisition text.
- Where d2ai has a cleaner string for the item's `sourceHash`, that text is
  shown; otherwise the manifest's `sourceString` is shown; if neither exists,
  **no Source row appears** (the panel looks exactly as today).
- Works **fully offline, always** — the d2ai snapshot ships as a bundled app
  asset and is never downloaded, so there is no network dependency at all.
- No regression if the d2ai asset is missing a `sourceHash`: the manifest
  `sourceString` is used; if that too is absent, no row renders.
- Attribution to DIM / d2-additional-info is present (MIT requires the notice).

## Decisions locked in

- **Source of truth: manifest-first, d2ai as override.** The manifest
  `sourceString` is always present (no dependency); when d2ai's `sources.json`
  has an entry for the same `sourceHash`, its cleaner text wins. This is a
  deterministic lookup (Rule 5), not a merge — **surface, don't average**
  (Rule 7): pick d2ai-if-present-else-manifest, never concatenate both.
- **Bundled asset only, no refresh.** The d2ai snapshots ship as committed
  Flutter assets and are never downloaded or refreshed at runtime. The game is
  no longer updated, so the snapshot is final. This is simpler than the Clarity
  pipeline (no downloader, no version/ETag check, no async bootstrap) — the
  asset is loaded synchronously once at startup (Rule 2 — no speculative
  refresh machinery).
- **Datasets in scope:** `sources.json` (the source text — the core feature)
  and `weapon-from-quest.json` (quest-origin note, narrow but cheap). Season
  badge from `watermark-to-season.json` is **out** — noted as a follow-up.

## Background: d2ai data shapes (verified)

**Source of the snapshot.** Files live under
`https://raw.githubusercontent.com/DestinyItemManager/d2-additional-info/master/output/`.
We commit a one-time snapshot of `sources.json` and `weapon-from-quest.json`
into the repo as assets; the app never fetches them. **License: MIT** —
redistribution and bundling are permitted with the license notice retained
(the `LICENSE` ships alongside the snapshot).

**`sources.json`** — flat object, **key = `sourceHash` (string), value =
description**:

```jsonc
{
  "10464158": "Source: Acquired from Xûr",
  "11666839": "Source: High-Difficulty Activities or Dismantled Exotic or Legendary Gear",
  "13912404": "Source: Unlock Your Arc Subclass"
}
```

**`weapon-from-quest.json`** — `weaponItemHash → initial quest step item hash`.
Resolve the quest step's name via `getInventoryItem(stepHash)` for a
"From the quest: *<name>*" note. Narrow coverage (quest weapons only).

**The join (verified against DIM's own code):**

```
collectibleHash = itemDef.collectibleHash            // on the weapon/armor def
collectible      = getDefinition('DestinyCollectibleDefinition', collectibleHash)
sourceHash       = collectible.sourceHash            // int, key into sources.json
manifestText     = collectible.sourceString          // always-present fallback
text = d2aiSources[sourceHash] ?? manifestText       // d2ai override, else manifest
```

`DestinyCollectibleDefinition` is present in the mobile-world-content SQLite the
app already downloads — it just isn't queried yet.

---

## Implementation phases (Part 2)

Ordered so each is independently verifiable. Checkpoint after each. Unlike
Clarity Part 1, there is **no downloader, store-freshness, or provider
bootstrap** — the d2ai data is a synchronously-loaded asset.

### Phase A — Manifest-only source (no d2ai yet)

Ship the always-available path first; it needs no new files or download.

- `lib/data/local/manifest_database.dart` — add
  `Map<String, dynamic>? getCollectible(int hash)` (a one-line sibling of the
  existing `getDefinition` wrappers).
- `lib/data/repositories/manifest_repository.dart` — expose it if the repo
  wraps the DB (match how `getRecord`/`getObjective` are surfaced).
- `lib/domain/models/item_detail.dart` — add `final String? source;` to
  `ItemDetail` (nullable; null = no row).
- `lib/data/repositories/inventory_repository.dart` — in `resolveDetail`,
  resolve `collectibleHash → collectible.sourceString` and pass it as `source`.
  Trim empties to null.
- `lib/presentation/screens/inventory/item_detail_panel.dart` — render a
  **Source** row only when `detail.source != null`.

**Checkpoint (Rule 9):** for a weapon with a known `collectibleHash`,
`resolveDetail(...).source` equals the manifest `sourceString`; for an item
with no collectible, it is null and no row renders.

### Phase B — Bundle the d2ai snapshot and load it

**Bundle the snapshot.** Add `assets/d2ai/sources.json`,
`assets/d2ai/weapon-from-quest.json`, and `assets/d2ai/LICENSE` (a one-time
committed snapshot of the d2ai `output/` files) and register `assets/d2ai/`
under `flutter: assets:` in `pubspec.yaml`.

**New: `lib/data/local/d2ai_source_data.dart`** — a small loader that reads the
two bundled assets via `rootBundle.loadString` and parses them once into memory:
- `Map<int, String> sourcesByHash` (parse the string keys to int on load)
- `Map<int, int> questStepByWeapon`

Expose a single `Future<D2aiSourceData> load()` (or an async init on the
repository). No Dio, no file I/O, no version check. If an asset fails to parse
(should never happen for a committed file), log it and continue with empty maps
(Rule 12 — visible), so a bad snapshot degrades to manifest-only, never crashes.

**Checkpoint:** a unit test loads the bundled (or a fixture) `sources.json` and
asserts a known `sourceHash` resolves to its expected string, and a known
weapon hash resolves to a quest step hash.

### Phase C — Repository/provider wiring and the override join

**New: `lib/data/repositories/d2ai_repository.dart`** — wraps `D2aiSourceData`.
Exposes `String? sourceFor(int sourceHash)`, `int? questStepFor(int weaponHash)`,
and `bool get isReady`. Loading is a single `await load()` at construction/init.

**New: `lib/presentation/providers/d2ai_provider.dart`** — a
`d2aiRepositoryProvider`. Since the data is a bundled asset (a few hundred KB,
parsed once), it can be a `FutureProvider` awaited during startup like the
manifest, or eagerly initialised; there is no network timing to design around.

**Apply the override.** In `resolveDetail` (or the panel — match Part 1's chosen
attachment approach), compute:
```dart
final override = collectible?.sourceHash != null
    ? d2ai.sourceFor(collectible.sourceHash) : null;
final questStep = d2ai.questStepFor(item.itemHash);   // optional
source = override ?? manifestSourceString;
```

**Checkpoint:** a weapon whose `sourceHash` is in `sources.json` shows the d2ai
text; a weapon whose `sourceHash` is absent shows the manifest `sourceString`;
neither present → no row.

### Phase D — Quest-origin note + attribution

- **Quest origin:** when `questStepFor(item.itemHash)` is non-null, resolve the
  step's display name via the manifest and show a secondary
  "From the quest: *<name>*" line under the Source row.
- **Attribution (MIT requires it):** add a credit line — "Source data from
  Bungie's manifest and DIM's [d2-additional-info](https://github.com/DestinyItemManager/d2-additional-info)
  (MIT)" — in the same About/Settings surface as the Clarity credit, and keep
  the d2ai `LICENSE` text with the bundled snapshot (`assets/d2ai/LICENSE`).

**Checkpoint (Rule 9):** a known quest weapon shows the quest line; the About
surface shows the d2ai attribution.

---

## Files touched (Part 2 summary)

**New**
- `lib/data/local/d2ai_source_data.dart` (bundled-asset loader/parser)
- `lib/data/repositories/d2ai_repository.dart`
- `lib/presentation/providers/d2ai_provider.dart`
- `assets/d2ai/sources.json`, `assets/d2ai/weapon-from-quest.json`,
  `assets/d2ai/LICENSE` (bundled snapshot + license)
- tests: manifest `getCollectible`, d2ai asset parse, override precedence,
  Source-row widget test

**Modified**
- `lib/data/local/manifest_database.dart` — add `getCollectible(int hash)`.
- `lib/data/repositories/manifest_repository.dart` — surface it (if wrapped).
- `lib/domain/models/item_detail.dart` — add `final String? source;` (and
  optionally `final String? questOrigin;`).
- `lib/data/repositories/inventory_repository.dart` — resolve source in
  `resolveDetail` (collectible lookup + d2ai override).
- `lib/presentation/screens/inventory/item_detail_panel.dart` — render the
  Source row (and quest-origin line) when present.
- `pubspec.yaml` — register `assets/d2ai/`.
- attribution surface — add the d2ai credit.

## Risks & open questions (Part 2)

- **`sourceString` is a hint, not exact.** Some strings are vague ("High-Difficulty
  Activities") or describe reacquisition rather than the original drop. This is
  Bungie's wording; we render as-is. d2ai cleans many but not all.
- **Snapshot is intentionally frozen.** The bundled `sources.json` is a one-time
  snapshot with no refresh — accepted because the game is no longer updated, so
  no new source hashes will appear. If that assumption ever changes, adding a
  downloader is a self-contained follow-up (the loader interface stays the same).
- **Coverage gaps.** Not every item has a `collectibleHash` (some crafted/quest
  rewards); those simply show no Source row.

## Explicitly out of scope (Part 2)

- **Season/event badge** (`watermark-to-season.json` / `watermark-to-event.json`) —
  deriving the season from the watermark icon. A clean, self-contained follow-up:
  the item's watermark icon path is already available on the definition; map it
  to a season number/name and render a small badge. Deferred per the scoping
  decision.
- d2ai's other outputs (`focusing-item-outputs.json`, `special-vendors-strings.json`,
  `seasons.json`) — not needed for a source line.
- Grid-tile source display — the Source line lives in the detail panel only,
  matching the Clarity insight placement.
