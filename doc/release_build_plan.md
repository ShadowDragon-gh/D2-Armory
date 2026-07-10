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
