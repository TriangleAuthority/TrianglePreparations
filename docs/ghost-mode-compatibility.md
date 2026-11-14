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
| `W3AlchemyManager.CookItem` | `@replaceMethod` (FOOD-07 cooking; 5.x's oil re-apply kept) | wrapper taking over refills | Wrapper over another blob's replacement: chaining unverified |
| `CInventoryComponent.SingletonItemGetMaxAmmo` | `@replaceMethod` (SKL-18 Efficiency, Heavy Artillery) | wrapper (oil max, table +1) | Same; table +1 after Heavy Artillery's multiplier (deviation) |
| `CR4Player.ApplyOil` | `@replaceMethod` (SKL-14 oil decay) | wrapper (jar charges) | Same |
| `CR4Player.ConsumeItem` | `@replaceMethod` (FOOD-05 toxicity) | wrapper (combat refusal) | Same |
| `CR4InventoryMenu.ApplyRepairKit` | `@replaceMethod` (ITEM-11 kits) | wrapper (gate, time) | Same |
| `CR4CharacterDupeMenu.OnSwapSkill` | `@replaceMethod` (skill slots); `OnConfigUI` wrapped | wrapper (gate) | Same |
| `CR4CharacterDupeMenu` as the only skill menu | draws both trees there (SKL-02); classic `CR4CharacterMenu` unused | wraps both menus | None if both menus are wrapped |
| `W3PlayerWitcher.MeditationRestoring` | wrapper (exhaustion cleared) | `@replaceMethod` | Ghost Mode's wrapper on Preparations' replacement: chaining unverified; with Preparations it also runs on the quest/replenish path |
| `W3PlayerWitcher.OnSpawned`, `NewGamePlusInitialize`, `OnCombatStart/Finished`, `CR4IngameMenu.SaveChangedSettings`, `W3TooltipComponent.GetBaseItemData`, `W3GameEffectManager` registration | wrappers (many) | wrappers | Low (several wrappers per method) |
| Refill by meditation | 5.x's, unchanged; its test `gmtest_craft07_refill` calls `SingletonItemsRefillAmmo` and expects a potion refilled | filtered by type (default: no potion autorefill) | **Ghost Mode's regression fails with Preparations installed** unless the test sets potions to Autorefill or skips the filter |
| Recipes | CRAFT-06 whole-file recipe overrides | reads each recipe's base | Checked: every potion, decoction, bomb and oil recipe on `master` has a base except Alraune Reagent, Sleeping Potion, Mutation Serum (as in 5.x) |
| Tawny Owl recipe | granted once (fact `gm_craft_recipes_added`) | granted once (fact `MissingTawnyOwlRecipeAdded`) | None |
| Options, strings | `modGhostMode.xml`, ids 2110992xxx | `modPreparationsConfig.xml`, ids 2110750xxx | None |
| Effect types | enum extension, array grown to `GMLastEffectType()` | enum extension, array grown to its own last | Both grow only when too small: compatible; numbering across blobs unknown |
| Character reset | `GMResetCharacter` (also switches the tree) | not gated | Decision: gate it like buying skills, or not (legacy had no reset) |

**The deciding unknown** is TriangleGhostMode's open question "How does the game merge the script blobs of several mods?": two blobs' `@replaceMethod`s of one method are winner-take-all (seen), but whether one blob's `@wrapMethod` wraps another blob's `@replaceMethod` is not tested. Six of Preparations' wrappers sit on Ghost Mode replacements, and Ghost Mode wraps one of Preparations'. **Plan:** answer it in slice 0 with a probe (Preparations' blob wraps `ConsumeItem`, Ghost Mode's replaces it: both effects seen in one run, at both priority orders). If wrappers do not chain across blobs, fall back to a merged build for the combined install (Preparations' changes as a compile-time option inside Ghost Mode's replaced bodies), as Gwent Improvements plans to merge later.

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
