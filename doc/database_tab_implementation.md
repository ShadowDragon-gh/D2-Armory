# Database Tab — Implementation Plan

Replace the Database stub with a browsable database of **all weapons and all armor**
(exotic and non-exotic) in the game — stats, traits/perks, and other definition data
— similar to destiny.report, sourced entirely from the local manifest.

Grounded in this codebase: it reuses the manifest DB, the search grammar, and the
detail-panel rendering already built. Read "Key architectural facts" first — two of
them shape the whole design.

---

## Key architectural facts (from the current code)

### 1. This is manifest-only — no account, no live components
The inventory tab shows *owned* items and resolves detail from live profile components
(instance stats, sockets, records) cached in `InventoryRepository`. The Database tab is
different: it enumerates **definitions**, not instances. That means:
- No auth/account dependency — the manifest is already downloaded at startup.
- Stats/perks come from the **definition's** `stats` and `sockets.socketEntries` /
  plug sets, not from an instance. This is a **new resolution path**, distinct from
  the existing instance-based `resolveDetail`.

### 2. The manifest DB can be queried and filtered server-side (verified)
`ManifestDatabase` today only does single-hash lookups (`getDefinition`). But the
SQLite build **supports `json_extract`** (verified against the live DB), so we can
enumerate and filter in SQL rather than loading everything into memory. Confirmed
counts (redacted excluded):
- **Weapons** (`itemType = 3`): ~2,208
- **Armor** (`itemType = 2`): ~6,029 (this includes ornaments/skins as armor-typed
  items — see filtering below; the true "armor pieces" count is much smaller).

So the browse layer adds **list/query** methods to the manifest access, keyed off
`json_extract(json, '$.itemType')`, `$.itemSubType`, `$.inventory.tierType`,
`$.classType`, `$.defaultDamageType`, `$.redacted`, and `$.displayProperties.name`.

### 3. What counts as a "weapon" / "armor piece" (filtering)
Naive `itemType=2` over-counts massively (ornaments, shaders-as-items, dummies). Filter to
real gear:
- **Weapons**: `itemType = 3`, `redacted = 0`, has `equippable = 1`, real
  `displayProperties.name`/icon, and an `inventory.bucketTypeHash` in the weapon buckets
  (Kinetic/Energy/Power — the `EquipmentBucket` weapon hashes we already have).
- **Armor**: `itemType = 2`, `redacted = 0`, `equippable = 1`, bucket in the armor slots
  (Helmet/Gauntlets/Chest/Legs/Class — again already in `EquipmentBucket`), which
  naturally excludes ornaments (`itemSubType 21`) and cosmetics.
- Exclude `itemSubType = 21` (ornaments) and dummy/`isWrapper` items explicitly.

The existing `EquipmentBucket` enum already enumerates exactly the buckets we care about
— reuse it as the gear filter (contract rule 11: reuse the established pattern).

### 4. Reusable vs new
- **Reusable**: `ManifestRepository`/`ManifestDatabase` (add list methods), the item
  detail *rendering* widgets in `item_detail_panel.dart`, the search tokenizer/grammar in
  `core/search/`, `DamageType`, `EquipmentBucket`, `ClassEmblem`.
- **New**: a definition-based detail resolver (stats + *possible* perks from plug sets),
  a paged/filtered list query layer, and the Database UI (master–detail).
- **Refactor flagged (not silent)**: the detail panel currently binds to
  `selectedItemDetailProvider` (instance-based). To render a definition-sourced
  `ItemDetail`, either (a) generalise the panel to take an `ItemDetail` directly, or (b)
  give the Database tab its own detail view. Prefer (a) if the panel can be decoupled
  cleanly; otherwise (b). Decide before building the UI — don't fork rendering logic
  into two divergent copies (rule 7).

---

## Definition-based detail: the important difference from instance detail

An instance has *the* rolled perks. A **definition** has the **pool of possible** perks
per socket (random-roll weapons) — this is what destiny.report shows: every column of
possible traits. Resolution:
- **Stats**: read the definition's `stats.stats` map (base values). No instance bonuses;
  no gold/red segments (those are instance-only — reuse the plain bar rendering path).
- **Perk columns**: for each weapon perk socket, gather candidate plugs from
  `randomizedPlugSetHash` / `reusablePlugSetHash` (via `getPlugSet`, already exists) and
  the inline `reusablePlugItems`. Group by socket → "column of possible perks", the
  destiny.report layout. (The catalyst-options resolver already walks plug sets this way
  — reuse that traversal.)
- **Intrinsic/frame, masterwork curve, breaker** as in the existing resolvers, minus the
  instance-specific bits (kill tracker, applied catalyst progress).

This is a **separate resolver** (`resolveDefinitionDetail(itemHash)`), not a change to
the instance path. Keep both; do not try to average them into one function (rule 7).

---

## Architecture

### Layer 1 — Manifest browse/query (`manifest_database.dart` + repository)
Add, backed by `json_extract`:
- `List<int> listGearHashes({required GearKind kind, filters...})` — returns matching
  hashes (weapons or armor), applying tier/class/element/subtype/name filters in SQL.
- `List<Map> queryGear({... , limit, offset})` — paged rows for the list view (select
  only the fields the list needs: name, icon, tier, subtype, element, power-cap — avoid
  decoding full JSON per row where possible).
- Keep single-hash `getDefinition` for the detail view.
- Guard: table/column names are fixed constants, values are bound params (no SQL
  injection surface from the search box).

### Layer 2 — Domain models + resolver
- A lightweight `GearSummary` (hash, name, icon, tier, subtype label, element,
  intrinsic name) for list rows — cheap to build in bulk.
- `resolveDefinitionDetail(int itemHash)` → an `ItemDetail`-shaped model extended to
  carry **perk columns** (List of sockets, each a list of possible perks). May need a
  small addition to the detail model (`List<PerkColumn> perkColumns`) used only by the
  Database detail view.

### Layer 3 — Providers (`database_provider.dart`)
- `databaseFilterProvider` (Notifier holding the active filters: kind, class, tier,
  element, damage, sort, search text).
- `databaseResultsProvider` (derives the filtered/sorted hash list from the manifest +
  filter). Recomputes on filter change; runs the SQL query.
- `selectedDatabaseItemProvider` + `databaseItemDetailProvider` (resolves definition
  detail for the selected hash).
- Large lists: build lazily (the list view is virtualised; only visible rows resolve
  their `GearSummary`).

### Layer 4 — UI (`lib/presentation/screens/database/`)
Master–detail, replacing `StubPage` for the Database tab:
- **Filter/sort bar**: Weapons | Armor toggle; class (Titan/Hunter/Warlock/Any); tier
  (Exotic/Legendary/…); weapon type or armor slot; element; sort (name, power cap, rarity,
  recently added). Reuse the search box + grammar for name/keyword filtering.
- **List/grid**: a virtualised (`ListView.builder`/`GridView.builder`) list of
  `GearSummary` rows — icon, name, type, element, tier accent. Thousands of rows → must
  be lazy.
- **Detail pane**: renders the definition detail. For weapons, the destiny.report-style
  **perk columns** (each socket = a column of possible perks) plus the stat bars; for
  armor, stats + intrinsic/exotic perk + slot. Reuse `item_detail_panel` widgets where
  possible (per the refactor decision above).

### Layer 5 — Search integration
The existing grammar (`is:exotic`, `is:weapon`, element/type keywords, name matching) is
already implemented for the inventory filter. Point the same compiled-query matcher at
`GearSummary` so `is:exotic hand cannon` filters the database identically. This is the
cheapest way to get powerful filtering — reuse, don't reinvent (rule 11). Verify each
keyword resolves from definition fields (some inventory keywords may rely on
instance-only data — flag any that can't apply to definitions).

---

## Performance considerations

- **Never load all ~2,200 weapon + ~6,000 armor JSON blobs at once.** Query hashes +
  minimal fields via `json_extract`, resolve full detail only for the selected item.
- SQL filtering + `LIMIT/OFFSET` (or hash-list + lazy row build) keeps memory flat.
- Consider a one-time in-memory index (hash → {name, tier, subtype, element}) built once
  after manifest load if repeated `json_extract` scans prove slow — measure first, don't
  pre-optimise (rule 2).
- `sqlite3` calls are synchronous on the UI isolate; a full-table `json_extract` scan of
  16k rows may jank. If measured jank appears, move queries to a background isolate
  (`compute`/`Isolate`) — but **measure before** adding that complexity.

---

## Incremental delivery (checkpoints — rule 10)

1. **Browse query layer**: `listGearHashes` / `queryGear` with `json_extract`,
   unit-tested against a fixture DB (weapon vs armor filtering, tier/class filters,
   redacted/ornament exclusion). Gate: correct counts and filtering.
2. **Weapon list UI**: virtualised list of weapons with the filter bar (no detail yet).
   Gate: all real weapons listed, filters work, scrolls smoothly.
3. **Weapon detail (definition-based)**: stats + perk columns from plug sets. Gate: a
   known random-roll weapon shows all its possible perk columns correctly.
4. **Armor**: add the Weapons|Armor toggle, armor list, armor detail (stats + intrinsic/
   exotic perk). Gate: exotic and legendary armor both render.
5. **Search grammar wired in**: `is:` keywords + name search filter the database.
6. **Polish**: sorting, element/tier accents, empty/error states, performance pass
   (isolate only if measured).

Each step ships independently and leaves a working tab.

---

## Testing

- **Unit — query layer**: filtering/exclusion correctness against a small fixture DB
  (weapon vs armor, exotic filter, ornament/redacted exclusion, name search).
- **Unit — definition resolver**: perk columns from a mocked plug set (all candidates in a
  column, empty/placeholder plugs dropped); definition stats (no instance bonuses).
- **Widget**: list virtualises (only visible rows build); selecting a row opens detail;
  filter changes update results.
- **Behaviour, not smoke** (rule 9): assert the *right* perks/stats appear, not merely
  that a list is non-empty.

---

## Risks & open questions

- **Armor "possible perks" are less meaningful than weapons'** — modern armor perks are
  the exotic intrinsic + mod slots, not random columns. Decide the armor detail shape
  (likely: intrinsic/exotic perk + stat spread + slot), rather than forcing the weapon
  perk-column layout onto armor (rule 1 — surface this, don't guess).
- **Sunset/duplicate definitions**: the manifest holds many versions/reissues of the same
  weapon. destiny.report typically shows the current one. Decide dedupe policy (by name +
  latest, or show all) — flag as a product choice.
- **Detail-panel reuse vs fork** (Layer/refactor note) — resolve early to avoid two
  rendering code paths.
- **Some search keywords are instance-only** (e.g. masterwork level, locked) — those
  can't apply to definitions; document which keywords the Database tab supports.
- **Perf** is the main technical risk; the plan defers isolate work until measured.

---

## Recommendation

Highly feasible and self-contained — no auth, no write scope, all data is already local.
The two real design decisions to settle up front are (1) definition-based detail as a
**separate** resolver from the instance path, and (2) whether the inventory detail panel
can be generalised to render definition detail or needs its own view. Start with the
query layer + weapon list (steps 1–2) as the first milestone; weapons are the
destiny.report core, armor follows the same skeleton with a different detail shape.
