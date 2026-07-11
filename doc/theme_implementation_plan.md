# D2 Armoury Theme — Implementation Plan

Adopt the brand system defined in `doc/design/d2-armoury-brand-handover.html` — the
"D2 Armoury" steel-and-bronze tactical dark theme — as the app's design system:
color tokens, typography, radii, shadows, and logo assets, replacing today's
seeded-indigo Material theme and the ~80 hardcoded color literals scattered
across the presentation layer.

Grounded in this codebase: today there is **no design-system layer at all**. The
only shared theme is `ColorScheme.fromSeed(seedColor: 0xFF5C6BC0, brightness: dark)`
in `main.dart`; everything else is inline. That is actually good news for this
migration — there is no legacy token system to fight, only literals to replace.

---

## What the handover defines (source of truth)

`doc/design/d2-armoury-brand-handover.html`, tokens in its `:root` block:

- **Surfaces** (elevation ramp): `surface-0` #0D1013 → `surface-4` #2E3742 (5 steps)
- **Borders**: `border` #2A323B, `border-strong` #3A4552, `border-stronger` #5A6672
- **Text**: primary #ECEFF2, secondary #8A95A1, muted #5A6672, disabled #3A4552
- **Accent ("vault bronze")**: 50 #F7E9D6, 200 #E0A355 (hover), 500 #C98A3C (brand
  primary), 600 #B3742C (pressed), 800 #6B4419, on-accent #1C130A
- **Semantic**: success #4CAF6D, danger #D1453B, warning #D1A13C, info #4A90C9,
  each with a `-bg` tint surface
- **Rarity** (optional set): common #8A95A1, uncommon #4CAF6D, rare #4A90C9,
  legendary #A565D1, exotic #D1A13C
- **Typography**: display `Rajdhani`/`Oswald`, body `Inter`/`Barlow`, mono
  `JetBrains Mono`
- **Radius**: sm 4 / md 8 / lg 12; **Shadows**: sm/md/lg black at 0.4–0.5 alpha
- **Logos**: six SVGs in `doc/design/` (full lockup, icon, wordmark × solid/transparent).
  Icon-only mark is the designated app icon / favicon (reads to ~32px).

## Current state (verified inventory)

- **Theme**: single `ThemeData` in `main.dart:38-43`, seeded indigo, no `textTheme`,
  no `ThemeExtension`, no component themes.
- **Hardcoded colors**: ~80 usages across 12 files. Screens mix `colorScheme.*`
  tokens with literals. Worst offenders: `database_detail_modal.dart` (~20),
  `item_tile.dart` (~13), `inventory_screen.dart` (~9), `destiny_enums.dart` (~10).
- **Cross-file duplicates** (highest-value token targets):
  - `0xFFE5C15B` masterwork/enhanced gold — 5 independent `static const` copies
    (`item_tile.dart:24`, `item_detail_panel.dart:692`,
    `database_detail_modal.dart:361/647/877`) plus the exotic label color in
    `destiny_enums.dart:109`.
  - `0xFFB84C43` stat-penalty red — 3 copies (`item_detail_panel.dart:354`,
    `database_detail_modal.dart:362/648`).
  - Three near-black chrome surfaces with no shared source: `0xFF14151A` (title
    bar), `0xEE111318` (tile tooltip), `0xF01A1C22` (perk tooltip).
  - `Colors.black26` image placeholder and `Colors.white24` icon border repeated
    in 4 files; `Colors.amber` for power level in 3 places.
- **Domain color maps** (already centralized, in `lib/core/destiny/`):
  `DestinyEnums.rarityColor()`/`rarityLabelColor()` (`destiny_enums.dart:93-111`)
  and `DamageType.color()` (`destiny_buckets.dart:68-76`).
- **Typography**: no custom fonts anywhere; default Roboto. ~121 inline `TextStyle`
  usages; the uppercase "section label" style is independently defined 3×
  (`item_detail_panel.dart:663`, `database_detail_modal.dart:987` and inline at 775).
- **Branding surfaces**: all code-drawn Material icons (`Icons.shield_moon_outlined`
  in the title bar, `Icons.shield_outlined` on the login screen). Windows app icon
  is the stock Flutter `windows/runner/resources/app_icon.ico`. No bundled image
  assets at all — `flutter_svg` is already a dependency (used for CDN icons).
- **Theme-clean already** (use only `colorScheme` tokens — they restyle for free once
  the scheme changes): `stub_page.dart`, `login_screen.dart`,
  `manifest_loading_screen.dart`.
- **Dead code**: `home_screen.dart` + `character_card.dart` are orphaned (never
  reached from `root_screen`/`app_shell`). Resolve before theming — don't migrate
  dead surfaces.

---

## Decisions (confirmed 2026-07-11)

These are the three places where the handover and the existing code disagree.
All three were decided per the proposals below: **D1 keep in-game rarity
colors, D2 keep masterwork gold as its own token, D3 rename user-facing
strings to "D2 Armoury".**

### D1. Rarity colors: handover tokens vs in-game-derived colors
The handover's rarity set (common #8A95A1 … exotic #D1A13C) is deliberately
generic and tuned to the steel/bronze palette. The existing
`DestinyEnums.rarityColor()` set (#C3BCB4 / #5076A3 / #522F65 / #CEAE33 + lighter
label variants) approximates Bungie's actual in-game tier colors, which Destiny
players recognize instantly on item tiles.

**Proposed**: keep the existing in-game-derived rarity colors for item displays
(tiles, accent bars, tier labels) — recognizability is a feature in a loadout
tool — and do **not** adopt the handover rarity tokens for gear. Record the
handover set in the palette file as unused-but-documented, in case the call is
later reversed. If the user prefers full brand consistency over in-game fidelity,
adopt the handover set everywhere instead; either is fine, but pick one.

### D2. Masterwork gold vs brand bronze
Masterwork/enhanced gold `0xFFE5C15B` sits close to accent-500 #C98A3C and
warning/exotic #D1A13C. Collapsing it into the accent would make masterworked
gear look interactive/branded.

**Proposed**: keep `0xFFE5C15B` as a distinct **domain** token
(`masterworkGold`), not part of the brand accent ramp. Bronze = interactive/brand;
gold = game meaning. They must stay visually distinguishable.

### D3. App name: "Destiny 2 Loadout Planner" vs "D2 Armoury"
The brand is "D2 Armoury"; the app title (MaterialApp title, title-bar text,
`Runner.rc` product strings, README) says "Destiny 2 Loadout Planner".

**Proposed**: rename user-facing strings to "D2 Armoury" (keep the pubspec package
name `destiny2_loadout_planner` — renaming the Dart package is churn with no user
value). If the rename is not wanted yet, Phase 5 shrinks to just the icon/logo swap.

---

## Architecture: how CSS tokens map to Flutter

New directory `lib/presentation/theme/` with three files. No new dependencies —
fonts are bundled assets, logos render with the existing `flutter_svg`.

### `armoury_palette.dart` — raw token constants
Private-ish constants mirroring the handover 1:1 (same names, same hexes), so the
handover HTML stays diff-able against this file. Includes the domain colors that
the handover doesn't own (masterwork gold, penalty red — per D2) so every literal
in the app has exactly one home.

### `armoury_theme_extension.dart` — `ArmouryColors extends ThemeExtension<ArmouryColors>`
For every token that has **no Material `ColorScheme` slot**:
- `borderStronger` (#5A6672)
- `textMuted` (#5A6672), `textDisabled` (#3A4552)
- `accent50`, `accent200` (hover), `accent600` (pressed), `accent800`
- `success`/`successBg`, `warning`/`warningBg`, `info`/`infoBg`
  (danger maps to `colorScheme.error`, so it is *not* duplicated here)
- `masterworkGold`, `statPenaltyRed` (domain, per D2)
- `tooltipSurface` (surface-3 at high alpha — replaces the three ad-hoc
  near-black chrome hexes)

Accessed as `Theme.of(context).extension<ArmouryColors>()!`. Since the app is
dark-only, `lerp` can be a simple `this`-return; still implement it properly
(trivial `Color.lerp` per field) so a future light theme doesn't require rework.

Radius and shadows are compile-time constants, not theme state:
`ArmouryRadius.sm/md/lg` (4/8/12) and `ArmouryShadows.sm/md/lg` as
`List<BoxShadow>` matching the handover's three shadow levels.

### `app_theme.dart` — builds the `ThemeData`
Replaces `ColorScheme.fromSeed` with an **explicit** dark `ColorScheme`. The
handover's 5-step surface ramp maps cleanly onto Material 3's surface containers:

| Handover token | ColorScheme slot |
|---|---|
| surface-0 #0D1013 | `surfaceContainerLowest` (also `scaffoldBackgroundColor` stays surface-1; surface-0 is the window-frame/page canvas) |
| surface-1 #12161B | `surface` |
| surface-2 #1C232B | `surfaceContainer` / `surfaceContainerLow` |
| surface-3 #232B34 | `surfaceContainerHigh` |
| surface-4 #2E3742 | `surfaceContainerHighest` |
| accent-500 #C98A3C | `primary` |
| on-accent #1C130A | `onPrimary` |
| accent-800 #6B4419 | `primaryContainer` (with `onPrimaryContainer` = accent-50 #F7E9D6) |
| text-primary #ECEFF2 | `onSurface` |
| text-secondary #8A95A1 | `onSurfaceVariant` |
| border #2A323B | `outlineVariant` (hairline dividers) |
| border-strong #3A4552 | `outline` (emphasized borders) |
| danger #D1453B / danger-bg #2B1C1C | `error` / `errorContainer` |
| info #4A90C9 | `tertiary` (existing screens already use `tertiary` for info-ish accents) |
| text-secondary steel | `secondary` |

This mapping is why `stub_page.dart`, `login_screen.dart`, and
`manifest_loading_screen.dart` need **zero edits** — they already consume these
slots.

Component themes set once so per-widget styling shrinks:
- `textTheme` (see Typography below)
- `appBarTheme` (surface-1 bg, display-font titles), `cardTheme`
  (surface-2, radius-lg, border hairline), `dialogTheme` (surface-3, radius-lg,
  shadow-lg), `tooltipTheme` (tooltipSurface, radius-sm, border)
- `filledButtonTheme`/`textButtonTheme` with `WidgetStateProperty` overlays:
  hover → accent-200, pressed → accent-600 (the handover's interaction states)
- `inputDecorationTheme` for the search bar (surface-2 fill, border/border-strong
  focus ring in accent-500), `dividerTheme` (`outlineVariant`),
  `scrollbarTheme`, `snackBarTheme`

### Typography
Bundle three OFL-licensed Google Fonts under `assets/fonts/` (subset of weights,
not whole families) and register in `pubspec.yaml`:
- **Rajdhani** 500/600/700 — display: `headlineSmall`, `titleLarge`, `titleMedium`,
  tab labels, item names, stat numbers, with the letter-spacing the handover shows
- **Inter** 400/500/600 — body: `bodyLarge/Medium/Small`, `labelLarge`
- **JetBrains Mono** 400/700 — stat tables / numeric columns (exposed as a
  `TextStyle` constant, not a whole TextTheme slot)

Pick **Rajdhani + Inter** (the handover's first choices) — do not also ship
Oswald/Barlow fallbacks; they're alternatives, not additions.

Consolidate the 3× duplicated uppercase section-label style into one
`labelSmall` definition (11px, w700, letterSpacing 0.8, `onSurfaceVariant`) and
delete the private `_SectionTitle`/`_SectionLabel` copies in favor of it (or a
single shared widget if the padding is also common — decide at implementation
against rule 2, simplest wins).

---

## Phased implementation

Each phase compiles, passes `flutter analyze` + existing tests, and is visually
checked by running the app before the next begins (checkpoint per phase).

### Phase 1 — Token foundation
1. Add `assets/fonts/` (Rajdhani, Inter, JetBrains Mono; OFL licenses committed
   alongside), register fonts + `assets/branding/` in `pubspec.yaml`.
2. Create `lib/presentation/theme/` (`armoury_palette.dart`,
   `armoury_theme_extension.dart`, `app_theme.dart`) per the mapping above.
3. Wire `theme: buildArmouryTheme()` in `main.dart`, registering the extension.

**Checkpoint**: app runs; every theme-token-consuming screen (login, stubs,
manifest loading, most chrome) already shows steel/bronze. Hardcoded surfaces
still look old — expected.

### Phase 2 — App chrome
1. `window_title_bar.dart`: bg `0xFF14151A` → surface-0; hover overlays from
   tokens (keep the Windows-convention red close-button hover `0xFFC42B1C` — it's
   platform UX, not brand); title text in display font.
2. `app_shell.dart`: tab styling (active tab = accent-500, display font,
   letter-spacing), action icons, shell background surface-1.
3. `search_bar_field.dart`: swap `Material(elevation: 6)` overlay to surface-3 +
   `ArmouryShadows.md` + border; suggestion highlight from accent tokens.

**Checkpoint**: shell, tabs, title bar, search all on-brand.

### Phase 3 — Inventory surfaces
1. `item_tile.dart`: `_masterwork` → `ArmouryColors.masterworkGold`; tooltip
   literals → `tooltipSurface`/outline/onSurface; selection highlight
   `0xFF7AB8FF` → accent-200 (verify it still reads as "selected" against
   masterwork gold — if too close, use `borderStronger` + accent glow);
   placeholder/border idioms → shared tokens; radius literals → `ArmouryRadius`.
2. `inventory_screen.dart`: `Colors.white10/12` dividers → `outlineVariant`;
   `Colors.amber` power + `_PowerDiamond` → masterworkGold (power/light is the
   same gold family in-game — one token, per D2).
3. `item_detail_panel.dart`: `_enhancedGold`/`_reducedRed` → extension tokens;
   recoil gauge track `0xFF333333` → surface-4; scrims standardized.

**Checkpoint**: inventory grid, tooltips, and detail panel fully tokenized;
side-by-side sanity check that masterwork/exotic/selection states remain
distinguishable.

### Phase 4 — Database surfaces
1. `database_screen.dart`: icon borders, placeholders, selected-row highlight →
   tokens.
2. `database_detail_modal.dart`: the ~20 literals — `_gold`/`_red`/`_enhancedGold`
   copies → extension tokens; perk tooltip `0xF01A1C22` → tooltipSurface; section
   labels → shared style; radii/shadows → constants.
3. Per D1 decision: rarity colors stay in `DestinyEnums` (single source, callers
   unchanged) or move to the palette — either way there must be exactly **one**
   rarity source when this phase ends. `DamageType.color()` element colors stay
   as-is (in-game accurate, already centralized).

**Checkpoint**: both heavy screens tokenized. Grep gate (below) passes for
`lib/presentation/`.

### Phase 5 — Branding assets
1. Copy the transparent logo SVGs from `doc/design/` into `assets/branding/`
   (icon + full lockup + wordmark; solid-bg variants stay in doc/ only).
2. `window_title_bar.dart`: `Icons.shield_moon_outlined` → `logo-icon-transparent.svg`
   via `flutter_svg` (~20px — verify legibility; the handover rates it to ~32px,
   so check at title-bar size and keep the Material icon if it muddies).
3. `login_screen.dart`: `Icons.shield_outlined` → full lockup (transparent) at a
   size that fits the card.
4. Regenerate `windows/runner/resources/app_icon.ico` from `logo-icon-bg.svg`
   (16/32/48/256 px layers — ImageMagick: render PNGs at each size, then
   `magick ... app_icon.ico`; one-off, done locally, commit the .ico).
5. Per D3: update `MaterialApp.title`, title-bar text, and `Runner.rc`
   product/file description strings to "D2 Armoury".

**Checkpoint**: taskbar icon, title bar, and login screen carry the brand.

### Phase 6 — Cleanup and verification gate
1. Resolve the dead code: delete `home_screen.dart` + `character_card.dart`
   (orphaned — confirm nothing imports them at time of deletion) or explicitly
   defer with a note; do not theme them.
2. **Grep gate** — after this phase these must hold, enforced by inspection (or a
   trivial test/script if desired):
   - No `Color(0x` literals in `lib/presentation/` outside `lib/presentation/theme/`.
   - No `Colors.amber`, `Colors.white10/12/24/70`, `Colors.black26/54/87` in
     `lib/presentation/` outside the theme dir (pure-black scrim gradients over
     CDN emblem images may stay if declared as a named token, e.g. `emblemScrim`).
   - `lib/core/destiny/` retains only the domain maps decided in D1/D2.
   - Zero inline `fontFamily:` strings — fonts come from the TextTheme.
3. `flutter analyze` clean; `flutter test` green; run the app and click through
   login → manifest load → all three tabs → item detail → database modal.

---

## Success criteria

- The app visually matches the handover: surface ramp, bronze accent with correct
  hover/pressed states, Rajdhani/Inter/JetBrains Mono type, radius and shadow
  scale, logo in title bar + login + app icon.
- Exactly one source of truth per color: brand tokens in
  `lib/presentation/theme/`, domain colors (rarity, element, masterwork) in their
  single decided home. The five copies of gold and three copies of red are gone.
- The grep gate in Phase 6 passes; `flutter analyze` and existing tests pass.
- Game-meaning colors (rarity tiers, element types, masterwork gold) remain
  visually distinct from brand/interactive bronze — verified by eye on the
  inventory grid with a masterworked exotic selected.

## Explicitly out of scope

- Light theme (dark-mode-first per the handover; the `ThemeExtension` `lerp` is
  implemented so one can be added later without rework).
- Re-theming Bungie CDN content (item icons, emblems, screenshots render as-is).
- Renaming the Dart package / repo (D3 covers user-facing strings only).
- New screens (Loadouts tab remains a stub; it inherits the theme via
  `stub_page.dart` for free).
