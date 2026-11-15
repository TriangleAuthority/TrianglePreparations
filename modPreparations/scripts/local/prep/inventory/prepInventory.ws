// PREP-INV: upgrading (runes, glyphs, armour upgrades) and repairing with kits only where the options allow
// (at a fire, while meditating), and never in combat. Blacksmiths are not affected. The time these cost
// comes with PREP-TIME. Ghost Mode replaces ApplyRepairKit (ITEM-11), and a replacement in the mod that loads
// first drops the other mod's wrappers of it, so Preparations gates the two events that call it instead.

// The reason an upgrade or repair is refused now ("" if allowed), as legacy checks it: combat first.
function PrepUpgradeRefusal() : string
{
	var cfg : CModPreparationsConfig;

	if(thePlayer.IsInCombat())
		return "menu_cannot_perform_action_combat";
	cfg = GetPreparationsConfig();
	if(cfg && !cfg.IsUpgradeAllowed())
		return cfg.GetUpgradeError();
	return "";
}

function PrepRepairRefusal() : string
{
	var cfg : CModPreparationsConfig;

	if(thePlayer.IsInCombat())
		return "menu_cannot_perform_action_combat";
	cfg = GetPreparationsConfig();
	if(cfg && !cfg.IsRepairAllowed())
		return cfg.GetRepairError();
	return "";
}

@addMethod(CR4InventoryMenu)
function PrepRefuse(key : string)
{
	var w : W3PlayerWitcher;

	w = GetWitcherPlayer();
	if(w)
		w.prepLastMessage = key;
	showNotification(GetLocStringByKeyExt(key));
	OnPlaySoundEvent("gui_global_denied");
}

// Choosing an upgrade to put in a socket. 5.x refuses in combat itself; Preparations' rule is checked after.
@wrapMethod(CR4InventoryMenu)
function OnPutInSocket(item : SItemUniqueId)
{
	var refusal : string;

	refusal = PrepUpgradeRefusal();
	if(refusal != "" && refusal != "menu_cannot_perform_action_combat")
	{
		PrepRefuse(refusal);
		return true;
	}
	return wrappedMethod(item);
}

// Choosing a repair kit (legacy also refuses it in combat, which 5.x does not).
@wrapMethod(CR4InventoryMenu)
function OnRepairItem(item : SItemUniqueId)
{
	var refusal : string;

	refusal = PrepRepairRefusal();
	if(refusal != "")
	{
		PrepRefuse(refusal);
		return true;
	}
	return wrappedMethod(item);
}

// Applying the upgrade or the kit to the chosen item (also reached by dragging it onto the item).
@wrapMethod(CR4InventoryMenu)
function ApplyUpgrade(itemId : SItemUniqueId, targetSlot : int)
{
	var refusal : string;

	refusal = PrepUpgradeRefusal();
	if(refusal != "")
	{
		PrepRefuse(refusal);
		return;
	}
	wrappedMethod(itemId, targetSlot);
}

// The two ways a repair kit is applied (ApplyRepairKit's only callers): the kit dropped on an item, and the
// item chosen after selecting the kit.
@wrapMethod(CR4InventoryMenu)
function OnApplyRepairKit(item : SItemUniqueId, slot : int)
{
	var refusal : string;

	refusal = PrepRepairRefusal();
	if(refusal != "")
	{
		PrepRefuse(refusal);
		return false;
	}
	return wrappedMethod(item, slot);
}

@wrapMethod(CR4InventoryMenu)
function OnSelectionModeTargetChosen(targetSlot : int)
{
	var refusal : string;

	if(_inv.ItemHasTag(m_selectionModeItem, 'WeaponReapairKit') || _inv.ItemHasTag(m_selectionModeItem, 'ArmorReapairKit'))
	{
		refusal = PrepRepairRefusal();
		if(refusal != "")
		{
			PrepRefuse(refusal);
			HideSelectionMode();
			return false;
		}
	}
	return wrappedMethod(targetSlot);
}
