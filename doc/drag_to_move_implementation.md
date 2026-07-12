# Drag-to-Move Inventory — Implementation Plan

Add interactive drag-and-drop to the inventory grid so a user can move an item to
another character or the vault (and equip by dropping on the equipped slot) — the
core DIM interaction. This turns the currently **read-only** app into one that
performs **write** operations against the live Bungie account.

Grounded in the current codebase, not a generic DnD writeup. Read "Hard
prerequisites" first — one of them (OAuth scope) blocks everything else.

---

## Hard prerequisites (blockers — resolve before any UI work)

### 1. OAuth scope — the app is currently read-only
The app is registered for read-only access. Every transfer/equip endpoint requires
the **`MoveEquipDestinyItems`** scope. Consequences:

- **Scopes are assigned at the bungie.net app registration, not per request.** The
  authorize URL (`AuthRepository._buildAuthorizeUrl`) sends only `client_id`,
  `response_type`, and `state` — no `scope` parameter, and Bungie ignores one if sent.
  So enabling writes is a registration change on bungie.net, not a code change to the
  authorize request. (`AppConfig.oauthScope` is a documentation-only constant; it is
  read nowhere in `lib/`.)
- **Every existing user must re-authenticate** — a token minted while the app was
  read-only cannot perform writes, because tokens carry the app's scopes as of when
  they were issued. Plan for a re-auth prompt ("New permissions needed to move
  items"), not a silent upgrade.
- This is a real, outward-facing capability change (moving a user's actual gear).
  Confirm the product intent before building (contract rule 1).

### 2. The API layer is GET-only
`BungieApi` has no POST helper — `_getResponse` is the only method, and `_mapDioError`
assumes GET semantics. A `_postResponse` (JSON body, same envelope-unwrap + error
mapping) must be added. Writes go to `POST /Destiny2/Actions/Items/...` and require
the `X-API-Key` header (already interceptor-supplied) plus the Bearer token.

### 3. Transfers need character + membership context we don't currently thread
Transfer/equip request bodies require: `itemReferenceHash`, `itemId` (instanceId),
`stackSize`, `characterId`, `membershipType`, and `transferToVault` (bool). Today:
- `membershipType` is resolved inside `InventoryRepository` (memberships service) but
  not exposed to the UI/action layer.
- Vault has no `characterId`; **you cannot transfer vault→vault or directly
  character A→character B.** Every cross-character move is **two hops**: source
  character → vault → destination character. The action layer must sequence these
  and fail-visibly if the second hop fails (item stranded in vault — rule 12).

### 4. Endpoint semantics (each a separate POST)
- **TransferItem** — move between a character and the vault (`transferToVault` true/false).
- **EquipItem** — equip an already-on-character item (drop onto the equipped slot).
- Postmaster pulls, and equipping something not on the target character, are **out of
  scope** for v1 (equip requires the item already be on that character).

### Instanced-only
Only instanced gear (weapons/armor with `itemInstanceId`) is draggable. The grid
already shows only equipment buckets, so this is naturally satisfied, but the drag
gesture must still guard `item.itemInstanceId != null`.

---

## Current-state facts that shape the design

- **Grid is an immutable snapshot** behind `inventoryGridProvider` (a `FutureProvider`
  returning `InventoryGrid`, whose `owners`/`itemsByBucket` are plain const lists).
  Nothing mutates it today; a move must either (a) invalidate and refetch, or (b)
  optimistically patch a mutable copy. See "State update strategy".
- **Layout is fixed-width columns** computed in `InventoryScreen` constants, rows per
  `EquipmentBucket`. Drop targets map cleanly onto existing widgets: `_CharacterCell`
  (equipped slot + 3-wide `Wrap`) and `_VaultCell` (`Wrap`).
- **Tiles** (`ItemTile`) are `ConsumerWidget`s that already handle tap (open detail) and
  render dimming/selection. Drag feedback can reuse the icon square.
- **The 3×3 rule**: each character holds **max 9 unequipped** items per bucket (a
  project invariant). A drop onto a full character bucket must be rejected up front,
  not attempted and bounced by Bungie.
- **Detail panel overlays the grid on the right** (`Stack` in `InventoryScreen`). Drag
  interactions must not conflict with the panel's pointer region.

---

## Architecture

Four layers, bottom-up. Keep deterministic decisions (validity, two-hop routing,
retry) in Dart, not scattered through widgets (rule 5).

### Layer 1 — API write methods (`bungie_api.dart`)
- Add `_postResponse(path, body)` mirroring `_getResponse` (envelope unwrap, ErrorCode
  check, dio-error mapping).
- `Future<void> transferItem({itemReferenceHash, itemId, stackSize=1, transferToVault,
  characterId, membershipType})`.
- `Future<void> equipItem({itemId, characterId, membershipType})`.
- Map known transfer error codes to typed `Failure`s with human messages (bucket full,
  item not found, wrong character), so the UI can surface why a move failed (rule 12).

### Layer 2 — Move service (`lib/data/repositories/item_transfer_repository.dart`)
Pure orchestration, unit-testable against a mocked `BungieApi`:
- `moveItem(item, fromOwnerId, toOwner)` → resolves the hop sequence:
  - character → vault: single TransferItem(`transferToVault: true`).
  - vault → character: single TransferItem(`transferToVault: false`, `characterId: dest`).
  - character A → character B: TransferItem(A→vault) **then** TransferItem(vault→B);
    if hop 2 fails, report "moved to vault, could not reach destination" (never claim
    success — rule 12).
- `equip(item, ownerId)` → EquipItem.
- Holds/receives `membershipType` (thread it out of `InventoryRepository`, or move
  membership resolution to a shared provider — flag as a small refactor, don't
  silently duplicate it — rule 8).

### Layer 3 — Validation (deterministic, pre-flight)
A pure `canDrop(item, targetOwner, targetBucket, {equipSlot})` returning an allow/deny
+ reason. Rules, all decidable locally from the current grid:
- item bucket must match target bucket (can't drop a helmet in the kinetic row).
- character bucket unequipped count < 9 (the 3×3 invariant).
- equip target: item must already be on that character (v1), and class-appropriate.
- deny dropping onto the item's current owner/slot (no-op).
This drives both the hover affordance (green/red target) and the guard before any POST.

### Layer 4 — UI (drag sources + drop targets)
- Wrap `ItemTile` in `Draggable<DestinyItem>` (or `LongPressDraggable` if we want tap
  and drag to coexist cleanly — tap already opens the detail panel, so a short drag
  threshold vs tap must be tuned). Feedback = the icon square at slight scale + shadow;
  `childWhenDragging` = dimmed placeholder.
- Wrap `_CharacterCell`'s grid, its equipped slot, and `_VaultCell` in
  `DragTarget<DestinyItem>`:
  - `onWillAcceptWithDetails` → `canDrop(...)` (drives highlight).
  - `onAcceptWithDetails` → dispatch to the move controller.
  - Equipped slot as its own DragTarget = the equip gesture.
- Highlight accepted targets (green outline) and rejected (red) during hover, using the
  validation reason.

### Layer 5 — State + controller (`inventory_provider.dart`)
- A `MoveController` (AsyncNotifier or Notifier) that: validates, calls the transfer
  repo, updates grid state, and exposes in-flight/error status for a snackbar.
- **State update strategy** — pick one (see below).

---

## State update strategy (decide explicitly)

The grid is currently immutable + refetched-on-invalidate. Two options:

**A. Invalidate-and-refetch after each move (simplest, safe).**
On success, `ref.invalidate(inventoryGridProvider)`. Pros: guaranteed-consistent with
Bungie; no local mutation logic. Cons: a full profile refetch per move (seconds of
latency, whole-grid fl*icker/spinner), poor for rapid multi-moves.

**B. Optimistic local patch + reconcile (DIM-like, more work).**
Make `InventoryGrid`/owners mutable (or rebuild a patched copy): move the item between
owner lists immediately, dispatch the POST, and on failure **roll back the patch and
show the error** (rule 12 — the rollback must be visible, not silent). Reconcile with a
debounced background refetch. Pros: instant, fluid. Cons: mutable-state complexity,
rollback correctness, the two-hop partial-failure case.

**Recommendation:** ship **A** first (correct, simple, unblocks the feature), then
upgrade the hot path to **B** once the write path is proven. Don't build B blind.

---

## Incremental delivery (checkpoints — rule 10)

1. **Scope + auth**: enable `MoveEquipDestinyItems` on the bungie.net app registration
   (not a code change to the authorize request), then re-auth so a fresh token is minted
   under it. Add the re-auth prompt flow. *No UI yet.* Gate: a token carries the write
   scope (a scripted single transfer is accepted, not rejected for scope).
2. **API write layer**: `_postResponse` + `transferItem`/`equipItem`, unit-tested with a
   mocked dio (success + each error code). Gate: a scripted single transfer succeeds
   against the live account (manual, one item).
3. **Move service + validation**: two-hop routing and `canDrop`, unit-tested. Gate:
   cross-character move works end-to-end via a temporary debug button (no drag yet).
4. **Drag UI (single-hop first)**: Draggable tiles + DragTargets for character↔vault,
   invalidate-refetch (strategy A), hover highlights, error snackbars. Gate: drag a
   vault item to a character and back, visibly.
5. **Equip-on-drop**: equipped-slot DragTarget → EquipItem.
6. **Cross-character (two-hop)** in the UI, with partial-failure messaging.
7. **(Optional) Optimistic updates** (strategy B) on the hot path.

Each step is independently shippable and leaves the app working.

---

## Testing

- **Unit — API**: `_postResponse` envelope/error mapping; `transferItem`/`equipItem`
  build correct bodies; error codes → typed failures.
- **Unit — move service**: hop sequencing (char→vault, vault→char, char→char two-hop),
  and the partial-failure path (hop 2 fails → correct "stranded in vault" outcome, not
  a false success). Behaviour, not "returned something" (rule 9).
- **Unit — validation**: `canDrop` matrix (bucket mismatch, full bucket / 3×3, self-drop,
  equip eligibility).
- **Widget**: Draggable emits the item; DragTarget accepts/rejects per validation;
  a successful drop triggers the controller; a failed move shows the error and (strategy
  B) rolls back.
- **Manual**: real account — single moves, rapid moves, offline mid-move, full-bucket
  rejection, equip.

---

## Risks

- **Read-only → write is a trust boundary.** Moving real gear; a bug can strand or
  misplace items. Fail-visible everywhere; never report a move that didn't complete
  (rule 12). Confirm intent before starting (rule 1).
- **Two-hop partial failure** is the nastiest correctness case — item in vault after a
  failed second hop. Must be surfaced with a clear recovery message.
- **Rate limits / throttling** on rapid drags — the controller should serialise moves,
  not fire concurrent POSTs for the same item.
- **Re-auth friction** for existing users; message it clearly.
- **Gesture conflict**: tap-to-open-detail vs drag-to-move on the same tile — tune the
  drag threshold / use LongPressDraggable so neither steals the other.
- **3×3 invariant**: enforce in `canDrop` so we reject locally instead of relying on a
  Bungie bounce.

---

## Recommendation

Feasible and a natural next step, but **not a UI-first task** — it's gated on the OAuth
scope change and a write-capable API layer. Sequence: scope/auth → write API →
move service + validation (proven via a debug button) → drag UI with refetch → equip →
two-hop → optional optimistic updates. Ship steps 1–4 as the first meaningful milestone
(single-hop drag works), then extend.
