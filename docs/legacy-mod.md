# The legacy mod: Preparations 6.2

What the legacy mod is, how it was packaged, and what it changes. Everything here was read from the files on `legacy-PREP` (`git diff -w legacy-PREP~1 legacy-PREP`), **unverified** in game.

## The release

- **Preparations 6.2** by Wasteland Ghost (wghost81), the author of Ghost Mode and Friendly Meditation. Readme: `release/README.txt` (and `README-RUS.txt`). Idea: meditation and campfires become the place where Geralt manages skills, equipment and alchemy; meditation no longer just skips time and refills alchemy.
- **Needs UPatch** (the readme); its `ingameMenu.ws` was written on top of **Community Patch – Base** v1.0 (committed on `legacy-PREP~1`, as in TriangleGhostMode's `legacy-GM`). The only Community Patch file the mod itself changes is `ingameMenu.ws` (one hook in `SaveChangedSettings`).
- "Works both with vanilla meditation and with Friendly Meditation" (recommended); with Friendly Meditation the player applies the "Friendly Meditation" preset in every menu group.
- Save-safe by the readme: install and uninstall at any time.

| Shipped | In the repository (`legacy-PREP`) |
|---|---|
| `modPreparations/content/scripts/*.ws` (UTF-16) | `modPreparations/scripts/` (UTF-8): 13 changed vanilla scripts, 2 new (`prepconfig/modPreparationsConfig.ws`, `game/gameplay/effects/effects/other/alchemyTable.ws`) |
| `content/blob0.bundle` | Unpacked: `dlc/bob/data/gameplay/abilities/effects_ep2.xml` and its `abilities_plus` copy (identical change) under `modPreparations/files/` |
| `content/*.w3strings` | Not kept; their sources `modPreparations/localization/{br,cz,de,en,es,fr,pl,ru}.csv` (cz has 4 fewer rows) and `readme-localization.txt` |
| `bin/config/r4game/user_config_matrix/pc/modPreparationsConfig.xml` (UTF-16) | `modPreparations/menu/modPreparationsConfig.xml` |
| `user.settings.part.txt` | `release/user.settings.part.txt`: the defaults, pasted by hand into `Documents\The Witcher 3\user.settings` ("if you miss this step, most of the mod's options will be off") |

Packaging and string facts:

- **Settings** live in `user.settings`, groups `[preparationsMeditation]`, `[preparationsFriendlyMeditation]`, `[preparationsAlchemy]`, `[preparationsCharacter]`, `[preparationsInventory]`, `[preparationsTime]`, read by `CModPreparationsConfig.UpdateUserSettings` through `theGame.GetInGameConfigWrapper().GetVarValue`. There are no defaults in script.
- **Strings:** encoded with the community encoder, `w3strings.exe --encode en.csv --id-space 750`: ids **2110750000–2110750125**, 97 rows in `en.csv`. Two rows have a key hash and no key name: they override vanilla texts by key, `e3d2e9fc` = `message_common_alchemy_table_buff_applied` and `dcf60e01` = `panel_buff_alchemy_table_descr` ("Bombs, oils and potions gain an additional charge."; hashes computed with TriangleGhostMode's `tools/w3strings.py`). `panel_Mods` (2110750000) duplicates the vanilla "Mods" label. Unused leftovers: `MeditationFastForward`, `HoldToMeditate`, `ToggleInteractions` (input action names), `option_prep_doNotDespawn`, `option_prep_useOldAlgorithm`.
- **"Restart after compiling" (readme, IMPORTANT):** loading a save right after the script compiler ran "sometimes does weird things to alchemy item charges", down to 0 or -1; the player must restart the game first. Legacy Ghost Mode's readme carries the same warning. Cause unknown.
- **Other mods' code inside the scripts** (pre-merged by the author, inert without those mods): Friendly Meditation's `W3PlayerWitcher` fields (`spawnedCampFire`, `fmedCanSpawnCampfire`, `fmedAutorefillAlchemy`, `fmedRefillIntervalSeconds`, `fmedApplyWitcherHouseBuffs`, `fmedWitcherHouseBuffsHours`) and functions (`IsMeditating`, `IsSkippingTime`, `UpdateEffectsAccelerated`); Friendly HUD's alchemy-menu shop (buy ingredients from the NPC who opened the menu: `OnBuyIngredient`, `BuyIngredient`, `GetTooltipData`, `UpdateMerchantData`, `UpdateItemsCounter`, `m_npc`, `bHerbalist`) and its flags `prepDisallowOilsInCombat`, `prepOilsHaveAmmo` (`SetupFHUD`); Friendly Stash's `bStashAccess`/`SetStashAccess` and `W3PlayerWitcher.Get/RemoveItemByNameForCrafting`, `Get/RemoveMutagenByNameForCrafting` (horse inventory as a stash; Preparations always passes `false`), and `RemoveUnusedMutagensCount(ById)` returning `bool`. Two lines are tagged `//modSigns` (Ghost Mode's internal tag).

## What it changes

All gates below share two predicates on `W3PlayerWitcher`: **`IsMeditating()`** (state `Meditation`) and **`HasCampfire()`** (below). Each gated action has a "requires meditation" and a "requires campfire" option; the action is allowed when every required condition holds (`CModPreparationsConfig.Is<Action>Allowed`), else a notification (`prep_error_meditation_required` / `prep_error_campfire_required`) and the "denied" sound.

### Skills, mutagens, mutations (`gui/menus/characterMenu.ws`, `CR4CharacterMenu`)

| Event | Gate | Time cost |
|---|---|---|
| `OnBuySkill` (drag an unlearned skill to a slot: buy and equip) | buy skill | buy skill |
| `OnUpgradeSkill` (opens the buy/upgrade confirmation popup) | buy skill | buy skill, charged **before** the popup (so also on cancel, from the code) |
| `OnResearchMutation` | buy skill | buy skill, when something was researched |
| `OnEquipSkill` | equip skill | equip skill (also when the same skill is dropped on its own slot) |
| `OnSwapSkill`, `OnUnequipSkill` | equip skill | none |
| `OnEquipMutation` | equip skill | equip skill |
| `OnUnequipMutation` | equip skill | none |
| `OnEquipMutagen` | equip mutagen | equip mutagen |
| `OnMoveMutagenToEmptySlot`, `OnUnequipMutagen` | equip mutagen | none |

The gate is checked after vanilla's combat refusal. `handleBuySkillConfirmation` is not touched.

### Repair and upgrade (`gui/menus/inventoryMenu.ws`, `CR4InventoryMenu`)

- `OnPutInSocket`, `ApplyUpgrade`: refused in combat and when upgrading is not allowed; `ApplyUpgrade` advances the upgrade time when the slot holds an item.
- `OnRepairItem`, `ApplyRepairKit` (repair kits): refused in combat (new) and when repairing is not allowed; `ApplyRepairKit` advances the repair time before repairing. Blacksmith repairs are not touched.

### Alchemy (`gui/menus/alchemyMenu.ws`, `CR4AlchemyMenu.CreateItem`)

- Brewing is refused unless `IsAlchemyAllowed()`, except quest recipes (`EACIT_Quest`), the forced Thunderbolt tutorial (`tut_forced_preparation`, `Recipe for Thunderbolt 1`) and **at a herbalist or alchemist** (`bHerbalist`: the menu was opened from an NPC whose merchant map pin is `Herbalist` or `Alchemic`).
- A successful brew or refill advances the create time, except quest recipes and at a herbalist.
- `PopulateData` appends ` | <charges>/<max> |` to the name of every singleton recipe whose item Geralt holds once.

### Per-item refill (`gameplay/alchemy/alchemyManager.ws`, `components/inventoryComponent.ws`, `alchemyMenu.ws`)

- **Charges** are vanilla's: the item modifier `ammo_current` on singleton items (potions, decoctions, bombs, oils; `SingletonItemGetAmmo/SetAmmo/RemoveAmmo`), max from `SingletonItemGetMaxAmmo`.
- **Refill = brewing an item Geralt already has** with charges missing: `W3AlchemyManager.IsRefillNeeded(recipe)` is true for a singleton potion, decoction, bomb or oil (oils only while oils have charges) held exactly once with `ammo < max`. Then `CanCookRecipe` skips vanilla's "cannot cook more" refusal and checks the refill cost, `CookItem` refills (`SingletonItemRefillAmmo(id, , refillOne)`: to max, or +1 with `prepRefillOne`) and takes the refill cost instead of the recipe, and `UpdateItemsById` lists the refill cost as the ingredient list.
- **Refill modes**, per type (`prepBombsRefillMode`, `prepOilsRefillMode`, `prepMutagensRefillMode`, `prepPotionsRefillMode`, menu vars `Virtual_prep*RefillMode`):

| Value | Mode | Refill cost |
|---|---|---|
| 0 | Autorefill | none in the menu; vanilla refill at meditation (only for this type) |
| 1 | Corresponding base (default) | 1 of the recipe's own base (`GetRefillBaseFromRecipe`): potions and decoctions Dwarven spirit / Alcohest / `White Gull 1`; bombs Saltpetre / Stammelfords dust / Alchemists powder; oils Dog tallow / Bear fat / Alchemical paste (`IsAlcohol`, `IsPowder`, `IsFat`) |
| 2–4 | One fixed base | 1 of the named base for every tier (`GetCommonRefillBase`; per type the three bases above, in that order) |
| 5 | Full recipe | every ingredient except the lower tier of the same item (`IsAnotherTier`: same name without level) |
| 6 | Base and herbs | the base and the ingredients tagged `HerbGameplay` |
| 7 | Exclude mutagen (decoctions only) | every ingredient except those whose name contains "mutagen" (`IsMutagen`); the lower tier is not skipped |

- **Vanilla refill filtered:** `SingletonItemsRefillAmmo` and `HasNotFilledSingletonItem` gained `skipPrepCheck` and act only on types in Autorefill mode unless it is set (so the alcohol is consumed only for those). `SingletonItemsRefillAmmoNoAlco` calls `HasNotFilledSingletonItem(, true)`.
- **Vanilla's alchemy-table bonus removed** from `SingletonItemRefillAmmo` (commented out: no more "max + 1 when the bed was used", no `SetWereItemsRefilled`); see the alchemy table effect below.
- Bug fixed in `CookItem`: `RemoveItemTag(items[i], 'NoShow')` → `items[0]`.

### Oils with limited uses (`inventoryComponent.ws`, `player/r4Player.ws`, `inventoryMenu.ws`, GUI)

- `prepMaxOilCharges` (0 = unlimited, vanilla; default 4): **an oil jar holds this many applications**. `SingletonItemGetMaxAmmo` returns it for an oil in Geralt's inventory instead of the item's `ammo` attribute (Red Wolf's set bonus and the alchemy-table effect still add to it; the bomb skills do not apply to oils).
- `CR4Player.ApplyOil`: with oil charges on, refuses an empty jar and removes one charge per application (after `CanApplyOilOnItem`).
- `CR4InventoryMenu.ApplyOil`: refused in combat with `prepDisallowOilsInCombat`; an empty jar gets the denied sound without a message; refreshes the jar's item and tab after applying.
- `CInventoryComponent.ModPrepCheckAmmo` (run at every settings update): sets every oil to its max when oil charges are off or when it holds more than its max.
- UI: `W3GuiBaseInventoryComponent.SetInventoryFlashObjectForItem` shows the jar's count on oil icons when oil charges are on; `W3TooltipComponent.GetBaseItemData` appends `[<charges>/<max>]` to an oil's "N charges" line (that N is the applied oil's hits, a different count), and shows the line for every oil.

### Meditation requirements (`player/playerWitcher.ws`)

`CanMeditate`, `CanMeditateWait` and `CanMeditateHere` are replaced by `IsMeditationAllowed()`; each shows the reason as a notification when false (`CModPreparationsConfig.GetMeditationError`). `IsMeditationAllowed` refuses, in order: game time paused by a quest; on a horse or boat; `EIAB_MeditationWaiting` blocked; state other than Exploration / Meditation / MeditationWaiting, or Exploration without `CanPerformPlayerAction`; threatened; submerged (`GetSubmergeDepth() < 0`); non-allied NPCs within `prepNpcDistance` m (`prepDisallowNPCs`; `HasNonAlliedActorsNearby`: every living actor except animals, horses and non-hostile VIPs); outdoors in a settlement (`prepDisallowSettlement`); in an interior (`prepDisallowInterior`); no fire nearby and none can be made (`prepDisallowMeditation`, default on).

- **`HasCampfire()`:** within 3 m (1.5 m in interiors) of: the cached `openFireEnt`; Friendly Meditation's `spawnedCampFire`; a `W3Campfire` (unless `prepDisallowCampFire`); a `W3FireSource` (unless `prepDisallowFireSource`); any entity with a `CGameplayLightComponent` (unless `prepDisallowLightSource`, default on). Whether the fire burns is not checked.
- **`CanSpawnCampfire()`** (Friendly Meditation's own campfire): no fire nearby, Friendly Meditation's `fmedSpawnCampfire` option on (read from FM's group `modFriendlyMeditation`), not in an interior (`prepDisallowCampFireInInterior`) or settlement (`prepDisallowCampFireInSettlement`), and `prepTimberAmount` Timber or `prepHardTimberAmount` Hardened timber in the bag. Sets `fmedCanSpawnCampfire`, which FM reads.
- Timers FM starts by name: `CampFireErrorMessageTimer` (`prep_error_campfire_*`, `prep_error_no_timber`) and `CampFireResourcesTimer` (`RemoveResourcesForCampfire`: Timber first, else Hardened timber).

### What meditation restores (`playerWitcher.ws`)

- `MeditationRestoring(simulatedTime)`: full heal unless `prepDisableRegenFullHealth` (default on; the option ignores difficulty, vanilla heals below Hard only). With time passed: `prepDisableCleanupCharStatus` (default on) runs `SimulateBuffTimePassing` (potions, toxicity and focus run their course), else drains toxicity and focus, `FinishQuen`, `RemoveAllNonAutoBuffs`; then the filtered refill. With no time passed (1.32 calls this from the clock menu when a quest paused time) and `prepDisableAutorefillQuest` off: vanilla's full restore and `SingletonItemsRefillAmmo(, true)`. `ApplyWitcherHouseBuffs` after.
- `SimulateBuffTimePassing` replaced: `effectManager.PerformUpdate(0.1)` in a loop over the simulated time ("the game can't handle updating effects over a long period"); vanilla's `super` call and `FinishQuen` gone.
- `ApplyWitcherHouseBuffs` (Corvo Bianco bed): also drains toxicity and focus; with an alchemy table (`AlchemyTableExists`) applies the alchemy table effect instead of vanilla's "items refilled" message.
- `NewGamePlusInitialize`: `SingletonItemsRefillAmmoNoAlco(true)` instead of `SingletonItemsRefillAmmo()` (full refill, no alcohol).
- `quest_function.ws`: `RecoverGeralt` skips its refill when `prepDisableAutorefillQuest`; `ApplyAlchemyTableBuff` calls `ManageAlchemyTableBonus` instead of `ManageSingletonItemsBonus`.

### Alchemy table effect (new effect type)

- `EET_AlchemyTable` (`effectTypes.ws`), `W3Effect_AlchemyTable extends CBaseGameplayEffect` (positive, `alchemyTable.ws`), registered in `gameEffectManager.ws` (`CacheEffect_Part1`, `EffectNameToType_Part2` "AlchemyTableEffect", `EffectTypeToName`).
- `effects_ep2.xml` (both folders): ability `AlchemyTableEffect` (`duration` 3600), effect entry (HUD icon `icon_alchemy_table`, label `effect_alchemytable` "Alchemy Laboratory"), icon `icons\buffs\icon_house_buff_alchemy.png`.
- Effect: **+1 max charge for every potion, bomb and oil (not decoctions) while it lasts** (`SingletonItemGetMaxAmmo`). Applied by `W3PlayerWitcher.ManageAlchemyTableBonus` (also shows `message_common_alchemy_table_buff_applied`). Legacy Ghost Mode's own `effects_ep2.xml` carries the same three entries (its readme: let Ghost Mode's file win).

### Time costs (`W3PlayerWitcher.AdvanceTimeSeconds`)

`theGame.SetGameTime(now + seconds, false)` and `UpdateEffectsAccelerated` (`effectManager.PerformUpdate`). Minutes per action (sliders 0–120, default 15): `prepTimeToCreateItemMins` (brew or refill), `prepTimeToRepairItemMins` (repair kit), `prepTimeToUpgradeItemMins`, `prepTimeToBuySkillMins`, `prepTimeToEquipSkillMins`, `prepTimeToEquipMutagenMins`. Charged whether meditating or not.

### Combat restrictions (`r4Player.ws`)

- `ConsumeItem`: edibles, `Drinks` and alcohol ingredients refused in combat with `prepDisallowEdiblesInCombat` (default on): inventory and quick slot.
- `OnCombatStart` / `OnCombatFinished`: `BlockAction(EIAB_OpenInventory, 'InCombat')` / unblock with `prepBlockInventoryInCombat` (default off); `DisallowedActionDontShowHack` lets the "blocked" message show for `EIAB_OpenInventory`.
- Oils in combat: see above. Upgrades and repair kits are refused in combat.

### Settings plumbing and fixes

- `CModPreparationsConfig` (`prepconfig/modPreparationsConfig.ws`), created in `W3PlayerWitcher.OnSpawned` (field `prepConfig`), initialised by the timer `ModPrepDelayedInit`; global `GetPreparationsConfig()`. `CR4IngameMenu.SaveChangedSettings` calls `UpdateUserSettings` (which also runs `SetupFHUD`, `SetupFMed`, `ModPrepCheckAmmo`).
- `SetupFMed`: `fmedCanSpawnCampfire = false`; FM's hourly autorefill on only if some type is in Autorefill mode.
- `ApplyModPrepFixes`: grants `Recipe for Tawny Owl 1` once (fact `MissingTawnyOwlRecipeAdded`).

## Menu options (`modPreparationsConfig.xml`)

Under Options → Mods → Preparations. Presets: Default / Friendly Meditation / Off (Time: Default / Off). Values: default; FM preset where it differs.

| Group | Option (var) | Type | Default | FM preset |
|---|---|---|---|---|
| Meditation `preparationsMeditation` | Disallow meditation away from fire `prepDisallowMeditation` | toggle | on | off |
| | Disallow existing campfires `prepDisallowCampFire` | toggle | off | |
| | Disallow existing fire sources `prepDisallowFireSource` | toggle | off | |
| | Disallow existing light sources `prepDisallowLightSource` | toggle | on | |
| | Disallow in interiors `prepDisallowInterior` | toggle | off | |
| | Disallow outdoors in settlements `prepDisallowSettlement` | toggle | off | |
| | Disallow near non-allied NPCs `prepDisallowNPCs` | toggle | off | |
| | Min distance to non-allied NPCs `prepNpcDistance` | slider 0–100 | 20 | |
| Friendly Meditation `preparationsFriendlyMeditation` | No campfire in interiors `prepDisallowCampFireInInterior` | toggle | off | on |
| | No campfire in settlements `prepDisallowCampFireInSettlement` | toggle | off | |
| | Timber for a campfire `prepTimberAmount` | slider 0–10 | 0 | 1 |
| | (or) Hardened timber `prepHardTimberAmount` | slider 0–10 | 0 | 1 |
| Alchemy `preparationsAlchemy` | Requires meditation `prepAlchemyMeditation` | toggle | off | on |
| | Requires campfire `prepAlchemyCampfire` | toggle | on | |
| | Disable quest autorefill `prepDisableAutorefillQuest` | toggle | off | |
| | Refill restores one charge `prepRefillOne` | toggle | off | |
| | Max uses per oil jar `prepMaxOilCharges` | slider 0–10 | 4 | |
| | Refill mode: bombs, oils, decoctions, potions `Virtual_prep*RefillMode` | options (table above) | 1 | |
| Character `preparationsCharacter` | Buy skills: meditation / campfire `prepBuySkillMeditation` / `…Campfire` | toggles | off / on | on / on |
| | Equip skills `prepEquipSkillMeditation` / `…Campfire` | toggles | off / on | on / on |
| | Equip mutagens `prepEquipMutagenMeditation` / `…Campfire` | toggles | off / on | on / on |
| | No full heal after meditation `prepDisableRegenFullHealth` | toggle | on | |
| | No effects cleanup after meditation `prepDisableCleanupCharStatus` | toggle | on | |
| Inventory `preparationsInventory` | Repair: meditation / campfire `prepRepairMeditation` / `…Campfire` | toggles | off / on | on / on |
| | Upgrade `prepUpgradeMeditation` / `…Campfire` | toggles | off / on | on / on |
| | No oils in combat `prepDisallowOilsInCombat` | toggle | on | |
| | No eating or drinking in combat `prepDisallowEdiblesInCombat` | toggle | on | |
| | Block inventory in combat `prepBlockInventoryInCombat` | toggle | off | |
| Time `preparationsTime` | Minutes to create, repair, upgrade, buy skill, equip skill, equip mutagen `prepTimeTo*Mins` | sliders 0–120 | 15 each | (Off preset: 0) |

The "Off" presets switch every restriction off and set every refill mode to Autorefill and oil charges to 0 (the meditation and alchemy Off presets leave `prepNpcDistance` and `prepRefillOne` unchanged).
