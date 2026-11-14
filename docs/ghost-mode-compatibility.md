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
| `W3PlayerWitcher.MeditationRestoring` | wrapper (exhaustion cleared) | `@replaceMethod` | Works at the default order: Ghost Mode's wrapper runs around Preparations' replacement (below); with Preparations it also runs on the quest/replenish path |
| `W3PlayerWitcher.OnSpawned`, `NewGamePlusInitialize`, `OnCombatStart/Finished`, `CR4IngameMenu.SaveChangedSettings`, `W3TooltipComponent.GetBaseItemData`, `W3GameEffectManager` registration | wrappers (many) | wrappers | Low (several wrappers per method) |
| Refill by meditation | 5.x's, unchanged; its test `gmtest_craft07_refill` calls `SingletonItemsRefillAmmo` and expects a potion refilled | filtered by type (default: no potion autorefill) | **Ghost Mode's regression fails with Preparations installed** unless the test sets potions to Autorefill or skips the filter |
| Recipes | CRAFT-06 whole-file recipe overrides | reads each recipe's base | Checked: every potion, decoction, bomb and oil recipe on `master` has a base except Alraune Reagent, Sleeping Potion, Mutation Serum (as in 5.x) |
| Tawny Owl recipe | granted once (fact `gm_craft_recipes_added`) | granted once (fact `MissingTawnyOwlRecipeAdded`) | None |
| Options, strings | `modGhostMode.xml`, ids 2110992xxx | `modPreparationsConfig.xml`, ids 2110750xxx | None |
| Effect types | enum extension, array grown to `GMLastEffectType()` | enum extension, array grown to its own last | Both grow only when too small: compatible; numbering across blobs untested |
| Character reset | `GMResetCharacter` (also switches the tree) | not gated | Decision: gate it like buying skills, or not (legacy had no reset) |

**How two blobs combine** (**verified** 2026-11-13 with throwaway blobs, TriangleGhostMode `docs/development.md`, "How the game loads mod scripts"): the mod whose folder sorts first takes precedence. Its `@replaceMethod` drops the other mod's replacement **and its wrappers**, silently. Its `@wrapMethod` runs around the other mod's replacement, and wrappers from both chain. `modGhostMode` sorts before `modPreparations`, so at the default order:

- Preparations' six wrappers on Ghost Mode's replacements (the first six rows) **never run**.
- Ghost Mode's wrapper of `MeditationRestoring` runs around Preparations' replacement (fine).
- A lower `Priority` for `modPreparations` in `mods.settings` reverses this (verified; the startup crashes first blamed on it were ReShade's).

Ways to combine them, for the owner to choose ([port-plan.md](port-plan.md#decisions-to-make)):

1. **Avoid the six methods.** Preparations hooks somewhere Ghost Mode does not replace: the callers, a check called from them, or the menus. Works at any folder order and with any other mod; costs a different design per method, and some may have no good alternative.
2. **Give Preparations precedence**: a folder name that sorts before `modGhostMode` (e.g. `modAPreparations`) or a lower `Priority` in `mods.settings`. Its six wrappers then wrap Ghost Mode's replacements. But anything Preparations *replaces* drops Ghost Mode's change of it: `MeditationRestoring` would lose Ghost Mode's exhaustion clear (Preparations would have to wrap it instead). Fragile: a renamed folder or a reset `mods.settings` breaks it silently.
3. **A merged build** for the combined install. **Script Merger Remastered v3 merges this case correctly** (verified 2026-11-13 by the owner's merge of two throwaway blobs with the same pattern: a replacement in one and a wrapper in the other, both directions; the merged mod ran every change). That test had no blob-only features, and its output was loose scripts. Ghost Mode uses scope-based overrides and enum extensions, and Preparations' effect type is an enum extension; whether Script Merger keeps those (perhaps as a merged blob) is untested, so whether it can merge the two real mods is still open. Or the two repos build a combined blob themselves. Every Ghost Mode or Preparations release needs a new merge either way.
4. **Ghost Mode turns its six replacements into wrappers** where its change allows it (it prefers wrappers anyway). Then Preparations' wrappers chain with Ghost Mode's at either order. Each of the six was a replacement for a reason (a changed body), so this is per method too.

Proposed: 1 or 4 per method (whichever is smaller), 3 for whatever is left. That keeps the default folder names and needs no merge for players.

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

**In 5.x the two blobs are compiled separately against vanilla** (Ghost Mode's open question on blob merging), so neither can name the other's fields or methods. Proposed interface, to agree with the FM port: timers started by name (works at runtime if the timer exists; Preparations `@addMethod`s `CampFireErrorMessageTimer` and `CampFireResourcesTimer` under these names); FM's spawned campfire tagged (e.g. `fmed_campfire`) so `PrepHasCampfire` finds it whatever `prepDisallowCampFire` says; "can spawn now" and "autorefill on" as facts or a Preparations config value FM reads; no shared `@addField`/`@addMethod` names (whether two blobs may add the same name is unknown: prefix them). Whether a vanilla 5.x player can open the character or alchemy menu while in the Meditation state decides whether the "requires meditation" options mean anything without FM.
