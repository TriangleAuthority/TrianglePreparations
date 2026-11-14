# Port plan

## Where the port stands

**2026-11-13: slice 0 under way.** The baselines and the legacy mod are committed ([repository.md](repository.md)); the legacy mod is described in [legacy-mod.md](legacy-mod.md) and compared with 5.x in [preparations-5.x.md](preparations-5.x.md) (both read from the files, **unverified** in game). The build tools are in and the compile check works (**verified**: a ping test script compiles, [tools.md](tools.md)). Next: the owner's [decisions](#decisions-to-make), then the rest of slice 0 in game.

## Approach

As in TriangleGhostMode and TriangleGwentImprovements: reproduce the legacy mod's behaviour in the least invasive 5.x form (wrappers first, replacements only where a wrapper cannot do it, XML through the mod's own DLC), one small slice at a time, each verified in game, in both skill trees. Legacy bugs are fixed when found and listed as deviations. The mod's DLC: `modPreparations/files/dlc/dlcpreparations/` (id `dlc_preparations`); prefix for everything the mod adds: `Prep`/`prep` (legacy already uses it for its options).

## Features and port forms

| ID | Feature | Port form | Difficulty |
|---|---|---|---|
| PREP-MENU | Options menu (6 groups, presets), strings (8 languages), the config class and its defaults | `menu/modPreparationsConfig.xml` (legacy's ids, UTF-8 BOM); `localization/<lang>.csv` (ids 2110750000–125, the two vanilla-text overrides rewritten with vanilla ids); `CModPreparationsConfig` with a default per option (no `user.settings.part`); `@wrapMethod CR4IngameMenu.SaveChangedSettings`; `@addField prepConfig`, `OnSpawned` wrapper and init timer on `W3PlayerWitcher` | Small |
| PREP-MED | Meditation requirements: fire nearby (campfire, fire source, light source), interiors, settlements, NPCs, the reasons shown | `@replaceMethod` of `CanMeditate` (with 5.x's new checks), `CanMeditateHere`, `CanMeditateWait`, **silent**; the reason shown from a `Meditate()` wrapper and the radial menu's choose path; `@addMethod`s `PrepIsMeditationAllowed`, `PrepHasCampfire`, `PrepHasNonAlliedActorsNearby`, `PrepGetMeditationError` | **Hard**: 5.x calls `CanMeditate` from many places, some on every UI update; the replenish-without-meditating path; fire detection must be checked against 5.x's world |
| PREP-REST | What meditation restores: no full heal, effects run their course, quest autorefill option; bed and NG+; `RecoverGeralt` | `@replaceMethod` `MeditationRestoring`, `SimulateBuffTimePassing`, `ApplyWitcherHouseBuffs`, quest functions `RecoverGeralt`, `ApplyAlchemyTableBuff`; `NewGamePlusInitialize` wrapper | Medium |
| PREP-SKILL | Buying and equipping skills, mutations and mutagens only at a fire / while meditating, **both trees** | `@wrapMethod` of 11 events on `CR4CharacterMenu` and on `CR4CharacterDupeMenu` | Medium: two menus, Ghost Mode's replaced `OnSwapSkill` and its tree switch |
| PREP-TIME | Time costs (create, repair, upgrade, buy skill, equip skill, equip mutagen) | `@addMethod PrepAdvanceTimeSeconds` (game time + accelerated effect update); called from the other features' wrappers; skill purchase charged in a `handleBuySkillConfirmation` wrapper (both menus) | Small–medium (effect update while time jumps: check in game) |
| PREP-ALCH | Brewing only at a fire / while meditating; exemptions (quest recipes, herbalists, the forced tutorial) | `@addField bHerbalist` + `OnConfigUI` wrapper; `CR4AlchemyMenu.CreateItem` `@replaceMethod` (small) or wrapper + flag | Small |
| PREP-REFILL | Per-item refill in the alchemy menu: modes per type, one-charge option, vanilla refill limited to Autorefill types, refill cost shown | `@addMethod`s on `W3AlchemyManager`; **wrappers** of `CanCookRecipe` and `CookItem` that take over the refill case; `@replaceMethod` `SingletonItemsRefillAmmo`, `HasNotFilledSingletonItem`, `SingletonItemRefillAmmo`; alchemy menu `UpdateItemsById` (and `PopulateData` for the charges in the title) `@replaceMethod` | **Hard**: Ghost Mode replaces `CookItem`; signatures that legacy extended need fields instead; many call sites of the vanilla refill |
| PREP-OIL | Oil jars with limited uses, refilled like the rest; UI counts | `SingletonItemGetMaxAmmo` wrapper (Ghost Mode replaces it); `CR4Player.ApplyOil` wrapper (Ghost Mode replaces it); `CR4InventoryMenu.ApplyOil` wrapper; `ModPrepCheckAmmo` `@addMethod`; `GetBaseItemData` and `SetInventoryFlashObjectForItem` wrappers | Medium; 5.x's auto-apply oils and `CookItem`'s oil re-apply need decisions |
| PREP-TABLE | Corvo Bianco's alchemy table: a 1-hour effect giving +1 charge instead of vanilla's refill bonus | Enum extension, effect class, registration wrappers (Ghost Mode's pattern), DLC XML (ability, effect, icon) | Medium: enum numbering across blobs and in saves; the icon may not exist |
| PREP-INV | Repairing (kits) and upgrading only at a fire / while meditating; both refused in combat | Wrappers of `OnPutInSocket`, `OnRepairItem`, `ApplyUpgrade`, `ApplyRepairKit` (Ghost Mode replaces it) | Small |
| PREP-COMBAT | No eating or drinking in combat; no oils in combat; optional inventory block in combat | Wrappers of `CR4Player.ConsumeItem` (Ghost Mode replaces it), `OnCombatStart`, `OnCombatFinished`, `DisallowedActionDontShowHack`; the oil gate is PREP-OIL's inventory wrapper | Small |
| PREP-FIX | Tawny Owl recipe granted once | In the `OnSpawned` init (same fact as legacy). Ghost Mode grants it too (CRAFT-06): harmless | Small |
| PREP-FMED | Friendly Meditation interface: campfire spawning allowed or not, timber cost, FM's hourly autorefill, FM's spawned campfire as a fire | Runtime-only interface (timers by name, facts, tags, config reads): see [below](ghost-mode-compatibility.md#friendly-meditation-interaction); with the FM port | Medium–hard: depends on the FM port |

Not carried: Friendly HUD's and Friendly Stash's code inside legacy's scripts (5.x has the alchemy shop; the stash helpers were inert), the unused strings.

## Slices

0. **Tooling and probes:** the tools and the compile check (done 2026-11-13); PREP-MENU: the menu shows under Options → Mods with labels in game, `autoconfig` reads every group, defaults apply on an empty settings file; the DLC mounts (`IsDLCEnabled('dlc_preparations')`). Install side by side with Ghost Mode on the shared game slot. The blob-combination probe is done (2026-11-13, [ghost-mode-compatibility.md](ghost-mode-compatibility.md#ghost-mode)).
1. **PREP-MED** fire detection and requirements (every later gate uses `PrepHasCampfire`), silent checks, reasons shown; **PREP-COMBAT**; **PREP-INV**.
2. **PREP-TIME** and **PREP-SKILL** in both menus, both trees (classic by 5.x's hidden setting and by Ghost Mode's option).
3. **PREP-ALCH** and **PREP-REFILL** (all modes, one-charge option, the autorefill filter, the UI).
4. **PREP-OIL** and **PREP-TABLE**.
5. **PREP-REST** (needs the quest-pause and replenish decisions), **PREP-FIX**.
6. **PREP-FMED**, once the Friendly Meditation port can spawn its campfire.

## Decisions to make

- **Preparations' alchemy-table effect type** (the last open part of combining without a patch): (a) no new `EEffectType` member: a timed +1 window read by the max-charges wrapper, with a notification, no HUD buff icon (a deviation); or (b) a member of its own, declared after a copy of Ghost Mode's 18 effect type names in Ghost Mode's order (verified with a probe, 2026-11-14), which must be updated whenever Ghost Mode adds an effect type; or (c) 5.x's one-time refill to max + 1. A plain member of its own breaks every Ghost Mode effect type (verified), and explicit values are refused by the compiler. See [ghost-mode-compatibility.md](ghost-mode-compatibility.md#combining-cleanly-without-a-patch-analysis-2026-11-13). The other fixes there are decided (owner, 2026-11-13).
- **Notifications from the meditation checks** (PREP-MED): show them only when meditation is attempted (proposed), since 5.x polls `CanMeditate`.
- **Replenish without meditating** (5.x radial, when waiting is blocked): keep it as 5.x's (with Preparations' filtered refill, heal per option), or close it as legacy's checks would.
- **5.x's auto-apply oils**: costs a jar charge per application and works in combat. Options: allowed (charges apply), refused in combat when "no oils in combat" is on, or the option ignored while oil charges are on.
- **`CookItem`'s oil re-apply** (5.x): charge the new jar or not.
- **Skill purchase time** charged on confirm (proposed; legacy charges when the classic popup opens, also on cancel).
- **Charges in recipe names** (`PopulateData` replacement) or not.
- **Friendly Meditation preset**: legacy asks the player to apply it in every group; the port could detect FM (its option group reads non-empty) and say so, or apply it.

## Compatibility

What Ghost Mode's port touches in the same places, and how this mod works with Friendly Meditation: [ghost-mode-compatibility.md](ghost-mode-compatibility.md).

## Deviations

Every difference from the legacy mod is listed in [deviations.md](deviations.md).
