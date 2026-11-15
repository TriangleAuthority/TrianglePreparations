// PREP-OIL: an oil jar holds "Max usages per oil jar" applications (0 = unlimited, vanilla). Each application
// takes one, an empty jar cannot be applied, and jars are refilled like other alchemy items (PREP-REFILL).
// "Disallow applying oils in combat" refuses applying from the inventory in combat (legacy) and 5.x's
// automatic oils in combat (owner, 2026-11-14); automatic and re-applied oils cost a charge like any other.
// Ghost Mode replaces CR4Player.ApplyOil and wraps SingletonItemGetMaxAmmo; Preparations wraps
// W3PlayerWitcher.ApplyOil (every player path reaches it; it calls CR4Player's through super).

// Legacy's SingletonItemGetMaxAmmo change: a player's oil holds maxOilCharges instead of its 'ammo' attribute
// (Red Wolf's set bonus still adds to it); the alchemy table effect (PREP-TABLE) adds one to every potion,
// bomb and oil (not decoctions).
@wrapMethod(CInventoryComponent)
function SingletonItemGetMaxAmmo(itemID : SItemUniqueId) : int
{
	var ammo, attr : int;
	var cfg : CModPreparationsConfig;
	var min, max : SAbilityAttributeValue;
	var witcher : W3PlayerWitcher;

	ammo = wrappedMethod(itemID);
	witcher = GetWitcherPlayer();
	if(!witcher || GetEntity() != witcher)
		return ammo;
	cfg = GetPreparationsConfig();
	if(cfg && cfg.OilsHaveAmmo() && IsItemOil(itemID))
	{
		attr = RoundMath(CalculateAttributeValue(GetItemAttributeValue(itemID, 'ammo')));
		if(attr > 0)
			ammo = ammo - attr + cfg.maxOilCharges;	// the attribute replaced, 5.x's bonuses kept
		else
		{
			ammo = cfg.maxOilCharges;
			if(!ItemHasTag(itemID, 'NoAdditionalAmmo') && witcher.IsSetBonusActive(EISB_RedWolf_2))
			{
				theGame.GetDefinitionsManager().GetAbilityAttributeValue(GetSetBonusAbility(EISB_RedWolf_2), 'amount', min, max);
				ammo += (int)min.valueAdditive;
			}
		}
	}
	if(ammo > 0 && !ItemHasTag(itemID, 'NoAdditionalAmmo') && !IsItemMutagenPotion(itemID) && PrepHasAlchemyTableEffect())
		ammo += 1;
	return ammo;
}

// Legacy's ModPrepCheckAmmo, at every settings update: with oil charges off every oil is full again; with them
// on, no oil holds more than its max.
@addMethod(CInventoryComponent)
function PrepCheckOilAmmo(oilsHaveAmmo : bool)
{
	var ids : array<SItemUniqueId>;
	var i : int;

	ids = GetSingletonItems();
	for(i = 0; i < ids.Size(); i += 1)
	{
		if(IsItemOil(ids[i]) && (!oilsHaveAmmo || SingletonItemGetAmmo(ids[i]) > SingletonItemGetMaxAmmo(ids[i])))
			SetItemModifierInt(ids[i], 'ammo_current', SingletonItemGetMaxAmmo(ids[i]));
	}
}

// Applying an oil (the inventory, 5.x's automatic oils, the re-apply after brewing a stronger oil): an empty
// jar is refused, so is any application in combat with "Disallow applying oils in combat"; a successful one
// takes a charge.
@wrapMethod(W3PlayerWitcher)
function ApplyOil(oilId : SItemUniqueId, usedOnItem : SItemUniqueId) : bool
{
	var cfg : CModPreparationsConfig;
	var applied : bool;

	cfg = GetPreparationsConfig();
	if(cfg && cfg.OilsHaveAmmo() && inv.SingletonItemGetAmmo(oilId) < 1)
		return false;
	if(cfg && cfg.disallowOilsInCombat && IsInCombat())
		return false;
	applied = wrappedMethod(oilId, usedOnItem);
	if(applied && cfg && cfg.OilsHaveAmmo())
		inv.SingletonItemRemoveAmmo(oilId);
	return applied;
}

// The inventory's oil: in combat with the option, the "combat" message; an empty jar, the "denied" sound; after
// applying, the jar's count is redrawn (legacy).
@wrapMethod(CR4InventoryMenu)
function ApplyOil(itemId : SItemUniqueId, targetSlot : int)
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	if(cfg && cfg.disallowOilsInCombat && thePlayer.IsInCombat())
	{
		PrepMenuRefuse("menu_cannot_perform_action_combat");
		return;
	}
	if(cfg && cfg.OilsHaveAmmo() && thePlayer.inv.SingletonItemGetAmmo(itemId) < 1)
	{
		OnPlaySoundEvent("gui_global_denied");
		return;
	}
	wrappedMethod(itemId, targetSlot);
	InventoryUpdateItem(itemId);
	updateCurrentTab();
}

// The jar's charges on the oil's icon (legacy shows them as for other singleton items).
@wrapMethod(W3GuiBaseInventoryComponent)
function SetInventoryFlashObjectForItem(item : SItemUniqueId, out flashObject : CScriptedFlashObject) : void
{
	var cfg : CModPreparationsConfig;
	var chargesCount : int;

	wrappedMethod(item, flashObject);
	cfg = GetPreparationsConfig();
	if(cfg && cfg.OilsHaveAmmo() && _inv.IsItemOil(item) && _inv.IsItemSingletonItem(item) && thePlayer.inv.SingletonItemGetMaxAmmo(item) > 0)
	{
		chargesCount = thePlayer.inv.SingletonItemGetAmmo(item);
		if(chargesCount <= 0)
			flashObject.SetMemberFlashString("charges", "<font color=\"#CC0000\">" + chargesCount + " </font>");
		else
			flashObject.SetMemberFlashString("charges", "<font color=\"#DEDEDE\">" + chargesCount + " </font>");
	}
}

// The oil's tooltip: its "N charges" line (the applied oil's hits) gets the jar's " [charges/max]", for every
// oil (legacy). At the default folder order Ghost Mode's wrapper runs outside this one and rewrites the line
// when Fixative is equipped (SKL-14), dropping the jar count there.
@wrapMethod(W3TooltipComponent)
function GetBaseItemData(item : SItemUniqueId, itemInvComponent : CInventoryComponent, optional isShopItem : bool, optional compareWithItem : SItemUniqueId, optional compareItemInv : CInventoryComponent) : CScriptedFlashObject
{
	var data : CScriptedFlashObject;
	var cfg : CModPreparationsConfig;
	var line : string;

	data = wrappedMethod(item, itemInvComponent, isShopItem, compareWithItem, compareItemInv);
	cfg = GetPreparationsConfig();
	if(data && cfg && cfg.OilsHaveAmmo() && itemInvComponent && itemInvComponent.IsItemOil(item) && itemInvComponent.GetEntity() == thePlayer)
	{
		line = data.GetMemberFlashString("charges");
		if(line == "")
			line = RoundF(CalculateAttributeValue(itemInvComponent.GetItemAttributeValue(item, 'ammo'))) + " " + GetLocStringByKeyExt("inventory_tooltip_charges");
		data.SetMemberFlashString("charges", line + " [" + itemInvComponent.SingletonItemGetAmmo(item) + "/" + itemInvComponent.SingletonItemGetMaxAmmo(item) + "]");
	}
	return data;
}
