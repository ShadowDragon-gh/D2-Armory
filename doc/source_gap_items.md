# Plan: acquisition-source gaps — the addressable item lists

## Purpose

An audit of weapon/armor definitions whose Source row shows **no usable source**,
so we can decide which deserve a hand-authored entry in
[`assets/d2ai/source_overrides.json`](../assets/d2ai/source_overrides.json).
Add an override by the item's **Item Hash**.

**The raw item rows live in [`source_gap_items.csv`](source_gap_items.csv)** (960
rows, one per item, with `group` / `confidence` columns for spreadsheet
filtering). This doc explains the classification and confidence caveats; the CSV
is the working list. The tables below mirror the CSV for at-a-glance reading.

## How items got here (classification rules)

Over all equippable weapon/armor definitions (`itemType` 2/3, `tierType >= 2`):

- An item is in these lists only if its **only** "source" is: a non-source note
  (`Random Perks: cannot be reacquired` or `Earned while leveling`, both hidden
  in-app), an **empty** source string, or **no collectible at all**.
- **Definitively-reissued items are excluded**: if a *same-name* item exists that
  carries a **real** source (a real activity/quest/vendor/location), this copy is
  the stale duplicate — the current reissue is the keeper — so it is dropped.
  **3146 items were dropped this way.**

## The honest caveat on "obtainable"

**The manifest has no reliable flag for "currently in the loot pool."** A season
watermark tells you *which season an item shipped in*, not whether it still drops.
So the split below is a **heuristic**, not ground truth:

- **"Likely NOT obtainable" is high-confidence** — these carry a definite tell:
  a sunset-upgrade name tag (`(Unkindled)`, `(Rekindled)`, …), a bare
  placeholder name (`Helmet`, `Gauntlets`), or no watermark at all (pre-watermark
  era). These are safe to ignore.
- **"Likely obtainable" is a REVIEW-CANDIDATE set, not verified** — it means only
  "no definite not-obtainable tell was found." It still contains older gear that
  is retired but not tagged as such. **Each needs a manual eyeball** (check the
  item on light.gg / in-game) before writing an override.

To make the "obtainable" side authoritative would need an external current-loot
dataset the app does not bundle. That is a possible follow-up, noted at the end.

---

# Group A — items with a non-source note

Their only "source" is `Random Perks: cannot be reacquired` or
`Earned while leveling` (both hidden in-app). 475 items after
dropping reissues.

## A1. Likely obtainable — review candidates (460)

| Name | Kind | Type | Class | Tier | Item Hash |
|---|---|---|---|---:|---|
| Bushido Vest | Armor | Chest Armor | Hunter | 5 | 1154629600 |
| Disaster Corps Vest | Armor | Chest Armor | Hunter | 5 | 438409602 |
| Eutechnology Vest | Armor | Chest Armor | Hunter | 5 | 726639044 |
| Ferropotent Cuirass | Armor | Chest Armor | Hunter | 5 | 2849508185 |
| Gumshoe Gumption Vest | Armor | Chest Armor | Hunter | 4 | 502477449 |
| Kit Fox 1.4 | Armor | Chest Armor | Hunter | 3 | 1117103511 |
| Last Discipline Vest | Armor | Chest Armor | Hunter | 5 | 2752429099 |
| Luminopotent Cuirass | Armor | Chest Armor | Hunter | 5 | 2883433250 |
| Makeshift Suit | Armor | Chest Armor | Hunter | 3 | 2657403961 |
| Mechanik 2.1 | Armor | Chest Armor | Hunter | 3 | 4269283110 |
| Mythos Hack 4.1 | Armor | Chest Armor | Hunter | 4 | 503306433 |
| Refugee Vest | Armor | Chest Armor | Hunter | 2 | 860993270 |
| Scavenger Suit | Armor | Chest Armor | Hunter | 3 | 1790272280 |
| Shadow Specter | Armor | Chest Armor | Hunter | 4 | 482198005 |
| Smoke Jumper Vest | Armor | Chest Armor | Hunter | 5 | 2348082405 |
| Swordmaster's Vest | Armor | Chest Armor | Hunter | 5 | 1604556427 |
| Techsec Vest | Armor | Chest Armor | Hunter | 5 | 503854896 |
| Triumphal Anthem Vest | Armor | Chest Armor | Hunter | 5 | 4071845509 |
| War Mantis | Armor | Chest Armor | Hunter | 4 | 3665810048 |
| Wastelander Vest | Armor | Chest Armor | Hunter | 2 | 30960615 |
| Wild Anthem Vest | Armor | Chest Armor | Hunter | 5 | 217940910 |
| Bushido Grips | Armor | Gauntlets | Hunter | 5 | 81786728 |
| Disaster Corps Grasps | Armor | Gauntlets | Hunter | 5 | 517814638 |
| Eutechnology Sleeves | Armor | Gauntlets | Hunter | 5 | 2270938588 |
| Ferropotent Grips | Armor | Gauntlets | Hunter | 5 | 4199055647 |
| Gumshoe Gumption Grips | Armor | Gauntlets | Hunter | 4 | 2120302383 |
| Kit Fox 2.1 | Armor | Gauntlets | Hunter | 3 | 1377391809 |
| Last Discipline Grasps | Armor | Gauntlets | Hunter | 5 | 1172384181 |
| Luminopotent Grips | Armor | Gauntlets | Hunter | 5 | 2835120910 |
| Makeshift Suit | Armor | Gauntlets | Hunter | 3 | 235325823 |
| Mechanik 1.1 | Armor | Gauntlets | Hunter | 3 | 3208987202 |
| Mythos Hack 4.1 | Armor | Gauntlets | Hunter | 4 | 944303735 |
| Refugee Gloves | Armor | Gauntlets | Hunter | 2 | 3493659058 |
| Scavenger Suit | Armor | Gauntlets | Hunter | 3 | 2742817008 |
| Shadow Specter | Armor | Gauntlets | Hunter | 4 | 1059980443 |
| Smoke Jumper Grasps | Armor | Gauntlets | Hunter | 5 | 2280816555 |
| Swordmaster's Grips | Armor | Gauntlets | Hunter | 5 | 2697887125 |
| Techsec Grasps | Armor | Gauntlets | Hunter | 5 | 3129990424 |
| Triumphal Anthem Grips | Armor | Gauntlets | Hunter | 5 | 3153400267 |
| War Mantis | Armor | Gauntlets | Hunter | 4 | 2268087176 |
| Wastelander Wraps | Armor | Gauntlets | Hunter | 2 | 4134502833 |
| Wild Anthem Grips | Armor | Gauntlets | Hunter | 5 | 361848666 |
| Bushido Cowl | Armor | Helmet | Hunter | 5 | 1465235089 |
| Disaster Corps Mask | Armor | Helmet | Hunter | 5 | 2571112423 |
| Eutechnology Cowl | Armor | Helmet | Hunter | 5 | 1152238701 |
| Ferropotent Mask | Armor | Helmet | Hunter | 5 | 3173749166 |
| Frumious Mask | Armor | Helmet | Hunter | 5 | 477057676 |
| Gumshoe Gumption Mask | Armor | Helmet | Hunter | 4 | 2891906302 |
| Kit Fox 1.5 | Armor | Helmet | Hunter | 3 | 1621184880 |
| Last Discipline Mask | Armor | Helmet | Hunter | 5 | 4112577340 |
| Luminopotent Mask | Armor | Helmet | Hunter | 5 | 593554567 |
| Makeshift Suit | Armor | Helmet | Hunter | 3 | 3080529038 |
| Mechanik 1.2 | Armor | Helmet | Hunter | 3 | 955082419 |
| Mythos Hack 4.1 | Armor | Helmet | Hunter | 4 | 1930343846 |
| Refugee Mask | Armor | Helmet | Hunter | 2 | 2822154467 |
| Scavenger Suit | Armor | Helmet | Hunter | 3 | 3229455225 |
| Shadow Specter | Armor | Helmet | Hunter | 4 | 593627314 |
| Smoke Jumper Mask | Armor | Helmet | Hunter | 5 | 2941172034 |
| Swordmaster's Mask | Armor | Helmet | Hunter | 5 | 1343009820 |
| Techsec Mask | Armor | Helmet | Hunter | 5 | 2292070913 |
| Triumphal Anthem Mask | Armor | Helmet | Hunter | 5 | 3855332578 |
| War Mantis | Armor | Helmet | Hunter | 4 | 3651432497 |
| Wastelander Mask | Armor | Helmet | Hunter | 2 | 2231988704 |
| Wild Anthem Mask | Armor | Helmet | Hunter | 5 | 2039591531 |
| At Least It's a Cape | Armor | Hunter Cloak | Hunter | 3 | 3971569908 |
| Bushido Cloak | Armor | Hunter Cloak | Hunter | 5 | 464665629 |
| Cloak of Retelling | Armor | Hunter Cloak | Hunter | 4 | 1285811484 |
| Disaster Corps Cloak | Armor | Hunter Cloak | Hunter | 5 | 3957372883 |
| Eutechnology Cloak | Armor | Hunter Cloak | Hunter | 5 | 1936503321 |
| Ferropotent Cloak | Armor | Hunter Cloak | Hunter | 5 | 293267476 |
| Gumshoe Gumption Cloak | Armor | Hunter Cloak | Hunter | 4 | 2282780740 |
| Hood of Tallies | Armor | Hunter Cloak | Hunter | 3 | 716764559 |
| Last Discipline Cloak | Armor | Hunter Cloak | Hunter | 5 | 1109145282 |
| Luminopotent Cloak | Armor | Hunter Cloak | Hunter | 5 | 2107326067 |
| Refugee Cloak | Armor | Hunter Cloak | Hunter | 2 | 615077791 |
| Renegade Hood | Armor | Hunter Cloak | Hunter | 2 | 746458358 |
| Scavenger Cloak | Armor | Hunter Cloak | Hunter | 3 | 185766709 |
| Shadow Specter | Armor | Hunter Cloak | Hunter | 4 | 3857537480 |
| Sly Cloak | Armor | Hunter Cloak | Hunter | 3 | 3245422950 |
| Smoke Jumper Cloak | Armor | Hunter Cloak | Hunter | 5 | 1003997240 |
| Swordmaster's Cloak | Armor | Hunter Cloak | Hunter | 5 | 385833378 |
| Techsec Cloak | Armor | Hunter Cloak | Hunter | 5 | 4150538093 |
| Triumphal Anthem Cloak | Armor | Hunter Cloak | Hunter | 5 | 2727863512 |
| War Mantis Cloak | Armor | Hunter Cloak | Hunter | 4 | 3017526077 |
| Wild Anthem Cloak | Armor | Hunter Cloak | Hunter | 5 | 536035447 |
| Bushido Strides | Armor | Leg Armor | Hunter | 5 | 1183125954 |
| Disaster Corps Strides | Armor | Leg Armor | Hunter | 5 | 2600892776 |
| Eutechnology Strides | Armor | Leg Armor | Hunter | 5 | 1232186726 |
| Ferropotent Strides | Armor | Leg Armor | Hunter | 5 | 3120202721 |
| Gumshoe Gumption Strides | Armor | Leg Armor | Hunter | 4 | 2270345041 |
| Kit Fox 1.1 | Armor | Leg Armor | Hunter | 3 | 2447779891 |
| Last Discipline Strides | Armor | Leg Armor | Hunter | 5 | 2748506263 |
| Luminopotent Strides | Armor | Leg Armor | Hunter | 5 | 1047792392 |
| Makeshift Suit | Armor | Leg Armor | Hunter | 3 | 3451543233 |
| Mechanik 1.1 | Armor | Leg Armor | Hunter | 3 | 958165756 |
| Mythos Hack 4.1 | Armor | Leg Armor | Hunter | 4 | 2752838425 |
| Refugee Boots | Armor | Leg Armor | Hunter | 2 | 24387532 |
| Scavenger Suit | Armor | Leg Armor | Hunter | 3 | 3059875530 |
| Shadow Specter | Armor | Leg Armor | Hunter | 4 | 4229548557 |
| Smoke Jumper Strides | Armor | Leg Armor | Hunter | 5 | 3755454909 |
| Swordmaster's Strides | Armor | Leg Armor | Hunter | 5 | 445076215 |
| Techsec Strides | Armor | Leg Armor | Hunter | 5 | 1589715538 |
| Triumphal Anthem Strides | Armor | Leg Armor | Hunter | 5 | 374648029 |
| War Mantis | Armor | Leg Armor | Hunter | 4 | 3369426530 |
| Wastelander Boots | Armor | Leg Armor | Hunter | 2 | 3965755651 |
| Wild Anthem Strides | Armor | Leg Armor | Hunter | 5 | 1618320532 |
| Atgeir 2T1 | Armor | Chest Armor | Titan | 3 | 595755242 |
| Bushido Plate | Armor | Chest Armor | Titan | 5 | 2199272806 |
| Disaster Corps Plate | Armor | Chest Armor | Titan | 5 | 3428369046 |
| Eutechnology Plate | Armor | Chest Armor | Titan | 5 | 433193440 |
| Ferropotent Plate | Armor | Chest Armor | Titan | 5 | 3554497829 |
| Fieldplate Type 10 | Armor | Chest Armor | Titan | 3 | 3450293405 |
| Firebreak Field | Armor | Chest Armor | Titan | 3 | 3503564556 |
| Fortress Field | Armor | Chest Armor | Titan | 3 | 702133035 |
| Last Discipline Plate | Armor | Chest Armor | Titan | 5 | 1459620921 |
| Legion-Bane | Armor | Chest Armor | Titan | 4 | 2840140116 |
| Luminopotent Plate | Armor | Chest Armor | Titan | 5 | 3307308272 |
| Midnight Oil Plate | Armor | Chest Armor | Titan | 4 | 2229615005 |
| Primal Siege Type 1 | Armor | Chest Armor | Titan | 4 | 730116261 |
| Refugee Plate | Armor | Chest Armor | Titan | 2 | 2570001258 |
| Renegade Plate | Armor | Chest Armor | Titan | 2 | 2676379051 |
| RPC Valiant | Armor | Chest Armor | Titan | 4 | 1133807721 |
| Smoke Jumper Plate | Armor | Chest Armor | Titan | 5 | 3347493825 |
| Swordmaster's Plate | Armor | Chest Armor | Titan | 5 | 262826703 |
| Techsec Plate | Armor | Chest Armor | Titan | 5 | 2401760398 |
| Triumphal Anthem Plate | Armor | Chest Armor | Titan | 5 | 2324823787 |
| Wild Anthem Plate | Armor | Chest Armor | Titan | 5 | 1644825026 |
| Atgeir 2T1 | Armor | Gauntlets | Titan | 3 | 3201304390 |
| Bushido Gauntlets | Armor | Gauntlets | Titan | 5 | 2195895938 |
| Disaster Corps Gauntlets | Armor | Gauntlets | Titan | 5 | 250597586 |
| Eutechnology Gauntlets | Armor | Gauntlets | Titan | 5 | 591555944 |
| Ferropotent Gauntlets | Armor | Gauntlets | Titan | 5 | 2370945771 |
| Fieldplate Type 10 | Armor | Gauntlets | Titan | 3 | 3260789875 |
| Firebreak Field | Armor | Gauntlets | Titan | 3 | 3862303220 |
| Fortress Field | Armor | Gauntlets | Titan | 3 | 3043014325 |
| Last Discipline Gauntlets | Armor | Gauntlets | Titan | 5 | 4079706495 |
| Legion-Bane | Armor | Gauntlets | Titan | 4 | 1386133900 |
| Luminopotent Gauntlets | Armor | Gauntlets | Titan | 5 | 3654657240 |
| Midnight Oil Gauntlets | Armor | Gauntlets | Titan | 4 | 2479764339 |
| Primal Siege Type 1 | Armor | Gauntlets | Titan | 4 | 1442064747 |
| Refugee Gloves | Armor | Gauntlets | Titan | 2 | 2103153350 |
| Renegade Gauntlets | Armor | Gauntlets | Titan | 2 | 1944863285 |
| RPC Valiant | Armor | Gauntlets | Titan | 4 | 1442860559 |
| Smoke Jumper Gauntlets | Armor | Gauntlets | Titan | 5 | 589006711 |
| Swordmaster's Gauntlets | Armor | Gauntlets | Titan | 5 | 2347181257 |
| Techsec Gauntlets | Armor | Gauntlets | Titan | 5 | 2709760314 |
| Triumphal Anthem Gauntlets | Armor | Gauntlets | Titan | 5 | 571839605 |
| Wild Anthem Gauntlets | Armor | Gauntlets | Titan | 5 | 225063086 |
| Atgeir 2T1 | Armor | Helmet | Titan | 3 | 3267437183 |
| Bushido Helm | Armor | Helmet | Titan | 5 | 407922163 |
| Disaster Corps Helm | Armor | Helmet | Titan | 5 | 3408026115 |
| Eutechnology Helm | Armor | Helmet | Titan | 5 | 1975004305 |
| Ferropotent Head | Armor | Helmet | Titan | 5 | 3031404418 |
| Fieldplate Type 10 | Armor | Helmet | Titan | 3 | 3255228714 |
| Firebreak Field | Armor | Helmet | Titan | 3 | 3123203109 |
| Fortress Field | Armor | Helmet | Titan | 3 | 1688240188 |
| Last Discipline Helm | Armor | Helmet | Titan | 5 | 2629942414 |
| Legion-Bane | Armor | Helmet | Titan | 4 | 2923601949 |
| Luminopotent Helm | Armor | Helmet | Titan | 5 | 2816737729 |
| Midnight Oil Helmet | Armor | Helmet | Titan | 4 | 2474203178 |
| Primal Siege Type 1 | Armor | Helmet | Titan | 4 | 2102523394 |
| Refugee Helm | Armor | Helmet | Titan | 2 | 2169286143 |
| Renegade Helm | Armor | Helmet | Titan | 2 | 590089148 |
| RPC Valiant | Armor | Helmet | Titan | 4 | 2638921950 |
| Smoke Jumper Helm | Armor | Helmet | Titan | 5 | 1575046822 |
| Swordmaster's Helm | Armor | Helmet | Titan | 5 | 1883377784 |
| Techsec Helm | Armor | Helmet | Titan | 5 | 517096395 |
| Triumphal Anthem Helm | Armor | Helmet | Titan | 5 | 3470352892 |
| Wild Anthem Helm | Armor | Helmet | Titan | 5 | 2278464039 |
| Atgeir 2T1 | Armor | Leg Armor | Titan | 3 | 3184791104 |
| Bushido Greaves | Armor | Leg Armor | Titan | 5 | 4281618492 |
| Disaster Corps Greaves | Armor | Leg Armor | Titan | 5 | 651836012 |
| Eutechnology Greaves | Armor | Leg Armor | Titan | 5 | 1692895170 |
| Ferropotent Greaves | Armor | Leg Armor | Titan | 5 | 3462703357 |
| Fieldplate Type 10 | Armor | Leg Armor | Titan | 3 | 2995743813 |
| Firebreak Field | Armor | Leg Armor | Titan | 3 | 4150041854 |
| Fortress Field | Armor | Leg Armor | Titan | 3 | 324169111 |
| Last Discipline Greaves | Armor | Leg Armor | Titan | 5 | 3000956609 |
| Legion-Bane | Armor | Leg Armor | Titan | 4 | 2031866166 |
| Luminopotent Greaves | Armor | Leg Armor | Titan | 5 | 1689821714 |
| Midnight Oil Greaves | Armor | Leg Armor | Titan | 4 | 2214718277 |
| Primal Siege Type 1 | Armor | Leg Armor | Titan | 4 | 2533822333 |
| Refugee Boots | Armor | Leg Armor | Titan | 2 | 2086640064 |
| Renegade Greaves | Armor | Leg Armor | Titan | 2 | 3520985367 |
| RPC Valiant | Armor | Leg Armor | Titan | 4 | 2058937521 |
| Smoke Jumper Boots | Armor | Leg Armor | Titan | 5 | 2397541401 |
| Swordmaster's Greaves | Armor | Leg Armor | Titan | 5 | 2639123099 |
| Techsec Boots | Armor | Leg Armor | Titan | 5 | 95722356 |
| Triumphal Anthem Greaves | Armor | Leg Armor | Titan | 5 | 2147961687 |
| Wild Anthem Greaves | Armor | Leg Armor | Titan | 5 | 2732598696 |
| Atgeir Mark | Armor | Titan Mark | Titan | 3 | 1232572923 |
| Baseline Mark | Armor | Titan Mark | Titan | 4 | 4147032568 |
| Black Shield Mark | Armor | Titan Mark | Titan | 4 | 3625546921 |
| Bushido Mark | Armor | Titan Mark | Titan | 5 | 2517367247 |
| Disaster Corps Mark | Armor | Titan Mark | Titan | 5 | 2757996223 |
| Eutechnology Mark | Armor | Titan Mark | Titan | 5 | 4038196765 |
| Ferropotent Mark | Armor | Titan Mark | Titan | 5 | 2676446840 |
| Last Discipline Mark | Armor | Titan Mark | Titan | 5 | 2773786868 |
| Luminopotent Mark | Armor | Titan Mark | Titan | 5 | 2192886829 |
| Mark of Inquisition | Armor | Titan Mark | Titan | 4 | 2447973668 |
| Mark of the Fire | Armor | Titan Mark | Titan | 3 | 1441321537 |
| Mark of the Golden Citadel | Armor | Titan Mark | Titan | 3 | 3353816514 |
| Mark of the Longest Line | Armor | Titan Mark | Titan | 3 | 617314000 |
| Mark of the Renegade | Armor | Titan Mark | Titan | 2 | 1033095234 |
| Midnight Oil Mark | Armor | Titan Mark | Titan | 4 | 3691602896 |
| Refugee Mark | Armor | Titan Mark | Titan | 2 | 3206818939 |
| Smoke Jumper Mark | Armor | Titan Mark | Titan | 5 | 4129998876 |
| Swordmaster's Mark | Armor | Titan Mark | Titan | 5 | 1934339678 |
| Techsec Mark | Armor | Titan Mark | Titan | 5 | 2719854935 |
| Triumphal Anthem Mark | Armor | Titan Mark | Titan | 5 | 1064523906 |
| Wild Anthem Mark | Armor | Titan Mark | Titan | 5 | 1334855187 |
| Aspirant Robes | Armor | Chest Armor | Warlock | 2 | 3577457804 |
| Atonement Tau | Armor | Chest Armor | Warlock | 4 | 3399906133 |
| Bushido Robes | Armor | Chest Armor | Warlock | 5 | 2046361909 |
| Chiron's Cure | Armor | Chest Armor | Warlock | 4 | 295856360 |
| Cosmic Wind III | Armor | Chest Armor | Warlock | 3 | 436836011 |
| Cry Defiance | Armor | Chest Armor | Warlock | 3 | 3238267532 |
| Disaster Corps Vestment | Armor | Chest Armor | Warlock | 5 | 2804194275 |
| Eutechnology Robes | Armor | Chest Armor | Warlock | 5 | 2897411591 |
| Ferropotent Robes | Armor | Chest Armor | Warlock | 5 | 4066564572 |
| Inspector's Robes | Armor | Chest Armor | Warlock | 4 | 3783871056 |
| Last Discipline Vestment | Armor | Chest Armor | Warlock | 5 | 2025110456 |
| Luminopotent Robes | Armor | Chest Armor | Warlock | 5 | 3345056013 |
| Prophet Snow | Armor | Chest Armor | Warlock | 4 | 2906174660 |
| Raven Shard | Armor | Chest Armor | Warlock | 3 | 330458218 |
| Refugee Vest | Armor | Chest Armor | Warlock | 2 | 3524186653 |
| Smoke Jumper Vestment | Armor | Chest Armor | Warlock | 5 | 3788059976 |
| Swordmaster's Robes | Armor | Chest Armor | Warlock | 5 | 1504698788 |
| Techsec Vestment | Armor | Chest Armor | Warlock | 5 | 4052965875 |
| Triumphal Anthem Robes | Armor | Chest Armor | Warlock | 5 | 350102826 |
| Vector Home | Armor | Chest Armor | Warlock | 3 | 3184996381 |
| Wild Anthem Robes | Armor | Chest Armor | Warlock | 5 | 2134373071 |
| Aspirant Gloves | Armor | Gauntlets | Warlock | 2 | 3931760244 |
| Atonement Tau | Armor | Gauntlets | Warlock | 4 | 3082920955 |
| Bushido Gloves | Armor | Gauntlets | Warlock | 5 | 970712027 |
| Chiron's Cure | Armor | Gauntlets | Warlock | 4 | 750431904 |
| Cosmic Wind | Armor | Gauntlets | Warlock | 3 | 4241323317 |
| Cry Defiance | Armor | Gauntlets | Warlock | 3 | 765644916 |
| Disaster Corps Gloves | Armor | Gauntlets | Warlock | 5 | 2557300061 |
| Eutechnology Gloves | Armor | Gauntlets | Warlock | 5 | 1851922001 |
| Ferropotent Gloves | Armor | Gauntlets | Warlock | 5 | 4037429988 |
| Inspector's Gloves | Armor | Gauntlets | Warlock | 4 | 674128952 |
| Last Discipline Gloves | Armor | Gauntlets | Warlock | 5 | 2403923088 |
| Luminopotent Gloves | Armor | Gauntlets | Warlock | 5 | 3737830979 |
| Prophet Snow | Armor | Gauntlets | Warlock | 4 | 2894481116 |
| Raven Shard | Armor | Gauntlets | Warlock | 3 | 104646086 |
| Refugee Gloves | Armor | Gauntlets | Warlock | 2 | 3330246899 |
| Smoke Jumper Gloves | Armor | Gauntlets | Warlock | 5 | 986078848 |
| Swordmaster's Gloves | Armor | Gauntlets | Warlock | 5 | 4172973116 |
| Techsec Gloves | Armor | Gauntlets | Warlock | 5 | 489126477 |
| Triumphal Anthem Gloves | Armor | Gauntlets | Warlock | 5 | 2414602118 |
| Vector Home | Armor | Gauntlets | Warlock | 3 | 164131571 |
| Wild Anthem Gloves | Armor | Gauntlets | Warlock | 5 | 2394455241 |
| Aspirant Helm | Armor | Helmet | Warlock | 2 | 3192660133 |
| Atonement Tau | Armor | Helmet | Warlock | 4 | 2616464530 |
| Bushido Cowl | Armor | Helmet | Warlock | 5 | 545935602 |
| Chiron's Cure | Armor | Helmet | Warlock | 4 | 2959022889 |
| Cosmic Wind | Armor | Helmet | Warlock | 3 | 2886549180 |
| Cry Defiance | Armor | Helmet | Warlock | 3 | 26544805 |
| Disaster Corps Hood | Armor | Helmet | Warlock | 5 | 2992986244 |
| Eutechnology Cover | Armor | Helmet | Warlock | 5 | 4285848704 |
| Ferropotent Cover | Armor | Helmet | Warlock | 5 | 1066619413 |
| Inspector's Hood | Armor | Helmet | Warlock | 4 | 4172753441 |
| Last Discipline Hood | Armor | Helmet | Warlock | 5 | 2932138009 |
| Luminopotent Cover | Armor | Helmet | Warlock | 5 | 1966593658 |
| Prophet Snow | Armor | Helmet | Warlock | 4 | 1775781229 |
| Raven Shard | Armor | Helmet | Warlock | 3 | 170778879 |
| Refugee Helm | Armor | Helmet | Warlock | 2 | 3324685738 |
| Smoke Jumper Hood | Armor | Helmet | Warlock | 5 | 3577550601 |
| Swordmaster's Cover | Armor | Helmet | Warlock | 5 | 3520307277 |
| Techsec Hood | Armor | Helmet | Warlock | 5 | 2082858804 |
| Triumphal Anthem Cover | Armor | Helmet | Warlock | 5 | 2480734911 |
| Vector Home | Armor | Helmet | Warlock | 3 | 158570410 |
| Wild Anthem Cover | Armor | Helmet | Warlock | 5 | 1930651768 |
| Aspirant Boots | Armor | Leg Armor | Warlock | 2 | 4219498878 |
| Atonement Tau | Armor | Leg Armor | Warlock | 4 | 1532961133 |
| Bushido Boots | Armor | Leg Armor | Warlock | 5 | 3715719501 |
| Chiron's Cure | Armor | Leg Armor | Warlock | 4 | 3740338778 |
| Cosmic Wind III | Armor | Leg Armor | Warlock | 3 | 1522478103 |
| Cry Defiance | Armor | Leg Armor | Warlock | 3 | 1053383550 |
| Disaster Corps Boots | Armor | Leg Armor | Warlock | 5 | 586381823 |
| Eutechnology Boots | Armor | Leg Armor | Warlock | 5 | 1683071779 |
| Ferropotent Boots | Armor | Leg Armor | Warlock | 5 | 1248547982 |
| Inspector's Boots | Armor | Leg Armor | Warlock | 4 | 3004363890 |
| Last Discipline Boots | Armor | Leg Armor | Warlock | 5 | 2762558442 |
| Luminopotent Boots | Armor | Leg Armor | Warlock | 5 | 1829877749 |
| Prophet Snow | Armor | Leg Armor | Warlock | 4 | 1855729254 |
| Raven Shard | Armor | Leg Armor | Warlock | 3 | 88132800 |
| Refugee Boots | Armor | Leg Armor | Warlock | 2 | 3065200837 |
| Smoke Jumper Boots | Armor | Leg Armor | Warlock | 5 | 63899322 |
| Swordmaster's Boots | Armor | Leg Armor | Warlock | 5 | 3558781766 |
| Techsec Boots | Armor | Leg Armor | Warlock | 5 | 1159925519 |
| Triumphal Anthem Boots | Armor | Leg Armor | Warlock | 5 | 1973631360 |
| Vector Home | Armor | Leg Armor | Warlock | 3 | 4194052805 |
| Wild Anthem Boots | Armor | Leg Armor | Warlock | 5 | 2686397083 |
| Bond of Chiron | Armor | Warlock Bond | Warlock | 4 | 1997953733 |
| Bond of Forgotten Wars | Armor | Warlock Bond | Warlock | 4 | 4116038937 |
| Bond of Insight | Armor | Warlock Bond | Warlock | 2 | 1515214785 |
| Bond of Refuge | Armor | Warlock Bond | Warlock | 2 | 691207248 |
| Bond of Symmetry | Armor | Warlock Bond | Warlock | 3 | 3088519490 |
| Bond of the Raven Shard | Armor | Warlock Bond | Warlock | 3 | 967275899 |
| Bushido Bond | Armor | Warlock Bond | Warlock | 5 | 743956488 |
| Disaster Corps Bond | Armor | Warlock Bond | Warlock | 5 | 1703017178 |
| Eutechnology Bond | Armor | Warlock Bond | Warlock | 5 | 4078840342 |
| Fatum Praevaricator | Armor | Warlock Bond | Warlock | 4 | 2521855144 |
| Ferropotent Bond | Armor | Warlock Bond | Warlock | 5 | 1057430865 |
| Homeward | Armor | Warlock Bond | Warlock | 3 | 352016976 |
| Inspector's Bond | Armor | Warlock Bond | Warlock | 4 | 3135586957 |
| Last Discipline Bond | Armor | Warlock Bond | Warlock | 5 | 420604757 |
| Luminopotent Bond | Armor | Warlock Bond | Warlock | 5 | 1924898304 |
| Rite of Refusal | Armor | Warlock Bond | Warlock | 3 | 1176024513 |
| Smoke Jumper Bond | Armor | Warlock Bond | Warlock | 5 | 1619647653 |
| Swordmaster's Bond | Armor | Warlock Bond | Warlock | 5 | 2248528889 |
| Techsec Bond | Armor | Warlock Bond | Warlock | 5 | 1963424554 |
| Triumphal Anthem Bond | Armor | Warlock Bond | Warlock | 5 | 986920507 |
| Wild Anthem Bond | Armor | Warlock Bond | Warlock | 5 | 3805886046 |
| Cuboid ARu | Weapon | Auto Rifle | — | 4 | 2351747816 |
| Cuboid ARu | Weapon | Auto Rifle | — | 4 | 2860172149 |
| Cydonia-AR1 | Weapon | Auto Rifle | — | 3 | 2694044461 |
| Home Again | Weapon | Auto Rifle | — | 3 | 2694044460 |
| Jiangshi AR1 | Weapon | Auto Rifle | — | 3 | 2694044463 |
| Pariah | Weapon | Auto Rifle | — | 2 | 2209451511 |
| Refrain-23 | Weapon | Auto Rifle | — | 4 | 2351747817 |
| Refrain-23 | Weapon | Auto Rifle | — | 4 | 2860172148 |
| Ros Lysis II | Weapon | Auto Rifle | — | 4 | 2351747819 |
| Ros Lysis II | Weapon | Auto Rifle | — | 4 | 2860172150 |
| Sand Wasp-3au | Weapon | Auto Rifle | — | 4 | 2351747818 |
| Sand Wasp-3au | Weapon | Auto Rifle | — | 4 | 2860172151 |
| SUROS Throwback | Weapon | Auto Rifle | — | 3 | 2694044462 |
| A Good Shout | Weapon | Combat Bow | — | 5 | 3615748501 |
| Holless-IV | Weapon | Combat Bow | — | 4 | 3651075426 |
| Equinox Tsu | Weapon | Fusion Rifle | — | 3 | 1393021133 |
| Monody-44 | Weapon | Fusion Rifle | — | 5 | 3201200906 |
| Nox Calyx II | Weapon | Fusion Rifle | — | 3 | 1393021135 |
| Nox Cordis II | Weapon | Fusion Rifle | — | 4 | 3441197112 |
| Nox Cordis II | Weapon | Fusion Rifle | — | 4 | 3662200189 |
| Nox Lumen II | Weapon | Fusion Rifle | — | 4 | 3441197113 |
| Nox Lumen II | Weapon | Fusion Rifle | — | 4 | 3662200188 |
| Nox Reve II | Weapon | Fusion Rifle | — | 3 | 1393021134 |
| Nox Sidereal IV | Weapon | Fusion Rifle | — | 5 | 2875763009 |
| Parsec TSu | Weapon | Fusion Rifle | — | 4 | 3441197115 |
| Parsec TSu | Weapon | Fusion Rifle | — | 4 | 3662200190 |
| TAHOMA 01 | Weapon | Fusion Rifle | — | 5 | 1225851434 |
| Hadrian-A | Weapon | Grenade Launcher | — | 3 | 3246523828 |
| Motif-41 | Weapon | Grenade Launcher | — | 5 | 1685533876 |
| Ouster Engine | Weapon | Grenade Launcher | — | 5 | 2223968549 |
| Para Torus I | Weapon | Grenade Launcher | — | 3 | 3246523831 |
| Plemusa-B | Weapon | Grenade Launcher | — | 4 | 3493948735 |
| Plemusa-B | Weapon | Grenade Launcher | — | 4 | 1120843238 |
| Resilient People | Weapon | Grenade Launcher | — | 3 | 3246523829 |
| Stampede Mk.32 | Weapon | Grenade Launcher | — | 4 | 3493948734 |
| Stampede Mk.32 | Weapon | Grenade Launcher | — | 4 | 1120843239 |
| Stay Away | Weapon | Grenade Launcher | — | 2 | 2734369894 |
| Allegro-34 | Weapon | Hand Cannon | — | 4 | 2591586260 |
| Allegro-34 | Weapon | Hand Cannon | — | 4 | 653875715 |
| Azimuth DSu | Weapon | Hand Cannon | — | 4 | 2591586261 |
| Azimuth DSu | Weapon | Hand Cannon | — | 4 | 653875714 |
| Ballyhoo Mk.27 | Weapon | Hand Cannon | — | 4 | 2591586263 |
| Ballyhoo Mk.27 | Weapon | Hand Cannon | — | 4 | 653875712 |
| Headstrong | Weapon | Hand Cannon | — | 2 | 2553946496 |
| Helios HC1 | Weapon | Hand Cannon | — | 2 | 2553946497 |
| IRONWOOD 03 | Weapon | Hand Cannon | — | 5 | 2041617874 |
| Lamia HC2 | Weapon | Hand Cannon | — | 4 | 2591586262 |
| Lamia HC2 | Weapon | Hand Cannon | — | 4 | 653875713 |
| Minuet-12 | Weapon | Hand Cannon | — | 3 | 3185293914 |
| Mos Athanor IV | Weapon | Hand Cannon | — | 5 | 4118334987 |
| Mos Ultima II | Weapon | Hand Cannon | — | 3 | 3185293912 |
| One Earth | Weapon | Hand Cannon | — | 3 | 3185293913 |
| Picayune Mk. 33 | Weapon | Hand Cannon | — | 3 | 3185293915 |
| Sarpedon-D | Weapon | Hand Cannon | — | 5 | 1242785638 |
| Solemn Lie | Weapon | Hand Cannon | — | 5 | 1041028435 |
| Willful Hamartia | Weapon | Linear Fusion Rifle | — | 5 | 1952295804 |
| DIABLERETS 06 | Weapon | Machine Gun | — | 5 | 1120206506 |
| Exitus Mk.I | Weapon | Machine Gun | — | 4 | 3117873459 |
| Qua Vinctus IV | Weapon | Machine Gun | — | 5 | 337893613 |
| Agrona PR2 | Weapon | Pulse Rifle | — | 4 | 1669771781 |
| Agrona PR2 | Weapon | Pulse Rifle | — | 4 | 1678957658 |
| Bayesian MSu | Weapon | Pulse Rifle | — | 4 | 1669771783 |
| Bayesian MSu | Weapon | Pulse Rifle | — | 4 | 1678957656 |
| Cadenza-11 | Weapon | Pulse Rifle | — | 3 | 2213848861 |
| Encore-25 | Weapon | Pulse Rifle | — | 4 | 1669771780 |
| Encore-25 | Weapon | Pulse Rifle | — | 4 | 1678957659 |
| Lost and Found | Weapon | Pulse Rifle | — | 2 | 3569842567 |
| Psi Aeterna IV | Weapon | Pulse Rifle | — | 5 | 3556730800 |
| Psi Cirrus II | Weapon | Pulse Rifle | — | 4 | 1669771782 |
| Psi Cirrus II | Weapon | Pulse Rifle | — | 4 | 1678957657 |
| Psi Ferox II | Weapon | Pulse Rifle | — | 3 | 2213848863 |
| Psi Termina II | Weapon | Pulse Rifle | — | 3 | 2213848860 |
| Standing Tall | Weapon | Pulse Rifle | — | 3 | 2213848862 |
| Butler RS/2 | Weapon | Rocket Launcher | — | 3 | 2037589099 |
| Cup-Bearer SA/2 | Weapon | Rocket Launcher | — | 4 | 4221925398 |
| Cup-Bearer SA/2 | Weapon | Rocket Launcher | — | 4 | 1877183765 |
| Reginar-B | Weapon | Rocket Launcher | — | 4 | 4221925399 |
| Reginar-B | Weapon | Rocket Launcher | — | 4 | 1877183764 |
| Armillary PSu | Weapon | Scout Rifle | — | 4 | 3906357379 |
| Armillary PSu | Weapon | Scout Rifle | — | 4 | 1650626964 |
| Black Tiger-2sr | Weapon | Scout Rifle | — | 4 | 3906357378 |
| Black Tiger-2sr | Weapon | Scout Rifle | — | 4 | 1650626965 |
| Fare-Thee-Well | Weapon | Scout Rifle | — | 3 | 3361694401 |
| Inverness-SR2 | Weapon | Scout Rifle | — | 3 | 3361694403 |
| Madrugada SR2 | Weapon | Scout Rifle | — | 4 | 3906357376 |
| Madrugada SR2 | Weapon | Scout Rifle | — | 4 | 1650626967 |
| Sea Scorpion-1sr | Weapon | Scout Rifle | — | 3 | 3361694402 |
| Thistle and Yew | Weapon | Scout Rifle | — | 2 | 3550697748 |
| Trax Arda II | Weapon | Scout Rifle | — | 3 | 3361694400 |
| Trax Lysis II | Weapon | Scout Rifle | — | 4 | 3906357377 |
| Trax Lysis II | Weapon | Scout Rifle | — | 4 | 1650626966 |
| Badlands Mk.24 | Weapon | Shotgun | — | 4 | 1457394911 |
| Badlands Mk.24 | Weapon | Shotgun | — | 4 | 1995011456 |
| Botheration Mk.28 | Weapon | Shotgun | — | 4 | 1457394910 |
| Botheration Mk.28 | Weapon | Shotgun | — | 4 | 1995011457 |
| Ded Acumen II | Weapon | Shotgun | — | 3 | 4138415949 |
| Ded Nemoris II | Weapon | Shotgun | — | 3 | 4138415950 |
| Fussed Dark Mk.21 | Weapon | Shotgun | — | 4 | 1457394908 |
| Fussed Dark Mk.21 | Weapon | Shotgun | — | 4 | 1995011459 |
| Stubborn Oak | Weapon | Shotgun | — | 2 | 1977926913 |
| Dissonance-34 | Weapon | Sidearm | — | 4 | 3809805228 |
| Dissonance-34 | Weapon | Sidearm | — | 4 | 711899775 |
| Evening SI4 | Weapon | Sidearm | — | 5 | 1763361847 |
| Recital-17 | Weapon | Sidearm | — | 3 | 1310413524 |
| Requiem SI2 | Weapon | Sidearm | — | 4 | 3809805229 |
| Requiem SI2 | Weapon | Sidearm | — | 4 | 711899774 |
| Roderic-C | Weapon | Sidearm | — | 4 | 3809805230 |
| Roderic-C | Weapon | Sidearm | — | 4 | 711899773 |
| Spiderbite-1si | Weapon | Sidearm | — | 2 | 3792720684 |
| Victoire SI2 | Weapon | Sidearm | — | 3 | 1310413525 |
| Vinegaroon-2si | Weapon | Sidearm | — | 4 | 3809805231 |
| Vinegaroon-2si | Weapon | Sidearm | — | 4 | 711899772 |
| Aachen-LR2 | Weapon | Sniper Rifle | — | 4 | 4157959958 |
| Aachen-LR2 | Weapon | Sniper Rifle | — | 4 | 1177293327 |
| ALLEN 05 | Weapon | Sniper Rifle | — | 5 | 423677697 |
| Damietta-LR2 | Weapon | Sniper Rifle | — | 4 | 4157959959 |
| Damietta-LR2 | Weapon | Sniper Rifle | — | 4 | 1177293326 |
| Luna Nullis II | Weapon | Sniper Rifle | — | 3 | 2605790033 |
| Refurbished A499 | Weapon | Sniper Rifle | — | 5 | 3661051060 |
| Something Something | Weapon | Sniper Rifle | — | 5 | 3421075982 |
| The Helmsman | Weapon | Sniper Rifle | — | 5 | 2325078119 |
| Tongeren-LR3 | Weapon | Sniper Rifle | — | 4 | 4157959956 |
| Tongeren-LR3 | Weapon | Sniper Rifle | — | 4 | 1177293325 |
| Trondheim-LR2 | Weapon | Sniper Rifle | — | 3 | 2605790034 |
| Troubadour | Weapon | Sniper Rifle | — | 3 | 2605790032 |
| Daystar SMG2 | Weapon | Submachine Gun | — | 3 | 531591353 |
| DEADHORSE 04 | Weapon | Submachine Gun | — | 5 | 822872238 |
| Etude-12 | Weapon | Submachine Gun | — | 2 | 772531208 |
| Forte-15 | Weapon | Submachine Gun | — | 3 | 531591352 |
| Furina-2mg | Weapon | Submachine Gun | — | 4 | 3383958217 |
| Furina-2mg | Weapon | Submachine Gun | — | 4 | 1281822858 |
| Harmony-21 | Weapon | Submachine Gun | — | 4 | 3383958216 |
| Harmony-21 | Weapon | Submachine Gun | — | 4 | 1281822859 |
| Peculiar Charm | Weapon | Submachine Gun | — | 5 | 3620277039 |
| Philippis-B | Weapon | Submachine Gun | — | 4 | 3383958218 |
| Philippis-B | Weapon | Submachine Gun | — | 4 | 1281822857 |
| Protostar CSu | Weapon | Submachine Gun | — | 4 | 3383958219 |
| Protostar CSu | Weapon | Submachine Gun | — | 4 | 1281822856 |
| Whatchamacallit | Weapon | Submachine Gun | — | 5 | 357669417 |
| Eighty-Six | Weapon | Sword | — | 5 | 2344383760 |
| Future Imperfect | Weapon | Sword | — | 4 | 2891976012 |
| Future Imperfect | Weapon | Sword | — | 4 | 1447973651 |
| Rest for the Wicked | Weapon | Sword | — | 4 | 2891976013 |
| Rest for the Wicked | Weapon | Sword | — | 4 | 1447973650 |


## A2. Likely NOT obtainable — high confidence (15)

| Name | Kind | Type | Class | Tier | Item Hash |
|---|---|---|---|---:|---|
| The Outlander's Heart | Armor | Chest Armor | Hunter | 4 | 748214628 |
| The Outlander's Grip | Armor | Gauntlets | Hunter | 4 | 1567215868 |
| The Outlander's Cover | Armor | Helmet | Hunter | 4 | 914653197 |
| The Outlander's Cloak | Armor | Hunter Cloak | Hunter | 4 | 1916502201 |
| The Outlander's Steps | Armor | Leg Armor | Hunter | 4 | 570143750 |
| Hardcase Battleplate | Armor | Chest Armor | Titan | 4 | 3152414792 |
| Hardcase Brawlers | Armor | Gauntlets | Titan | 4 | 2252742528 |
| Hardcase Helm | Armor | Helmet | Titan | 4 | 549246985 |
| Hardcase Stompers | Armor | Leg Armor | Titan | 4 | 1330563002 |
| Mark of Confrontation | Armor | Titan Mark | Titan | 4 | 984002469 |
| Farseeker's Intuition | Armor | Chest Armor | Warlock | 4 | 1576992137 |
| Farseeker's Reach | Armor | Gauntlets | Warlock | 4 | 460400687 |
| Farseeker's Casque | Armor | Helmet | Warlock | 4 | 1232004606 |
| Farseeker's March | Armor | Leg Armor | Warlock | 4 | 610443345 |
| Stagnatious Rebuke | Armor | Warlock Bond | Warlock | 4 | 3357295428 |


---

# Group B — items with an empty source string

The collectible exists but its `sourceString` is blank. 21 items.

## B1. Likely obtainable — review candidates (21)

| Name | Kind | Type | Class | Tier | Item Hash |
|---|---|---|---|---:|---|
| Veteran Legend vest | Armor | Chest Armor | Hunter | 5 | 3465152776 |
| Veteran Legend Grasps | Armor | Gauntlets | Hunter | 5 | 2920433728 |
| Veteran Legend Casque | Armor | Helmet | Hunter | 5 | 1216938185 |
| Veteran Legend Cloak | Armor | Hunter Cloak | Hunter | 5 | 872282981 |
| Veteran Legend Strides | Armor | Leg Armor | Hunter | 5 | 1615373434 |
| Veteran Legend Plate | Armor | Chest Armor | Titan | 5 | 2183976852 |
| Veteran Legend Gauntlets | Armor | Gauntlets | Titan | 5 | 1800866764 |
| Veteran Legend Helm | Armor | Helmet | Titan | 5 | 2913980509 |
| Veteran Legend Greaves | Armor | Leg Armor | Titan | 5 | 2446702198 |
| Veteran Legend Mark | Armor | Titan Mark | Titan | 5 | 3352264425 |
| Veteran Legend Robes | Armor | Chest Armor | Warlock | 5 | 2813298149 |
| Veteran Legend Gloves | Armor | Gauntlets | Warlock | 5 | 11926187 |
| Veteran Legend Hood | Armor | Helmet | Warlock | 5 | 672281666 |
| Veteran Legend Boots | Armor | Leg Armor | Warlock | 5 | 1486564541 |
| Veteran Legend Bond | Armor | Warlock Bond | Warlock | 5 | 1469212984 |
| Cull's Shadow | Weapon | Fusion Rifle | — | 6 | 2200470033 |
| Targeted Redaction | Weapon | Hand Cannon | — | 5 | 3890055324 |
| Different Times | Weapon | Pulse Rifle | — | 5 | 3016891299 |
| A Distant Pull | Weapon | Sniper Rifle | — | 5 | 1769847435 |
| Thin Precipice | Weapon | Sword | — | 5 | 4066778670 |
| Wolfsbane | Weapon | Sword | — | 6 | 1753923263 |


## B2. Likely NOT obtainable — high confidence (0)

_None._


---

# Group C — items with no collectible at all

No Collections entry, so nothing to resolve. As expected this group is dominated
by not-obtainable gear (old reissues already dropped; the rest are sunset
variants, placeholders, and pre-watermark gear). 464 items after
dropping reissues.

> **Read this group with extra skepticism.** Even the "likely obtainable" side
> here is weaker than in Groups A/B — a no-collectible item is *more* likely to be
> a manifest ghost, since current gear almost always has a collectible. Treat C1
> as "not yet ruled out," not "probably obtainable."

## C1. Not ruled out — needs review (392)

| Name | Kind | Type | Class | Tier | Item Hash |
|---|---|---|---|---:|---|
| Daring Hunter Vest | Armor | Chest Armor | Hunter | 2 | 2261200416 |
| Daring Hunter Vest | Armor | Chest Armor | Hunter | 2 | 3640744220 |
| Flowing Vest | Armor | Chest Armor | Hunter | 5 | 548290754 |
| Flowing Vest | Armor | Chest Armor | Hunter | 5 | 773318266 |
| Kit Fox 1.4 | Armor | Chest Armor | Hunter | 3 | 3877365781 |
| Makeshift Suit | Armor | Chest Armor | Hunter | 3 | 2363903643 |
| Mechanik 2.1 | Armor | Chest Armor | Hunter | 3 | 3790903614 |
| Mythos Hack 4.1 | Armor | Chest Armor | Hunter | 4 | 3264653916 |
| Mythos Hack 4.1 | Armor | Chest Armor | Hunter | 4 | 747210772 |
| Mythos Hack 4.1 | Armor | Chest Armor | Hunter | 4 | 1658512403 |
| Refugee Vest | Armor | Chest Armor | Hunter | 2 | 2985655620 |
| Scavenger Suit | Armor | Chest Armor | Hunter | 3 | 857264972 |
| Scorched Hunter Vest | Armor | Chest Armor | Hunter | 2 | 1363280826 |
| Scorched Hunter Vest | Armor | Chest Armor | Hunter | 2 | 2044322464 |
| Shadow Specter | Armor | Chest Armor | Hunter | 4 | 3035240099 |
| Shadow Specter | Armor | Chest Armor | Hunter | 4 | 3309120116 |
| Shadow Specter | Armor | Chest Armor | Hunter | 4 | 3585730968 |
| The Outlander's Heart | Armor | Chest Armor | Hunter | 4 | 897275209 |
| The Outlander's Heart | Armor | Chest Armor | Hunter | 4 | 1701236611 |
| War Mantis | Armor | Chest Armor | Hunter | 4 | 3212340413 |
| War Mantis | Armor | Chest Armor | Hunter | 4 | 4155348771 |
| War Mantis | Armor | Chest Armor | Hunter | 4 | 1118437892 |
| Wastelander Vest | Armor | Chest Armor | Hunter | 2 | 397654099 |
| Daring Hunter Grips | Armor | Gauntlets | Hunter | 2 | 1961777956 |
| Daring Hunter Grips | Armor | Gauntlets | Hunter | 2 | 1961861544 |
| Flowing Grips | Armor | Gauntlets | Hunter | 5 | 2641591726 |
| Flowing Grips | Armor | Gauntlets | Hunter | 5 | 945907382 |
| Kit Fox 2.1 | Armor | Gauntlets | Hunter | 3 | 648638907 |
| Makeshift Suit | Armor | Gauntlets | Hunter | 3 | 648022469 |
| Mechanik 1.1 | Armor | Gauntlets | Hunter | 3 | 844823562 |
| Mythos Hack 4.1 | Armor | Gauntlets | Hunter | 4 | 423789 |
| Mythos Hack 4.1 | Armor | Gauntlets | Hunter | 4 | 1045948748 |
| Mythos Hack 4.1 | Armor | Gauntlets | Hunter | 4 | 1365739620 |
| Refugee Gloves | Armor | Gauntlets | Hunter | 2 | 1578478684 |
| Scavenger Suit | Armor | Gauntlets | Hunter | 3 | 4091127092 |
| Scorched Hunter Grips | Armor | Gauntlets | Hunter | 2 | 3782032118 |
| Scorched Hunter Grips | Armor | Gauntlets | Hunter | 2 | 389344040 |
| Shadow Specter | Armor | Gauntlets | Hunter | 4 | 3160437036 |
| Shadow Specter | Armor | Gauntlets | Hunter | 4 | 124410141 |
| Shadow Specter | Armor | Gauntlets | Hunter | 4 | 418611312 |
| The Outlander's Grip | Armor | Gauntlets | Hunter | 4 | 3174394351 |
| The Outlander's Grip | Armor | Gauntlets | Hunter | 4 | 1556652797 |
| War Mantis | Armor | Gauntlets | Hunter | 4 | 2230522771 |
| War Mantis | Armor | Gauntlets | Hunter | 4 | 2476964124 |
| War Mantis | Armor | Gauntlets | Hunter | 4 | 803939997 |
| Wastelander Wraps | Armor | Gauntlets | Hunter | 2 | 2930768301 |
| Daring Hunter Mask | Armor | Helmet | Hunter | 2 | 3285934677 |
| Daring Hunter Mask | Armor | Helmet | Hunter | 2 | 3303733201 |
| Flowing Cowl | Armor | Helmet | Hunter | 5 | 3127319343 |
| Flowing Cowl | Armor | Helmet | Hunter | 5 | 400025383 |
| Frumious Mask | Armor | Helmet | Hunter | 5 | 4248632159 |
| Frumious Mask | Armor | Helmet | Hunter | 5 | 558125905 |
| Kit Fox 1.5 | Armor | Helmet | Hunter | 3 | 182285650 |
| Makeshift Suit | Armor | Helmet | Hunter | 3 | 1452147980 |
| Mechanik 1.2 | Armor | Helmet | Hunter | 3 | 3639035739 |
| Mythos Hack 4.1 | Armor | Helmet | Hunter | 4 | 2159062493 |
| Mythos Hack 4.1 | Armor | Helmet | Hunter | 4 | 2689896341 |
| Mythos Hack 4.1 | Armor | Helmet | Hunter | 4 | 1169595348 |
| Refugee Mask | Armor | Helmet | Hunter | 2 | 459778797 |
| Scavenger Suit | Armor | Helmet | Hunter | 3 | 3310450277 |
| Scorched Hunter Mask | Armor | Helmet | Hunter | 2 | 1202339439 |
| Scorched Hunter Mask | Armor | Helmet | Hunter | 2 | 1731215697 |
| Shadow Specter | Armor | Helmet | Hunter | 4 | 177215556 |
| Shadow Specter | Armor | Helmet | Hunter | 4 | 402937789 |
| Shadow Specter | Armor | Helmet | Hunter | 4 | 905249529 |
| The Outlander's Cover | Armor | Helmet | Hunter | 4 | 3904524734 |
| The Outlander's Cover | Armor | Helmet | Hunter | 4 | 1992338980 |
| War Mantis | Armor | Helmet | Hunter | 4 | 2183384906 |
| War Mantis | Armor | Helmet | Hunter | 4 | 856745412 |
| War Mantis | Armor | Helmet | Hunter | 4 | 1824298413 |
| Wastelander Mask | Armor | Helmet | Hunter | 2 | 4100043028 |
| Airhead Hood | Armor | Hunter Cloak | Hunter | 5 | 2751794833 |
| Airhead Hood | Armor | Hunter Cloak | Hunter | 5 | 3002815194 |
| Airhead Hood | Armor | Hunter Cloak | Hunter | 5 | 1504041928 |
| All-Star Cloak | Armor | Hunter Cloak | Hunter | 5 | 1520144521 |
| At Least It's a Cape | Armor | Hunter Cloak | Hunter | 3 | 720723122 |
| Cloak Judgment | Armor | Hunter Cloak | Hunter | 5 | 238320915 |
| Cloak Judgment | Armor | Hunter Cloak | Hunter | 5 | 421771595 |
| Cloak of Retelling | Armor | Hunter Cloak | Hunter | 4 | 4288395850 |
| Cloak of Retelling | Armor | Hunter Cloak | Hunter | 4 | 255520209 |
| Cloak of Retelling | Armor | Hunter Cloak | Hunter | 4 | 1915498345 |
| Daring Hunter Cloak | Armor | Hunter Cloak | Hunter | 2 | 1056171153 |
| Daring Hunter Cloak | Armor | Hunter Cloak | Hunter | 2 | 1188458845 |
| Holeshot Cloak | Armor | Hunter Cloak | Hunter | 5 | 2751794832 |
| Holeshot Cloak | Armor | Hunter Cloak | Hunter | 5 | 3002815195 |
| Hood of Tallies | Armor | Hunter Cloak | Hunter | 3 | 3544884935 |
| Hunter Cloak | Armor | Hunter Cloak | Hunter | 2 | 1364005110 |
| Refugee Cloak | Armor | Hunter Cloak | Hunter | 2 | 4195519897 |
| Renegade Hood | Armor | Hunter Cloak | Hunter | 2 | 2644553610 |
| Scavenger Cloak | Armor | Hunter Cloak | Hunter | 3 | 3556023425 |
| Scorched Hunter Cloak | Armor | Hunter Cloak | Hunter | 2 | 587276683 |
| Scorched Hunter Cloak | Armor | Hunter Cloak | Hunter | 2 | 971580893 |
| Shadow Specter | Armor | Hunter Cloak | Hunter | 4 | 2317046938 |
| Shadow Specter | Armor | Hunter Cloak | Hunter | 4 | 4052950089 |
| Shadow Specter | Armor | Hunter Cloak | Hunter | 4 | 1981225397 |
| Sly Cloak | Armor | Hunter Cloak | Hunter | 3 | 2574857320 |
| The Outlander's Cloak | Armor | Hunter Cloak | Hunter | 4 | 2211544324 |
| The Outlander's Cloak | Armor | Hunter Cloak | Hunter | 4 | 600059642 |
| War Mantis Cloak | Armor | Hunter Cloak | Hunter | 4 | 3437155610 |
| War Mantis Cloak | Armor | Hunter Cloak | Hunter | 4 | 420937712 |
| War Mantis Cloak | Armor | Hunter Cloak | Hunter | 4 | 1862164825 |
| Daring Hunter Strides | Armor | Leg Armor | Hunter | 2 | 2597269762 |
| Daring Hunter Strides | Armor | Leg Armor | Hunter | 2 | 3892423886 |
| Flowing Boots | Armor | Leg Armor | Hunter | 5 | 2158289680 |
| Flowing Boots | Armor | Leg Armor | Hunter | 5 | 854160040 |
| Kit Fox 1.1 | Armor | Leg Armor | Hunter | 3 | 3352069677 |
| Makeshift Suit | Armor | Leg Armor | Hunter | 3 | 995248967 |
| Mechanik 1.1 | Armor | Leg Armor | Hunter | 3 | 4179002916 |
| Mythos Hack 4.1 | Armor | Leg Armor | Hunter | 4 | 2871824910 |
| Mythos Hack 4.1 | Armor | Leg Armor | Hunter | 4 | 246765359 |
| Mythos Hack 4.1 | Armor | Leg Armor | Hunter | 4 | 1691784182 |
| Refugee Boots | Armor | Leg Armor | Hunter | 2 | 539726822 |
| Scavenger Suit | Armor | Leg Armor | Hunter | 3 | 83898430 |
| Scorched Hunter Strides | Armor | Leg Armor | Hunter | 2 | 699343952 |
| Scorched Hunter Strides | Armor | Leg Armor | Hunter | 2 | 1024752258 |
| Shadow Specter | Armor | Leg Armor | Hunter | 4 | 4230626646 |
| Shadow Specter | Armor | Leg Armor | Hunter | 4 | 735669834 |
| Shadow Specter | Armor | Leg Armor | Hunter | 4 | 2065578431 |
| The Outlander's Steps | Armor | Leg Armor | Hunter | 4 | 3748997649 |
| The Outlander's Steps | Armor | Leg Armor | Hunter | 4 | 3880804895 |
| War Mantis | Armor | Leg Armor | Hunter | 4 | 2745108287 |
| War Mantis | Armor | Leg Armor | Hunter | 4 | 1479892134 |
| War Mantis | Armor | Leg Armor | Hunter | 4 | 1965476837 |
| Wastelander Boots | Armor | Leg Armor | Hunter | 2 | 3643144047 |
| Atgeir 2T1 | Armor | Chest Armor | Titan | 3 | 703683040 |
| Brave Titan Plate | Armor | Chest Armor | Titan | 2 | 722380134 |
| Brave Titan Plate | Armor | Chest Armor | Titan | 2 | 1816178788 |
| Crushing Plate | Armor | Chest Armor | Titan | 5 | 784751926 |
| Crushing Plate | Armor | Chest Armor | Titan | 5 | 934145080 |
| Fieldplate Type 10 | Armor | Chest Armor | Titan | 3 | 846463017 |
| Firebreak Field | Armor | Chest Armor | Titan | 3 | 3523134386 |
| Fortress Field | Armor | Chest Armor | Titan | 3 | 226227391 |
| Hardcase Battleplate | Armor | Chest Armor | Titan | 4 | 3885104741 |
| Hardcase Battleplate | Armor | Chest Armor | Titan | 4 | 201644247 |
| Legion-Bane | Armor | Chest Armor | Titan | 4 | 3183585337 |
| Legion-Bane | Armor | Chest Armor | Titan | 4 | 3656549306 |
| Legion-Bane | Armor | Chest Armor | Titan | 4 | 1775818231 |
| Primal Siege Type 1 | Armor | Chest Armor | Titan | 4 | 3163241201 |
| Primal Siege Type 1 | Armor | Chest Armor | Titan | 4 | 463563656 |
| Primal Siege Type 1 | Armor | Chest Armor | Titan | 4 | 1912568536 |
| Refugee Plate | Armor | Chest Armor | Titan | 2 | 59990642 |
| Renegade Plate | Armor | Chest Armor | Titan | 2 | 2886651369 |
| RPC Valiant | Armor | Chest Armor | Titan | 4 | 2739875972 |
| RPC Valiant | Armor | Chest Armor | Titan | 4 | 3007889693 |
| RPC Valiant | Armor | Chest Armor | Titan | 4 | 1484009400 |
| Wrecked Titan Plate | Armor | Chest Armor | Titan | 2 | 3663467820 |
| Wrecked Titan Plate | Armor | Chest Armor | Titan | 2 | 2134070164 |
| Atgeir 2T1 | Armor | Gauntlets | Titan | 3 | 3650925928 |
| Brave Titan Gauntlets | Armor | Gauntlets | Titan | 2 | 2166685180 |
| Brave Titan Gauntlets | Armor | Gauntlets | Titan | 2 | 2448010882 |
| Crushing Guard | Armor | Gauntlets | Titan | 5 | 3025466098 |
| Crushing Guard | Armor | Gauntlets | Titan | 5 | 1863012880 |
| Fieldplate Type 10 | Armor | Gauntlets | Titan | 3 | 203317967 |
| Firebreak Field | Armor | Gauntlets | Titan | 3 | 516502270 |
| Fortress Field | Armor | Gauntlets | Titan | 3 | 627055961 |
| Hardcase Brawlers | Armor | Gauntlets | Titan | 4 | 3302420523 |
| Hardcase Brawlers | Armor | Gauntlets | Titan | 4 | 867963905 |
| Legion-Bane | Armor | Gauntlets | Titan | 4 | 2253044470 |
| Legion-Bane | Armor | Gauntlets | Titan | 4 | 2815743359 |
| Legion-Bane | Armor | Gauntlets | Titan | 4 | 3867725217 |
| Primal Siege Type 1 | Armor | Gauntlets | Titan | 4 | 4062934448 |
| Primal Siege Type 1 | Armor | Gauntlets | Titan | 4 | 392489920 |
| Primal Siege Type 1 | Armor | Gauntlets | Titan | 4 | 1665016007 |
| Refugee Gloves | Armor | Gauntlets | Titan | 2 | 452060094 |
| Renegade Gauntlets | Armor | Gauntlets | Titan | 2 | 3967705743 |
| RPC Valiant | Armor | Gauntlets | Titan | 4 | 2466525328 |
| RPC Valiant | Armor | Gauntlets | Titan | 4 | 3456147612 |
| RPC Valiant | Armor | Gauntlets | Titan | 4 | 739196403 |
| Wrecked Titan Gauntlets | Armor | Gauntlets | Titan | 2 | 3878952908 |
| Wrecked Titan Gauntlets | Armor | Gauntlets | Titan | 2 | 880861204 |
| Atgeir 2T1 | Armor | Helmet | Titan | 3 | 739406993 |
| Brave Titan Helm | Armor | Helmet | Titan | 2 | 660037107 |
| Brave Titan Helm | Armor | Helmet | Titan | 2 | 1514122509 |
| Crushing Helm | Armor | Helmet | Titan | 5 | 2391227801 |
| Crushing Helm | Armor | Helmet | Titan | 5 | 1929400867 |
| Fieldplate Type 10 | Armor | Helmet | Titan | 3 | 933345182 |
| Firebreak Field | Armor | Helmet | Titan | 3 | 1443091319 |
| Fortress Field | Armor | Helmet | Titan | 3 | 1279721672 |
| Hardcase Helm | Armor | Helmet | Titan | 4 | 3962776002 |
| Hardcase Helm | Armor | Helmet | Titan | 4 | 1070180272 |
| Legion-Bane | Armor | Helmet | Titan | 4 | 3968319087 |
| Legion-Bane | Armor | Helmet | Titan | 4 | 4069941456 |
| Legion-Bane | Armor | Helmet | Titan | 4 | 1365979278 |
| Primal Siege Type 1 | Armor | Helmet | Titan | 4 | 2983961673 |
| Primal Siege Type 1 | Armor | Helmet | Titan | 4 | 4166795065 |
| Primal Siege Type 1 | Armor | Helmet | Titan | 4 | 461025654 |
| Refugee Helm | Armor | Helmet | Titan | 2 | 1378545975 |
| Renegade Helm | Armor | Helmet | Titan | 2 | 868799838 |
| RPC Valiant | Armor | Helmet | Titan | 4 | 2803481901 |
| RPC Valiant | Armor | Helmet | Titan | 4 | 2994740249 |
| RPC Valiant | Armor | Helmet | Titan | 4 | 733635242 |
| Wrecked Titan Helm | Armor | Helmet | Titan | 2 | 141761093 |
| Wrecked Titan Helm | Armor | Helmet | Titan | 2 | 697099357 |
| Atgeir 2T1 | Armor | Leg Armor | Titan | 3 | 457297858 |
| Brave Titan Greaves | Armor | Leg Armor | Titan | 2 | 238766140 |
| Brave Titan Greaves | Armor | Leg Armor | Titan | 2 | 1169613062 |
| Crushing Greaves | Armor | Leg Armor | Titan | 5 | 2221648234 |
| Crushing Greaves | Armor | Leg Armor | Titan | 5 | 3426704396 |
| Fieldplate Type 10 | Armor | Leg Armor | Titan | 3 | 777818225 |
| Firebreak Field | Armor | Leg Armor | Titan | 3 | 1360445272 |
| Fortress Field | Armor | Leg Armor | Titan | 3 | 3519241547 |
| Hardcase Stompers | Armor | Leg Armor | Titan | 4 | 2362809459 |
| Hardcase Stompers | Armor | Leg Armor | Titan | 4 | 482091581 |
| Legion-Bane | Armor | Leg Armor | Titan | 4 | 3465323600 |
| Legion-Bane | Armor | Leg Armor | Titan | 4 | 643145875 |
| Legion-Bane | Armor | Leg Armor | Titan | 4 | 1736993473 |
| Primal Siege Type 1 | Armor | Leg Armor | Titan | 4 | 3382396922 |
| Primal Siege Type 1 | Armor | Leg Armor | Titan | 4 | 126602378 |
| Primal Siege Type 1 | Armor | Leg Armor | Titan | 4 | 417821705 |
| Refugee Boots | Armor | Leg Armor | Titan | 2 | 871442456 |
| Renegade Greaves | Armor | Leg Armor | Titan | 2 | 288815409 |
| RPC Valiant | Armor | Leg Armor | Titan | 4 | 2459075622 |
| RPC Valiant | Armor | Leg Armor | Titan | 4 | 2825160682 |
| RPC Valiant | Armor | Leg Armor | Titan | 4 | 474150341 |
| Wrecked Titan Greaves | Armor | Leg Armor | Titan | 2 | 229821046 |
| Wrecked Titan Greaves | Armor | Leg Armor | Titan | 2 | 744142366 |
| All-Star Mark | Armor | Titan Mark | Titan | 5 | 3159160837 |
| Atgeir Mark | Armor | Titan Mark | Titan | 3 | 13719069 |
| Baseline Mark | Armor | Titan Mark | Titan | 4 | 2165661157 |
| Baseline Mark | Armor | Titan Mark | Titan | 4 | 732520437 |
| Baseline Mark | Armor | Titan Mark | Titan | 4 | 1022126988 |
| Black Shield Mark | Armor | Titan Mark | Titan | 4 | 2880545163 |
| Black Shield Mark | Armor | Titan Mark | Titan | 4 | 3438103366 |
| Black Shield Mark | Armor | Titan Mark | Titan | 4 | 202783988 |
| Brave Titan's Mark | Armor | Titan Mark | Titan | 2 | 2984466361 |
| Brave Titan's Mark | Armor | Titan Mark | Titan | 2 | 3538928634 |
| Brave Titan's Mark | Armor | Titan Mark | Titan | 2 | 1040474575 |
| Ere the End | Armor | Titan Mark | Titan | 5 | 249698875 |
| Ere the End | Armor | Titan Mark | Titan | 5 | 1700762222 |
| Ere the End | Armor | Titan Mark | Titan | 5 | 1809381922 |
| Mark Judgment | Armor | Titan Mark | Titan | 5 | 3624606677 |
| Mark Judgment | Armor | Titan Mark | Titan | 5 | 155955679 |
| Mark of Confrontation | Armor | Titan Mark | Titan | 4 | 2329963686 |
| Mark of Confrontation | Armor | Titan Mark | Titan | 4 | 2541019576 |
| Mark of Inquisition | Armor | Titan Mark | Titan | 4 | 3483602905 |
| Mark of Inquisition | Armor | Titan Mark | Titan | 4 | 4174470997 |
| Mark of Inquisition | Armor | Titan Mark | Titan | 4 | 174910288 |
| Mark of the Colliders | Armor | Titan Mark | Titan | 5 | 249698874 |
| Mark of the Colliders | Armor | Titan Mark | Titan | 5 | 1700762223 |
| Mark of the Colliders | Armor | Titan Mark | Titan | 5 | 1809381923 |
| Mark of the Fire | Armor | Titan Mark | Titan | 3 | 3693917763 |
| Mark of the Golden Citadel | Armor | Titan Mark | Titan | 3 | 1473385934 |
| Mark of the Longest Line | Armor | Titan Mark | Titan | 3 | 2626766308 |
| Mark of the Renegade | Armor | Titan Mark | Titan | 2 | 4200817316 |
| Refugee Mark | Armor | Titan Mark | Titan | 2 | 696808195 |
| Tattered Titan Mark | Armor | Titan Mark | Titan | 2 | 3302357737 |
| Tattered Titan Mark | Armor | Titan Mark | Titan | 2 | 2067155809 |
| Titan Mark | Armor | Titan Mark | Titan | 2 | 1844055850 |
| Aspirant Robes | Armor | Chest Armor | Warlock | 2 | 3468148580 |
| Atonement Tau | Armor | Chest Armor | Warlock | 4 | 3391214896 |
| Atonement Tau | Armor | Chest Armor | Warlock | 4 | 4035217656 |
| Atonement Tau | Armor | Chest Armor | Warlock | 4 | 91289429 |
| Channeling Robes | Armor | Chest Armor | Warlock | 5 | 72827963 |
| Channeling Robes | Armor | Chest Armor | Warlock | 5 | 891933383 |
| Chiron's Cure | Armor | Chest Armor | Warlock | 4 | 2937068650 |
| Chiron's Cure | Armor | Chest Armor | Warlock | 4 | 2943629439 |
| Chiron's Cure | Armor | Chest Armor | Warlock | 4 | 4177795589 |
| Cosmic Wind III | Armor | Chest Armor | Warlock | 3 | 2567295299 |
| Cry Defiance | Armor | Chest Armor | Warlock | 3 | 2803009638 |
| Damaged Warlock Robe | Armor | Chest Armor | Warlock | 2 | 2416634317 |
| Damaged Warlock Robe | Armor | Chest Armor | Warlock | 2 | 2422973919 |
| Farseeker's Intuition | Armor | Chest Armor | Warlock | 4 | 3061532064 |
| Farseeker's Intuition | Armor | Chest Armor | Warlock | 4 | 3958133156 |
| Prophet Snow | Armor | Chest Armor | Warlock | 4 | 341343759 |
| Prophet Snow | Armor | Chest Armor | Warlock | 4 | 387708030 |
| Prophet Snow | Armor | Chest Armor | Warlock | 4 | 1300106409 |
| Raven Shard | Armor | Chest Armor | Warlock | 3 | 4133705268 |
| Refugee Vest | Armor | Chest Armor | Warlock | 2 | 137713267 |
| Vector Home | Armor | Chest Armor | Warlock | 3 | 3403897789 |
| Wise Warlock Robes | Armor | Chest Armor | Warlock | 2 | 2209865285 |
| Wise Warlock Robes | Armor | Chest Armor | Warlock | 2 | 3997262569 |
| Aspirant Gloves | Armor | Gauntlets | Warlock | 2 | 3812037372 |
| Atonement Tau | Armor | Gauntlets | Warlock | 4 | 2339344379 |
| Atonement Tau | Armor | Gauntlets | Warlock | 4 | 3102366928 |
| Atonement Tau | Armor | Gauntlets | Warlock | 4 | 67798808 |
| Channeling Wraps | Armor | Gauntlets | Warlock | 5 | 4177448933 |
| Channeling Wraps | Armor | Gauntlets | Warlock | 5 | 530515217 |
| Chiron's Cure | Armor | Gauntlets | Warlock | 4 | 4267370571 |
| Chiron's Cure | Armor | Gauntlets | Warlock | 4 | 484126150 |
| Chiron's Cure | Armor | Gauntlets | Warlock | 4 | 833626649 |
| Cosmic Wind | Armor | Gauntlets | Warlock | 3 | 3260546749 |
| Cry Defiance | Armor | Gauntlets | Warlock | 3 | 76554114 |
| Damaged Warlock Gloves | Armor | Gauntlets | Warlock | 2 | 234415107 |
| Damaged Warlock Gloves | Armor | Gauntlets | Warlock | 2 | 236847737 |
| Farseeker's Reach | Armor | Gauntlets | Warlock | 4 | 3507639356 |
| Farseeker's Reach | Armor | Gauntlets | Warlock | 4 | 4281850920 |
| Prophet Snow | Armor | Gauntlets | Warlock | 4 | 2190967049 |
| Prophet Snow | Armor | Gauntlets | Warlock | 4 | 2959986506 |
| Prophet Snow | Armor | Gauntlets | Warlock | 4 | 881194063 |
| Raven Shard | Armor | Gauntlets | Warlock | 3 | 610837228 |
| Refugee Gloves | Armor | Gauntlets | Warlock | 2 | 911039437 |
| Vector Home | Armor | Gauntlets | Warlock | 3 | 2049820819 |
| Wise Warlock Gloves | Armor | Gauntlets | Warlock | 2 | 2421406347 |
| Wise Warlock Gloves | Armor | Gauntlets | Warlock | 2 | 1018337679 |
| Aspirant Helm | Armor | Helmet | Warlock | 2 | 3159474701 |
| Atonement Tau | Armor | Helmet | Warlock | 4 | 3164547673 |
| Atonement Tau | Armor | Helmet | Warlock | 4 | 3524846593 |
| Atonement Tau | Armor | Helmet | Warlock | 4 | 1872887954 |
| Channeling Cowl | Armor | Helmet | Warlock | 5 | 2964441920 |
| Channeling Cowl | Armor | Helmet | Warlock | 5 | 686607148 |
| Chiron's Cure | Armor | Helmet | Warlock | 4 | 550258943 |
| Chiron's Cure | Armor | Helmet | Warlock | 4 | 674335586 |
| Chiron's Cure | Armor | Helmet | Warlock | 4 | 1486292360 |
| Cosmic Wind | Armor | Helmet | Warlock | 3 | 3313352164 |
| Cry Defiance | Armor | Helmet | Warlock | 3 | 2583547635 |
| Damaged Warlock Hood | Armor | Helmet | Warlock | 2 | 2292007738 |
| Damaged Warlock Hood | Armor | Helmet | Warlock | 2 | 889513448 |
| Farseeker's Casque | Armor | Helmet | Warlock | 4 | 2854973517 |
| Farseeker's Casque | Armor | Helmet | Warlock | 4 | 1328755281 |
| Prophet Snow | Armor | Helmet | Warlock | 4 | 2151724216 |
| Prophet Snow | Armor | Helmet | Warlock | 4 | 1500704923 |
| Prophet Snow | Armor | Helmet | Warlock | 4 | 1611221278 |
| Raven Shard | Armor | Helmet | Warlock | 3 | 2148305277 |
| Refugee Helm | Armor | Helmet | Warlock | 2 | 2504771764 |
| Vector Home | Armor | Helmet | Warlock | 3 | 2002682954 |
| Wise Warlock Hood | Armor | Helmet | Warlock | 2 | 2214399070 |
| Wise Warlock Hood | Armor | Helmet | Warlock | 2 | 3081865122 |
| Aspirant Boots | Armor | Leg Armor | Warlock | 2 | 2814965254 |
| Atonement Tau | Armor | Leg Armor | Warlock | 4 | 2822491218 |
| Atonement Tau | Armor | Leg Armor | Warlock | 4 | 3419425578 |
| Atonement Tau | Armor | Leg Armor | Warlock | 4 | 789384557 |
| Channeling Treads | Armor | Leg Armor | Warlock | 5 | 4100217959 |
| Channeling Treads | Armor | Leg Armor | Warlock | 5 | 4232174819 |
| Chiron's Cure | Armor | Leg Armor | Warlock | 4 | 3725709067 |
| Chiron's Cure | Armor | Leg Armor | Warlock | 4 | 467612864 |
| Chiron's Cure | Armor | Leg Armor | Warlock | 4 | 1488618333 |
| Cosmic Wind III | Armor | Leg Armor | Warlock | 3 | 1331205087 |
| Cry Defiance | Armor | Leg Armor | Warlock | 3 | 2162276668 |
| Damaged Warlock Boots | Armor | Leg Armor | Warlock | 2 | 2579749301 |
| Damaged Warlock Boots | Armor | Leg Armor | Warlock | 2 | 3128930155 |
| Farseeker's March | Armor | Leg Armor | Warlock | 4 | 2893448006 |
| Farseeker's March | Armor | Leg Armor | Warlock | 4 | 622291842 |
| Prophet Snow | Armor | Leg Armor | Warlock | 4 | 2441435355 |
| Prophet Snow | Armor | Leg Armor | Warlock | 4 | 1455694321 |
| Prophet Snow | Armor | Leg Armor | Warlock | 4 | 1616317796 |
| Raven Shard | Armor | Leg Armor | Warlock | 3 | 1256569366 |
| Refugee Boots | Armor | Leg Armor | Warlock | 2 | 1581838479 |
| Vector Home | Armor | Leg Armor | Warlock | 3 | 1784774885 |
| Wise Warlock Boots | Armor | Leg Armor | Warlock | 2 | 3471587229 |
| Wise Warlock Boots | Armor | Leg Armor | Warlock | 2 | 1634414641 |
| All-Star Bond | Armor | Warlock Bond | Warlock | 5 | 3168934826 |
| Bond of Chiron | Armor | Warlock Bond | Warlock | 4 | 2833813592 |
| Bond of Chiron | Armor | Warlock Bond | Warlock | 4 | 3573886331 |
| Bond of Chiron | Armor | Warlock Bond | Warlock | 4 | 320174990 |
| Bond of Forgotten Wars | Armor | Warlock Bond | Warlock | 4 | 3080409700 |
| Bond of Forgotten Wars | Armor | Warlock Bond | Warlock | 4 | 4012302343 |
| Bond of Forgotten Wars | Armor | Warlock Bond | Warlock | 4 | 1630079134 |
| Bond of Insight | Armor | Warlock Bond | Warlock | 2 | 341468857 |
| Bond of Refuge | Armor | Warlock Bond | Warlock | 2 | 2343139242 |
| Bond of Symmetry | Armor | Warlock Bond | Warlock | 3 | 1848999098 |
| Bond of the Raven Shard | Armor | Warlock Bond | Warlock | 3 | 1048498953 |
| Fatum Praevaricator | Armor | Warlock Bond | Warlock | 4 | 2742930797 |
| Fatum Praevaricator | Armor | Warlock Bond | Warlock | 4 | 2813695893 |
| Fatum Praevaricator | Armor | Warlock Bond | Warlock | 4 | 3508205736 |
| Homeward | Armor | Warlock Bond | Warlock | 3 | 612495088 |
| Judgement's Wrap | Armor | Warlock Bond | Warlock | 5 | 3149072082 |
| Judgement's Wrap | Armor | Warlock Bond | Warlock | 5 | 1607431126 |
| Rite of Refusal | Armor | Warlock Bond | Warlock | 3 | 3121104079 |
| Shattered Warlock Bond | Armor | Warlock Bond | Warlock | 2 | 3670132590 |
| Shattered Warlock Bond | Armor | Warlock Bond | Warlock | 2 | 572122304 |
| Stagnatious Rebuke | Armor | Warlock Bond | Warlock | 4 | 406995961 |
| Stagnatious Rebuke | Armor | Warlock Bond | Warlock | 4 | 1988790493 |
| Tethering Void | Armor | Warlock Bond | Warlock | 5 | 243454056 |
| Tethering Void | Armor | Warlock Bond | Warlock | 5 | 1418191157 |
| The Beyond | Armor | Warlock Bond | Warlock | 5 | 2729305927 |
| The Beyond | Armor | Warlock Bond | Warlock | 5 | 243454057 |
| The Beyond | Armor | Warlock Bond | Warlock | 5 | 1418191156 |
| Warlock Bond | Armor | Warlock Bond | Warlock | 2 | 2969943001 |
| Wise Warlock Bond | Armor | Warlock Bond | Warlock | 2 | 1016461220 |
| Wise Warlock Bond | Armor | Warlock Bond | Warlock | 2 | 1331814296 |
| Rebuke AX-GL | Weapon | Auto Rifle | — | 4 | 2903592986 |
| A Good Shout | Weapon | Combat Bow | — | 5 | 649691506 |
| Nox Sidereal IV | Weapon | Fusion Rifle | — | 5 | 74733286 |
| Bushwhacker | Weapon | Grenade Launcher | — | 5 | 311852248 |
| Ouster Engine | Weapon | Grenade Launcher | — | 5 | 3718184802 |
| Judgment (Adept) | Weapon | Hand Cannon | — | 5 | 3329218848 |
| Judgment (Adept) | Weapon | Hand Cannon | — | 5 | 1987644603 |
| Mos Athanor IV | Weapon | Hand Cannon | — | 5 | 1288422452 |
| Presto-48 | Weapon | Hand Cannon | — | 4 | 1595336071 |
| Sarpedon-D | Weapon | Hand Cannon | — | 5 | 3318545829 |
| Dawn Far Off | Weapon | Machine Gun | — | 5 | 2770617440 |
| Dawn Far Off | Weapon | Machine Gun | — | 5 | 1484294659 |
| Qua Vinctus IV | Weapon | Machine Gun | — | 5 | 4176551594 |
| Psi Aeterna IV | Weapon | Pulse Rifle | — | 5 | 135971347 |
| Evening SI4 | Weapon | Sidearm | — | 5 | 3618823368 |
| Timecard | Weapon | Sidearm | — | 5 | 1648316470 |
| Rapid Growth | Weapon | Sniper Rifle | — | 5 | 3448712083 |
| Rapid Growth | Weapon | Sniper Rifle | — | 5 | 3856342856 |
| Refurbished A499 | Weapon | Sniper Rifle | — | 5 | 593808239 |
| Something Something | Weapon | Sniper Rifle | — | 5 | 690412397 |
| The Helmsman | Weapon | Sniper Rifle | — | 5 | 3215649176 |
| Whatchamacallit | Weapon | Submachine Gun | — | 5 | 149110926 |


## C2. Likely NOT obtainable — high confidence (72)

| Name | Kind | Type | Class | Tier | Item Hash |
|---|---|---|---|---:|---|
| Candescent Vest (Unkindled) | Armor | Chest Armor | Hunter | 5 | 177463495 |
| Chest Armor | Armor | Chest Armor | Hunter | 2 | 648507367 |
| Lustrous Vest (Unkindled) | Armor | Chest Armor | Hunter | 5 | 861860247 |
| Sunlit Vest (Unkindled) | Armor | Chest Armor | Hunter | 5 | 3987309016 |
| The Outlander's Heart | Armor | Chest Armor | Hunter | 4 | 3922069396 |
| Candescent Grips (Unkindled) | Armor | Gauntlets | Hunter | 5 | 2535002841 |
| Gauntlets | Armor | Gauntlets | Hunter | 2 | 2899766705 |
| Lustrous Grips (Unkindled) | Armor | Gauntlets | Hunter | 5 | 3268422857 |
| Sunlit Grips (Unkindled) | Armor | Gauntlets | Hunter | 5 | 3154193408 |
| The Outlander's Grip | Armor | Gauntlets | Hunter | 4 | 366418892 |
| Candescent Cloak (Unkindled) | Armor | Helmet | Hunter | 5 | 2840606178 |
| Helmet | Armor | Helmet | Hunter | 2 | 997252576 |
| Lustrous Casque (Unkindled) | Armor | Helmet | Hunter | 5 | 3755408274 |
| Sunlit Hood (Unkindled) | Armor | Helmet | Hunter | 5 | 3053891303 |
| The Outlander's Cover | Armor | Helmet | Hunter | 4 | 1479532637 |
| Candescent Strides (Unkindled) | Armor | Hunter Cloak | Hunter | 5 | 2160858284 |
| Lustrous Cloak (Unkindled) | Armor | Hunter Cloak | Hunter | 5 | 1376512508 |
| Sunlit Cloak (Unkindled) | Armor | Hunter Cloak | Hunter | 5 | 259522459 |
| The Outlander's Cloak | Armor | Hunter Cloak | Hunter | 4 | 795389673 |
| Candescent Mask (Unkindled) | Armor | Leg Armor | Hunter | 5 | 1743191871 |
| Leg Armor | Armor | Leg Armor | Hunter | 2 | 2731019523 |
| Lustrous Strides (Unkindled) | Armor | Leg Armor | Hunter | 5 | 3130152719 |
| Sunlit Strides (Unkindled) | Armor | Leg Armor | Hunter | 5 | 2339497078 |
| The Outlander's Steps | Armor | Leg Armor | Hunter | 4 | 1012254326 |
| Candescent Plate (Unkindled) | Armor | Chest Armor | Titan | 5 | 1947358241 |
| Chest Armor | Armor | Chest Armor | Titan | 2 | 3933597171 |
| Hardcase Battleplate | Armor | Chest Armor | Titan | 4 | 280187206 |
| Lustrous Plate (Unkindled) | Armor | Chest Armor | Titan | 5 | 2589289009 |
| Sunlit Plate (Unkindled) | Armor | Chest Armor | Titan | 5 | 3599356244 |
| Candescent Gauntlets (Unkindled) | Armor | Gauntlets | Titan | 5 | 2916149327 |
| Gauntlets | Armor | Gauntlets | Titan | 2 | 765924941 |
| Hardcase Brawlers | Armor | Gauntlets | Titan | 4 | 3763392098 |
| Lustrous Gauntlets (Unkindled) | Armor | Gauntlets | Titan | 5 | 4261618303 |
| Sunlit Gauntlets (Unkindled) | Armor | Gauntlets | Titan | 5 | 3769043228 |
| Candescent Mark (Unkindled) | Armor | Helmet | Titan | 5 | 3526595120 |
| Hardcase Helm | Armor | Helmet | Titan | 4 | 1933944659 |
| Helmet | Armor | Helmet | Titan | 2 | 2359657268 |
| Lustrous Helm (Unkindled) | Armor | Helmet | Titan | 5 | 2488007584 |
| Sunlit Helm (Unkindled) | Armor | Helmet | Titan | 5 | 985750811 |
| Candescent Helm (Unkindled) | Armor | Leg Armor | Titan | 5 | 2056606165 |
| Hardcase Stompers | Armor | Leg Armor | Titan | 4 | 1512570524 |
| Leg Armor | Armor | Leg Armor | Titan | 2 | 1436723983 |
| Lustrous Greaves (Unkindled) | Armor | Leg Armor | Titan | 5 | 3510701861 |
| Sunlit Greaves (Unkindled) | Armor | Leg Armor | Titan | 5 | 4221563250 |
| Candescent Greaves (Unkindled) | Armor | Titan Mark | Titan | 5 | 1103965354 |
| Lustrous Mark (Unkindled) | Armor | Titan Mark | Titan | 5 | 821031610 |
| Mark of Confrontation | Armor | Titan Mark | Titan | 4 | 598178607 |
| Sunlit Mark (Unkindled) | Armor | Titan Mark | Titan | 5 | 3744631007 |
| Candescent Robes (Unkindled) | Armor | Chest Armor | Warlock | 5 | 309633584 |
| Chest Armor | Armor | Chest Armor | Warlock | 2 | 2226216068 |
| Farseeker's Intuition | Armor | Chest Armor | Warlock | 4 | 721208609 |
| Lustrous Robes (Unkindled) | Armor | Chest Armor | Warlock | 5 | 1133567616 |
| Sunlit Robes (Unkindled) | Armor | Chest Armor | Warlock | 5 | 2189358721 |
| Candescent Gloves (Unkindled) | Armor | Gauntlets | Warlock | 5 | 2873900232 |
| Farseeker's Reach | Armor | Gauntlets | Warlock | 4 | 3349439959 |
| Gauntlets | Armor | Gauntlets | Warlock | 2 | 673268892 |
| Lustrous Sleeves (Unkindled) | Armor | Gauntlets | Warlock | 5 | 3863829688 |
| Sunlit Gloves (Unkindled) | Armor | Gauntlets | Warlock | 5 | 906505391 |
| Candescent Bond (Unkindled) | Armor | Helmet | Warlock | 5 | 3179985807 |
| Farseeker's Casque | Armor | Helmet | Warlock | 4 | 40512774 |
| Helmet | Armor | Helmet | Warlock | 2 | 20603181 |
| Lustrous Cover (Unkindled) | Armor | Helmet | Warlock | 5 | 3607796223 |
| Sunlit Mask (Unkindled) | Armor | Helmet | Warlock | 5 | 613984400 |
| Candescent Hood (Unkindled) | Armor | Leg Armor | Warlock | 5 | 1301766302 |
| Farseeker's March | Armor | Leg Armor | Warlock | 4 | 863007481 |
| Leg Armor | Armor | Leg Armor | Warlock | 2 | 3971164198 |
| Lustrous Boots (Unkindled) | Armor | Leg Armor | Warlock | 5 | 1977129966 |
| Sunlit Boots (Unkindled) | Armor | Leg Armor | Warlock | 5 | 1545181237 |
| Candescent Boots (Unkindled) | Armor | Warlock Bond | Warlock | 5 | 1372428179 |
| Lustrous Bond (Unkindled) | Armor | Warlock Bond | Warlock | 5 | 4180444323 |
| Stagnatious Rebuke | Armor | Warlock Bond | Warlock | 4 | 1503713660 |
| Sunlit Bond (Unkindled) | Armor | Warlock Bond | Warlock | 5 | 1002555530 |


---

# Summary

| Group | Likely obtainable / review | Likely NOT obtainable |
|---|---:|---:|
| A. Non-source note | 460 | 15 |
| B. Empty source string | 21 | 0 |
| C. No collectible | 392 | 72 |
| **Total** | **873** | **87** |

Reissue duplicates dropped entirely: **3146**.

The **Group A + B "likely obtainable"** rows (481 items) are the
strongest override candidates — they have a real Collections entry (so they were
meant to be earnable) but no usable source text.

# Obtainability: what was investigated (and why it's still a heuristic)

We tried to replace the "likely obtainable" heuristic with a reliable,
automated signal for **"is this item currently in the loot pool."** Every
avenue was ruled out. This section records them so they are not re-attempted.

**There is no signal — static or live — that Bungie exposes for current
world-obtainability.** DIM has the same limitation: it shows everything and
relies on the player to know.

| Approach tried | Verdict | Why it fails |
|---|---|---|
| **Web search / scrape** (light.gg, blueberries.gg, Bungie Help, wikis) | Unreliable | Direct fetch is **403-blocked** on light.gg, blueberries, Bungie Help, and the game wikis. Only WebSearch snippets work, surfacing dateless SEO guide-farms — a guide existing does not prove current availability (guides persist for removed items). A strict, honest probe returned UNKNOWN or low-confidence-inference for most of a 5-item sample. |
| **`quality.versions[].powerCap`** | Dead signal | Bungie reverted power-cap sunsetting; every gear item now shows a near-sentinel cap (999940–999990). A current item and a retired-2022 item are indistinguishable by cap. |
| **`iconWatermark` / `iconWatermarkShelved`** | Wrong axis | The watermark encodes the item's **season**, not whether it still drops. `iconWatermarkShelved` is present on ~all gear (8207/8237), so it is not a sunset flag. |
| **d2ai `source-to-season-v2.json`** | Wrong axis | Maps `sourceHash -> season number` (current season = 28). Season of origin ≠ current availability — a season-2 world drop may still drop; a season-26 activity may be gone. |
| **Live collectible `state`** (component 800) | Wrong question | `DestinyCollectibleState` is about **re-pulling already-obtained gear from Collections** (gated on materials), and is **per-account**. It does not indicate world-obtainability, and would answer differently for different players. |

**Conclusion:** the "likely obtainable" columns are, and will remain, a
**manual-review worklist** — there is no automated shortcut. To verify an item,
check it in-game or on a current community source by hand, then (if obtainable)
add a per-item entry to
[`assets/d2ai/source_overrides.json`](../assets/d2ai/source_overrides.json)
keyed by its Item Hash from the CSV.
