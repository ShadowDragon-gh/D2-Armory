# Gear Preview — Implementation Guide

Two independent paths to a rendered weapon/armor preview **with shader applied**,
each a self-contained plan. Read the shared context first, then pick a path.

- **Path A — Embed a community 3D viewer** (light.gg / lowlines Model Viewer in a
  WebView). Days of work, gets shaders "for free", but online-only and dependent
  on a third party.
- **Path B — Native 3D rendering** from Bungie's gear-asset format. Weeks-to-months,
  fully offline and self-owned, but a large undertaking against an unofficial format.

Static screenshot preview (the manifest's per-item `screenshot` field, ornament-aware,
no shader) is deliberately **out of scope** here — it's a small feature tracked
separately. This doc is only about the *shaded 3D* ask.

---

## Shared context

### What the manifest already gives us
Verified against the live content DB in this project:

- **`DestinyInventoryItemDefinition.screenshot`** — a pre-rendered 1920×1080 JPG per
  weapon/armor and per ornament plug (3,680 ornament plugs carry one). Default colours
  only; **no shader variants exist as 2D assets.** This is why shaded preview *requires*
  3D rendering — there is no image to fetch.
- **Shader dye data** — a shader's `translationBlock.defaultDyes` is a list of
  `{channelHash, dyeHash}` pairs (confirmed: e.g. channel `662199250` → dye `749149797`).
  These are inputs to the model's material shading, not pixels.
- **Item dyes** — a weapon/armor def's `translationBlock` has `defaultDyes`,
  `lockedDyes`, `customDyes`, `weaponPatternHash`, and `arrangements` (geometry LODs).

### What the manifest does NOT contain (important)
- The current content DB has **no `DestinyGearAssetsDefinition` table** (verified).
  Geometry/texture data lives in a **separate mobile gear-asset database**, referenced
  from the manifest metadata response as **`mobileGearAssetDataBases`** (a list of
  `{version, path}`) plus a **`mobileGearCDN`** base for the actual asset containers.
  Path B must download and open that DB in addition to the content manifest.

### How this maps onto the existing app
- Config is via `--dart-define-from-file=env/dev.json` (`AppConfig`), **not** envied.
  Any new base URL / flag follows that pattern.
- Downloads go through `ManifestDownloader` (dio, `X-API-Key` header, unzip-single-entry).
  Reuse that shape for any new asset fetch.
- The manifest metadata is already fetched in `ManifestRepository.ensureLoaded()` via
  `_api.getManifest()`; `mobileGearAssetDataBases` / `mobileGearCDN` are siblings of the
  `mobileWorldContentPaths` we already read — no new endpoint needed to *discover* assets.
- The detail panel (`item_detail_panel.dart`) is the natural host. The equipped shader and
  ornament are already resolvable from the sockets we cache (see `_resolvePlugs` /
  `_ornamentIconPath`) — both paths need "which shader/ornament hash is equipped", which
  we can already produce.
- Platform is Windows desktop. That constrains plugin choices (WebView2 for Path A; the
  weak state of Flutter 3D for Path B).

### Success criteria (both paths)
1. Opening the detail panel for an equipped weapon/armor shows a 3D preview.
2. The preview reflects the **equipped ornament** and **equipped shader**.
3. Failure is visible and graceful — a clear "preview unavailable" state, never a hang or
   a crash (contract rule 12).
4. No regression to detail-panel open time when the preview is collapsed/lazy.

---

## Path A — Embed a community 3D viewer (WebView)

**Goal:** render the shaded model by loading an existing web viewer in an embedded browser,
pre-selecting the equipped item + shader + ornament.

**Effort:** ~2–4 days for a working spike; ~1 week to harden.
**Owns the renderer:** no (third party).
**Offline:** no.

### Dependencies & prerequisites
- `webview_windows` (WebView2 — requires the Evergreen WebView2 Runtime, present on
  current Win11; older machines need the bootstrapper). Add to `pubspec.yaml`.
- Decide the target viewer and **confirm its deep-link contract**:
  - **lowlines Destiny Model Viewer** (`lowlidev.com.au/destiny/meta/...`) — has URL-driven
    item selection; historically the most parameterisable.
  - **light.gg** item pages — embed a 3D preview but URL control over *shader selection* is
    not guaranteed.
  - Verify current URL params by hand before committing (see Step 1). This is the single
    biggest risk in Path A.

### Implementation steps
1. **Spike the deep link (do this before writing any code).**
   Manually construct a viewer URL for a known item hash and confirm you can drive:
   (a) which item, (b) which ornament, (c) which shader — via query params. Record the exact
   param names. **If shader can't be pre-selected via URL, Path A cannot meet success
   criterion #2** — stop and reassess. Time-box to half a day.
2. **URL builder** (`lib/data/remote/gear_preview_url.dart`): pure function
   `String buildPreviewUrl({required int itemHash, int? ornamentHash, int? shaderHash})`.
   Base host in `AppConfig` (from dart-define, so it's swappable). Unit-test it — pure input→output.
3. **Resolve equipped cosmetics.** Add a small resolver (reuse socket-scan logic already in
   `inventory_repository.dart`) returning `(itemHash, ornamentHash?, shaderHash?)` for a
   `DestinyItem`. The ornament path already exists; add the equipped-shader hash (the plug in
   the shader socket, category `shader`).
4. **WebView host widget** (`lib/presentation/widgets/gear_preview_web.dart`):
   - Lazy: only initialise the controller when the preview is expanded (button in the panel:
     "View in 3D"). Keeps panel-open cost at zero.
   - Loading, error, and offline states as explicit widgets. On controller/init failure or
     load timeout, show "3D preview unavailable" — never a blank pane.
   - Dispose the controller when the panel closes / item changes.
5. **Panel integration.** A collapsible section under the item header. Respect the existing
   overlay/animation structure — the WebView must live inside the panel's bounds and not leak
   pointer events to the grid behind it.
6. **CSP / navigation lock-down.** Restrict the WebView to the viewer's host; block popups and
   external navigation so a click inside can't wander off.

### Testing
- Unit: URL builder (item/ornament/shader permutations, null handling).
- Unit: equipped-cosmetics resolver (mocked sockets — same style as `item_detail_test.dart`).
- Manual: matrix of {no ornament, ornament} × {no shader, shader} × {weapon, armor}; offline
  behaviour (airplane mode → graceful message); WebView2-absent machine.

### Risks & mitigations
- **Deep-link contract changes / disappears** (third-party site). Mitigate: isolate all
  coupling in the URL builder + host widget; feature-flag the whole section so it can be
  hidden without touching the panel.
- **Terms of use / hotlinking.** Check the target site's terms before shipping; embedding
  someone's viewer in a desktop app is different from linking to it.
- **WebView2 runtime missing** on some Windows installs → detect and show a one-line install
  hint instead of a broken pane.
- **Online-only.** Accept as a known limitation of this path; document it in the UI.

### Definition of done
"View in 3D" opens an embedded viewer showing the item with the equipped ornament and shader;
offline / failure shows a clear message; nothing regresses when the section is collapsed.

---

## Path B — Native 3D rendering from gear assets

**Goal:** download Bungie's gear-asset data, parse the proprietary geometry/texture format,
and render the model in-app with item + shader dyes applied — fully offline, no third party.

**Effort:** weeks to months. This is a subsystem, not a feature.
**Owns the renderer:** yes.
**Offline:** yes (after asset download).

> Reality check (contract rule 1): Flutter has no first-class 3D engine, the gear format is
> undocumented/reverse-engineered (TGX containers), and Bungie can change it without notice.
> Community projects prove it's *possible* (spasm.js on web, Charm for extraction, lowlines'
> viewer) but none are Dart/Flutter-on-Windows. Treat this as an R&D project with staged
> go/no-go gates, not a linear build.

### Prerequisites / unknowns to resolve first (spike gate 0)
Before committing, time-box a spike to answer:
- Can we fetch and open the **mobile gear-asset DB** (`mobileGearAssetDataBases` → SQLite,
  same download shape as the content manifest) and read one item's gear-asset JSON?
- Can we pull the referenced **geometry/texture containers** from `mobileGearCDN` and identify
  the TGX/asset structure for a single simple weapon?
- Is there a Dart-viable rendering layer? (Options below — all immature on Windows.)

If any answer is "no / prohibitively hard", Path B stops here with findings documented.

### Architecture (layers)
1. **Gear-asset acquisition** (`lib/data/local/gear_asset_downloader.dart`,
   `gear_asset_repository.dart`): mirror `ManifestDownloader`/`ManifestRepository`. Download the
   gear-asset DB (versioned filename, same as `manifest_<v>.sqlite`), open with `sqlite3`, expose
   `getGearAsset(itemHash)`.
2. **Container fetch + cache**: download the geometry/texture blobs from `mobileGearCDN` on
   demand, cache to app-support dir. Fail-visible on missing assets.
3. **Format parsing** (`lib/domain/gear/tgx_parser.dart`): parse the gear-asset container into
   meshes (vertices, indices, UVs, normals) + texture references. This is the hardest,
   least-documented part; port logic from spasm.js / Charm as reference. Parser must be pure and
   heavily unit-tested against a checked-in fixture blob.
4. **Material / dye pipeline** (`lib/domain/gear/dye_pipeline.dart`): apply the item's
   `translationBlock` dyes and the **equipped shader's `defaultDyes`** (the `{channelHash,
   dyeHash}` data we confirmed exists) to the mesh materials. This is what makes shaders work —
   the whole point of Path B. Requires reverse-engineering Destiny's dye channel semantics
   (gearstack slots, primary/secondary/detail colours, wear/roughness maps).
5. **Renderer** (`lib/presentation/widgets/gear_preview_3d.dart`): draw the parsed, dyed mesh.
   Flutter options, all with caveats:
   - `flutter_gl` + a hand-written GL/WebGL layer — most control, most work.
   - `three_dart` / `three_js` Dart ports — higher level, maturity/perf risk on Windows.
   - `flutter_scene` (Impeller-based) — newest, promising, but early and API-unstable.
   Prototype one with a hardcoded cube→textured mesh before wiring real assets.
6. **Panel integration**: same collapsible "View in 3D" host as Path A, but pointing at the
   native renderer. Lazy-load; dispose GPU resources on close.

### Staged plan with go/no-go gates
- **Gate 0 — Data spike:** fetch gear-asset DB + one container from CDN. *No further work if
  assets are unreachable.*
- **Gate 1 — Parse spike:** turn one container into a renderable mesh in memory (dump vertex
  count / bounds). *No further work if the format can't be parsed.*
- **Gate 2 — Render spike:** display that mesh untextured, orbit camera, in a Flutter Windows
  window with an acceptable frame rate.
- **Gate 3 — Textures:** apply base textures.
- **Gate 4 — Dyes/shaders:** apply item + shader dye channels (the actual deliverable).
- **Gate 5 — Productionise:** caching, LOD selection via `arrangements`, error states,
  memory/GPU cleanup, ornament switching.

Each gate is a checkpoint (contract rule 10): summarise findings and confirm before proceeding.

### Testing
- Unit: gear-asset repo (mocked DB), TGX parser (fixture blob → known mesh stats), dye pipeline
  (channel/dye hashes → expected material params). Behaviour, not "returned something".
- Golden/manual: rendered output for a known item with/without a known shader.
- Perf: frame time budget; memory after opening/closing many previews (no leak).

### Risks & mitigations
- **Undocumented, changeable format.** Isolate all format knowledge in the parser; version-guard
  the gear-asset DB like the content DB so a Bungie change fails loudly at parse, not silently.
- **Asset volume.** Containers are large; download lazily per item, cache, and cap cache size.
- **Flutter 3D immaturity on Windows.** The renderer choice is the biggest technical risk —
  resolve at Gate 2 before investing in parsing polish.
- **Scope.** This can balloon. The gates exist precisely so it can be abandoned cheaply with
  documented findings at any point.

### Definition of done
The detail panel renders the actual item model with the equipped ornament and shader dyes
applied, offline, at an acceptable frame rate, with visible failure states and no GPU/memory leak.

---

## Recommendation

If shaded preview is wanted **soon** and an external dependency is acceptable, do **Path A**
behind a feature flag — validate the deep-link contract (Step 1) before anything else, because
that single unknown decides whether Path A is even viable.

**Path B** is the only route to an offline, self-owned, fully-controlled renderer, but it is an
R&D subsystem. Only start it past **Gate 0**, and only if owning the renderer is a real product
goal rather than a nice-to-have.

Both are independent — Path A can ship first and be replaced by Path B later without rework of
the panel integration (the collapsible host widget is shared; only its body swaps).
