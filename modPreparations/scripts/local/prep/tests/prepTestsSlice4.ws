// Slice 4 (test only): PREP-OIL and PREP-TABLE. Channel 'PREPTest'. Options are changed in memory only and
// read back at the end.
//   preptest_oil()          jar charges: max, an application takes one, an empty jar refused, charges off
//   preptest_oil_combat()   in combat (after preptest_combat_setup and spawned wolves): applying refused
//   preptest_table()        the alchemy table effect: registration, +1 charge, the message text, Ghost Mode's effects

function PrepTestOil() : SItemUniqueId
{
	var ids : array<SItemUniqueId>;

	thePlayer.inv.RemoveItemByName('Hanged Man Venom 1', 100);
	ids = thePlayer.inv.AddAnItem('Hanged Man Venom 1', 1);
	return ids[0];
}

exec function preptest_oil()
{
	var w : W3PlayerWitcher;
	var cfg : CModPreparationsConfig;
	var oil, sword : SItemUniqueId;
	var tooltip : W3TooltipComponent;
	var data : CScriptedFlashObject;
	var bad, attr : int;

	w = GetWitcherPlayer();
	cfg = GetPreparationsConfig();
	oil = PrepTestOil();
	w.GetItemEquippedOnSlot(EES_SteelSword, sword);
	attr = RoundMath(CalculateAttributeValue(w.inv.GetItemAttributeValue(oil, 'ammo')));
	bad += PrepTestCheck(cfg.maxOilCharges == 4 && w.inv.SingletonItemGetMaxAmmo(oil) == 4, "a jar holds the option's 4 applications (max " + w.inv.SingletonItemGetMaxAmmo(oil) + ", the oil's own 'ammo' " + attr + ")");
	w.inv.SingletonItemSetAmmo(oil, 4);
	bad += PrepTestCheck(w.ApplyOil(oil, sword) && w.inv.SingletonItemGetAmmo(oil) == 3, "applying takes one charge (4 -> " + w.inv.SingletonItemGetAmmo(oil) + ")");
	w.inv.SingletonItemSetAmmo(oil, 0);
	bad += PrepTestCheck(!w.ApplyOil(oil, sword) && w.inv.SingletonItemGetAmmo(oil) == 0, "an empty jar cannot be applied");

	// the tooltip line with the jar's count
	w.inv.SingletonItemSetAmmo(oil, 2);
	tooltip = new W3TooltipComponent in w;
	tooltip.initialize(w.inv, theGame.GetHud().GetHudFlashValueStorage());
	tooltip.setCurrentInventory(w.inv);
	data = tooltip.GetBaseItemData(oil, w.inv);
	bad += PrepTestCheck(StrEndsWith(data.GetMemberFlashString("charges"), "[2/4]"), "tooltip: '" + data.GetMemberFlashString("charges") + "'");

	// charges off: vanilla jars, all full again
	cfg.maxOilCharges = 0;
	w.inv.PrepCheckOilAmmo(cfg.OilsHaveAmmo());
	bad += PrepTestCheck(w.inv.SingletonItemGetMaxAmmo(oil) == attr && w.inv.SingletonItemGetAmmo(oil) == attr, "charges off: the oil's own max (" + attr + "), full");
	bad += PrepTestCheck(w.ApplyOil(oil, sword) && w.inv.SingletonItemGetAmmo(oil) == attr, "charges off: applying takes nothing");

	cfg.UpdateUserSettings();
	bad += PrepTestCheck(w.inv.SingletonItemGetAmmo(oil) == 4, "charges back on: the jar clamped to 4 (" + w.inv.SingletonItemGetAmmo(oil) + ")");
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_oil");
	else
		LogChannel('PREPTest', "FAIL preptest_oil: " + bad + " failed");
}

exec function preptest_oil_combat()
{
	var w : W3PlayerWitcher;
	var oil, sword : SItemUniqueId;
	var bad : int;

	w = GetWitcherPlayer();
	oil = PrepTestOil();
	w.inv.SingletonItemSetAmmo(oil, 4);
	w.GetItemEquippedOnSlot(EES_SteelSword, sword);
	bad += PrepTestCheck(w.IsInCombat(), "in combat");
	bad += PrepTestCheck(!w.ApplyOil(oil, sword) && w.inv.SingletonItemGetAmmo(oil) == 4, "applying an oil in combat refused (automatic oils go the same way), no charge taken");
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_oil_combat");
	else
		LogChannel('PREPTest', "FAIL preptest_oil_combat: " + bad + " failed");
}

exec function preptest_table()
{
	var w : W3PlayerWitcher;
	var potion, oil, decoction : SItemUniqueId;
	var ids : array<SItemUniqueId>;
	var potionMax, oilMax, decoctionMax, bad : int;
	var buff : CBaseGameplayEffect;
	var text : string;

	w = GetWitcherPlayer();
	potion = PrepTestSwallow('Swallow 1', 1);
	oil = PrepTestOil();
	thePlayer.inv.RemoveItemByName('Mutagen 3', 100);
	ids = thePlayer.inv.AddAnItem('Mutagen 3', 1);
	decoction = ids[0];
	potionMax = w.inv.SingletonItemGetMaxAmmo(potion);
	oilMax = w.inv.SingletonItemGetMaxAmmo(oil);
	decoctionMax = w.inv.SingletonItemGetMaxAmmo(decoction);

	bad += PrepTestCheck(EffectTypeToName(EET_PrepAlchemyTable) == 'PrepAlchemyTableEffect', "effect type <-> name registered");
	w.prepLastMessage = "";
	w.PrepManageAlchemyTableBonus();
	buff = w.GetBuff(EET_PrepAlchemyTable);
	bad += PrepTestCheck(w.HasBuff(EET_PrepAlchemyTable), "the alchemy table effect is on Geralt");
	if(buff)
		bad += PrepTestCheck(buff.GetDurationLeft() > 3500 && buff.GetDurationLeft() <= 3600, "it lasts an hour (" + buff.GetDurationLeft() + " s left)");
	bad += PrepTestCheck(w.inv.SingletonItemGetMaxAmmo(potion) == potionMax + 1 && w.inv.SingletonItemGetMaxAmmo(oil) == oilMax + 1,
		"+1 charge: Swallow " + potionMax + " -> " + w.inv.SingletonItemGetMaxAmmo(potion) + ", oil " + oilMax + " -> " + w.inv.SingletonItemGetMaxAmmo(oil));
	bad += PrepTestCheck(w.inv.SingletonItemGetMaxAmmo(decoction) == decoctionMax, "decoctions unchanged (" + decoctionMax + ")");
	text = GetLocStringByKeyExt("message_common_alchemy_table_buff_applied");
	bad += PrepTestCheck(StrFindFirst(text, "oils") >= 0 || StrFindFirst(text, "oil") >= 0, "the table's message names oils too: '" + text + "'");

	// a refill sets the max, also down from above it once the effect is gone
	w.inv.SingletonItemSetAmmo(potion, potionMax + 1);
	w.RemoveAllBuffsOfType(EET_PrepAlchemyTable);
	bad += PrepTestCheck(!w.HasBuff(EET_PrepAlchemyTable) && w.inv.SingletonItemGetAmmo(potion) == potionMax + 1, "effect removed: the charge above the max stays until used or refilled");
	w.inv.SingletonItemRefillAmmo(potion);
	bad += PrepTestCheck(w.inv.SingletonItemGetAmmo(potion) == potionMax, "a refill sets it back to the max (" + w.inv.SingletonItemGetAmmo(potion) + ")");

	// Ghost Mode's effects still work beside the mirrored enum
	w.AddEffectDefault(EET_GMAardCooldown, w, "preptest");
	bad += PrepTestCheck(w.HasBuff(EET_GMAardCooldown) && EffectTypeToName(EET_GMAardCooldown) == 'GMAardCooldownEffect', "Ghost Mode's Aard cooldown effect works");
	w.RemoveAllBuffsOfType(EET_GMAardCooldown);

	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_table");
	else
		LogChannel('PREPTest', "FAIL preptest_table: " + bad + " failed");
}
