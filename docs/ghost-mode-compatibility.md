# Ghost Mode and Friendly Meditation compatibility

This mod is independent of the Ghost Mode port ([TriangleGhostMode](https://github.com/TriangleAuthority/TriangleGhostMode)) and of the Friendly Meditation port, but must work with both.

## Ghost Mode

State on 2026-11-13 (Ghost Mode's `master`), read from both repositories (**unverified** in game).

### What legacy said

- Legacy Ghost Mode was **built to be played with Preparations**: "fully compatible with Preparations mod and is balanced for playing with Preparations using default refill option (refilling with base ingredient)", and accounts for "no eating/drinking in combat or no applying oils in combat" (`docs/legacy-ModDescription.txt`); alcohol recipes and empty bottles were added for it.
- **Merge rule** (legacy Ghost Mode readme, `legacy-GM:design-docs/release/Readme.txt`): "Preparations - do not merge effects_ep2.xml file. Make sure the one from Ghost Mode has a priority". Ghost Mode's `effects_ep2.xml` already carried Preparations' `AlchemyTableEffect` entries. Both readmes also warn about restarting after script compilation (charges at -1).
- In 5.x neither mod ships `effects_ep2.xml`: Ghost Mode adds its effects in `gm_effects.xml`, Preparations will add its effect in its own DLC XML. The rule disappears.

### What both touch

| Method or system | Ghost Mode (`master`) | Preparations (planned) | Risk |
|---|---|---|---|
| `W3AlchemyManager.CookItem` | `@replaceMethod` (FOOD-07 cooking; 5.x's oil re-apply kept) | wrapper taking over refills | **Wrapper dropped** at the default order (below) |
| `CInventoryComponent.SingletonItemGetMaxAmmo` | `@replaceMethod` (SKL-18 Efficiency, Heavy Artillery) | wrapper (oil max, table +1) | Same; if it runs, table +1 after Heavy Artillery's multiplier (deviation) |
| `CR4Player.ApplyOil` | `@replaceMethod` (SKL-14 oil decay) | wrapper (jar charges) | Same |
| `CR4Player.ConsumeItem` | `@replaceMethod` (FOOD-05 toxicity) | wrapper (combat refusal) | Same |
| `CR4InventoryMenu.ApplyRepairKit` | `@replaceMethod` (ITEM-11 kits) | wrapper (gate, time) | Same |
| `CR4CharacterDupeMenu.OnSwapSkill` | `@replaceMethod` (skill slots); `OnConfigUI` wrapped | wrapper (gate) | Same |
| `CR4CharacterDupeMenu` as the only skill menu | draws both trees there (SKL-02); classic `CR4CharacterMenu` unused | wraps both menus | None if both menus are wrapped |
| `W3PlayerWitcher.MeditationRestoring` | wrapper (exhaustion cleared) | `@replaceMethod` | Works at the default order only (Ghost Mode's wrapper runs around Preparations' replacement because `modGhostMode` sorts first), so the compatibility patch takes it over; with Preparations it also runs on the quest/replenish path |
| `W3PlayerWitcher.OnSpawned`, `NewGamePlusInitialize`, `OnCombatStart/Finished`, `CR4IngameMenu.SaveChangedSettings`, `W3TooltipComponent.GetBaseItemData`, `W3GameEffectManager` registration | wrappers (many) | wrappers | Low (several wrappers per method) |
| Refill by meditation | 5.x's, unchanged; its test `gmtest_craft07_refill` calls `SingletonItemsRefillAmmo` and expects a potion refilled | filtered by type (default: no potion autorefill) | **Ghost Mode's regression fails with Preparations installed** unless the test sets potions to Autorefill or skips the filter |
| Recipes | CRAFT-06 whole-file recipe overrides | reads each recipe's base | Checked: every potion, decoction, bomb and oil recipe on `master` has a base except Alraune Reagent, Sleeping Potion, Mutation Serum (as in 5.x) |
| Tawny Owl recipe | granted once (fact `gm_craft_recipes_added`) | granted once (fact `MissingTawnyOwlRecipeAdded`) | None |
| Options, strings | `modGhostMode.xml`, ids 2110992xxx | `modPreparationsConfig.xml`, ids 2110750xxx | None |
| Effect types | enum extension, array grown to `GMLastEffectType()` | enum extension, array grown to its own last | **Conflict (verified 2026-11-14):** the game merges every mod's members by name at load and resolves class defaults against the merged list, so a plain Preparations member breaks every Ghost Mode effect type (or its own). Fix in the table below: no member, or Ghost Mode's names declared first. |
| Character reset | `GMResetCharacter` (also switches the tree) | not gated | Decision: gate it like buying skills, or not (legacy had no reset) |

**How two blobs combine** (**verified** 2026-11-13 with throwaway blobs, TriangleGhostMode `docs/development.md`, "How the game loads mod scripts"): the mod whose folder sorts first takes precedence. Its `@replaceMethod` drops the other mod's replacement **and its wrappers**, silently. Its `@wrapMethod` runs around the other mod's replacement, and wrappers from both chain. `modGhostMode` sorts before `modPreparations`, so at the default order:

- As first planned, Preparations' six wrappers on Ghost Mode's replacements (the first six rows) would **never run** (hence the fixes below).
- Ghost Mode's wrapper of `MeditationRestoring` runs around Preparations' replacement, but only at this order.
- A lower `Priority` for `modPreparations` in `mods.settings` reverses this (verified; the startup crashes first blamed on it were ReShade's).

### Combining cleanly without a patch (analysis, 2026-11-13)

Every hunk of legacy Preparations was mapped to its function (about 75 functions in 12 files) and checked against Ghost Mode's annotations and scope blocks on `master`. The conflicting set is the seven methods in the table above plus `EEffectType`; everything else either is only wrapped (in calling form) by both, or is changed by one mod only. **Each of the eight has a fix that works in either folder order**, so Ghost Mode and Preparations can combine with no compatibility patch. Read in code unless marked; nothing built or tested yet.

| Method | Fix | Side | Effort |
|---|---|---|---|
| `W3AlchemyManager.CookItem` | Preparations does its refill in `CR4AlchemyMenu.CreateItem` (which it replaces anyway; Ghost Mode does not touch it) and never touches `CookItem`. `CookItem`'s only gameplay caller is `alchemyMenu.ws:349` (the other, `ryanAlchemyMenu`, is a debug menu opened from `temp.ws`). | Prep | Small |
| `CInventoryComponent.SingletonItemGetMaxAmmo` | Ghost Mode's replacement becomes a wrapper adding its bomb bonus as a difference to `wrappedMethod()` (it changes only bombs); Preparations wraps for oils and the table bonus. Unavoidable on Preparations' side: about 25 callers. | GM + Prep | Small (GM retest SKL-15/SKL-18) |
| `CR4Player.ApplyOil` | Preparations wraps the subclass's `W3PlayerWitcher.ApplyOil` (`playerWitcher.ws:2349`, calls `super.ApplyOil`), which Ghost Mode does not touch; every player path goes through it. | Prep | Small |
| `CR4Player.ConsumeItem` | Same: Preparations wraps `W3PlayerWitcher.ConsumeItem` (`playerWitcher.ws:5489`, reaches `super` at 5551) and refuses before `wrappedMethod`. | Prep | Small |
| `CR4InventoryMenu.ApplyRepairKit` | Preparations wraps the two events that call it (`OnApplyRepairKit`, and the repair-kit branch of `OnSelectionModeTargetChosen`) for its gate and time cost; Ghost Mode unchanged. (Alternative: Ghost Mode turns its replacement into a wrapper.) | Prep | Small |
| `CR4CharacterDupeMenu.OnSwapSkill` | Ghost Mode's replacement becomes a wrapper: its colour gate before `wrappedMethod`, and its "empty both slots first" moved into a wrapper of the player's `EquipSkill` active only during the swap, so a refusal by either mod's gate changes nothing. | GM | Small to medium (GM retest the swap and Sun and Stars) |
| `W3PlayerWitcher.MeditationRestoring` | Ghost Mode moves its exhaustion clear to a wrapper of `ApplyWitcherHouseBuffs` (its only caller is `MeditationRestoring`'s last line, `playerWitcher.ws:10268`); Preparations keeps replacing `MeditationRestoring` but must call `ApplyWitcherHouseBuffs` on every path, and wraps (not replaces) it for its bed effects. | GM + Prep | Small |
| `EEffectType` (enum) | Preparations adds no member: its alchemy-table bonus uses 5.x's own table bonus (refill to max + 1, `QUANTITY_INCREASED_BY_ALCHEMY_TABLE`) or a timed fact read by its max-ammo wrapper. Loses legacy's buff icon: a deviation. A member of its own would break Ghost Mode's effect types (or its own): the game merges enum extensions by name at load and resolves class defaults against the merged list (**verified** 2026-11-14, TriangleGhostMode `docs/development.md`). Works only if Preparations declares Ghost Mode's effect type names first, in Ghost Mode's order, then its own (verified with a probe), and updates them whenever Ghost Mode adds one. Explicit values are refused by the compiler. | Prep | Small to medium |

Also: Preparations' wrapper of `CR4Player.DisallowedActionDontShowHack` must call `wrappedMethod` (Friendly Meditation wraps it too); its planned unprefixed `@addField bHerbalist` gets the `prep` prefix. Contracts both repos record: Preparations' `MeditationRestoring` always ends with `ApplyWitcherHouseBuffs()`.

**Ghost Mode's three refactors** (`SingletonItemGetMaxAmmo`, `OnSwapSkill`, the exhaustion clear) are done and **verified** in Ghost Mode (owner's go-ahead 2026-11-13; in game 2026-11-14, both trees; TriangleGhostMode `docs/development.md`, "Other mods and vanilla code").

## Compatibility patch (fallback)

**Decision** (owner, 2026-11-13): if conflicts remain that the mods cannot be written around, they go into **our own compatibility patch mod** in its own repository, not into Script Merger (v3.01 loses `default` lines and loose replacements on blobs like Ghost Mode's; TriangleGhostMode `docs/development.md`). The analysis above found none left for Ghost Mode with Preparations, so the patch is not planned unless a refactor fails in game. If it is needed:

- **Independent of the order of the mods below it.** The patch's folder sorts before all of them (e.g. `mod0TriangleCompat`; digits sort before letters), so it takes precedence whatever their names or `mods.settings` priorities say about each other. Its `@replaceMethod` of a method drops every other mod's change of that method, replacements and wrappers alike.
- **It covers every method that one mod replaces and another mod changes in any way**, not only the pairs that fail at the default order. A replacement in one mod and a wrapper in another combine only when the wrapping mod comes first, so any such pair depends on the order: the patch takes it over. Today that means Preparations' six wrappers on Ghost Mode's replacements (`CookItem`, `SingletonItemGetMaxAmmo`, `ApplyOil`, `ConsumeItem`, `ApplyRepairKit`, `OnSwapSkill`) and `MeditationRestoring` (Preparations replaces it, Ghost Mode wraps it: that works now only because `modGhostMode` sorts first), plus whatever Friendly Meditation shares with either. Scope-based overrides count as replacements (how two blobs' overrides of one method combine is untested). Only methods that every mod merely wraps stay out of the patch: wrappers chain in any order.
- **For each such method, one `@replaceMethod` that contains every mod's change**: the replacing mod's body with the other mods' wrappers folded in (e.g. `ConsumeItem`: Ghost Mode's toxicity rule and Preparations' combat refusal). The fold-in fixes the order of the wrapped parts once, in the patch, instead of leaving it to the mod order.
- **Installed only together with every mod it merges** (owner, 2026-11-13); without one of them it is not installed. Its combined bodies need the mods' own fields and functions (Ghost Mode's option helpers, Preparations' settings). Each blob is compiled against vanilla only, so the patch must be compiled against the mods' sources as declarations (Script Merger's `Tools\WSCompiler\WSCompiler.exe --reference <mod scripts>` does that; `wcc_lite` has no such option). That works in game (**verified** 2026-11-13: a blob built this way called another blob's global function and `@addMethod`, read its `@addField` and created its class; TriangleGhostMode `docs/development.md`). The patch is therefore built with `WSCompiler`, referencing the mods' sources.
- **Enum members:** not a patch matter. The game merges every mod's members by name at load; a mod extending `EEffectType` keeps Ghost Mode working only by declaring Ghost Mode's names first, in order (TriangleGhostMode `docs/development.md`). Preparations adds none.
- **Upkeep:** the patch copies the mods' code of those methods, so a change to one of them in any mod needs a patch release; the patch's build should compare its copies with the mods' sources and fail when they drift. The patch is needed only when Ghost Mode and the other mod are both installed.
- **Where it lives:** its own repository next to the others (owner, 2026-11-13).

## Friendly Meditation interaction

Legacy's two mods talk through shared code: Preparations' `playerWitcher.ws` contains Friendly Meditation's fields and functions, and each mod calls into the other.

| Direction | Legacy channel | What it carries |
|---|---|---|
| Preparations → FM | `fmedCanSpawnCampfire` (set in `IsMeditationAllowed` / `CanSpawnCampfire`) | Whether FM may spawn its campfire now (options, interior/settlement, timber) |
| Preparations → FM | `fmedAutorefillAlchemy` (`SetupFMed`) | FM's hourly refill while meditating: on only if some type is in Autorefill mode (FM calls `SingletonItemsRefillAmmo`, which Preparations filters anyway) |
| FM → Preparations | `GetVarValue('modFriendlyMeditation', 'fmedSpawnCampfire')` | FM's own spawn option |
| FM → Preparations | `CanMeditate`, `CanMeditateWait`, `CanMeditateHere` (FM's `ModCanMeditate`: "checking everything for Preparations compatibility") | Preparations' requirements |
| FM → Preparations | `AddTimer('CampFireErrorMessageTimer')`, `AddTimer('CampFireResourcesTimer')` (timers defined only in Preparations) | The reason a campfire could not be made; taking the timber after spawning |
| FM → Preparations | `spawnedCampFire` | FM's campfire counts as a fire for `HasCampfire` |
| shared | `IsMeditating()`, `IsSkippingTime()`, `UpdateEffectsAccelerated` (defined in both mods' copies) | The "requires meditation" options mean FM's real-time meditation; `MeditationRestoring(0)` from FM's clock menu |

**In 5.x the two blobs are compiled separately against vanilla** (Ghost Mode's open question on blob merging), so neither can name the other's fields or methods. Proposed interface (the current version, agreed with the FM design, is in TriangleFriendlyMeditation `docs/ghost-mode-compatibility.md`, "Preparations interaction"); first sketch: timers started by name (works at runtime if the timer exists; Preparations `@addMethod`s `CampFireErrorMessageTimer` and `CampFireResourcesTimer` under these names); FM's spawned campfire tagged (e.g. `fmed_campfire`) so `PrepHasCampfire` finds it whatever `prepDisallowCampFire` says; "can spawn now" and "autorefill on" as facts or a Preparations config value FM reads; no shared `@addField`/`@addMethod` names (whether two blobs may add the same name is unknown: prefix them). Whether a vanilla 5.x player can open the character or alchemy menu while in the Meditation state decides whether the "requires meditation" options mean anything without FM.
