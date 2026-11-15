# Open questions

Only the game can answer:

- **Two blobs adding the same name:** can two blobs add a field or method of the same name to one class? (How wrappers and replacements from two blobs combine is answered in [ghost-mode-compatibility.md](ghost-mode-compatibility.md#ghost-mode).)
- **Enum extensions in saves:** does a saved `EET_PrepAlchemyTable` effect survive adding or removing Ghost Mode (renumbering), and removing Preparations?
- **Fire detection in 5.x:** a spawned `campfire_01.w2ent` is a `W3Campfire` and counts (**verified**, slice 1). Open: are the world's campfires and fireplaces still `W3Campfire` / `W3FireSource`; does an unlit campfire count (legacy does not check); which entities have a `CGameplayLightComponent`?
- **Meditation state and menus:** in vanilla 5.x, is Geralt in the `Meditation` state while the clock menu is open, and can he reach the character, alchemy and inventory menus from there?
- **Time jumps:** `SetGameTime` moves the clock by the exact amount (**verified**, slice 2). Open: does `effectManager.PerformUpdate` run potions and toxicity down over the jump; does the HUD clock follow; does `SimulateBuffTimePassing` still need the 0.1 s loop?
- **`icon_house_buff_alchemy.png`:** does the texture exist in 5.x's caches?
- **"Restart after compiling":** does the charge bug (0 or -1 charges on the first load after compiling) happen with a precompiled blob?
- **Auto-apply oils:** with an empty jar, does `AutoApplyBladeOil` fail silently or try another oil?

### To test in legacy Preparations

Things only the legacy game can show:

- `OnUpgradeSkill` (classic): is the buy time charged when the confirmation popup is cancelled (the code says yes)?
- `OnUnequipSkill` refused: does the slot look empty afterwards (legacy does not call `UpdateAppliedSkill`, vanilla's combat refusal does)?
- `HasNonAlliedActorsNearby`: do friendly villagers block meditation with "non-allied NPCs" on (the code skips only animals, horses and non-hostile VIPs)?
- `prepBlockInventoryInCombat` switched while in combat, or a save loaded in combat: does the inventory stay blocked?
- Oil tooltip: how did the two counts read ("20 charges [3/4]")?
- With the alchemy table effect expired, do items keep a charge above their max until used?
