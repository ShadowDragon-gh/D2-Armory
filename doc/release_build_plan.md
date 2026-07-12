# Release Build & Distribution — Plan

Goal: produce a Windows build of the app that a friend can run with as little
friction as possible, using their own Bungie account, without needing Flutter,
without needing a Bungie API registration of their own, and with the two known
friction points (self-signed cert, unsigned exe) handled deliberately instead
of surprising them.

---

## 1. Bungie application registration

The app already supports both OAuth client types (`AppConfig.isConfidentialClient`
branches in [auth_repository.dart](../lib/data/repositories/auth_repository.dart)),
so this is a config change, not a code change.

1. Go to https://www.bungie.net/en/Application and open the existing app
   registration (or create a new one dedicated to the shipped build, so local
   dev and distribution don't share a registration).
2. Set **OAuth Client Type** to **Public**. Public clients authenticate with
   `client_id` only — no secret to protect, which matters once the config is
   embedded in a binary handed to someone else.
3. Confirm the registered **Redirect URL** matches `AppConfig.oauthRedirectUrl`:
   `https://127.0.0.1:7355/callback`.
4. Note the **API Key** and **OAuth client_id** — these go in the release env
   file in step 2, below.

If Bungie doesn't allow editing client type on an existing registration in
place, register a second app for this purpose and use its key/client_id
instead.

**Gotcha hit in practice:** switching the OAuth Client Type in the portal
requires actually clicking Save on that specific change — the form can let you
toggle the field visually without persisting it. Symptom: the token endpoint
returns `400 invalid_client — "Confidential client must authenticate with a
client secret"` even though the app is sending the public-client request shape
correctly. Fix is to re-open the app registration, confirm the type after a
full page reload (not just right after saving), and re-save if it reverted.

### Public vs Confidential — session-length tradeoff (open decision)

This choice affects more than "does a secret exist" — it determines how often
the user has to re-authenticate:

- **Public client**: no refresh token is ever issued by Bungie
  (`OAuthTokens.refreshToken` stays null — see
  [oauth_tokens.dart](../lib/domain/models/oauth_tokens.dart)). The access
  token's lifetime is whatever Bungie's `expires_in` says (their own docs show
  ~3600s / 1 hour as an example, not a documented guarantee). Once it expires,
  `canRefresh` is false, so the app signs the user out and they must click
  "Sign in with Bungie.net" again — a real browser round-trip, roughly hourly.
- **Confidential client**: Bungie does issue a refresh token, so the app can
  silently renew access tokens via the `refresh_token` grant
  (`_refresh()` / `_postToken()` with `Authorization: Basic` in
  [auth_repository.dart](../lib/data/repositories/auth_repository.dart))
  without the user ever seeing a browser prompt again, until the refresh
  token itself expires (much longer-lived).

**Why DIM never re-prompts for weeks:** DIM is registered as a Confidential
client with Bungie (confirmed from its source, `src/app/bungie-api/oauth.ts`)
and ships `client_secret` directly in its client-side JS bundle — visible to
anyone who opens browser dev tools. Bungie's OAuth system doesn't verify that
a "Confidential" client's secret is actually kept confidential; it only
trusts whatever type the app registered as. DIM accepts that its secret is
technically exposed in exchange for long-lived sessions via a real refresh
token, on the reasoning that a JS-bundle secret was never going to be
meaningfully protected anyway. A compiled native Windows exe (this app's
case) is harder to extract a string from than open dev tools, though not
impossible for a motivated reverse-engineer.

**What leaking the secret would actually expose, if this app went
Confidential:** the secret alone does not grant access to any user's
account — Bungie's token endpoint only acts on a specific refresh token
already presented to it, and the secret can't be used to fetch or enumerate
other users' tokens. It only matters in combination with a *separately
already-leaked* refresh token for a specific victim (e.g. exfiltrated from
that user's local secure storage by some other compromise) — in that
narrow combined case, the leaked secret removes the natural expiry that
would otherwise limit how long the stolen token stays useful. For a private
build shared with one trusted person, that compound risk is low; it would
matter more if this were distributed broadly to strangers.

**Decision:** not yet finalized — currently reverted back to Confidential
for local dev (`env/dev.json` has `BUNGIE_CLIENT_SECRET` set) after
initially trying Public. Revisit which one the release build should use
before following the checklist in §8; §1-§2 as written below describe the
Public-client path used when this doc was first drafted.

## 2. Release env file

Create `env/release.json` (gitignored already, matches the `/env/*.json`
pattern in `.gitignore`) with the Public client's credentials and **no**
`BUNGIE_CLIENT_SECRET`:

```json
{
  "BUNGIE_API_KEY": "<api key from step 1>",
  "BUNGIE_CLIENT_ID": "<client id from step 1>",
  "BUNGIE_CLIENT_SECRET": ""
}
```

An empty/absent secret makes `AppConfig.isConfidentialClient` false, which
routes token requests through the public-client body-param flow already
implemented in `_postToken`.

## 3. Build

```
flutter build windows --release --dart-define-from-file=env/release.json
```

Output lands in `build/windows/x64/runner/Release/`. This folder — the exe,
its DLLs, and the `data/` subfolder — must ship together; it is not a
single-file executable.

## 4. Packaging — options for how the other person gets the app

Presented as options because the right one depends on how much you want to
invest versus how often you'll ship updates.

### Option A: Zip + GitHub Release (recommended for "as little effort as possible")
Zip the `Release` folder, attach it to a GitHub Release (`gh release create`).
Your friend downloads the zip, extracts it anywhere, runs the exe. No
installer, no admin rights, no install/uninstall entries. Update = download a
new zip and overwrite the folder.

### Option B: Installer (Inno Setup)
Wrap the Release folder in an Inno Setup script to produce a single
`Setup.exe` with a Start Menu entry and uninstaller. More polished, more
setup work on your side, and one more unsigned executable that itself may
trigger a SmartScreen prompt (see §6) — so it doesn't avoid that problem, it
just moves it earlier.

### Option C: MSIX package
Flutter supports `msix` packaging for Windows. Gives a "real" installed-app
experience and can be self-signed with a locally-trusted dev cert, but
sideloading an MSIX still requires enabling sideloading or trusting the
signing cert on the friend's machine — comparable friction to Option A, more
build complexity.

**Recommendation: Option A.** It has the fewest moving parts and the fewest
extra prompts on the friend's machine — the SmartScreen and cert warnings
described below happen regardless of packaging choice, so a plain zip avoids
adding a third one.

## 5. Fixing the missing/untrusted certificate on the OAuth callback

Background: Bungie requires an HTTPS redirect URL, so the app runs its own
tiny HTTPS server on `127.0.0.1:7355` for the loopback OAuth callback,
serving a self-signed cert bundled as an asset
([loopback_cert.pem](../assets/certs/loopback_cert.pem), 10-year validity, CN
`127.0.0.1`). No public CA will issue a cert for `127.0.0.1`, so this problem
can't be eliminated outright — only mitigated. The browser will show an
"unsafe/untrusted certificate" interstitial the first time it hits the
callback during each sign-in. Options, roughly best-to-worst tradeoff:

### Option A: Do nothing, document the click-through (current behavior)
The warning is one-time per sign-in flow, not persistent — clicking
"Advanced → Proceed" delivers the auth code and the flow completes normally.
Zero extra work; the risk is a friend seeing a scary browser page with no
context and assuming the app is broken or malicious.

**Mitigation at no cost:** add a line to the login screen or a README the
friend sees first, e.g. "Your browser will warn about an untrusted
certificate when it redirects back — this is expected, click through it."
This is the same approach DIM and similar tools use for local-loopback OAuth.

### Option B: Install the cert as a locally-trusted root on the friend's machine
Ship a small setup step (or one-line PowerShell snippet) that imports
`loopback_cert.pem` into the friend's Windows "Trusted Root Certification
Authorities" store, scoped to that one cert. Removes the warning entirely
after a one-time `Import-Certificate` step, but that step itself needs admin
rights and is arguably a scarier ask than "click through a browser warning" —
installing a trusted root CA cert is a bigger trust grant than it sounds, even
though this cert only matters for `127.0.0.1`.

### Option C: Per-install generated cert instead of a shared bundled one
Generate the self-signed cert on first run (per machine) rather than shipping
one fixed cert baked into every copy. Doesn't remove the browser warning
(still self-signed, still untrusted by default), but avoids every installed
copy of the app sharing one private key — a minor hardening step, not a UX
fix. Real code work (cert generation at runtime, likely via a bundled
tool or a pure-Dart cert generator), disproportionate to the actual risk for
a share-with-a-friend use case.

**Recommendation: Option A.** The click-through is a one-time, well
understood browser interaction, and every alternative trades a small one-time
prompt for either an admin-rights step (Option B) or real implementation work
with no corresponding warning removed (Option C).

## 6. Will Windows block or flag the executable? (yes — SmartScreen)

Separately from the OAuth cert: the built exe itself is **unsigned** (no
Authenticode code-signing certificate), and it will be a fresh binary with no
download reputation. Expect Windows **SmartScreen** to show "Windows
protected your PC" when the friend double-clicks it — this is unrelated to
the OAuth flow and unrelated to any actual malware heuristic; it's purely
"unrecognized publisher + low reputation."

### Option A: Do nothing, document the click-through (recommended)
SmartScreen's block has a manual override: "More info" → "Run anyway." This
is a one-time prompt per machine (per binary hash) — after that first
approval, SmartScreen won't re-prompt for the same exe. Tell your friend in
advance to expect this and click through it, same as the cert warning. Free,
standard for indie/hobby Windows software.

### Option B: Code-sign with a certificate
A proper Authenticode certificate (from a CA like DigiCert/Sectigo, or a
cheaper OV cert reseller) removes the SmartScreen prompt, but has both a real
cost (~$100-400/year) and a reputation ramp-up — a newly-signed cert with no
download history can still get flagged until it accumulates reputation with
Microsoft. Disproportionate for sharing with one person.

### Option C: Self-sign
A self-signed Authenticode cert doesn't help — Windows SmartScreen only
trusts signatures chained to a public CA. Self-signing changes nothing about
the SmartScreen prompt; skip this option for this purpose.

**Recommendation: Option A**, same reasoning as the cert warning — one
explained, one-time click-through beats real cost or complexity for a
single-recipient share.

## 7. Combined friction summary for the friend

Two separate one-time prompts, both expected and both harmless to click
through:
1. **SmartScreen**, on first launching the exe → "More info" → "Run anyway."
2. **Browser cert warning**, on first sign-in → "Advanced" → "Proceed to
   127.0.0.1."

Neither recurs after the first time (SmartScreen remembers the binary; the
cert warning only reappears if the browser is told to forget the exception,
which is not the default). Worth putting both in a short note alongside the
release download so the friend isn't surprised mid-flow.

## 8. Steps checklist

1. [ ] Confirm/set Bungie app registration to Public client type (or register
       a second Public app for distribution).
2. [ ] Create `env/release.json` with API key + client_id, empty secret.
3. [ ] `flutter build windows --release --dart-define-from-file=env/release.json`
4. [ ] Zip `build/windows/x64/runner/Release/`.
5. [ ] Write a short note for the friend covering both click-throughs (§7).
6. [ ] Create a GitHub Release, attach the zip and the note.
7. [ ] Test on a second machine (or clean VM) before sending — this is the
       only way to actually see the SmartScreen/cert prompts as the friend
       will see them, since your dev machine has likely already trusted both.

## 9. Auto-updater (not yet started — design notes only)

Goal explored: let the app check GitHub for a newer release and update itself,
instead of the friend manually re-downloading and swapping the folder each
time. No code has been written for this yet.

### Off-the-shelf packages don't fit cleanly
`desktop_updater` and `auto_updater` (leanflutter, Sparkle/WinSparkle-based)
both expect updates to be served from **your own hosted manifest** (a
`app-archive.json`/`release.json` pair, or a Sparkle "appcast" XML) on a
server you control — neither consumes GitHub Releases directly out of the
box. Using them would mean standing up extra static hosting (e.g. GitHub
Pages) purely to satisfy their expected file format — more moving parts than
this project's single-repo, GitHub-Releases-only setup needs.

### DIY against the GitHub Releases API fits better
`GET /repos/{owner}/{repo}/releases/latest` already returns the version tag
and asset `browser_download_url` as JSON — no extra hosting needed. A
lightweight in-app updater: call that endpoint (via `dio`, already a
dependency), compare the tag to the running app's version, and act if newer.

### Blocker: this repo is currently private
The releases API requires authentication for a private repo — the app can't
call it anonymously the way it could for a public repo. Shipping a personal
GitHub token embedded in the app to work around this would be a worse
credential-exposure problem than the OAuth client-secret question in §1,
since a leaked personal token can reach every repo/resource that account can
touch, not just this one project. Options surfaced, **decision not yet
made**:
- **Make the repo public** — source has no committed secrets (Bungie
  credentials are dart-define'd in at build time, not committed), so this
  removes the auth problem entirely and lets the updater use the
  unauthenticated public API. Simplest option if there's no other reason to
  keep the source private.
  - Note: the commit-history anonymization work (author names and emails
    scrubbed of the old account identity) should finish *before* going
    public.
- **Keep private, use a scoped fine-grained PAT** — read-only, scoped to just
  this repo, embedded in the app. Still extractable from the binary like any
  embedded secret, but a narrow scope limits blast radius if leaked (same
  shape as the Confidential-client-secret tradeoff in §1).
- **Keep private, publish releases to a separate public location** — e.g. a
  public releases-only repo or GitHub Pages site the updater checks, while
  the source repo stays private. Avoids embedding any token; more setup
  work maintaining two publish targets.

### Automation-level chosen: full self-update
The user selected **full self-update** (download new release → exit →
replace local files → relaunch) over the lighter "check + notify" or
"check + download, manual install" options. This is the most convenient for
the friend but the most complex to implement correctly on Windows:
- A running `.exe` cannot overwrite its own file — needs a separate
  helper process/script (spawned just before exit) to perform the
  file swap once the main process has released its file locks, then
  relaunch the app.
- Needs real handling for partial-download/partial-extract failures,
  files locked by antivirus scanning, and leaving the app in a working
  state (not half-updated) if any step fails.
- Should verify the downloaded asset (e.g. size and/or a checksum published
  alongside the release) before replacing anything, so a corrupted or
  interrupted download can't brick the install.

**Status:** design-only — no implementation started. Needs the private-repo
question resolved first, since that determines what the update-check request
even looks like.
