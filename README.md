# D2 Armory

> A Windows desktop app for managing your Destiny 2 gear with live game data —
> browse your inventory, move and equip items across characters and the vault,
> change weapon perks and mods in-game, and explore a full database of every
> weapon and armor piece.

D2 Armory connects to your own Bungie.net account. It is a Windows-only desktop
application built with Flutter.

---

## What it does

- **Inventory** — See all your characters and your vault side by side in a
  grid, one column per character plus a vault column, with rows for each gear
  slot. Character headers show the emblem, name, and power level.
  - **Drag items to move them** between characters and the vault. Drops are
    validated as you hover (valid = green, invalid = red), and the move is
    written back to the game.
  - **Drag an item onto a character's equipped slot to equip it** — including
    pulling a copy from another character or the vault, which moves it over and
    equips it in one action.
  - **Tap an item** to open its detail view: element and power, full stat bars,
    and its Frame / Traits / Mods / Masterwork / Catalyst sections.
  - **Change a weapon's perks and mods in-game.** When you open an item you own,
    a "This Roll" view lets you click a different perk column option — or pick a
    mod — to apply it to that weapon on your account. Changes apply optimistically
    and roll back if Bungie rejects them. (Items must be on a character, not in
    the vault, to edit.)
  - **Search and filter** with autocomplete and query syntax like `is:exotic`,
    `perk:rampage`, `ammo:heavy`, `frame:"..."`. Non-matching items dim out.
  - **Show/Hide cosmetics** toggles ornaments, and **Refresh** re-fetches your
    inventory. The grid also stays current on its own via a background poll.

- **Database** — Browse every weapon and armor piece in the game, straight from
  the local game data (no account interaction needed here).
  - Toggle between **Weapons** and **Armor**, and use the same search/filter
    syntax as the inventory.
  - Open any item for a detail modal with its screenshot, flavor text, clickable
    facet chips (element, breaker, type, ammo, frame, rarity) that filter the
    list, a stat block, the intrinsic frame, and a **full perk grid showing every
    possible roll**. Click perks to preview how they change the item's stats.

- **Loadouts** — *Coming soon.* This tab is currently a placeholder; loadout
  building and saving are not yet implemented.

---

## Download & use (for players)

You do **not** need Flutter, a Bungie developer account, or any setup — just a
Windows PC and your own Destiny 2 / Bungie.net account.

1. **Download** the latest release zip from the
   [Releases page](../../releases) and extract the folder anywhere you like
   (Desktop, Documents — wherever).
2. **Run** `destiny2_loadout_planner.exe` from inside the extracted folder.
3. **First launch — two one-time prompts.** Both are expected and safe; see
   [doc/release_note.md](doc/release_note.md) for the full explanation:
   - **"Windows protected your PC" (SmartScreen)** — click **More info →
     Run anyway.** The app isn't signed with a paid certificate, so Windows
     doesn't recognize the publisher yet. This is not a virus warning.
   - **Browser certificate warning** on first sign-in — click **Advanced →
     Proceed to 127.0.0.1.** Sign-in redirects through a local `127.0.0.1`
     address that uses a self-signed certificate; nothing leaves your machine at
     that step.
4. **Sign in with Bungie.net.** Your browser opens Bungie's login page; after you
   approve access it hands control back to the app. You'll stay signed in and
   won't need to re-authenticate for a long while.
5. On first launch the app downloads the current Destiny game data (a
   several-tens-of-MB file) and shows a progress bar. This happens once per game
   update, not every launch.

**Updating:** the app updates itself. When a newer release is available, an
update icon appears in the top bar; clicking it and choosing **Update now**
downloads the new version, closes the app, applies it, and reopens. (If you ever
need to, you can still update manually by downloading the newer release zip and
replacing the folder.)

There is no installer — the app is a self-contained folder you can move or delete
freely. It stores its game data and your sign-in in your Windows user profile,
not in the folder.

---

## Building from source (for developers)

### Prerequisites

- Flutter SDK (Dart SDK `^3.12.2`, per [pubspec.yaml](pubspec.yaml))
- A Windows machine with desktop build support enabled
  (`flutter config --enable-windows-desktop`)
- A [Bungie.net application registration](https://www.bungie.net/en/Application)
  (see below)

### 1. Register a Bungie application

At [bungie.net/en/Application](https://www.bungie.net/en/Application), create an
app and set:

| Field | Value |
|---|---|
| **Redirect URL** | `https://127.0.0.1:7355/callback` |
| **OAuth Client Type** | `Confidential` (issues a refresh token → stays signed in) or `Public` (no secret, but re-auth ~hourly) |
| **Scopes** | Enable **Read** *and* **Move or Equip Destiny Items** on the app registration |

Enable both scopes on the portal registration — the app grants whatever the
registration allows (it does not request scopes per sign-in), and the inventory
move / equip / perk-edit features need the write scope, not just read.

Note your **API Key**, **OAuth client_id**, and — for a Confidential client —
your **OAuth client_secret**. The app authenticates the loopback OAuth callback
on `127.0.0.1:7355`, so the Redirect URL above must match exactly.

> The **client type** decides how often the user re-authenticates. Confidential
> clients receive a refresh token, so the app silently renews access and rarely
> re-prompts; Public clients get no refresh token and must sign in again roughly
> hourly.

### 2. Provide credentials

Credentials are passed at build/run time via `--dart-define-from-file` and read
through `String.fromEnvironment` in
[app_config.dart](lib/core/config/app_config.dart) — there is no `.env` file.

Copy the example and fill it in:

```
cp env/dev.example.json env/dev.json
```

```json
{
  "BUNGIE_API_KEY": "your_api_key",
  "BUNGIE_CLIENT_ID": "your_client_id",
  "BUNGIE_CLIENT_SECRET": "your_client_secret_or_empty_for_public"
}
```

`env/*.json` files are gitignored. Leaving `BUNGIE_CLIENT_SECRET` empty makes the
app behave as a Public client; providing it makes it Confidential.

### 3. Run

```
flutter pub get
flutter run -d windows --dart-define-from-file=env/dev.json
```

### 4. Build a release

```
flutter build windows --release --dart-define-from-file=env/release.json
```

The output is a folder at `build/windows/x64/runner/Release/` containing the exe,
its DLLs, and a `data/` subfolder — they must ship together (it is not a single
file). To package a release for distribution, run
[tool/package_release.ps1](tool/package_release.ps1), which builds, zips the
folder's contents, and prints the `gh release` command (with the checksum the
in-app updater verifies against).

---

## How it works

- **Platform:** Flutter, Windows desktop only. The native title bar is hidden in
  favor of a custom slim title bar; minimum window size is 900×600
  ([main.dart](lib/main.dart)).
- **Authentication:** OAuth 2.0 against Bungie.net. Because Bungie requires an
  HTTPS redirect, the app runs a tiny local HTTPS server on `127.0.0.1:7355`
  (serving a bundled self-signed cert) to catch the OAuth callback, and opens the
  system browser via `url_launcher`
  ([auth_repository.dart](lib/data/repositories/auth_repository.dart)). Tokens are
  stored in the Windows Credential Locker via `flutter_secure_storage`.
- **Game data (manifest):** The Destiny manifest is a SQLite database Bungie
  ships as a zip. The app downloads it with `dio`, unzips it with `archive`, and
  queries it read-only via the `sqlite3` package directly
  ([manifest_database.dart](lib/data/local/manifest_database.dart)). It is
  re-downloaded only when Bungie publishes a new version.
- **State management:** `flutter_riverpod`.

### Tech stack

| Purpose | Package |
|---|---|
| State management | `flutter_riverpod` |
| Bungie API HTTP | `dio` |
| Token storage | `flutter_secure_storage` |
| Manifest database | `sqlite3` (queried directly) |
| Manifest unzip | `archive` |
| Storage paths | `path_provider` |
| Desktop window | `window_manager` |
| Open browser for OAuth | `url_launcher` |
| Icons / SVG | `cached_network_image`, `flutter_cache_manager`, `flutter_svg` |
| Logging | `logger` |

---

## Project layout

```
lib/
├── core/config/            # AppConfig: endpoints, OAuth redirect, dart-define secrets
├── data/
│   ├── local/              # manifest SQLite (sqlite3), token storage
│   └── repositories/       # auth, inventory, manifest, item transfer
├── domain/models/          # plain Dart models (oauth_tokens, etc.)
└── presentation/
    ├── providers/          # Riverpod providers
    └── screens/            # auth, inventory, database, app shell, manifest loading
env/                        # dev.json / release.json (gitignored), *.example.json
doc/                        # implementation notes and release_note.md
tool/                       # package_release.ps1 (build + package a release)
windows/                    # Windows runner (the only platform target)
```

---

## Useful resources

| Resource | URL |
|---|---|
| Bungie API docs | https://bungie-net.github.io |
| Bungie Developer Portal | https://www.bungie.net/en/Application |
| Bungie API GitHub | https://github.com/Bungie-net/api |
| DIM (open-source reference app) | https://github.com/DestinyItemManager/DIM |
| Riverpod docs | https://riverpod.dev |
