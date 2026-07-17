# Armor Feature-Parity Plan

Branch: `armor-feature-parity`

Bring armor viewing/editing up to the level weapons already enjoy. Five deliverables:

1. Editable armor mods (like weapon mods).
2. Class filter (Titan/Hunter/Warlock) in the Database tab.
3. A toggleable "collapse armor into sets" mode (on by default).
4. Armor **set bonuses** shown per set.
5. A single set-detail modal: screenshot previews of each piece + the set bonus.
6. Search filters (both Inventory and Database tabs) for **2-piece / 4-piece set effect names**.

Everything below is grounded in the actual manifest and current code, not assumptions.

---

## Manifest facts established (probed against the live manifest)

- **`DestinyEquipableItemSetDefinition`** exists (56 sets). Shape:
  - `displayProperties.name` — the set name (e.g. "Thriving Survivor").
  - `setItems` — `List<int>` of member **item hashes** (all pieces across all classes).
  - `setPerks` — `[{ requiredSetCount: int, sandboxPerkHash: int }, …]` (typically the 2-piece and 4-piece bonuses).
- **Set membership is reverse-only.** Armor item defs carry **no** `equipableItemSetHash` field (probed: 0 items have it). Membership must be built by inverting `setItems` into an item-hash → set map, once, at warm time.
- **Not all armor is in a set.** Only 56 sets exist and they skew to newer/featured gear; most legendary armor has no set. The collapse-into-sets UI and set-bonus section must degrade gracefully for setless pieces.
- **Armor socket categories** (confirmed against a real helmet def):
  - `590099826` = **ARMOR MODS** — the editable target (general + slot-specific mod sockets, plus "Upgrade Armor").
  - `3154740035` = **ARMOR PERKS** — built-in, *cannot be swapped* (matches the existing test). **Not** part of the editable-mods feature.
  - `1926152773` = **ARMOR COSMETICS** — shader/ornament. Out of scope.
- Armor mod sockets expose their options via each socket entry's `reusablePlugSetHash` (definition side) and, on an instance, via ItemReusablePlugs (310) — exactly the fallback the weapon mod resolver already handles.
- Set perks resolve through the existing `DestinySandboxPerkDefinition` accessor (`getSandboxPerk`) → `displayProperties.name` + `.description` + `.icon`.

**Correction to the earlier exploration note:** the ARMOR PERKS category is `3154740035`, not `2518356196`. The test's `2518356196` is a *different* armor category constant; the plan uses the probed values. (A `2518356196` sanity re-check is a task in Phase 0.)

---

## Rule-driven decisions to confirm before coding (CLAUDE.md rules 1 & 7)

1. **"Armor mods editable like weapon mods" → reuse the weapon path, generalized.** The insert pipeline (`MoveController.insertPlug` → `ItemTransferRepository.insertPlug` → `insertSocketPlugFree`) is already gear-agnostic. The only gate is that `_resolveInstanceModColumns` is hard-coded to `_weaponModsCategory`. Plan: parameterize the category (accept weapon-mods *or* armor-mods category) rather than duplicate the resolver. This honors rule 11 (convention beats novelty) and rule 2 (simplicity).

2. **Editable scope = ARMOR MODS (`590099826`) + swappable ARMOR PERKS (`2518356196`)** — decided with the user after the Phase 0 probe. Both are mod-shaped (single-chip pick, reusable plug set), so both flow through one generalized mod resolver; the resolver's existing guards (≥2 real mod plugs) auto-exclude the masterwork/tier socket, empty legacy sockets, and the fixed-perks category `3154740035`. The fixed ARMOR PERKS category stays read-only (the API would reject inserts — failing visibly would violate rule 12).

3. **Set-collapse is a Database-tab view mode, default on, armor-only.** When browsing weapons the toggle is hidden/ignored (weapons have no sets). **Decided:** the toggle lives in the filter bar beside the class filter, and its state is **session-only** (lives in `DatabaseFilter`, resets to ON each launch — matching current filter behavior; no persistence hook).

4. **One set = one collapsed row.** A set groups its member pieces regardless of class; the row shows the set name + a piece/count summary. Tapping opens the **set detail modal** (deliverable 5), distinct from the existing per-item `DatabaseDetailModal`. Setless armor still lists as individual rows (same `_GearRow` as today) interleaved with set rows, sorted alphabetically by name.

5. **Set bonuses render in two places:** (a) as a compact line/badges on the collapsed set row and (b) fully in the set detail modal (2-piece / 4-piece perk name + description + icon).

---

## Phase 0 — Confirm unknowns & lock scope (no product code) — **DONE**

Probed against the live manifest across legendary + exotic armor of all five slots. Findings:

- **There are THREE armor socket categories, two of them named "ARMOR PERKS":**
  - `590099826` = **ARMOR MODS** — present on *every* piece. Its sockets are the classic mod slots (General/Helmet/Arms/… mods) **plus** a masterwork/tier socket ("Upgrade Armor", whitelist `v460.plugs.armor.masterworks.*`).
  - `3154740035` = **ARMOR PERKS (fixed)** — "built into a given piece of armor. They **cannot be swapped out**." Non-editable by design.
  - `2518356196` = **ARMOR PERKS (swappable)** — "exclusive to each other while in the same column and **can be swapped freely**." This is the newer armor-perk system; it IS user-editable in-game. Appears on some legendary (e.g. Annealed Shaper Robes) and exotic (Sealed Ahamkara Grasps, Solipsism) pieces, not all.
- **A single piece mixes categories**, and which perk category it uses varies by piece. Example: Tangled Web Helm uses `590099826` + `3154740035`; Annealed Shaper Robes uses `2518356196` + `590099826`.
- **ARMOR MODS socket detail (legendary helmet, category `590099826`, indexes `[0,1,2,3,5]`):**
  - `[0]` General Armor Mod (`enhancements.v2_general`), `[1..3]` Helmet Armor Mod (`enhancements.v2_head`) — the real user-swappable mod slots.
  - `[5]` "Upgrade Armor" — the masterwork/tier socket (whitelist `v460.plugs.armor.masterworks.*`), **not** a normal mod pick.
- **Reconciliation:** the existing `database_repository_test.dart` uses `2518356196` and asserts the *definition* modal builds no weapon-style `perkColumns` for armor — that stays valid (it's the WEAPON-PERKS-gated definition path, unrelated to instance mod editing).

**Editable-socket predicate (locked):** within category `590099826`, treat a socket as a user mod slot when its type whitelist is an `enhancements.*` mod family (General/slot mods) — i.e. exclude the masterwork/tier socket (`v460.plugs.armor.masterworks.*`) and any Restore-Defaults cosmetic. This keeps "Upgrade Armor" out of the mod picker and matches what players call "armor mods."

**Scope of the swappable "ARMOR PERKS" category (`2518356196`), probed across all 5893 equippable armor defs:**
- 1101 pieces carry it — 984 legendary, 78 exotic, 27 rare, 12 common. **4095 pieces carry the FIXED perks category instead.**
- Despite the "perks" name, on real pieces its populated sockets hold **legacy armor mods** (e.g. "Plasteel Reinforcement Mod", "Restorative Mod" via a reusable plug set) — the old Year-1/2 armor mod system. Many of its sockets are **empty/legacy** (`singleInitialItemHash: null`, no plug set) and offer nothing.
- **Key implication:** `2518356196` is not a distinct weapon-style perk-column system. Its editable content is *mods*, structured exactly like `590099826` (single-chip pick backed by a reusable plug set). So it does **not** need a separate perk-column path — both categories flow through the **same generalized mod-column resolver**, and the existing single-option-drop / placeholder-skip logic naturally hides the empty legacy sockets.

**Editable-socket predicate (locked):** a socket is a user-editable armor mod slot when (a) it belongs to category `590099826` OR `2518356196`, AND (b) it resolves to ≥2 real, swappable mod plugs. Rule (b) — which the weapon mod resolver already enforces via `plugs.length < 2 → skip` and `category != PlugCategory.mod → skip` — automatically excludes the "Upgrade Armor" masterwork socket (a single tier plug, not a mod-category plug) and every empty legacy socket. No special-casing needed.

Exit criterion met: socket-category constants and the editable-socket predicate are known and testable.

---

## Phase 1 — Editable armor mods — **DONE**

Files changed: `lib/data/repositories/inventory_repository.dart` (+ import), `test/item_detail_test.dart` (new test).

- [x] Added `_armorModsCategories = {590099826, 2518356196}`. Generalized `_resolveInstanceModColumns` to select the applicable mod categories by `item.itemType` (armor → both armor categories, weapon → `_weaponModsCategory`) and collect socket indexes from every matching category. Kept the single-option-drop (`plugs.length < 2`) and mod-only (`category != PlugCategory.mod`) guards intact — they auto-exclude the masterwork "Upgrade Armor" socket and empty legacy sockets.
- [x] `resolveDetail(..., withPerkColumns: true)` already populates `modColumns` unconditionally (the weapon-only gate lived inside the resolver, now generalized). `perkColumns` stays empty for armor — `_resolveInstancePerkColumns` is still gated to `_weaponPerksCategory`.
- [x] Verified the modal's `_RolledMods` / `_ModPicker` is gear-agnostic (keys off `instance.modColumns` matched by `socketIndex`; the perk-grid's weapon-only help text lives in the `perkColumns` block, which stays empty for armor). No widget change needed. `MoveController.insertPlug` and `ItemTransferRepository.insertPlug` are already gear-agnostic.
- [x] Behavioral test added: an armor helmet resolves BOTH an ARMOR MODS socket and a legacy ARMOR PERKS socket into swappable mod columns with the equipped plug flagged and insert hashes carried; the single-option masterwork socket and the fixed-perk socket produce no column; `perkColumns` stays empty.

Verification: `flutter analyze` clean; full suite green (331 tests), including the new armor test, the unchanged weapon mod test, and the existing armor "no weapon perk columns" test. **Not** driven against a live Bungie profile (needs OAuth + a real account with armor); verified at the resolver layer that changed, with the picker widgets provably reusing the same interactive path as weapons.

Success criteria met: opening an owned armor piece's modal will surface interactive mod pickers wherever a socket offers ≥2 real mods, issuing `insertSocketPlugFree` and reconciling stats — the same UX and code path as weapons. Existing weapon behavior unchanged.

---

## Phase 2 — Class filter in the Database tab — **DONE**

Files changed: `lib/presentation/providers/database_provider.dart`, `lib/presentation/screens/database/database_screen.dart`, `test/database_screen_test.dart`.

- [x] Added nullable `classType` to `DatabaseFilter` (null = all classes), threaded into `toGearFilter()` (the repo's `listGear` already filters `classType`). Added `setClassType`, and made `setKind` drop the constraint when leaving armor.
- [x] Added `_ClassFilter` (All/Titan/Hunter/Warlock `SegmentedButton<int?>`, "All" = null) to `_FilterBar`, shown only when `kind == GearKind.armor`. Mirrors the existing `_KindToggle` style.
- [x] The search-grammar `is:titan` path is untouched — the control just pre-populates the structured filter.
- [x] Widget test: weapons show no class control; switching to armor reveals it and lists all classes; picking Hunter narrows to the Hunter piece and sets `classType == 1`; switching back to Weapons hides the control and clears `classType`.

Verification: `flutter analyze` clean; full suite green (332 tests, +1 for the class-filter test). Default class filter is **All** (per the locked decision). UI layout uses the desktop-width test surface, matching the existing modal tests.

Success criteria met: with Armor selected a class control filters the list to that class; switching to Weapons hides it and clears the constraint.

---

## Phase 3 — Set model, accessor, and reverse-membership index — **DONE**

Files changed: `lib/data/local/manifest_database.dart`, `lib/data/repositories/manifest_repository.dart`, new `lib/domain/models/armor_set.dart`, `lib/data/repositories/database_repository.dart`, `test/database_repository_test.dart` (+ 3 test-double updates).

- [x] Added `getEquipableItemSet(int hash)` and `allEquipableItemSets()` (a `SELECT json FROM DestinyEquipableItemSetDefinition` enumerator, following the `queryGearSummaries` precedent) to `ManifestDatabase`, re-exposed on `ManifestRepository`.
- [x] New models `ArmorSet { hash, name, memberHashes, perks: List<SetPerk> }` and `SetPerk { requiredSetCount, name, description, iconPath/iconUrl }` — set perks resolved via `getSandboxPerk`.
- [x] `DatabaseRepository._ensureSetsBuilt` builds the reverse index once (cached): inverts every set's `setItems` into `itemHash → ArmorSet`, plus `setHash → ArmorSet`, sorting perks ascending by `requiredSetCount`. Accessors: `armorSetForItem(hash)`, `armorSetByHash(hash)`.

Verified: unit tests assert a member resolves to its set with both perks (sorted 2pc→4pc, real names/descriptions/icons), every member maps back, a non-member resolves null, and the index is built once (`allEquipableItemSets` called once). `flutter analyze` clean; full suite green (343 tests).

---

## Phase 4 — Collapse-into-sets view mode (Database list) — **DONE**

Files changed: `lib/presentation/providers/database_provider.dart`, `lib/presentation/screens/database/database_screen.dart`, `test/database_screen_test.dart`.

- [x] Added `collapseSets` bool to `DatabaseFilter` (default **true**) with `setCollapseSets`; preserved across kind switches. Added the `_CollapseSetsToggle` ("Sets" filter chip) to `_FilterBar`, armor-only, beside the class filter.
- [x] `databaseRowsProvider` transforms the flat `databaseResultsProvider` into `List<DatabaseRow>` (piece or set). For armor + collapse, set members group into one `DatabaseRow.set` (carrying the members that passed the filter); setless pieces stay `DatabaseRow.piece`. Interleaved and sorted alphabetically by display name. Weapons / collapse-off are all piece rows.
- [x] `_GearList` renders the heterogeneous list: `_GearRow` for pieces, new `_SetRow` for sets (set name, "N pieces", small 2pc/4pc `_SetPerkBadge`s, a representative member icon since sets usually have `iconHash: 0`). Count label reads "N items · M sets".
- [x] Tapping a set row sets `selectedArmorSetProvider` (the set-detail modal in Phase 5 reads it); piece rows still open `DatabaseDetailModal`.
- [x] Class filter × collapse: the grouped provider builds from the already class-filtered flat results, so a set row only holds members of the active class, its count reflects the filter, and a set with no matching members produces no row.

- [x] **Legacy (pre-set) armor grouping.** Older armor (Bulletsmith's Ire, Eidolon Pursuant, Iron Will, Kit Fox, …) has no `DestinyEquipableItemSetDefinition` — the only link is the shared name. `_addLegacyNameSets` derives a set name by stripping the item name's **final word** (the piece noun — unbounded, so stripped by position, not from an enumerated list; an enumerated list proved to be endless whack-a-mole), then groups non-exotic setless armor by that name. **Exotics are excluded** (always single pieces). A group qualifies as a set when it (a) spans **2+ armor slots** (`itemSubType`) — an ordinary set — or (b) sits in one slot but is **one-piece-per-class** (member count == distinct real class count, 2+ classes) and its name is not an `<Noun> of [the] …` template — a class-specific single-slot set (class-item Mark/Bond/Cloak trios, and single-slot sets like Shieldbreaker Robes/Plate/Vest), while rejecting templated families (Mask of X, Boots of the X). Synthetic sets carry `isLegacy: true` and no `perks`. Verified against the manifest: Eidolon Pursuant / Pathfinder's / Iron Will (15 each), Kit Fox / Farseeker's / Hardcase (4), Shieldbreaker / Gearhead / All-Star / Allstar (single-slot 3-piece) all group; Mask of / Boots of / "The …" exotics-and-templates correctly stay individual.

Verified: widget tests cover collapse-on-by-default grouping (set row + bonus badges, setless piece stays), the Sets toggle flattening back to pieces, tapping a set selecting it, and the class filter interacting correctly (it toggles collapse off to test flat filtering); repository tests cover the legacy multi-slot grouping and its guards. `flutter analyze` clean; full suite green (346 tests).

---

## Phase 5 — Set detail modal — **DONE**

Files: new `lib/presentation/screens/database/armor_set_detail_modal.dart`; wired from `_SetRow` via `selectedArmorSetProvider`; `database_provider.dart` (`selectedArmorSetDetailProvider`, `armorSetModalOpenProvider`); `database_detail_modal.dart` (single-piece set-bonus section).

- [x] `ArmorSetDetailModal` — a `Dialog` on `DatabaseDetailModal`'s shell (1400×820), `showArmorSetDetailModal` guarded by its own `armorSetModalOpenProvider` (parallel to `gearModalOpenProvider`), opened from a `selectedArmorSetProvider` listener in the Database screen, closing clears the selection.
- [x] Body: set name + piece count, a `SetBonusSection` (each perk's icon, "N Piece: name", description; a legacy set instead shows a "no set bonus" note), then a member-screenshot gallery (16:9 `CachedNetworkImage`, piece name + type under each) laid out as one **row per class** (Titan/Hunter/Warlock), each row ordered by slot (helmet, arms, chest, legs, class item) and horizontally scrollable. Members resolved by `selectedArmorSetDetailProvider`.
- [x] Tapping a gallery piece pops the set modal and selects the item (`selectedDatabaseItemProvider`), so the Database screen's listener opens that piece's `DatabaseDetailModal` — the two open-guards are independent, so they don't fight.
- [x] **Extra (requested):** the single-piece armor detail modal shows the set bonus too — `_ArmorSetBonus` resolves the item's set via `armorSetForItem` and renders the shared `SetBonusSection` in the left column under the stats, in both the roll and definition views (it keys off the item's set, not the instance).

Verified: widget tests cover the set modal's bonus + member gallery from a set-row tap, and the single-piece modal showing its set bonus. `flutter analyze` clean; full suite green (357 tests).

---

## Phase 6 — Set-effect search filter (both tabs)

Search for gear by the **name of its set's 2-piece / 4-piece effect**, on both the Inventory and Database tabs.

Files: `lib/core/search/item_filter.dart`, `lib/data/repositories/facet_builder.dart`, `lib/data/repositories/inventory_repository.dart`, `lib/data/repositories/database_repository.dart` (shared reverse set-index from Phase 3), `lib/presentation/widgets/search_help_modal.dart` (help text).

**Why it works on both tabs uniformly:** set membership and set-perk names are reverse-resolved from `DestinyEquipableItemSetDefinition` by **item hash** — no instance data needed. Both tabs already build `SearchFacets` from an item hash (`FacetBuilder.facetsFor` on Database; `InventoryRepository.inventoryFacetsFor` on Inventory), so both can populate the new facet the same way.

**Grammar (decided with user — see Decisions):**
- `set2:<name>` — item belongs to a set whose **2-piece** effect name contains `<name>`.
- `set4:<name>` — item belongs to a set whose **4-piece** effect name contains `<name>`.
- `set:<name>` — matches the set **name** OR any of its effect names (broad, like `keyword:`).

Steps:
- [ ] Extend `SearchFacets` with set-effect data: `setName` (lowercased, nullable) and `setPerksByCount` (e.g. `Map<int, Set<String>>` of requiredSetCount → effect names lowercased), so the predicate can match a specific piece count. Default empty (non-armor, setless armor).
- [ ] Populate it in **both** facet builders via the shared reverse set-index (Phase 3): look up the item hash → `ArmorSet`, map `setPerks` to name sets keyed by `requiredSetCount`. Resolve effect names through `getSandboxPerk`.
- [ ] Add predicates `_setPredicate` / `_setEffectPredicate(count)` in `item_filter.dart`, wired in `_predicateFor` for keys `set`, `set2`, `set4`. Null (→ unsupported) when facets are unavailable, matching every other facet-backed filter.
- [ ] Add the new keys to `filterSuggestionCatalog` (both tabs — the data is definition-only, so no `instanceData` gate) and to the search help modal.
- [ ] Autocomplete values (in scope — decided): expose a set-effect name catalog (like `perkCatalogProvider`) so `set2:`/`set4:`/`set:` suggest real effect names. Sourced from the reverse set-index, so it is game-wide on both tabs.

Success (rule 9 — behavioral): on both tabs, `set2:"opening act"` matches exactly the pieces in sets whose 2-piece effect is "Opening Act" and excludes others; `set4:` matches only on the 4-piece effect; a setless piece matches none. Unit tests assert each against a fixture set (e.g. "Thriving Survivor").

---

## Testing strategy (rule 9)

- **Repository/model tests** (behavioral, not smoke): armor mod columns resolve to swappable options for a real armor piece; ARMOR PERKS resolve to *no* editable columns; set reverse-index maps a known member hash to the right set; set perks resolve real names/descriptions.
- **Widget tests**: class filter narrows the armor list; collapse toggle switches between set rows and flat rows; set row renders bonus badges.
- **Manual verification** (per memory: UI polish is user-verified) for the set modal's screenshot gallery layout and the mod-picker interaction feel.
- Do **not** add tests for pure visual polish unless asked.

---

## Risks / watch-items

- **Setless armor dominance:** the collapse view must not hide the majority of armor that has no set. Interleaving setless pieces as normal rows is mandatory, not optional.
- **Cross-class sets:** `setItems` mixes all three classes. The class filter must filter *within* a set's member view, and a set row should hide when no members match the active class filter.
- **Category-constant drift:** lock the armor mods/perks category constants behind Phase 0 confirmation and a test, so a future manifest change fails loudly.
- **Insert rejection:** only expose genuinely swappable armor mod sockets; if the API rejects an insert, surface it (rule 12) — reuse the weapon insert's existing rollback/error path.
- **Token/scope budget (rule 6):** five deliverables is large. Phases are independently shippable; checkpoint after each (rule 10) before starting the next.

---

## Decisions locked with the user

1. **Set-collapse toggle:** filter bar beside the class filter; **session-only** state in `DatabaseFilter` (resets ON each launch, no persistence).
2. **Set detail modal:** gallery pieces **are clickable** — tapping a piece opens the existing per-item `DatabaseDetailModal` (Phase 5 includes this wiring, not deferred).
3. **Collapsed set row:** shows set name + piece count + small **2pc/4pc perk-name badges**.
4. **Class filter default:** **All classes** (no constraint by default; Database tab stays account-agnostic — no active-character read).
5. **Set-effect search grammar:** `set2:<name>` (2pc effect), `set4:<name>` (4pc effect), and broad `set:<name>` (set name OR any effect) — mirrors `perk1:`/`perk2:`/`perk:`. On **both** tabs.
6. **Set-effect autocomplete:** yes — a game-wide set-effect name catalog backs `set2:`/`set4:`/`set:` value suggestions.
