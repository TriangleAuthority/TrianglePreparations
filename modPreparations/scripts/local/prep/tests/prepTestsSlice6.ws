// Slice 6 (test only): PREP-FMED, with Friendly Meditation (and Ghost Mode) installed. Channel 'PREPTest'. Only
// vanilla calls, facts and tags reach Friendly Meditation from here (separate blobs). Preparations' options are
// changed in memory (CModPreparationsConfig fields); FM's through the config wrapper, unsaved.
//   preptest_fmed_defaults()        FM detected: the options default to legacy's "Friendly Meditation" preset
//   preptest_fmed_setup(timber)     FM: campfire on, removed on standing; Preparations: 1 Timber per campfire,
//                                   meditation allowed away from fire; Geralt carries that much Timber
//   preptest_fmed_start()           Meditate(): FM asks Preparations whether it may make its fire
//   preptest_fmed_nofire()          ~2 s later, with no Timber: no fire, Preparations said why
//   preptest_fmed_fire()            ~8 s later, with Timber: FM's fire burns, 1 Timber taken, it counts as a fire
//                                   even with "existing campfires do not count" on
//   preptest_fmed_stop()            stands Geralt up (MeditationForceAbort: closing 5.x's clock before an hour is
//                                   chosen leaves a seated Geralt seated)
//   preptest_fmed_after()           options read back

@addField(W3PlayerWitcher)
var prepTestTimber : int;

exec function preptest_fmed_defaults()
{
	var cfg : CInGameConfigWrapper;
	var keepValue : string;
	var bad : int;

	cfg = theGame.GetInGameConfigWrapper();
	bad += PrepTestCheck(PrepFMInstalled(), "Friendly Meditation detected (its menu has " + cfg.GetVarsNumByGroupName('modFriendlyMeditation') + " options)");
	bad += PrepTestCheck(PrepOptionDefault('preparationsMeditation', 'prepDisallowMeditation') == "false", "default: meditation allowed away from fire (FM preset)");
	bad += PrepTestCheck(PrepOptionDefault('preparationsFriendlyMeditation', 'prepDisallowCampFireInInterior') == "true", "default: no FM campfire in interiors");
	bad += PrepTestCheck(PrepOptionDefault('preparationsFriendlyMeditation', 'prepTimberAmount') == "1" && PrepOptionDefault('preparationsFriendlyMeditation', 'prepHardTimberAmount') == "1", "default: 1 Timber or 1 Hardened timber");
	bad += PrepTestCheck(PrepOptionDefault('preparationsAlchemy', 'prepAlchemyMeditation') == "true", "default: alchemy needs meditation");
	bad += PrepTestCheck(PrepOptionDefault('preparationsCharacter', 'prepBuySkillMeditation') == "true" && PrepOptionDefault('preparationsCharacter', 'prepEquipSkillMeditation') == "true"
		&& PrepOptionDefault('preparationsCharacter', 'prepEquipMutagenMeditation') == "true", "default: skills and mutagens need meditation");
	bad += PrepTestCheck(PrepOptionDefault('preparationsInventory', 'prepRepairMeditation') == "true" && PrepOptionDefault('preparationsInventory', 'prepUpgradeMeditation') == "true", "default: repair and upgrade need meditation");
	bad += PrepTestCheck(PrepOptionDefault('preparationsAlchemy', 'prepAlchemyCampfire') == "true" && PrepOptionDefault('preparationsMeditation', 'prepNpcDistance') == "20", "the other defaults unchanged");
	// an option never set takes the FM preset's value when the defaults are applied; one set is kept
	keepValue = cfg.GetVarValue('preparationsFriendlyMeditation', 'prepTimberAmount');
	cfg.SetVarValue('preparationsFriendlyMeditation', 'prepTimberAmount', "");
	PrepApplyDefaultOptions();
	bad += PrepTestCheck(cfg.GetVarValue('preparationsFriendlyMeditation', 'prepTimberAmount') == "1", "unset Timber amount set to 1 (" + cfg.GetVarValue('preparationsFriendlyMeditation', 'prepTimberAmount') + ")");
	cfg.SetVarValue('preparationsFriendlyMeditation', 'prepTimberAmount', "3");
	PrepApplyDefaultOptions();
	bad += PrepTestCheck(cfg.GetVarValue('preparationsFriendlyMeditation', 'prepTimberAmount') == "3", "a set Timber amount is kept");
	cfg.SetVarValue('preparationsFriendlyMeditation', 'prepTimberAmount', keepValue);
	LogChannel('PREPTest', "SUMMARY preptest_fmed_defaults " + bad + " failed");
}

exec function preptest_fmed_setup(timber : int)
{
	var w : W3PlayerWitcher;
	var have : int;

	w = GetWitcherPlayer();
	theGame.GetInGameConfigWrapper().SetVarValue('modFriendlyMeditation', 'fmedSpawnCampfire', "true");
	theGame.GetInGameConfigWrapper().SetVarValue('modFriendlyMeditation', 'fmedDoNotDespawnCampfire', "false");
	w.prepConfig.disallowMeditation = false;
	w.prepConfig.disallowCampFireInInterior = false;
	w.prepConfig.disallowCampFireInSettlement = false;
	w.prepConfig.timberAmount = 1;
	w.prepConfig.hardTimberAmount = 1;
	have = w.inv.GetItemQuantityByName('Timber');
	if(have > 0)
		w.inv.RemoveItemByName('Timber', have);
	have = w.inv.GetItemQuantityByName('Hardened timber');
	if(have > 0)
		w.inv.RemoveItemByName('Hardened timber', have);
	if(timber > 0)
		w.inv.AddAnItem('Timber', timber);
	w.prepTestTimber = w.inv.GetItemQuantityByName('Timber');
	w.prepLastMessage = "";
	LogChannel('PREPTest', "INFO Timber " + w.prepTestTimber + ", FM campfire option " + w.prepConfig.FMSpawnCampFire() + ", fire here " + w.PrepHasCampfire()
		+ ", may spawn " + w.PrepCanSpawnCampfire());
}

exec function preptest_fmed_start()
{
	var w : W3PlayerWitcher;

	w = GetWitcherPlayer();
	LogChannel('PREPTest', "INFO Meditate() " + w.Meditate() + ", state " + w.GetCurrentStateName() + ", facts left: query " + FactsQuerySum('fmed_campfire_query')
		+ ", answer " + FactsQuerySum('prep_fmed_campfire_ok') + ", MeditateWithIgnite " + w.GetBehaviorVariable('MeditateWithIgnite'));
}

exec function preptest_fmed_nofire()
{
	var w : W3PlayerWitcher;
	var bad : int;

	w = GetWitcherPlayer();
	LogChannel('PREPTest', "INFO state " + w.GetCurrentStateName() + ", fire by tag " + (bool)theGame.GetEntityByTag('fmed_campfire') + ", last message '" + w.prepLastMessage
		+ "', MeditateWithIgnite " + w.GetBehaviorVariable('MeditateWithIgnite'));
	bad += PrepTestCheck(w.PrepIsMeditating(), "meditating (allowed away from fire)");
	bad += PrepTestCheck(!theGame.GetEntityByTag('fmed_campfire') && w.GetBehaviorVariable('MeditateWithIgnite') == 0, "no FM campfire, no Igni pose");
	bad += PrepTestCheck(w.prepLastMessage == "prep_error_no_timber", "Preparations said why: '" + w.prepLastMessage + "'");
	bad += PrepTestCheck(FactsQuerySum('fmed_campfire_query') == 0 && FactsQuerySum('prep_fmed_campfire_ok') == 0, "the query facts are gone");
	LogChannel('PREPTest', "SUMMARY preptest_fmed_nofire " + bad + " failed");
}

exec function preptest_fmed_fire()
{
	var w : W3PlayerWitcher;
	var fire : CEntity;
	var bad : int;

	w = GetWitcherPlayer();
	fire = theGame.GetEntityByTag('fmed_campfire');
	LogChannel('PREPTest', "INFO state " + w.GetCurrentStateName() + ", fire by tag " + (bool)fire + ", Timber " + w.inv.GetItemQuantityByName('Timber') + " (had " + w.prepTestTimber
		+ "), last message '" + w.prepLastMessage + "'");
	bad += PrepTestCheck(w.PrepIsMeditating(), "meditating");
	bad += PrepTestCheck(fire && ((W3Campfire)fire).IsOnFire(), "FM's campfire burns");
	bad += PrepTestCheck(w.inv.GetItemQuantityByName('Timber') == w.prepTestTimber - 1, "1 Timber taken");
	bad += PrepTestCheck(w.PrepHasCampfire(), "it counts as a fire");
	w.prepConfig.disallowCampFire = true;
	w.prepConfig.disallowLightSource = true;
	w.prepOpenFireEnt = NULL;
	bad += PrepTestCheck(w.PrepHasCampfire(), "it counts with \"existing campfires do not count\" on");
	bad += PrepTestCheck(!w.PrepCanSpawnCampfire(), "no second FM campfire next to it");
	bad += PrepTestCheck(w.prepLastMessage == "", "no refusal shown");
	LogChannel('PREPTest', "SUMMARY preptest_fmed_fire " + bad + " failed");
}

exec function preptest_fmed_stop()
{
	GetWitcherPlayer().MeditationForceAbort(true);
	LogChannel('PREPTest', "INFO stop requested");
}

exec function preptest_fmed_after()
{
	var w : W3PlayerWitcher;

	w = GetWitcherPlayer();
	LogChannel('PREPTest', "INFO after: state " + w.GetCurrentStateName() + ", fire by tag " + (bool)theGame.GetEntityByTag('fmed_campfire'));
	w.prepConfig.UpdateUserSettings();
	theGame.GetInGameConfigWrapper().SetVarValue('modFriendlyMeditation', 'fmedSpawnCampfire', "false");
	LogChannel('PREPTest', "INFO options read back");
}
