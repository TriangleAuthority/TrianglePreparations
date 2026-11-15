// Slice 2 (test only): PREP-SKILL and PREP-TIME in the open character menu. Channel 'PREPTest'.
//   preptest_skill_setup()   skill points, a greater mutagen; then open the menu (dupemenu() for the new tree
//                            and Ghost Mode's classic tree, preptest_open_classic_menu() for 5.x's CR4CharacterMenu)
//   preptest_skill_menu()    with the menu open: refused away from fire, allowed with time charged at a campfire
//   preptest_time()          PrepAdvanceTimeSeconds moves the clock and runs the effects

exec function preptest_skill_setup()
{
	GetWitcherPlayer().AddPoints(ESkillPoint, 10, false);
	thePlayer.inv.AddAnItem('Greater mutagen red', 1);
	LogChannel('PREPTest', "INFO skill setup: points=" + GetWitcherPlayer().levelManager.GetPointsFree(ESkillPoint)
		+ " greater red mutagens=" + thePlayer.inv.GetItemQuantityByName('Greater mutagen red') + " level=" + GetWitcherPlayer().GetLevel());
}

exec function preptest_open_classic_menu()
{
	theGame.RequestMenu('CharacterMenu');
}

function PrepTestNow() : int
{
	return GameTimeToSeconds(theGame.GetGameTime());
}

function PrepTestCharMenu(out classic : CR4CharacterMenu, out dupe : CR4CharacterDupeMenu) : bool
{
	var root : CR4MenuBase;
	var common : CR4CommonMenu;

	root = (CR4MenuBase)theGame.GetGuiManager().GetRootMenu();
	classic = (CR4CharacterMenu)root;
	dupe = (CR4CharacterDupeMenu)root;
	common = (CR4CommonMenu)root;
	if(common)
	{
		classic = (CR4CharacterMenu)common.GetSubMenu();
		dupe = (CR4CharacterDupeMenu)common.GetSubMenu();
	}
	if(classic)
		return true;
	if(dupe)
		return true;
	return false;
}

function PrepTestBuy(classic : CR4CharacterMenu, dupe : CR4CharacterDupeMenu, skill : ESkill, slot : int)
{
	if(classic) classic.OnBuySkill(skill, slot); else dupe.OnBuySkill(skill, slot);
}
function PrepTestUpgrade(classic : CR4CharacterMenu, dupe : CR4CharacterDupeMenu, skill : ESkill)
{
	if(classic) classic.OnUpgradeSkill(skill); else dupe.OnUpgradeSkill(skill);
}
function PrepTestConfirm(classic : CR4CharacterMenu, dupe : CR4CharacterDupeMenu, skill : ESkill)
{
	if(classic) classic.handleBuySkillConfirmation(skill); else dupe.handleBuySkillConfirmation(skill);
}
function PrepTestEquip(classic : CR4CharacterMenu, dupe : CR4CharacterDupeMenu, skill : ESkill, slot : int)
{
	if(classic) classic.OnEquipSkill(skill, slot); else dupe.OnEquipSkill(skill, slot);
}
function PrepTestUnequip(classic : CR4CharacterMenu, dupe : CR4CharacterDupeMenu, slot : int)
{
	if(classic) classic.OnUnequipSkill(slot); else dupe.OnUnequipSkill(slot);
}
function PrepTestEquipMutagen(classic : CR4CharacterMenu, dupe : CR4CharacterDupeMenu, item : SItemUniqueId, slot : EEquipmentSlots)
{
	if(classic) classic.OnEquipMutagen(item, slot); else dupe.OnEquipMutagen(item, slot);
}
function PrepTestUnequipMutagen(classic : CR4CharacterMenu, dupe : CR4CharacterDupeMenu, slot : EEquipmentSlots)
{
	if(classic) classic.OnUnequipMutagen(slot); else dupe.OnUnequipMutagen(slot);
}

exec function preptest_skill_menu()
{
	var classic : CR4CharacterMenu;
	var dupe : CR4CharacterDupeMenu;
	var w : W3PlayerWitcher;
	var slots : array<SSkillSlot>;
	var skill, onSlot : ESkill;
	var slot, i, level, t, bad : int;
	var fire : CEntity;
	var mutagens : array<SItemUniqueId>;
	var onMutagenSlot : SItemUniqueId;
	var what, tree : string;

	w = GetWitcherPlayer();
	if(!PrepTestCharMenu(classic, dupe))
	{
		LogChannel('PREPTest', "FAIL preptest_skill_menu: no character menu open");
		return;
	}
	tree = theGame.GetInGameConfigWrapper().GetVarValue('GMGameplayOptions', 'GMClassicSkillTree');
	if(classic)
		what = "CR4CharacterMenu";
	else
		what = "CR4CharacterDupeMenu (Ghost Mode classic tree=" + tree + ")";
	if(classic || tree == "true")
		skill = S_Sword_s01;
	else
		skill = S_Sword_s35;
	slots = w.GetSkillSlots();
	slot = -1;
	for(i = 0; i < slots.Size() && slot < 0; i += 1)
		if(slots[i].unlocked)
			slot = slots[i].id;
	if(w.GetSkillOnSlot(slot, onSlot))
		w.UnequipSkill(slot);
	LogChannel('PREPTest', "INFO menu " + what + ": skill " + skill + " level " + w.GetSkillLevel(skill) + ", slot " + slot);

	// away from fire: everything refused, no time
	w.prepOpenFireEnt = NULL;
	level = w.GetSkillLevel(skill);
	t = PrepTestNow();
	w.prepLastMessage = "";
	PrepTestBuy(classic, dupe, skill, slot);
	bad += PrepTestCheck(w.GetSkillLevel(skill) == level && w.prepLastMessage == "prep_error_campfire_required", what + ": buy-and-equip refused away from fire ('" + w.prepLastMessage + "')");
	w.prepLastMessage = "";
	PrepTestUpgrade(classic, dupe, skill);
	bad += PrepTestCheck(w.GetSkillLevel(skill) == level && w.prepLastMessage == "prep_error_campfire_required", what + ": upgrade refused away from fire");
	bad += PrepTestCheck(PrepTestNow() == t, what + ": no time charged for refusals");

	// at a campfire
	fire = PrepTestSpawnCampfire(1.5);
	t = PrepTestNow();
	PrepTestConfirm(classic, dupe, skill);
	bad += PrepTestCheck(w.GetSkillLevel(skill) == level + 1, what + ": purchase confirmed at the fire (level " + level + " -> " + w.GetSkillLevel(skill) + ")");
	bad += PrepTestCheck(PrepTestNow() - t == 900, what + ": buy time charged on confirm (" + (PrepTestNow() - t) + " s, expected 900)");
	t = PrepTestNow();
	PrepTestEquip(classic, dupe, skill, slot);
	bad += PrepTestCheck(w.GetSkillOnSlot(slot, onSlot) && onSlot == skill, what + ": skill equipped at the fire");
	bad += PrepTestCheck(PrepTestNow() - t == 900, what + ": equip time charged (" + (PrepTestNow() - t) + " s)");
	t = PrepTestNow();
	PrepTestUnequip(classic, dupe, slot);
	bad += PrepTestCheck(!w.GetSkillOnSlot(slot, onSlot) || onSlot != skill, what + ": skill unequipped at the fire");
	bad += PrepTestCheck(PrepTestNow() == t, what + ": unequipping costs no time");

	// mutagen
	mutagens = thePlayer.inv.GetItemsByName('Greater mutagen red');
	if(mutagens.Size() > 0 && ((W3PlayerAbilityManager)w.abilityManager).IsSkillMutagenSlotUnlocked(EES_SkillMutagen1))
	{
		fire.Destroy();
		w.prepOpenFireEnt = NULL;
		w.prepLastMessage = "";
		PrepTestEquipMutagen(classic, dupe, mutagens[0], EES_SkillMutagen1);
		bad += PrepTestCheck(!(w.GetItemEquippedOnSlot(EES_SkillMutagen1, onMutagenSlot) && onMutagenSlot == mutagens[0])
			&& w.prepLastMessage == "prep_error_campfire_required", what + ": mutagen refused away from fire");
		fire = PrepTestSpawnCampfire(1.5);
		t = PrepTestNow();
		PrepTestEquipMutagen(classic, dupe, mutagens[0], EES_SkillMutagen1);
		bad += PrepTestCheck(w.GetItemEquippedOnSlot(EES_SkillMutagen1, onMutagenSlot) && onMutagenSlot == mutagens[0], what + ": mutagen equipped at the fire");
		bad += PrepTestCheck(PrepTestNow() - t == 900, what + ": mutagen time charged (" + (PrepTestNow() - t) + " s)");
		PrepTestUnequipMutagen(classic, dupe, EES_SkillMutagen1);
	}
	else
		LogChannel('PREPTest', "INFO mutagen check skipped: mutagens=" + mutagens.Size() + ", mutagen slot 1 locked at this level");

	// the fire gone: equipping refused
	fire.Destroy();
	w.prepOpenFireEnt = NULL;
	w.prepLastMessage = "";
	PrepTestEquip(classic, dupe, skill, slot);
	bad += PrepTestCheck(!(w.GetSkillOnSlot(slot, onSlot) && onSlot == skill) && w.prepLastMessage == "prep_error_campfire_required", what + ": equip refused away from fire");

	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_skill_menu " + what);
	else
		LogChannel('PREPTest', "FAIL preptest_skill_menu " + what + ": " + bad + " failed");
}

exec function preptest_time()
{
	var w : W3PlayerWitcher;
	var t, bad : int;

	w = GetWitcherPlayer();
	t = PrepTestNow();
	w.PrepAdvanceTimeSeconds(1800);
	bad += PrepTestCheck(PrepTestNow() - t == 1800, "PrepAdvanceTimeSeconds(1800) moved the clock " + (PrepTestNow() - t) + " s");
	t = PrepTestNow();
	w.PrepAdvanceTimeSeconds(0);
	bad += PrepTestCheck(PrepTestNow() == t, "0 s moves nothing");
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_time");
	else
		LogChannel('PREPTest', "FAIL preptest_time: " + bad + " failed");
}
