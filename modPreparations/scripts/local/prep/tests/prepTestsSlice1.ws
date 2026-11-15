// Slice 1 (test only): PREP-MED, PREP-COMBAT, PREP-INV. Channel 'PREPTest'. Options are changed in memory
// only (CModPreparationsConfig fields) and read back from the settings at the end of each test.
//   preptest_med()            fire detection and the meditation rules, with a spawned campfire
//   preptest_inv()            the upgrade and repair rules
//   preptest_combat_setup()   in-memory "block inventory in combat" on and an apple in the bag; then spawn
//                             wolves (game.py: spawn(wolf, 2, 6, true)) and wait for combat
//   preptest_combat_check()   in combat: food refused, inventory blocked; then killall() and wait
//   preptest_combat_after()   out of combat: inventory unblocked, food allowed; options read back

function PrepTestCheck(ok : bool, what : string) : int
{
	if(ok)
	{
		LogChannel('PREPTest', "PASS " + what);
		return 0;
	}
	LogChannel('PREPTest', "FAIL " + what);
	return 1;
}

function PrepTestSpawnCampfire(offset : float) : CEntity
{
	var template : CEntityTemplate;
	var pos : Vector;

	template = (CEntityTemplate)LoadResource("environment\decorations\light_sources\campfire\campfire_01.w2ent", true);
	pos = thePlayer.GetWorldPosition() + VecFromHeading(thePlayer.GetHeading()) * offset;
	return theGame.CreateEntity(template, pos, thePlayer.GetWorldRotation());
}

exec function preptest_med()
{
	var w : W3PlayerWitcher;
	var cfg : CModPreparationsConfig;
	var fire : CEntity;
	var camp : W3Campfire;
	var bad : int;
	var vanillaOk : bool;

	w = GetWitcherPlayer();
	cfg = GetPreparationsConfig();
	w.prepOpenFireEnt = NULL;
	LogChannel('PREPTest', "INFO state=" + w.GetCurrentStateName() + " interior=" + w.IsInInterior() + " settlement=" + w.IsInSettlement()
		+ " threatened=" + w.IsThreatened() + " fire here=" + w.PrepHasCampfire() + " NPCs near=" + w.PrepHasNonAlliedActorsNearby());

	// defaults: no fire, no meditation
	bad += PrepTestCheck(cfg.disallowMeditation && cfg.disallowLightSource, "defaults: meditation needs a fire, light sources do not count");
	bad += PrepTestCheck(!w.PrepHasCampfire(), "no fire at the test spot");
	bad += PrepTestCheck(!w.PrepCanSpawnCampfire(), "no Friendly Meditation campfire without Friendly Meditation");
	bad += PrepTestCheck(w.PrepMeditationError() == "prep_error_no_campfire_found", "rule: no fire -> '" + w.PrepMeditationError() + "'");
	bad += PrepTestCheck(!w.CanMeditate() && w.prepMeditationRefusal == "prep_error_no_campfire_found", "CanMeditate refused, silently (refusal noted)");
	w.prepLastMessage = "";
	w.CanOpenMeditationMenu();
	w.CanReplenishWithoutMeditate();
	bad += PrepTestCheck(w.prepLastMessage == "", "the checks 5.x polls show nothing");
	bad += PrepTestCheck(!w.Meditate() && w.prepLastMessage == "prep_error_no_campfire_found", "Meditate() refused with the reason shown");
	w.prepLastMessage = "";
	w.DisplayActionDisallowedHudMessage(EIAB_OpenMeditation, , w.IsThreatened(), !w.CanMeditateHere(), w.IsThreatened());
	bad += PrepTestCheck(w.prepLastMessage == "prep_error_no_campfire_found", "the radial menu's refusal message shows Preparations' reason");

	// option off: 5.x's own rules only
	cfg.disallowMeditation = false;
	vanillaOk = w.CanMeditate();
	bad += PrepTestCheck(w.prepMeditationRefusal == "", "option off: no Preparations refusal (CanMeditate=" + vanillaOk + ")");
	w.prepLastMessage = "";
	w.DisplayActionDisallowedHudMessage(EIAB_OpenMeditation);
	bad += PrepTestCheck(w.prepLastMessage == "", "option off: 5.x's own message, not Preparations'");
	cfg.disallowMeditation = true;

	// a campfire next to Geralt
	fire = PrepTestSpawnCampfire(1.5);
	camp = (W3Campfire)fire;
	if(camp)
		bad += PrepTestCheck(true, "spawned a W3Campfire");
	else
		bad += PrepTestCheck(false, "spawned a W3Campfire");
	bad += PrepTestCheck(w.PrepHasCampfire(), "campfire 1.5 m away counts as fire");
	bad += PrepTestCheck(w.PrepMeditationError() == "", "rule met at the campfire");
	bad += PrepTestCheck(w.CanMeditate() == vanillaOk, "CanMeditate at the campfire = 5.x's own answer (" + vanillaOk + ")");
	w.prepOpenFireEnt = NULL;
	cfg.disallowCampFire = true;
	bad += PrepTestCheck(!w.PrepHasCampfire(), "'existing campfires do not count' on: no fire");
	cfg.disallowCampFire = false;
	bad += PrepTestCheck(w.PrepHasCampfire(), "option back off: fire again");

	// interiors, settlements and NPCs (forced on: only checks they do not refuse where they do not apply)
	cfg.disallowInterior = true;
	cfg.disallowSettlement = true;
	cfg.disallowNPCs = true;
	bad += PrepTestCheck(w.PrepMeditationError() == "" || w.IsInInterior() || w.IsInSettlement() || w.PrepHasNonAlliedActorsNearby(),
		"interior, settlement, NPC rules on outside them: no refusal ('" + w.PrepMeditationError() + "')");
	cfg.npcDistance = 0;
	bad += PrepTestCheck(!w.PrepHasNonAlliedActorsNearby(), "NPC distance 0: nobody near");

	// the campfire gone
	fire.Destroy();
	w.prepOpenFireEnt = NULL;
	bad += PrepTestCheck(!w.PrepHasCampfire(), "campfire destroyed: no fire");

	cfg.UpdateUserSettings();
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_med");
	else
		LogChannel('PREPTest', "FAIL preptest_med: " + bad + " failed");
}

exec function preptest_inv()
{
	var w : W3PlayerWitcher;
	var cfg : CModPreparationsConfig;
	var fire : CEntity;
	var bad : int;

	w = GetWitcherPlayer();
	cfg = GetPreparationsConfig();
	w.prepOpenFireEnt = NULL;
	bad += PrepTestCheck(cfg.repairCampfire && cfg.upgradeCampfire && !cfg.repairMeditation && !cfg.upgradeMeditation, "defaults: repair and upgrade need a campfire");
	bad += PrepTestCheck(PrepRepairRefusal() == "prep_error_campfire_required", "repair away from fire refused: '" + PrepRepairRefusal() + "'");
	bad += PrepTestCheck(PrepUpgradeRefusal() == "prep_error_campfire_required", "upgrade away from fire refused: '" + PrepUpgradeRefusal() + "'");
	cfg.repairMeditation = true;
	bad += PrepTestCheck(cfg.GetRepairError() == "prep_error_meditation_required", "both required: meditation named first");
	cfg.repairMeditation = false;

	fire = PrepTestSpawnCampfire(1.5);
	bad += PrepTestCheck(PrepRepairRefusal() == "" && PrepUpgradeRefusal() == "", "at a campfire: repair and upgrade allowed");
	fire.Destroy();
	w.prepOpenFireEnt = NULL;

	cfg.repairCampfire = false;
	cfg.upgradeCampfire = false;
	bad += PrepTestCheck(PrepRepairRefusal() == "" && PrepUpgradeRefusal() == "", "options off: allowed anywhere");

	cfg.UpdateUserSettings();
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_inv");
	else
		LogChannel('PREPTest', "FAIL preptest_inv: " + bad + " failed");
}

exec function preptest_combat_setup()
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	cfg.blockInventoryInCombat = true;
	thePlayer.inv.AddAnItem('Apple', 2);
	LogChannel('PREPTest', "INFO combat setup: block inventory in combat on (in memory), apples=" + thePlayer.inv.GetItemQuantityByName('Apple')
		+ " inCombat=" + thePlayer.IsInCombat());
}

function PrepTestEatApple() : bool
{
	var ids : array<SItemUniqueId>;

	ids = thePlayer.inv.GetItemsByName('Apple');
	if(ids.Size() == 0)
		return false;
	return thePlayer.ConsumeItem(ids[0]);
}

exec function preptest_combat_check()
{
	var bad, before : int;

	bad += PrepTestCheck(thePlayer.IsInCombat(), "in combat");
	before = thePlayer.inv.GetItemQuantityByName('Apple');
	bad += PrepTestCheck(!PrepTestEatApple() && thePlayer.inv.GetItemQuantityByName('Apple') == before, "eating in combat refused, apple kept");
	bad += PrepTestCheck(!thePlayer.IsActionAllowed(EIAB_OpenInventory), "inventory blocked in combat");
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_combat_check");
	else
		LogChannel('PREPTest', "FAIL preptest_combat_check: " + bad + " failed");
}

exec function preptest_combat_after()
{
	var bad, before : int;

	bad += PrepTestCheck(!thePlayer.IsInCombat(), "out of combat");
	bad += PrepTestCheck(thePlayer.IsActionAllowed(EIAB_OpenInventory), "inventory unblocked after combat");
	before = thePlayer.inv.GetItemQuantityByName('Apple');
	bad += PrepTestCheck(PrepTestEatApple() && thePlayer.inv.GetItemQuantityByName('Apple') == before - 1, "eating out of combat allowed");
	GetPreparationsConfig().UpdateUserSettings();
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_combat_after");
	else
		LogChannel('PREPTest', "FAIL preptest_combat_after: " + bad + " failed");
}
