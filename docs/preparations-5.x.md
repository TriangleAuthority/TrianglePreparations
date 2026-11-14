# Preparations in 5.x

How 5.x differs in every file and function the legacy mod changes, and the proposed 5.x form for each. Read from `vanilla-1.32` and `vanilla-5.x` (`git diff -w vanilla-1.32 vanilla-5.x -- <path>`), **unverified** in game. "Same" means the function body is identical apart from whitespace (compared function by function). Port forms follow TriangleGhostMode's [development.md](https://github.com/TriangleAuthority/TriangleGhostMode/blob/master/docs/development.md): annotations in new files under `scripts/local/prep/`, a script blob, XML through the mod's own DLC, the menu XML in `bin\config\r4game\user_config_matrix\pc\`.

## Summary

- **Almost everything the mod touches is unchanged in 5.x**: the refill code (`SingletonItemRefillAmmo`, `SingletonItemsRefillAmmo`, `…NoAlco`, `HasNotFilledSingletonItem`, `SingletonItemGetMaxAmmo`, `ManageSingletonItemsBonus`), `CanCookRecipe`, the alchemy menu's `CreateItem`, `PopulateData`, `UpdateItemsById`, every gated event of the classic character menu but `OnUnequipSkill`, the five inventory-menu functions, `MeditationRestoring`, `ApplyWitcherHouseBuffs`, `SimulateBuffTimePassing`, `CanMeditateWait`, `CanMeditateHere`, `DisallowedActionDontShowHack`, `OnCombatStart`, `SaveChangedSettings`, `RecoverGeralt`, `ApplyAlchemyTableBuff`. Oils are still singleton items (`def_item_alchemy_oils.xml`: `SingletonItem` tag).
- **5.x adds nothing like Preparations**: no meditation requirements, no per-item refill, no oil charges, no time costs (the only new meditation options are the time-lapse's speed and blend: `RemasterCombat` `Meditation*`).
- **What 5.x changed that matters:** a second character menu for the new skill tree; more callers of `CanMeditate` (and a "replenish without meditating" path); the alchemy menu's ingredient shop (adopted from Friendly HUD, for any NPC); `CookItem` re-applies a brewed higher-tier oil; an "Auto Apply Blade Oils" accessibility option that calls `CR4Player.ApplyOil` in combat.
- **Community Patch – Base is not needed**: the mod's only change to a patch file is a hook in `SaveChangedSettings`, a wrapper in 5.x.

## Per file

### `gui/menus/characterMenu.ws` and the two skill trees

**Where skills are bought and equipped in 5.x:**

- **Classic tree:** `CR4CharacterMenu` (`characterMenu.ws`), opened when the hidden setting `RemasterCombat` `UseLegacySkillTree` is on (`CR4CommonMenu` swaps `CharacterMenuDupe` for `CharacterMenu`, `commonMenu.ws:675`).
- **New tree:** `CR4CharacterDupeMenu` (`characterMenuDupe.ws`, menu `CharacterMenuDupe`), the default.
- **With Ghost Mode:** Ghost Mode draws both trees in `CR4CharacterDupeMenu` (its SKL-02) and does not use `CR4CharacterMenu`; its own option `GMClassicSkillTree` picks the tree.
- Both menus have the same events: `OnBuySkill`, `OnSwapSkill`, `OnEquipSkill`, `OnUnequipSkill`, `OnUpgradeSkill`, `OnResearchMutation`, `OnEquipMutation`, `OnUnequipMutation`, `OnMoveMutagenToEmptySlot`, `OnEquipMutagen`, `OnUnequipMutagen`, each starting with vanilla's combat refusal. `characterSkillsMenu.ws` (`CR4CharacterSkillsMenu.OnBuySkill(skillName)`) is never opened (no `RequestMenu` of it).
- **Differences:** the classic `OnUpgradeSkill` opens the confirmation popup (`W3BuySkillConfirmation`, which calls `handleBuySkillConfirmation`), as in 1.32; the new tree's `OnUpgradeSkill` calls `handleBuySkillConfirmation` directly, no popup. Classic `OnUnequipSkill` gained one line. No other path buys skills from the UI (5.x's one-off `RemasterSkillResetAndRefund` at load, Ghost Mode's character reset `GMResetCharacter`, level-ups and Places of Power give or refund points but buy nothing).
- **Port form:** `@wrapMethod` of the eleven events on **both** `CR4CharacterMenu` and `CR4CharacterDupeMenu`: if not allowed, notify and `return false` before `wrappedMethod` (one call per wrapper; events cannot use a bare `return;`). Time costs: equip/research events after `wrappedMethod` when something changed; the skill purchase is better charged in a wrapper of `handleBuySkillConfirmation` (both menus), which covers the classic popup's confirm and the new tree's direct upgrade and does not charge a cancelled popup (a deviation: legacy charges before the popup). `OnBuySkill` (buy and equip in one) charges buy time. Ghost Mode replaces `CR4CharacterDupeMenu.OnSwapSkill`: a Preparations wrapper must stack on it ([port-plan.md](ghost-mode-compatibility.md#ghost-mode)).
- **Notes:** the new tree has 3 levels per skill, so a build costs fewer purchases (less time); the mutation panel exists in both menus.

### `gui/menus/inventoryMenu.ws`

`OnPutInSocket`, `OnRepairItem`, `ApplyUpgrade`, `ApplyOil`, `ApplyRepairKit`: same. 5.x adds `OnUseSharpstone` (no item has the `Sharpstone` tag in 5.x's data: dead code) and dyes (`ApplyDye`, untouched).

- **Port form:** `@wrapMethod` of all five (gate before `wrappedMethod`; time and the oil jar refresh after). `ApplyOil`, `ApplyUpgrade`, `ApplyRepairKit` are private: wrappers work on private methods (verified in Ghost Mode). Ghost Mode replaces `ApplyRepairKit` (its ITEM-11).

### `gui/menus/alchemyMenu.ws`

- 5.x took Friendly HUD's ingredient shop (`m_npc`, `m_npcInventory`, `m_shopInvComponent`, `OnBuyIngredient`, `BuyIngredient`, `GetTooltipData`, `UpdateItemsCounter`, `m_lastSelectedTag`) for **any** NPC who opens the menu, without the `bHerbalist` test and without `UpdateMerchantData`. 5.x also adds `m_forcedThunderbolt` (the forced tutorial) and `IsInShop()` returns `m_npc`. `CreateItem`, `PopulateData`, `UpdateItemsById`: same.
- **Port form:** `@addField bHerbalist`, set in a wrapper of `OnConfigUI` from `m_npc`'s `W3MerchantComponent.GetMapPinType()` (`Herbalist`, `Alchemic`). `CreateItem`: small, untouched by Ghost Mode: `@replaceMethod` (5.x body + gate + time after a successful `CookItem`), or a wrapper with the gate and a flag set by the `CookItem` wrapper for the time. `UpdateItemsById` (12 lines): `@replaceMethod` with the refill cost list. `PopulateData` (long; legacy adds the `| n/m |` title in mid-loop): `@replaceMethod` of the 5.x body, or drop the title suffix in favour of the ingredient list (decision). None of these is touched by Ghost Mode. The Friendly HUD and Friendly Stash code is not carried (5.x has the shop; the stash helpers were inert).

### `gameplay/alchemy/alchemyManager.ws`

- `CanCookRecipe`: same. `CookItem`: 5.x moved `witcher = GetWitcherPlayer()` up and **re-applies a brewed oil of level > 1 to a sword upgraded with the lower oil** (`IsEquippedSwordUpgradedWithOil`, `thePlayer.ApplyOil`); with oil charges this costs the new jar one charge.
- **Port form:** `@addMethod`s for legacy's helpers (`IsRefillNeeded`, `GetRefillBaseFromRecipe`, `UseTierBasedAlcoForRefill`, `UseBaseOnlyForRefill`, `UseFullRecipeForRefill`, `UseBaseAndHerbsForRefill`, `ExcludeMutagenForRefill`, `GetCommonRefillBase`, `IsBaseForRecipe`, `IsAnotherTier`, `IsHerb`, `IsMutagen`, `IsAlcohol`, `IsPowder`, `IsFat`; prefixed). **Wrappers, not replacements**, of `CanCookRecipe` and `CookItem`: when `IsRefillNeeded`, the wrapper does the refill check or the refill itself (cost by mode, `SingletonItemRefillAmmo`, the `NoShow` case) and skips `wrappedMethod`; otherwise it calls `wrappedMethod`. A refill then never reaches vanilla's (or Ghost Mode's replaced) brewing body, and a normal brew is untouched. Ghost Mode `@replaceMethod`s `CookItem` (FOOD-07), which is why a replacement is ruled out. Legacy's `items[i]` → `items[0]` fix: 5.x still has `RemoveItemTag(items[i], 'NoShow')` (`alchemyManager.ws:245`); the wrapper handles the `NoShow` item itself (legacy treats it as a re-brew, not a refill).
- 5.x's and Ghost Mode's recipes keep a base in every potion, decoction, bomb and oil recipe except Alraune Reagent, Sleeping Potion and Mutation Serum (checked by script over both `master` and `vanilla-5.x`), so "Corresponding base" works with both.

### `components/inventoryComponent.ws`

- All refill and ammo functions: same; `IsItemOil` same; `RemoveUnusedMutagensCount` same (still `void`).
- **Port form:**
  - `SingletonItemsRefillAmmo`, `HasNotFilledSingletonItem` gain a parameter in legacy: a signature cannot change. Use a field instead (`@addField prepSkipCheck`, set around the calls that need the unfiltered refill) and wrap: `SingletonItemsRefillAmmo` can be **replaced** (small; Ghost Mode does not touch it) with the per-type filter in its loop, `HasNotFilledSingletonItem` (private) likewise.
  - `SingletonItemRefillAmmo`: `@replaceMethod` (remove the alchemy-table branch, add the one-charge mode through a field or a new `@addMethod PrepRefillOne(id)` called by the `CookItem` wrapper instead).
  - `SingletonItemGetMaxAmmo`: **Ghost Mode replaces it** (SKL-18, Heavy Artillery and Efficiency). Preparations wraps it: for a player's oil, return `maxOilCharges` plus Red Wolf and the table effect; else `wrappedMethod` + 1 under the table effect (not decoctions). Difference: legacy adds the table's +1 before Heavy Artillery's multiplier, a wrapper after it (a deviation, small).
  - `ModPrepCheckAmmo`: `@addMethod`.

### `player/r4Player.ws`

- `ApplyOil`: 5.x adds one call, `CheckForPreviousLevelOilExploit` (with Fixative, `S_Alchemy_s06`), after the point where legacy inserts its charge check. **Ghost Mode replaces it** (SKL-14). Port: wrapper: refuse an empty jar before `wrappedMethod`, remove one charge when it returns true.
- `OnCombatStart` same, `OnCombatFinished` changed (5.x additions); port: wrappers. Ghost Mode replaces `W3PlayerWitcher.OnCombatStart` (calls `super`) and wraps both on `W3PlayerWitcher`; Preparations wraps `CR4Player`'s.
- `DisallowedActionDontShowHack`: same (private final; wrapping private and final methods works): wrapper returning false for `EIAB_OpenInventory`.
- `ConsumeItem`: 5.x adds a diving refusal. **Ghost Mode replaces it** (FOOD-05). Port: wrapper refusing edibles, drinks and alcohol in combat before `wrappedMethod`.
- **New in 5.x:** "Auto Apply Blade Oils" (`Accessibility` `AutoApplyBladeOils`): `ShouldAutoApplyOil` / `AutoApplyBladeOil` apply the right oil when combat starts or the target changes, through `CR4Player.ApplyOil`. With oil charges each auto-application costs a charge, an empty jar fails silently, and it bypasses "no oils in combat" (legacy's gate is only in the inventory menu). Decision needed.

### `player/playerWitcher.ws`

- `CanMeditate`: **changed**: 5.x first refuses when `EIAB_OpenMeditation` is blocked and while the Meditation state is leaving. `CanMeditateWait`, `CanMeditateHere`: same.
- **More callers:** 1.32 calls `CanMeditate*` from the clock menu and the radial menu only. 5.x adds `CanOpenMeditationMenu()` (`CanMeditate() && IsActionAllowed(EIAB_MeditationWaiting)`) and `CanReplenishWithoutMeditate()` (`CanMeditate() && EIAB_OpenMeditation allowed && EIAB_MeditationWaiting blocked`), called from `playerInput.ws:958/975`, `commonMenu.ws:982/2277`, `hudModuleRadialMenu.ws` (also every UI update: `m_fxSetMeditationButtonEnabledSFF`, line 408), and `CanMeditateHere` from `hudModuleMinimap2.ws`. **Legacy's replacements show a notification on every call**: ported as they are, they would spam notifications whenever the radial menu or the common menu updates.
  - **Port form:** `@replaceMethod` of `CanMeditate` (5.x's new checks + `IsMeditationAllowed`), `CanMeditateHere`, `CanMeditateWait`, all silent; show the reason only where meditation is actually attempted (wrapper of `Meditate()`, and the radial menu's choose branch, `hudModuleRadialMenu` wrapper). This is the main redesign of the port.
  - **"Replenish without meditating"** (radial, when waiting is blocked but meditation allowed) calls `MeditationRestoring(0)`: legacy's quest branch (full restore, unfiltered refill unless `prepDisableAutorefillQuest`). Since legacy's `IsMeditationAllowed` refuses when `EIAB_MeditationWaiting` is blocked, `CanReplenishWithoutMeditate` is then always false: the path is closed unless the port keeps 5.x's split. Decision needed.
- `MeditationRestoring`: same; 5.x also calls it with 0 from the clock menu when `GamePausedNotByUI` (as 1.32) and from the radial replenish. Port: `@replaceMethod` (legacy's body on 5.x's). **Ghost Mode wraps it** (STAM exhaustion clear): a wrapper stacks on a replacement.
- `SimulateBuffTimePassing`: same. Port: `@replaceMethod`. Whether 5.x's effect manager still needs the 0.1 s loop is a game question.
- `ApplyWitcherHouseBuffs`: same. Port: `@replaceMethod` (small).
- `NewGamePlusInitialize`: changed by 5.x; still calls `GetInventory().SingletonItemsRefillAmmo()` (line 1191). Port: no replacement: a wrapper that sets the unfiltered-refill field around `wrappedMethod` (or refills with `SingletonItemsRefillAmmoNoAlco(true)` after it). Ghost Mode wraps it too.
- `OnSpawned`: changed by 5.x; port: wrapper creating the config (`@addField prepConfig`) and starting the init timer (`@addMethod` timer, verified possible).
- New members (`IsMeditationAllowed`, `HasNonAlliedActorsNearby`, `HasCampfire`, `CanSpawnCampfire`, `AdvanceTimeSeconds`, `ManageAlchemyTableBonus`, `ApplyModPrepFixes`, the two campfire timers, `openFireEnt`): `@addField`/`@addMethod`, prefixed. None of legacy's names exists in 5.x; `IsMeditating`, `IsSkippingTime`, `UpdateEffectsAccelerated` are Friendly Meditation's too (see the plan). `W3Campfire`, `W3FireSource`, `CGameplayLightComponent`, `IsInInterior`, `IsInSettlement`, `theGame.SetGameTime` exist in 5.x.

### `quests/quest_function.ws`

`RecoverGeralt`, `ApplyAlchemyTableBuff`: same. Port: `@replaceMethod` of the two global quest functions (or wrappers: `ApplyAlchemyTableBuff` can skip `wrappedMethod`; `RecoverGeralt` needs the refill skipped in its middle: replacement).

### `gui/_old/components/guiTooltipComponent.ws`, `guiBaseInventoryComponent.ws`

- `GetBaseItemData` rewritten by 5.x (unique sword descriptions); the oil "charges" lines are unchanged. **Ghost Mode wraps it six times.** Port: wrapper that overwrites the `charges` member for an oil afterwards (Ghost Mode's pattern for flash values).
- `SetInventoryFlashObjectForItem` changed by 5.x (17 lines), its `if (!_inv.IsItemOil(item))` block is the same. Port: wrapper that sets the oil's quantity/charges member after `wrappedMethod` (which flash member carries the count: read in the 5.x body before writing).

### `gui/main_menu/ingameMenu.ws`

`SaveChangedSettings`: same. Port: `@wrapMethod` calling `UpdateUserSettings` (Ghost Mode wraps it too). 5.x reads settings from `dx12user.settings`; `user.settings.part.txt` is obsolete, so **every option needs a default in script** (unset vars read `""`, unset virtual options `"-1"`): with legacy's reader an unset refill mode reads -1, which is no mode at all (full recipe including the lower tier).

### Effects: `effectTypes.ws`, `gameEffectManager.ws`, `alchemyTable.ws`, `effects_ep2.xml`

- 5.x's `EEffectType` grew (43 lines); 5.x's `effects_ep2.xml` changed a few values, none near legacy's insertions. No `AlchemyTableEffect` and no reference to `icon_house_buff_alchemy.png` in 5.x's data (the other house icons, `icon_house_buff_bed/bookshelf/stables.png`, are referenced).
- **Port form** (Ghost Mode's verified recipe): enum extension (`EET_PrepAlchemyTable` or legacy's name), the class in a new file, registration by wrappers of `W3GameEffectManager.Initialize` (grow the array only if too small, as Ghost Mode does), `HACK_NO_MEMORY_TO_COMPILE_CacheEffect_Part1`, `HACK_NO_MEMORY_TO_COMPILE_EffectNameToType_Part1` (legacy used `_Part2`) and `EffectTypeToName`; ability, effect and icon entries in the mod's DLC XML (`abilities` and `abilities_plus`), not an override of `effects_ep2.xml`.
- **Hard:** two mods' enum extensions are numbered at load; whether a saved effect keeps its type when the mod set changes is unknown. Alternative without a new type: keep 5.x's own table bonus (refill to max + `QUANTITY_INCREASED_BY_ALCHEMY_TABLE`) for the bed refill.

### Menu and strings

- Menu XML: UTF-16 → UTF-8 with BOM, same groups and vars (keeps players' habits; no clash with Ghost Mode's or Friendly Meditation's group ids). Labels as now (`panel_*`, `option_*`, `preset_value_*`, `preset_Mods_*`); drop `panel_Mods` (vanilla's `panel_mods` serves).
- Strings: keep ids 2110750000–2110750125 (inside REDkit's mod range; Ghost Mode uses 2110992xxx, Gwent Improvements 211332xxxx, Friendly Meditation 2112067xxx), encode with `tools/w3strings.py`. The two hash-only rows override vanilla texts by key under a new id; Ghost Mode's rule for overrides is "the vanilla id, and the key": rewrite them that way. Drop the unused rows.
