# Destiny 2 Loadout Planner — Read Me First

Thanks for trying this out. It's a small Windows app for browsing and building
Destiny 2 loadouts using your own Bungie account. A couple of one-time prompts
will show up the first time you use it — **both are expected and safe to click
through.** Here's what they are and why.

## 1. First launch: "Windows protected your PC" (SmartScreen)

When you double-click the app the first time, Windows may show a blue
"Windows protected your PC" box. This happens because the app isn't
code-signed with a paid certificate — Windows just doesn't recognize the
publisher yet. It is **not** a virus warning.

**To run it:** click **More info**, then **Run anyway.**

You'll only see this once per machine — Windows remembers the app after that.

## 2. First sign-in: browser certificate warning

When you click **Sign in with Bungie.net**, your browser opens Bungie's login
page. After you approve access, Bungie sends you back to the app through a tiny
local address (`https://127.0.0.1:7355`). Your browser will warn that this
address's security certificate isn't trusted — this is normal, because no
public certificate authority can issue a certificate for a local `127.0.0.1`
address. Nothing is being sent over the internet at this step; it's the app
talking to itself on your own machine.

**To continue:** click **Advanced**, then **Proceed to 127.0.0.1 (unsafe).**

The wording ("unsafe") is just the browser's generic language for any
self-issued certificate. You'll only need to do this once per sign-in.

## After that

You're done — the app stays signed in and won't ask you to re-authenticate for
a long while. If you ever get signed out, just click **Sign in with
Bungie.net** again (and click through the certificate warning once more).

## Installing / updating

There's no installer. Unzip the folder anywhere you like and run the `.exe`
inside it. To update later, download the new zip and replace the folder.
