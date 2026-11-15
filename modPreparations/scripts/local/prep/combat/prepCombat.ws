// PREP-COMBAT: no eating or drinking in combat; the inventory optionally blocked in combat.
// Ghost Mode replaces CR4Player.ConsumeItem (FOOD-05) and W3PlayerWitcher.OnCombatStart; these wrappers stack on them.

// Food, drinks and alcohol are refused in combat with "Disallow eating food in combat" (legacy adds this to
// 5.x's fist-fight refusal, with the same message).
@wrapMethod(CR4Player)
function ConsumeItem(itemId : SItemUniqueId) : bool
{
	var category : name;
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	if(cfg && cfg.disallowEdiblesInCombat && IsInCombat() && inv.IsIdValid(itemId))
	{
		category = inv.GetItemCategory(itemId);
		if(category == 'edibles' || inv.ItemHasTag(itemId, 'Drinks') || (category == 'alchemy_ingredient' && inv.ItemHasTag(itemId, 'Alcohol')))
		{
			DisplayActionDisallowedHudMessage(EIAB_Undefined, false, false, true);
			return false;
		}
	}
	return wrappedMethod(itemId);
}

// "Block inventory access in combat": the inventory is blocked while in combat. The option is read when
// combat starts and ends, as in legacy.
@wrapMethod(CR4Player)
function OnCombatStart()
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	if(cfg && cfg.blockInventoryInCombat)
		BlockAction(EIAB_OpenInventory, 'InCombat');
	return wrappedMethod();
}

@wrapMethod(CR4Player)
function OnCombatFinished()
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	if(cfg && cfg.blockInventoryInCombat)
		UnblockAction(EIAB_OpenInventory, 'InCombat');
	return wrappedMethod();
}

// The "blocked" message shows for the inventory too (legacy adds EIAB_OpenInventory to 5.x's meditation case).
@wrapMethod(CR4Player)
function DisallowedActionDontShowHack(action : EInputActionBlock, isTimeLock : bool) : bool
{
	if(action == EIAB_OpenInventory)
		return false;
	return wrappedMethod(action, isTimeLock);
}
