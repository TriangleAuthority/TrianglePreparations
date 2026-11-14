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
| Effect types | enum extension, array grown to `GMLastEffectType()` | enum extension, array grown to its own last | **Collision (verified mechanism):** two blobs that extend one enum give their new members the same numbers (TriangleGhostMode `docs/development.md`, scope-based overrides). Ghost Mode's first effect type and Preparations' `AlchemyTableEffect` type would get the same `EEffectType` value, so the game would confuse the two effects. Preparations needs its effect without a new enum member (e.g. reuse a vanilla effect type it can tell apart by its source or ability name), or a merged build |
| Character reset | `GMResetCharacter` (also switches the tree) | not gated | Decision: gate it like buying skills, or not (legacy had no reset) |

**How two blobs combine** (**verified** 2026-11-13 with throwaway blobs, TriangleGhostMode `docs/development.md`, "How the game loads mod scripts"): the mod whose folder sorts first takes precedence. Its `@replaceMethod` drops the other mod's replacement **and its wrappers**, silently. Its `@wrapMethod` runs around the other mod's replacement, and wrappers from both chain. `modGhostMode` sorts before `modPreparations`, so at the default order:

- Preparations' six wrappers on Ghost Mode's replacements (the first six rows) **never run**.
- Ghost Mode's wrapper of `MeditationRestoring` runs around Preparations' replacement (fine).
- A lower `Priority` for `modPreparations` in `mods.settings` reverses this (verified; the startup crashes first blamed on it were ReShade's).

Ways to combine them, for the owner to choose ([port-plan.md](port-plan.md#decisions-to-make)):

1. **Avoid the six methods.** Preparations hooks somewhere Ghost Mode does not replace: the callers, a check called from them, or the menus. Works at any folder order and with any other mod; costs a different design per method, and some may have no good alternative.
2. **Give Preparations precedence**: a folder name that sorts before `modGhostMode` (e.g. `modAPreparations`) or a lower `Priority` in `mods.settings`. Its six wrappers then wrap Ghost Mode's replacements. But anything Preparations *replaces* drops Ghost Mode's change of it: `MeditationRestoring` would lose Ghost Mode's exhaustion clear (Preparations would have to wrap it instead). Fragile: a renamed folder or a reset `mods.settings` breaks it silently.
3. **A merged build** for the combined install. **Script Merger Remastered v3 merges this case correctly** (verified 2026-11-13 by the owner's merge of two throwaway blobs with the same pattern: a replacement in one and a wrapper in the other, both directions; the merged mod ran every change). But a second test with blob-only features (scope-based overrides with a `default`, an enum member, an annotation-added event, a wrapped native) went wrong: the default was lost, the enum collision stayed, and the earlier merge's loose replacements stopped working (TriangleGhostMode `docs/development.md`). Ghost Mode has all of these, so Script Merger v3.01 cannot be relied on for Ghost Mode with Preparations. Or the two repos build a combined blob themselves. Every Ghost Mode or Preparations release needs a new merge either way.
4. **Ghost Mode turns its six replacements into wrappers** where its change allows it (it prefers wrappers anyway). Then Preparations' wrappers chain with Ghost Mode's at either order. Each of the six was a replacement for a reason (a changed body), so this is per method too.

Chosen (owner, 2026-11-13): 3, as our own compatibility patch built from the repos ([below](#compatibility-patch-planned)); 1 or 4 where a method is easy to avoid or to turn into a wrapper. That keeps the default folder names and needs no merge for players.

## Compatibility patch (planned)

**Decision** (owner, 2026-11-13): conflicts that do not combine cleanly are fixed by **our own compatibility patch mod**, shipped on top of Ghost Mode, Preparations and Friendly Meditation, not by Script Merger (v3.01 loses `default` lines and loose replacements on blobs like Ghost Mode's; TriangleGhostMode `docs/development.md`). How it works, from the verified blob rules:

- **A blob of its own whose folder sorts before `modGhostMode`** (e.g. `mod0TriangleCompat`; digits sort before letters), so its `@replaceMethod` of a method wins over both mods' changes of it. Precedence by folder name needs nothing from the player; a `mods.settings` priority would work too but is easy to lose.
- **For each clashing method, one `@replaceMethod` whose body is the combined code**: Ghost Mode's replaced body with the other mod's change worked in (e.g. `ConsumeItem` with Ghost Mode's toxicity rule and Preparations' combat refusal). Wrappers of mods that sort after the patch are dropped by its replacement, so the patch also carries those mods' wrappers of that method, folded into the body.
- **Only the methods that clash**: Preparations' six wrappers on Ghost Mode's replacements (`CookItem`, `SingletonItemGetMaxAmmo`, `ApplyOil`, `ConsumeItem`, `ApplyRepairKit`, `OnSwapSkill`), and whatever Friendly Meditation and the other two turn out to share. Everything that already combines (wrappers on both sides, wrapper over replacement in the right order) stays in the mods.
- **What it cannot fix: enum members.** Each blob numbers its new enum members as if it were alone, so Ghost Mode's and Preparations' new effect types get the same number, and the values are compiled into each blob. Preparations must manage without a new `EEffectType` member (see the effect-types row above).
- **Upkeep:** the patch copies Ghost Mode's bodies of those methods, so a Ghost Mode change to one of them needs a patch release; the patch's build should compare its copies with Ghost Mode's sources and fail when they drift. The patch is needed only when Ghost Mode and the other mod are both installed.
- **Where it lives:** to decide (its own repository next to the others, or inside one of them).

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
