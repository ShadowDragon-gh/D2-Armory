# Destiny 2 Loadout Planner — Flutter Project Handover

> A Flutter application that connects to the Bungie API to let players browse, build, and save Destiny 2 loadouts with accurate, live game data.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Bungie API Setup](#bungie-api-setup)
4. [Tech Stack](#tech-stack)
5. [Project Architecture](#project-architecture)
6. [Directory Structure](#directory-structure)
7. [Key Implementation Areas](#key-implementation-areas)
8. [Environment Configuration](#environment-configuration)
9. [Getting Started](#getting-started)
10. [API Quick Reference](#api-quick-reference)
11. [Known Gotchas & Tips](#known-gotchas--tips)
12. [Useful Resources](#useful-resources)

---

## Project Overview

This app allows Destiny 2 players to:

- **Authenticate** with their Bungie.net account via OAuth 2.0
- **Browse** their in-game inventory (weapons, armor, mods)
- **Build** loadouts by combining weapons, armor, abilities, and mods
- **Save** loadouts locally and optionally sync them to Bungie's in-game loadout system
- **Inspect** perk rolls, stat breakdowns, and mod compatibility

The app targets **iOS and Android** from a single Flutter codebase, with potential for desktop support.

---

## Prerequisites

Before starting development, ensure you have:

- [ ] Flutter SDK installed (`flutter --version` — target Flutter 3.27+)
- [ ] Dart SDK 3.0+
- [ ] Android Studio or Xcode (for device targets)
- [ ] A [Bungie.net developer account](https://www.bungie.net/en/Application)
- [ ] A registered Bungie application (see below)
- [ ] Git

---

## Bungie API Setup

### 1. Register Your Application

Go to [bungie.net/en/Application](https://www.bungie.net/en/Application) and create a new app with these settings:

| Field | Value |
|---|---|
| **OAuth Client Type** | `Public` (for mobile) |
| **Redirect URL** | `destiny2loadout://callback` (or your custom scheme) |
| **Scope** | `ReadDestinyInventoryAndVault` |
| **Origin Header** | Your app's bundle ID or origin |

After creating the app, note your:
- **API Key** — included in every API request as `X-API-Key`
- **OAuth Client ID** — used in the OAuth flow
- **OAuth Client Secret** — only needed for Confidential clients (not required for Public mobile apps)

### 2. OAuth Endpoints

| Endpoint | URL |
|---|---|
| Authorization | `https://www.bungie.net/en/oauth/authorize` |
| Token | `https://www.bungie.net/platform/app/oauth/token/` |
| Refresh | `https://www.bungie.net/Platform/App/OAuth/token/` |

### 3. Required OAuth Scope

```
ReadDestinyInventoryAndVault
```

This single scope covers all read operations: inventory, vault, vendors, milestones, progression, and loadouts.

> ⚠️ **Important:** Bungie blocks WebView-based OAuth flows. On Android use Chrome Custom Tabs, on iOS use SFSafariViewController. The `flutter_web_auth_2` package handles both automatically.

---

## Tech Stack

### Core

| Purpose | Package | Notes |
|---|---|---|
| Authentication | `flutter_web_auth_2` | System browser OAuth, handles redirect capture |
| Secure token storage | `flutter_secure_storage` | Stores access + refresh tokens in keychain/keystore |
| HTTP client | `dio` | Interceptors for API key header, rate limit handling, retries |
| State management | `riverpod` (v3) | Async-first, compile-time safe, Flutter Favorite |
| Local manifest DB | `drift` | Type-safe SQLite ORM for the Destiny manifest |
| Key-value cache | `hive_ce` | Fast NoSQL store for preferences, saved loadouts |
| Code generation | `freezed` + `json_serializable` | Immutable models for all API response types |
| Code generation runner | `build_runner` | Runs freezed and json_serializable generators |
| Image caching | `cached_network_image` | Caches Bungie-hosted item icons |
| SVG support | `flutter_svg` | Destiny UI elements and class icons |

### Dev / Tooling

| Purpose | Package |
|---|---|
| Linting | `flutter_lints` |
| Testing | `mocktail` + `flutter_test` |
| Logging | `logger` |
| Environment vars | `envied` (compile-time safe env variables) |

---

## Project Architecture

This project follows **Clean Architecture + MVVM**, separating concerns into three layers:

```
Data Layer
  └── Remote (Bungie API via Dio)
  └── Local (Drift manifest DB + Hive cache)
  └── Repositories (combine remote + local, expose clean interfaces)

Domain Layer
  └── Models (Freezed immutable entities: Weapon, Armor, Perk, Loadout...)
  └── Use Cases (BuildLoadout, FetchInventory, SyncLoadout...)

Presentation Layer
  └── Riverpod Providers (AsyncNotifiers wrapping use cases)
  └── Screens + Widgets (pure UI, reads from providers)
```

**Data flows in one direction.** Widgets never call the API directly — they observe providers. Providers call use cases. Use cases call repositories. Repositories call the API or local DB.

---

## Directory Structure

```
lib/
├── core/
│   ├── config/
│   │   └── app_config.dart          # API base URL, manifest URL, etc.
│   ├── network/
│   │   ├── dio_client.dart          # Dio setup with interceptors
│   │   └── interceptors/
│   │       ├── api_key_interceptor.dart
│   │       └── auth_interceptor.dart  # Attaches Bearer token, handles 401
│   └── errors/
│       └── failures.dart            # Typed failure classes
│
├── data/
│   ├── remote/
│   │   ├── bungie_api.dart          # All Bungie endpoint calls
│   │   └── dto/                     # Raw JSON response objects (json_serializable)
│   │       ├── profile_response.dart
│   │       ├── item_instance.dart
│   │       └── manifest_response.dart
│   ├── local/
│   │   ├── manifest_database.dart   # Drift DB schema + queries
│   │   ├── manifest_dao.dart        # Data Access Object for item definitions
│   │   └── hive_service.dart        # Hive boxes for auth tokens + saved loadouts
│   └── repositories/
│       ├── auth_repository.dart
│       ├── inventory_repository.dart
│       ├── manifest_repository.dart
│       └── loadout_repository.dart
│
├── domain/
│   ├── models/                      # Freezed immutable models
│   │   ├── weapon.dart
│   │   ├── armor.dart
│   │   ├── perk.dart
│   │   ├── mod.dart
│   │   ├── loadout.dart
│   │   └── character.dart
│   └── usecases/
│       ├── fetch_inventory.dart
│       ├── build_loadout.dart
│       ├── sync_loadout_to_game.dart
│       └── refresh_manifest.dart
│
├── presentation/
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── inventory_provider.dart
│   │   ├── loadout_provider.dart
│   │   └── manifest_provider.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   └── login_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── loadout_builder/
│   │   │   ├── loadout_builder_screen.dart
│   │   │   ├── weapon_slot_widget.dart
│   │   │   └── armor_slot_widget.dart
│   │   ├── item_search/
│   │   │   └── item_search_screen.dart
│   │   └── character/
│   │       └── character_screen.dart
│   └── widgets/
│       ├── item_icon.dart           # Cached Bungie item icon
│       ├── perk_grid.dart
│       └── stat_bar.dart
│
└── main.dart
```

---

## Key Implementation Areas

### 1. OAuth Authentication Flow

```dart
// In auth_repository.dart
Future<void> signIn() async {
  final result = await FlutterWebAuth2.authenticate(
    url: 'https://www.bungie.net/en/oauth/authorize'
        '?client_id=$clientId&response_type=code&state=$state',
    callbackUrlScheme: 'destiny2loadout',
  );
  
  final code = Uri.parse(result).queryParameters['code']!;
  await _exchangeCodeForTokens(code);
}
```

Configure the callback URL scheme in:
- **Android:** `android/app/src/main/AndroidManifest.xml` — add an intent filter
- **iOS:** `ios/Runner/Info.plist` — add a URL scheme under `CFBundleURLTypes`

### 2. Manifest Download & Storage

The Destiny manifest is a versioned SQLite database containing every item definition (weapons, armor, perks, mods, lore, etc.). It must be downloaded on first launch and refreshed when Bungie updates it (typically with each patch).

```dart
// Step 1: Get the manifest metadata
GET https://www.bungie.net/Platform/Destiny2/Manifest/
// Returns version string + download paths per language

// Step 2: Download the SQLite file
// URL format: https://www.bungie.net/{mobileWorldContentPaths.en}

// Step 3: Store the version string in Hive
// On each app launch, compare stored version to API version
// Re-download only if they differ
```

Store the manifest SQLite file in the app's documents directory using `path_provider`. Open it with `drift` using `NativeDatabase`.

### 3. Fetching Player Inventory

Use the `GetProfile` endpoint with components to control what data is returned:

```
GET https://www.bungie.net/Platform/Destiny2/{membershipType}/Profile/{membershipId}/
    ?components=100,102,200,201,205,300,302,304,305,307
```

Key component codes:

| Code | Component | Use |
|---|---|---|
| 100 | Profiles | Membership info |
| 102 | ProfileInventories | Vault items |
| 200 | Characters | Character list |
| 201 | CharacterInventories | Character items |
| 205 | CharacterEquipment | Currently equipped items |
| 300 | ItemInstances | Power level, damage type |
| 302 | ItemPerks | Active perks |
| 304 | ItemStats | Weapon/armor stats |
| 305 | ItemSockets | Equipped mods and perks |
| 307 | ItemPlugStates | Perk column options |

### 4. Resolving Item Definitions from the Manifest

API responses return `itemHash` integers, not item names. You resolve them against the local manifest:

```dart
// In manifest_dao.dart
Future<DestinyInventoryItemDefinition> getItemDefinition(int hash) async {
  // Query local Drift DB
  return await db.select(db.inventoryItemDefinitions)
    ..where((t) => t.hash.equals(hash));
}
```

The manifest tables you'll query most:
- `DestinyInventoryItemDefinition` — weapons, armor, mods, perks
- `DestinyStatDefinition` — stat names and descriptions
- `DestinySocketTypeDefinition` — which mods fit which slots
- `DestinySandboxPerkDefinition` — perk descriptions
- `DestinyClassDefinition` — Hunter, Titan, Warlock

### 5. Loadout Saving & Syncing

**Local saving:** Serialize loadouts as JSON and store in a Hive box.

**Syncing to the game:** Bungie added native in-game loadout support. You can write loadouts back via:

```
POST https://www.bungie.net/Platform/Destiny2/Actions/Loadouts/Snapshot/
```

This requires the `MoveEquipDestinyItems` scope in addition to the read scope. Add it to your app's registered scopes if you want write support.

---

## Environment Configuration

Use `envied` to keep secrets out of source control. Create a `.env` file at the project root (add to `.gitignore`):

```
# .env  — DO NOT COMMIT
BUNGIE_API_KEY=your_api_key_here
BUNGIE_CLIENT_ID=your_client_id_here
```

Then define an annotated class:

```dart
// lib/core/config/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class Env {
  @EnviedField(varName: 'BUNGIE_API_KEY', obfuscate: true)
  static final String apiKey = _Env.apiKey;

  @EnviedField(varName: 'BUNGIE_CLIENT_ID', obfuscate: true)
  static final String clientId = _Env.clientId;
}
```

Run `dart run build_runner build` to generate `env.g.dart`. The `obfuscate: true` flag prevents the key from being visible as a plain string in the compiled binary.

---

## Getting Started

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd destiny2_loadout_planner

# 2. Install dependencies
flutter pub get

# 3. Create your .env file
cp .env.example .env
# Then fill in your Bungie API key and client ID

# 4. Run code generation (models, DB schema, env)
dart run build_runner build --delete-conflicting-outputs

# 5. Run on a device or simulator
flutter run
```

On first launch the app will:
1. Show the login screen
2. After OAuth sign-in, download the Destiny manifest (~50–100 MB)
3. Store the manifest version in Hive for future comparison
4. Fetch the player's characters and inventory

---

## API Quick Reference

| Action | Method | Endpoint |
|---|---|---|
| Get manifest metadata | GET | `/Platform/Destiny2/Manifest/` |
| Get player profile + inventory | GET | `/Platform/Destiny2/{type}/{id}/Profile/?components=...` |
| Get character details | GET | `/Platform/Destiny2/{type}/{id}/Character/{charId}/?components=...` |
| Search player by name | POST | `/Platform/Destiny2/SearchDestinyPlayerByBungieName/{type}/` |
| Get linked profiles | GET | `/Platform/Destiny2/{type}/{id}/LinkedProfiles/` |
| Equip item | POST | `/Platform/Destiny2/Actions/Items/EquipItem/` |
| Snapshot loadout to game | POST | `/Platform/Destiny2/Actions/Loadouts/Snapshot/` |
| Get item definition | GET | `/Platform/Destiny2/Manifest/{entityType}/{hash}/` |

All endpoints are prefixed with `https://www.bungie.net` and require the header `X-API-Key: {your_api_key}`. Authenticated endpoints additionally require `Authorization: Bearer {access_token}`.

---

## Known Gotchas & Tips

- **Manifest versioning** — The manifest updates with every game patch, sometimes mid-day. Always check the version on launch and refresh if needed. Cache the SQLite file to avoid re-downloading on every cold start.

- **Hash overflow** — Bungie item hashes are unsigned 32-bit integers, but Dart's `int` is 64-bit. API responses sometimes return negative values for hashes — this is a known quirk. Apply `hash & 0xFFFFFFFF` to normalize if needed.

- **Component data can be null** — Even if you request a component, the API may return null for it (e.g., a character with no equipped items). Always null-check component responses.

- **Rate limiting** — Bungie enforces rate limits per API key. Implement exponential backoff in a Dio interceptor for 429 responses. Batch your component requests instead of making many small calls.

- **Image base URL** — Item icons are relative paths. Prefix them with `https://www.bungie.net` to get the full image URL (e.g., `https://www.bungie.net/common/destiny2_content/icons/...`).

- **Membership types** — Players can be on multiple platforms (Xbox = 1, PSN = 2, Steam = 3, Epic = 6). Use `LinkedProfiles` to find all platforms for a given Bungie account and respect cross-save primary settings.

- **Token refresh** — Access tokens expire after ~60 minutes; refresh tokens after ~90 days. Implement proactive refresh in your `AuthInterceptor` before the token expires to avoid mid-session 401 errors.

- **WebView is blocked** — Bungie will technically block WebView OAuth and will not feature/promote apps that use it. Use `flutter_web_auth_2` — it uses the correct system browser APIs on each platform.

---

## Useful Resources

| Resource | URL |
|---|---|
| Bungie API Full Docs | https://bungie-net.github.io |
| Bungie Developer Portal | https://www.bungie.net/en/Application |
| Bungie API GitHub | https://github.com/Bungie-net/api |
| Destiny Data Explorer (manifest browser) | https://data.destinysets.com |
| GuardianDock (Flutter + Bungie reference app) | https://github.com/topics/bungie-destiny-api |
| DIM (Destiny Item Manager — open source, great reference) | https://github.com/DestinyItemManager/DIM |
| light.gg (item database, god roll reference) | https://www.light.gg |
| Riverpod docs | https://riverpod.dev |
| Drift docs | https://drift.simonbinder.eu |
| flutter_web_auth_2 | https://pub.dev/packages/flutter_web_auth_2 |
| Community Discord (The100 / Destiny API devs) | https://github.com/Bungie-net/api/issues |

---

*Handover document generated for the Destiny 2 Loadout Planner Flutter project. Update this document as the project evolves — especially the Directory Structure and Key Implementation Areas sections as patterns are established.*
