# Loadouts Tab — Implementation Plan

Replace the Loadouts stub with an interactive loadout builder that works in **two
distinct modes** — a definition **sandbox** and an **owned-items** builder — plus
**save it locally** and **read/write real in-game loadouts** on characters.

Grounded in this codebase. Two framings drive the whole design: the **two builder modes**
(below), and the **three capability tiers** (further down) that each mode passes through.

---

## Two builder modes (read this first)

The tab has a top-level mode toggle. Both modes produce the *same* `Loadout` model and
share the same builder UI and local persistence — they differ only in **what the item
picker draws from** and **whether the result is realisable in-game**.

| | **Sandbox mode** | **Owned mode** |
|---|---|---|
| Item source | Any **definition** (the Database) | Only items the account **owns** (the inventory) |
| Perk/plug choices | Any candidate plug the socket *can* roll | Only plugs available on the **owned instance** |
| Stats | Definition + chosen-plug math (theorycraft) | The instance's **actual rolled** stats |
| Cosmetics | Any ornament/shader definition | Owned ornaments/shaders |
| Realisable in-game (Tier 3) | **No** — theorycraft only (planner) | **Yes** — every item/plug is owned, so it can be equipped |
| Auth needed | None (manifest-only) | Account data (already read today) |

This split **resolves the "sandbox loadouts aren't equippable" tension** entirely:
sandbox mode is an explicit *planner* (never claims to push to a character), while owned
mode is *always* realisable because it is constrained to what the character actually has.
Make the mode obvious in the UI so the user is never surprised that a sandbox build can't
be equipped (rule 12).

Design consequence: the builder logic must be **mode-parameterised over its plug/stat
source**, not two forked builders. One builder; a `LoadoutSource` abstraction with a
`DefinitionSource` (manifest) and an `OwnedSource` (inventory) implementation. Do not
duplicate the builder per mode (rule 7/11).

---

## The three tiers (read this second)

Each mode still passes through the same **three capability tiers**, built in order.

---

## The three tiers (read this first)

| Tier | What | Auth needed | Depends on |
|------|------|-------------|------------|
| **1. Builder** | Assemble a loadout in-memory (either mode) — customise perks/stats/cosmetics | Sandbox: none. Owned: read (already have) | Database (sandbox) / inventory (owned) |
| **2. Local persistence** | Save/name/load built loadouts on disk (both modes) | None | Tier 1 |
| **3. In-game sync** | Read characters' real loadouts; snapshot/equip/rename slots; (owned mode) push a build | **Write scope + real gear** | Tiers 1–2, inventory data |

Tier 3 is the hard, outward-facing one (it changes the user's actual account and needs a
re-auth). Tiers 1–2 are self-contained and safe. **Build 1 → 2 → 3.** Confirm the intent
for Tier 3 separately before starting it (contract rule 1). Within Tier 1, **sandbox mode
is the natural first target** (no account dependency); owned mode reuses the same builder
with an inventory-backed source.

---

## Dependencies on the other planned tabs

- **Requires the Database tab's definition layer** (now built —
  `lib/presentation/screens/database/`, `lib/data/repositories/database_repository.dart`):
  the sandbox's "pick any item" and "customise perks" flows are exactly the Database tab's
  definition browse + perk-column resolution. Reuse that query + definition-detail layer;
  don't duplicate the resolution here (rule 8/11).
- **Tier 3 overlaps the shipped write layer** (now built —
  `lib/data/repositories/item_transfer_repository.dart`): the drag-to-move/equip feature
  already has the write OAuth scope and item-action POSTs. Tier 3 reuses its action methods
  and the re-auth flow; don't build a second write layer.

---

## Key architectural facts (from the code / manifest)

### 1. Config & scope
- OAuth scope is **`ReadDestinyInventoryAndVault`** (read-only). Tiers 1–2 need nothing
  more. **Tier 3 needs `MoveEquipDestinyItemsFromVault`** and a re-auth of every user —
  same blocker as drag-to-move.
- Config is dart-define (`AppConfig`), not envied — any new constant follows that.

### 2. The sandbox is definition customisation, not instances
A built loadout is a *specification*: item hash + chosen plug hash per socket + chosen
stat roll + cosmetics. It is **not** tied to any owned instance until Tier 3 tries to
realise it on a character. So Tiers 1–2 have **no account dependency** and can be fully
built/tested offline.

### 3. Socket structure is already discoverable (verified)
A weapon def's `sockets.socketCategories` maps categories to socket **indexes**
(confirmed against a live weapon):
- `INTRINSIC TRAITS` → [0]
- `WEAPON PERKS` → [1,2,3,4,9]
- `WEAPON COSMETICS` → [5]
- `WEAPON MODS` → [6,7]

So "customise perks" = for each perk-category socket index, offer the candidate plugs
(from `getPlugSet` / inline `reusablePlugItems`, the same traversal the catalyst-options
resolver and the Database perk columns use) and let the user pick one. Cosmetics/mods
sockets work the same way with their categories. **This is the core sandbox mechanic and
the data fully supports it.**

### 4. In-game loadout cosmetics exist as manifest defs (verified)
Destiny's own loadout system has preset name/color/icon pickers, present in the manifest:
- `DestinyLoadoutColorDefinition` (22), `DestinyLoadoutIconDefinition` (21),
  `DestinyLoadoutNameDefinition` (22).
These are needed for Tier 3 (an in-game loadout slot has a colorHash/iconHash/nameHash)
and are a nice touch for Tier 1 loadout identity.

### 5. In-game loadout data (Tier 3)
- **Read**: the profile **Loadouts component (1100)** returns each character's loadout
  slots (each: `colorHash`, `iconHash`, `nameHash`, and per-item `itemInstanceId` +
  `plugItemHashes`). Add `1100` to the components list in `InventoryRepository`.
- **Write**: `POST /Destiny2/Actions/Loadouts/SnapshotLoadout/` (capture current equip
  into a slot) and `.../EquipLoadout/` (apply a slot); plus `UpdateLoadoutIdentifiers`
  for name/color/icon. These are **separate write endpoints** from item transfer.
- Realising a *sandbox* loadout in-game is harder than snapshotting: the game can only
  equip items the character **owns** with those exact plugs. A sandbox loadout built from
  arbitrary definitions may not be equippable — see "Sandbox → reality gap".

### 6. Persistence — nothing exists yet
There is **no local storage** in the app today (tokens use `flutter_secure_storage`, but
no general app data store). Tier 2 introduces the first persistent app data. Options:
a JSON file in the app-support dir (simplest, matches the manifest-file pattern), or
`hive_ce` (already noted as a future dep in `pubspec.yaml`). Prefer the simple JSON-file
store first unless we need querying (rule 2).

---

## Architecture

### Tier 1 — Builder (both modes)

**Domain models (`lib/domain/models/loadout.dart`)**
- `LoadoutItemSpec { itemHash, itemInstanceId?, Map<int,int> plugBySocketIndex,
  statRoll?, ornamentHash?, shaderHash? }` — a fully-specified item. `itemInstanceId` is
  **null in sandbox mode** (definition only) and **set in owned mode** (points at the
  real instance), which is also exactly what Tier 3 needs to equip it.
- `Loadout { id, name, LoadoutMode mode, colorHash?, iconHash?, List<LoadoutItemSpec>
  items (by slot) }`. `mode` is persisted so a loaded loadout knows whether it's
  theorycraft (sandbox) or realisable (owned).
- Slots keyed by `EquipmentBucket` (reuse the enum) — one weapon per weapon slot, one
  armor per armor slot, matching a real loadout's shape.

**The mode abstraction (the key to not forking the builder)**
- `abstract LoadoutSource` with two methods: `candidateItems(bucket)` and
  `candidatePlugs(itemHash|instance, socketIndex)` + a stat resolver.
  - `DefinitionSource` — draws items from the Database query layer; plugs from the
    socket's full plug set; stats from definition + chosen-plug math.
  - `OwnedSource` — draws items from the loaded inventory grid; plugs from the owned
    instance's available plugs; stats from the instance's actual roll.
- The builder logic and UI depend only on `LoadoutSource`. Switching mode swaps the
  source; nothing else forks (rule 7/11).

**Builder logic (`lib/data/repositories/loadout_builder.dart`)**
- Given a slot, ask the active `LoadoutSource` for candidate items; on pick, expose its
  customisable sockets (from `socketCategories`) and the source's candidate plugs per
  socket.
- Apply a chosen plug → update the spec; recompute stats via the source's resolver
  (reuse the stat-bonus math already written for the detail panel — the gold/red bar
  logic; sandbox drives it from *chosen* plugs, owned from the *instance's* roll).
- **Stat rolls**: for weapons, the roll is largely determined by the barrel/mag/perk
  choices (their investment stats) — so "random stat roll" is mostly a consequence of
  perk selection, not a free slider. In **owned mode** the stats are simply the
  instance's real values (no choice). For armor, expose the stat spread. Clarify with the
  user which "stat customisation" they mean (rule 1) — flagged below.

**UI (`lib/presentation/screens/loadouts/`)**
- A **mode toggle** at the top (Sandbox | Owned) — swaps the `LoadoutSource`.
- A loadout canvas: the equipment slots (like the inventory column layout, reuse the
  bucket rows). Each slot: tap → pick an item (sandbox → Database browser; owned →
  inventory picker filtered to that slot) → then a socket-editor (perk columns as
  selectable chips, cosmetics pickers). In owned mode the perk chips are limited to the
  instance's available plugs.
- Live preview of resulting stats (reuse stat-bar widgets) as the user changes perks.
- Loadout identity: name + optional in-game color/icon (from the loadout cosmetic defs).
- A clear mode indicator on saved loadouts (theorycraft vs realisable), since only owned
  loadouts can be pushed in-game (rule 12).

### Tier 2 — Local persistence

**Store (`lib/data/local/loadout_store.dart`)**
- Serialize `Loadout` to JSON, write to `<app-support>/loadouts.json` (list). CRUD:
  save, rename, duplicate, delete, list. Atomic write (temp + rename) so a crash mid-save
  can't corrupt the file (rule 12 — fail safely).
- Versioned schema field for forward migration.

**Providers (`lib/presentation/providers/loadout_provider.dart`)**
- `savedLoadoutsProvider` (loads the store), `loadoutBuilderProvider` (the in-progress
  loadout being edited), CRUD controller.

### Tier 3 — In-game sync

**Read**
- Add component `1100` to `InventoryRepository`; parse each character's loadout slots into
  a display model (name/color/icon + item instances). Show a character's real loadouts as
  a list the user can inspect or load into the builder.

**Write** (needs write scope + re-auth)
- `snapshotLoadout(characterId, loadoutIndex)` — save the character's *current* equipped
  set into a slot (the safe, reliable in-game op).
- `equipLoadout(characterId, loadoutIndex)` — apply an existing in-game slot.
- `updateLoadoutIdentifiers(...)` — set name/color/icon.
- Keep deterministic sequencing + fail-visible reporting in a service layer, mirroring the
  drag-to-move move service (reuse it if it exists).

**Pushing a built loadout — the two modes diverge here (surface, don't hide)**
Destiny's API equips **owned** items and inserts only **owned/available** plugs. The two
modes land on opposite sides of this:
- **Owned-mode loadouts are realisable by construction.** Every item carries its
  `itemInstanceId` and every plug is one the instance already has, so pushing the build =
  transfer/equip each instance + insert the chosen plugs. This is the reliable "apply my
  build to a character" path, and it needs the item-action + plug-insert writes (shares
  infrastructure with drag-to-move).
- **Sandbox-mode loadouts are theorycraft** and may reference items/perks the user doesn't
  own — they **cannot be pushed**. Sandbox is a planner; the UI must say so (rule 12).
  A useful bridge (later): "resolve this sandbox build against my inventory" → converts a
  sandbox loadout to an owned one where possible, **reporting every item/perk that has no
  owned match** rather than silently dropping it.

So the honest v1: sandbox saves/plans locally and never claims to equip; owned-mode read
+ snapshot/equip-existing/rename first, then owned-mode *push* as the "apply build" feature
once the plug-insert write is proven.

---

## Incremental delivery (checkpoints — rule 10)

1. **Loadout models + `LoadoutSource` abstraction + builder logic** (perk selection, stat
   recompute), unit-tested with a mocked `DefinitionSource`. Gate: choosing a perk updates
   the spec and recomputed stats, through the source interface.
2. **Sandbox-mode builder UI** on top of the Database browser: assemble a loadout, edit
   sockets, live stat preview. Gate: build a complete weapon+armor sandbox loadout.
3. **Local persistence**: save/list/rename/delete to `loadouts.json` (mode recorded).
   Gate: loadouts survive an app restart.
4. **Owned-mode source + mode toggle**: `OwnedSource` backed by the inventory grid; the
   builder now works in both modes with no forked logic. Gate: build a loadout from owned
   items with real rolls; toggle switches sources cleanly.
5. **Tier 3 read**: component 1100, show characters' real in-game loadouts; load one into
   the builder. Gate: real loadouts display correctly.
6. **Tier 3 write (safe subset)**: snapshot / equip existing slot / update identifiers,
   behind the write scope + re-auth. Gate: snapshot and equip work on a real character.
7. **(Later) Push an owned-mode build**: transfer/equip instances + insert chosen plugs,
   reporting anything that couldn't be applied (rule 12). Optionally, "resolve sandbox →
   owned" as a bridge.

Steps 1–4 deliver a complete offline loadout planner (both modes) with zero account risk.
Steps 5–7 add the account-connected features and are separately gated.

---

## Testing

- **Unit — builder**: perk selection updates the spec; stat recompute with chosen plugs
  matches expected (reuse/extend the stat-bonus tests); invalid plug for a socket rejected.
- **Unit — store**: round-trip serialize/deserialize; atomic write; schema version
  handling; corrupt-file recovery (fail visible, not silent).
- **Unit — Tier 3 service**: snapshot/equip/identifier request bodies; error mapping;
  the "cannot fully apply" path reports each missing item (rule 9/12).
- **Widget**: slot picker opens the Database browser; socket editor reflects choices;
  saved loadouts list updates.
- **Manual (Tier 3)**: real account — read loadouts, snapshot, equip, rename; verify no
  false-success when an equip partially fails.

---

## Risks & open questions

- **"Random stat rolls" is ambiguous** — for weapons, stats derive from perk/barrel/mag
  choices, not a free roll; for armor there's a stat spread. Clarify what customisation is
  wanted before building the stat UI (rule 1).
- **Two modes must not fork the builder** — enforce the `LoadoutSource` abstraction so
  sandbox and owned share one builder/UI; a divergent second builder is the main design
  risk here (rule 7).
- **Sandbox loadouts aren't fully equippable in-game** — inherent; owned mode is the
  realisable path. Keep sandbox a planner and label saved loadouts by mode so the user is
  never misled (rule 12).
- **Write scope + re-auth** (Tier 3) — same friction/trust boundary as drag-to-move;
  confirm intent, message clearly.
- **Depends on the Database tab** — the sandbox is impractical without the definition
  browse + perk resolution. Sequence accordingly.
- **Persistence is new ground** — pick the simplest store that works (JSON file) unless
  querying needs justify Hive (rule 2).
- **In-game loadout slot count / unlock state** varies per character — handle locked/empty
  slots gracefully.

---

## Recommendation

Two modes over three tiers, built on one mode-parameterised builder. Start with the
`LoadoutSource` abstraction and **sandbox mode** (steps 1–2) — it depends only on the
Database tab's definition layer and has zero account risk — then add **local persistence**
(step 3) and **owned mode** (step 4, an `OwnedSource` over the inventory grid we already
load). Steps 1–4 give a complete offline planner in both modes.

**Tier 3 (in-game sync)** is gated on the write scope and shares infrastructure with
drag-to-move. Ship its *read* and *safe write subset* (snapshot / equip existing / rename)
first. The realisable "apply my build to a character" feature is an **owned-mode** push
(instances + owned plugs) — do it once the plug-insert write is proven, reporting anything
unappliable rather than failing silently. Sandbox builds stay planner-only; never claim to
equip them.

The key design discipline throughout: **one builder, two sources — do not fork.**
