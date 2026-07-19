# Plan: Subclasses & abilities — inventory row, ability swapping, Database tab

Status: **planned, not started** (2026-07-18). Facts below marked *verified*
were measured against the live manifest (`244213.26.06.29.2000`) and the live
Clarity database (v2.0577+), not assumed.

This is the first concrete step toward the Loadouts feature: before loadouts
can *store* a subclass configuration, the app must be able to *display and
edit* one.

## Goal

1. **Inventory tab:** a Subclass row per character showing the equipped
   subclass and the character's other subclasses. Tapping a subclass opens a
   detail modal showing its Super, Abilities (class/movement/melee/grenade),
   Aspects, and Fragments — each socket editable in-game (click an option to
   select it), exactly like the existing weapon-perk / armor-mod editing.
   Dragging an unequipped subclass onto the equipped slot equips it.
2. **Database tab:** an **Abilities** kind beside Weapons/Armor listing every
   super, ability, aspect, and fragment for every class, searchable, with a
   detail modal per entry.
3. **Clarity everywhere:** both new surfaces render Community Insights. This
   finally surfaces the ~99 fragment and ~35 class-ability Clarity entries the
   app already downloads and parses but has nowhere to show (see
   [clarity_community_insights_plan.md](clarity_community_insights_plan.md),
   As-built status).

Success criteria:

- Each character column shows a Subclass row; the equipped subclass reflects
  in-game state and updates after an equip.
- The subclass modal shows the live configuration (super, abilities, aspects,
  fragments) grouped like the in-game screen; clicking a different option
  selects it in-game with the optimistic-highlight → POST → reconcile flow the
  weapon perk grid already uses; a failed insert rolls back visibly (toast).
- Subclasses can never be dragged to the vault or another character (denied
  locally with a reason, never a bounced POST).
- The Database Abilities list shows every current ability plug, filterable by
  class, searchable by name (`is:arc` etc. works via the derived element).
- Fragment rows show their stat effects (e.g. −10 Discipline) wherever
  ability details render.
- Clarity insights appear on covered plugs in both surfaces; uncovered plugs
  render exactly as the manifest describes them.

## Decisions locked in

- **No new network or profile components.** Subclasses are instanced items
  already present in `characterInventories`/`characterEquipment` with sockets
  (305) and reusablePlugs (310) already fetched — the grid simply filters them
  out today (`_toDestinyItem` drops buckets outside `EquipmentBucket`).
- **Ability selection uses the existing free-insert flow** —
  `ItemTransferRepository.insertPlug` → `insertSocketPlugFree`. Subclass
  plugs are free, reversible plugs (DIM uses the same endpoint). No new write
  path, and `MoveController.insertPlug`'s optimistic
  override/patch/reconcile machinery is reused as-is.
- **Subclass equip uses the existing equip flow** (`equipItem`); the grid's
  drag-onto-equipped-slot UX carries over unchanged.
- **Socket grouping is data-driven** from the definition's `socketCategories`
  (stable hashes, labels from `DestinySocketCategoryDefinition`) — not from
  hardcoded socket indexes and not from plug-category string parsing.
- **The Database kind is plug-category-driven.** Ability plugs are not gear
  (no bucket, `itemType` 19); the Abilities index queries
  `plugCategoryIdentifier` patterns (taxonomy below) instead of
  itemType+bucket.
- **Subclass tiles open a new subclass modal, not the gear modal.** The gear
  modal is weapon/armor-shaped (stat bars, perk columns, catalyst); a subclass
  needs a socket-group layout. Routing branches on `itemType == 16` at the
  tile tap.
- **Reuse `ItemPlug`** for subclass plugs and ability options — it already
  carries `plugHash` (the Clarity join key), `socketIndex`, `description`,
  and `statEffects`.

## Background: verified manifest structure

### Subclass items (*verified* by probe)

35 defs with `itemType = 16` (DestinyItemType.Subclass), all in bucket
**3284755031**. Each has `classType`, a `screenshot` (usable as modal art),
and its element at `talentGrid.hudDamageType` (2=Arc … 7=Strand; instance
`damageTypeHash` is not needed). Socket layout is uniform across subclasses:

| Socket category | Hash (stable) | Socket indexes |
|---|---|---|
| ABILITIES | 309722977 | 0 (class), 1 (movement), 3 (melee), 4 (grenade) |
| SUPER | 457473665 | 2 |
| ASPECTS | 2140934067 | 5, 6 |
| FRAGMENTS | 1313488945 | 7–12 |

Every socket entry carries a `reusablePlugSetHash` (definition-side option
list). Empty aspect/fragment sockets hold real placeholder plugs ("Empty
Aspect Socket", "Empty Fragment Socket") — these are **valid inserts** (that
is how a fragment is removed), so they stay in the option list, unlike the
armor-mod placeholders that fail the free insert (see
`armor-mod-plug-filtering` memory: that filtering lesson applies to armor
mods, not here).

> **Prismatic caveat:** the probe printed two of 35 subclasses (Solar/Arc
> Hunter). Prismatic subclasses likely add sockets (transcendence). The
> category-driven grouping handles extra categories automatically, but
> **verify a Prismatic def during Phase B** and render any unknown category
> under its own label rather than dropping it (Rule 12).

### Ability plug taxonomy (*verified* — 108 distinct categories)

All ability plugs are `itemType = 19`, `classType = 3` on the definition —
**class affinity lives in the category prefix**, not the def:

```
<class>.<element>.class_abilities   class = titan | hunter | warlock
<class>.<element>.movement          element = arc | solar | void | stasis |
<class>.<element>.melee                       strand | prism
<class>.<element>.supers            (note: "melee" singular, "supers" plural)
<class>.<element>.aspects
shared.<element>.grenades           (grenades & fragments are class-shared)
shared.<element>.fragments
```

Quirks (all *verified*):
- Stasis aspects are `<class>.stasis.totems`; stasis fragments are
  `shared.stasis.trinkets` (Stasis pre-dates the 3.0 naming).
- Placeholder-only categories exist (`hunter.shared.aspects`,
  `shared.fragments`) holding only "Empty … Socket" plugs.
- `itemTypeDisplayName` is rich and display-ready ("Solar Fragment",
  "Super Ability", "Stasis Aspect", "Prismatic Fragment"); a few aspect defs
  have an empty one — fall back to a label derived from the category.
- Old subclass-2.0 plugs do not match these patterns (they lived in talent
  grids), so the query naturally excludes them.

### Clarity coverage of these plugs (*verified* earlier)

Covered: fragments (~99 entries incl. stasis trinkets) and class abilities
(~35). Not covered: **aspects** (zero entries). Supers / melees / grenades /
movement: little or none observed. The join is `plugHash` — coverage gaps
simply render no insight block, so no special handling is needed.

## Architecture fit — what already exists and is reused unchanged

| Need | Existing piece |
|---|---|
| Select a plug in-game | `MoveController.insertPlug` → `insertSocketPlugFree` (serialised, optimistic, rollback + toast) |
| Optimistic highlight | `gearModalPlugOverrideProvider` (keyed by socket index, reset on instance change) |
| Local cache patch + re-resolve | `InventoryRepository.patchSocketPlug` (generic over any instanced item) + `gearModalRevisionProvider` |
| Equip | `ItemTransferRepository.equip` + drag-onto-equipped-slot UX |
| Live socket/option data | components 305 (`_sockets`) and 310 (`_reusablePlugs`), already fetched |
| Option-list pattern | `_resolveInstancePerkColumns` (310 options, active plug flagged, definition fallback) |
| Plug display model | `ItemPlug` (incl. `plugHash`, `statEffects` via `_plugStatEffects`) |
| Clarity rendering | `ClarityInsightExpander` / `ClarityTooltipInsight` (hash-keyed, self-hiding) |
| Database index/facets | `DatabaseRepository.warmIndex`/`warmFacets` per `GearKind`; `FacetBuilder` already degrades gracefully for a non-weapon/armor kind (perk facets are weapon-gated, set facets armor-gated; stats/description/name paths are generic — *verified in code*) |

`MoveController.insertPlug` re-selects `gearModalInstanceProvider` after its
reconcile — so the subclass tile tap must also select the subclass into
`gearModalInstanceProvider` (in addition to the new subclass selection
provider) for the override-reset and reconcile plumbing to work unchanged.
The gear modal does not open because nothing writes
`selectedDatabaseItemProvider`.

---

## Part 1 — Inventory: subclass row + subclass detail modal

### Phase A — Subclass items enter the grid

- `EquipmentBucket`: add `subclass(3284755031, 'Subclass')` **last** (so
  `isWeapon`'s index arithmetic is untouched); `forKind` explicitly excludes
  it (it is neither weapon nor armor). `_toDestinyItem`'s
  `EquipmentBucket.fromHash` gate then admits subclasses with no further
  change.
- `DestinyEnums`: add `typeSubclass = 16`.
- `inventory_screen.dart`: render the Subclass row **first** (explicit row
  order in `_Grid`, not enum order). The row's vault cell is a plain empty
  cell, not a `_VaultCell` drop target (subclasses never reach the vault).
- `drop_validation.dart`: `canDrop` denies `itemType == 16`
  ("Subclasses can't be transferred."). `canEquip` already handles class
  gating via `classType`; the exotic-conflict check does not fire (subclasses
  are not tier 6).

**Checkpoint (Rule 9):** grid test — a fetched profile containing subclass
items shows them under the Subclass row on their character; `canDrop` denies
a subclass → vault/other-character drop with the reason; drag-equip of an
unequipped subclass on the same character calls the equip flow.

### Phase B — `resolveSubclassDetail`

New models (`lib/domain/models/subclass_detail.dart`), plain classes matching
`item_detail.dart` style:

```dart
class SubclassDetail {
  final DestinyItem item;
  final int element;                    // talentGrid.hudDamageType
  final String screenshotPath;
  final List<SubclassSocketGroup> groups;
}
class SubclassSocketGroup {              // one per socketCategory, def order
  final String label;                    // DestinySocketCategoryDefinition name
  final List<SubclassSocket> sockets;
}
class SubclassSocket {
  final int socketIndex;                 // for insertPlug
  final ItemPlug equipped;               // from live 305
  final List<ItemPlug> options;          // 310 first, def plug set fallback
}
```

`InventoryRepository.resolveSubclassDetail(DestinyItem)`:
- Walk the definition's `socketCategories` in order; label each group via a
  new `ManifestDatabase.getSocketCategory` wrapper (one-line sibling of
  `getCollectible`).
- Per socket index: equipped plug from `_sockets[id]` (respect `isVisible` —
  locked fragment slots are invisible until aspects grant them); options from
  `_reusablePlugs[id]['plugs'][index]`, falling back to the definition
  entry's `reusablePlugSetHash` plug set (same fallback order as
  `_resolveInstancePerkColumns`). Keep placeholder "Empty …" plugs — they are
  the remove action.
- Build plugs with the existing `_columnPlugOf`/`_plugStatEffects` helpers so
  fragments carry their stat effects.
- Unknown socket categories (Prismatic extras) get their own group, never
  dropped.

**Checkpoint:** unit test with a mocked manifest + socket/reusable components:
groups come out in category order with correct labels; a socket's options
come from 310 when present and the def plug set when absent; an invisible
socket is skipped; fragment stat effects populate.

### Phase C — Subclass detail modal

New `lib/presentation/screens/inventory/subclass_detail_modal.dart`, opened
by an `InventoryScreen` listener (mirror of the armor-set modal pattern:
selection provider + open-guard + clear-on-close).

- Providers (`inventory_provider.dart`): `selectedSubclassProvider`
  (`DestinyItem?`) and `subclassDetailProvider` (autoDispose; watches
  `gearModalRevisionProvider` so an insert's cache patch re-resolves, same as
  `gearModalInstanceDetailProvider`).
- Tile routing (`item_tile.dart`): `itemType == 16` → select into
  `selectedSubclassProvider` **and** `gearModalInstanceProvider`; otherwise
  the existing gear-modal path.
- Layout: header (name, element color via `DamageType.color`, screenshot
  banner), then one section per `SubclassSocketGroup`. Each socket renders as
  a chip (icon + name); clicking opens a `MenuAnchor` option grid (the
  `_ModPicker` pattern); picking a non-equipped option calls
  `moveControllerProvider.insertPlug(item, socketIndex, plugHash, name)`.
  Equipped/override highlight reads `gearModalPlugOverrideProvider`.
- The modal builds its own small chip/tooltip widgets — `_PerkChip`/
  `_PerkTooltip` are private to `database_detail_modal.dart`, and extracting
  them is a refactor this feature doesn't need (Rule 3). If a later feature
  needs a third copy, extract then.

**Checkpoint (manual per `ui-changes-verified-manually` + widget test):**
widget test that the modal renders the groups and that tapping an option
fires `insertPlug` with the right socket index/plug hash; manual in-game
verification that a fragment swap and a super swap actually apply.

### Phase D — Clarity on the subclass surfaces

- The equipped plug row of each socket gets `ClarityInsightExpander` under
  its description (fragments and class abilities light up; aspects show
  manifest text only — expected, Clarity has no aspect entries). Hover
  tooltips carry **no** insight block — per the locked UX decision, insights
  live in expanders and swappable side panels (see the gear modal's
  `_SidePanel` / `_SwapRail`), never tooltips.

**Checkpoint:** with the Clarity fixture loaded, a covered fragment's row
shows the expander; an aspect row shows none and is layout-identical to
pre-Clarity rendering.

---

## Part 2 — Database: Abilities kind

### Phase E — `GearKind.ability` + manifest query

- `GearKind`: add `ability(19)` (`itemType` informational here — the query is
  category-driven). Audit the enum's exhaustive uses (*surveyed*: `forKind`
  weapon/armor branch, `queryGearSummaries`, `DatabaseFilter`, facet warm
  loop in `app_warmup_provider` — the loop picks the new kind up
  automatically and `FacetBuilder` degrades gracefully).
- `ManifestDatabase.queryGearSummaries`: branch for `ability` → a query over
  `plug.plugCategoryIdentifier` matching the taxonomy above (prefixes
  `titan.|hunter.|warlock.|shared.` × suffixes `.class_abilities|.movement|
  .melee|.supers|.aspects|.totems|.grenades|.fragments|.trinkets`),
  excluding names starting `Empty ` (placeholders). Project the same aliases
  plus `pci`.
- `DatabaseRepository._summaryOf`: when a row carries `pci`, derive
  `classType` from the prefix (titan 0 / hunter 1 / warlock 2 / shared 3) and
  `damageType` from the element segment (arc 2 / solar 3 / void 4 / stasis 6 /
  strand 7; `prism` → 0, its identity reads from `itemTypeDisplayName`) —
  the defs themselves carry `classType 3` and no damage type. This makes
  `is:arc` and the class filter work through the existing search grammar
  with no grammar changes.
- Dedupe by name (the existing reissue rule; multiple subclass generations
  share plug names).

**Checkpoint:** unit test (mirroring `database_repository_test`) — the
ability index contains a known fragment/super; class/element derive
correctly; "Empty Fragment Socket" is absent; a name shared across
generations appears once.

### Phase F — Filter bar + list + ability detail modal

- `database_screen.dart`: `_KindToggle` gains **Abilities**; the class filter
  shows for armor *and* abilities; armor-only toggles (Sets, Exotics, Legacy)
  and the rarity floor stay armor/weapon-only — `DatabaseFilter.toGearFilter`
  applies no `minTierType` for abilities (ability plugs are low-tier;
  the floor would blank the list).
- `listGear`: a class filter passes `classType == 3` rows too (shared
  fragments/grenades belong to every class; armor is never classType 3, so
  armor semantics are unchanged).
- Row tap: the `DatabaseScreen` listener branches on the active kind —
  abilities open a new lightweight `AbilityDetailModal` (icon, name,
  `itemTypeDisplayName`, element chip, manifest description, stat effects
  list, and the Clarity insight rendered **directly** (not collapsed) with
  the standard attribution footer). The weapon/armor gear modal is untouched.

**Checkpoint:** widget test — switching to Abilities lists entries; class
filter narrows supers but keeps shared fragments; tapping a covered fragment
shows manifest text + Clarity block; an uncovered aspect shows manifest text
only.

---

## Files touched (summary)

**New**
- `lib/domain/models/subclass_detail.dart`
- `lib/presentation/screens/inventory/subclass_detail_modal.dart`
- `lib/presentation/screens/database/ability_detail_modal.dart`
- tests: subclass grid/validation, resolveSubclassDetail, subclass modal
  interaction, ability index/query, ability modal

**Modified**
- `lib/core/destiny/destiny_buckets.dart` — `EquipmentBucket.subclass`,
  `GearKind.ability`, `forKind` exclusion
- `lib/core/destiny/destiny_enums.dart` — `typeSubclass`
- `lib/core/destiny/drop_validation.dart` — subclass transfer denial
- `lib/data/local/manifest_database.dart` — ability summaries query,
  `getSocketCategory`
- `lib/data/repositories/manifest_repository.dart` — surface it
- `lib/data/repositories/inventory_repository.dart` — `resolveSubclassDetail`
- `lib/data/repositories/database_repository.dart` — pci-derived summary
  fields, ability-kind handling
- `lib/presentation/providers/inventory_provider.dart` — subclass selection +
  detail providers
- `lib/presentation/providers/database_provider.dart` — filter semantics for
  the ability kind
- `lib/presentation/screens/inventory/inventory_screen.dart` — subclass row,
  modal listener
- `lib/presentation/widgets/item_tile.dart` — subclass tap routing
- `lib/presentation/screens/database/database_screen.dart` — kind toggle,
  class filter visibility, modal routing

**Not modified:** transfer repository and Bungie API layer (no new
endpoints), Clarity pipeline (already hash-keyed), search grammar.

## Risks & open questions

- **Prismatic socket layout** — verify during Phase B (extra categories such
  as transcendence must render, not vanish).
- **Locked/not-unlocked plugs.** 310 reflects the instance's available plugs;
  the definition fallback lists everything, so an option a character hasn't
  unlocked may appear and fail the insert. The failure is already visible
  (toast + rollback). If it proves noisy, filter fallback options against
  310 when 310 exists — decide from real use, not up front (Rule 2).
- **`ItemTile` assumptions.** Subclass tiles have no power/damage instance
  data; verify the tile renders acceptably (it degrades to icon + name), and
  that the equipped-tile size fits the row.
- **Fragment slots that appear/disappear** as aspects change: handled by
  `isVisible`, but the modal must recompute after an aspect swap — it does,
  via the revision bump; verify manually.
- **Facet warm cost** for the ability kind is trivial (~500 defs), but it
  runs in the startup loop — confirm no measurable startup regression.
- **Older subclass defs** (some of the 35 are previous-generation
  duplicates): the inventory path only shows what the profile owns (no
  issue); the Database path lists plugs, not subclass items (no issue).

## Explicitly out of scope (this step)

- Loadout saving/applying (this is the display/editing prerequisite).
- Diamond-shaped subclass tile art (DIM-style); square tiles are fine v1.
- Transcendence/Prismatic special UI beyond rendering its socket groups.
- Subclass entries in the Database tab (it lists ability plugs; subclasses
  themselves are inventory-only).
- Search-grammar extensions (`fragment:`, `aspect:` keywords) — name search
  plus `is:<element>` and the class filter cover v1.
