# d2ai source data

Bundled acquisition-source data, loaded at runtime by `D2aiRepository`. Read as
app assets — never fetched over the network.

## Files

- **`sources.json`** — DIM's [d2-additional-info](https://github.com/DestinyItemManager/d2-additional-info)
  snapshot: `sourceHash -> text`. A frozen copy; do not hand-edit (a refresh
  overwrites it). MIT — see `LICENSE.md`.
- **`weapon-from-quest.json`** — DIM snapshot: `weaponItemHash -> quest-step hash`.
- **`source_overrides.json`** — **ours.** `itemHash -> source text`. Edit this to
  add or fix sources you find in-game. Layered *above* d2ai, so it survives a
  d2ai refresh and takes precedence over everything (including the hidden
  "Random Perks" items).

## Adding a source override

Add an entry to `source_overrides.json` keyed by the item's **unsigned item
hash** (the same hash in a `light.gg` / DIM URL), with the text to show:

```json
{
  "1716620044": "Source: Nightfall — Chain of Command",
  "3688176697": "Source: Trials of Osiris"
}
```

Precedence when resolving an item's Source row (highest first):

1. `source_overrides.json` (this file)
2. `sources.json` (d2ai, by the collectible's `sourceHash`)
3. the manifest's own `sourceString`

An item with no match at any level shows no Source row. The ~384 random-rolled
items sharing sourceHash `2387628034` ("cannot be reacquired from Collections")
are hidden by default — add a per-item override here to give one a real source.

Finding a hash: search the item on [light.gg](https://www.light.gg) — the number
in the URL is its item hash.
