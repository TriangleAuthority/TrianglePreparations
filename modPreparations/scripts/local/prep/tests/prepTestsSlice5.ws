// Slice 5 (test only): PREP-REST and PREP-FIX. Channel 'PREPTest'. Options are changed in memory only and read
// back at the end.
//   preptest_rest()   what MeditationRestoring restores in each branch, the quest refill, the Tawny Owl fix

// A timed effect and some toxicity, as drinking a potion gives. The effect is Preparations' alchemy table effect
// (an hour long): the Cat potion's effect did not attach when drunk or added by script.
function PrepTestDrinkCat() : CBaseGameplayEffect
{
	var w : W3PlayerWitcher;

	w = GetWitcherPlayer();
	w.RemoveAllBuffsOfType(EET_PrepAlchemyTable);
	w.AddEffectDefault(EET_PrepAlchemyTable, w, "preptest");
	w.ForceSetStat(BCS_Toxicity, 40);
	return w.GetBuff(EET_PrepAlchemyTable);
}

exec function preptest_rest()
{
	var w : W3PlayerWitcher;
	var cfg : CModPreparationsConfig;
	var cat : CBaseGameplayEffect;
	var potion : SItemUniqueId;
	var left, tox, vit, sim : float;
	var bad : int;

	w = GetWitcherPlayer();
	cfg = GetPreparationsConfig();
	bad += PrepTestCheck(cfg.disableRegenFullHealth && cfg.disableCleanupCharStatus && !cfg.disableAutorefillQuest, "defaults: no full heal, effects run their course, quest refill on");
	bad += PrepTestCheck(FactsQuerySum("MissingTawnyOwlRecipeAdded") >= 1, "PREP-FIX: the Tawny Owl fact is set after the load");

	// time passed, defaults: the Cat potion runs on with less time, toxicity not drained, no heal
	cat = PrepTestDrinkCat();
	if(!cat)
	{
		LogChannel('PREPTest', "FAIL preptest_rest: the test effect did not attach");
		return;
	}
	left = cat.GetTimeLeft();
	tox = w.GetStat(BCS_Toxicity);
	w.ForceSetStat(BCS_Vitality, w.GetStatMax(BCS_Vitality) * 0.5);
	sim = 30;
	w.MeditationRestoring(sim);
	cat = w.GetBuff(EET_PrepAlchemyTable);
	bad += PrepTestCheck(cat && cat.GetTimeLeft() < left && cat.GetTimeLeft() > left - sim - 1,
		"time passed: the effect runs on (" + left + " s -> " + cat.GetTimeLeft() + " s after " + sim + " s)");
	bad += PrepTestCheck(w.GetStat(BCS_Toxicity) > 0, "time passed: toxicity not drained (" + tox + " -> " + w.GetStat(BCS_Toxicity) + ")");

	// time passed, cleanup on: effects cleared, toxicity drained
	cfg.disableCleanupCharStatus = false;
	PrepTestDrinkCat();
	w.MeditationRestoring(sim);
	bad += PrepTestCheck(!w.HasBuff(EET_PrepAlchemyTable) && w.GetStat(BCS_Toxicity) == 0, "cleanup on: effect removed, toxicity drained");
	cfg.disableCleanupCharStatus = true;

	// no time passed (a quest paused time): full restore and unfiltered refill
	PrepTestDrinkCat();
	potion = PrepTestSwallow('Swallow 1', 0);
	thePlayer.inv.AddAnItem('Dwarven spirit', 1);
	w.ForceSetStat(BCS_Vitality, w.GetStatMax(BCS_Vitality) * 0.5);
	vit = w.GetStat(BCS_Vitality);
	w.MeditationRestoring(0);
	bad += PrepTestCheck(!w.HasBuff(EET_PrepAlchemyTable) && w.GetStat(BCS_Toxicity) == 0, "no time passed: effects cleared, toxicity drained");
	bad += PrepTestCheck(thePlayer.inv.SingletonItemGetAmmo(potion) == thePlayer.inv.SingletonItemGetMaxAmmo(potion), "no time passed: everything refilled (Swallow too, whatever its mode)");
	bad += PrepTestCheck(w.GetStat(BCS_Vitality) == vit, "no full heal by default (" + vit + " -> " + w.GetStat(BCS_Vitality) + ")");

	// full heal option off: healed on every difficulty
	cfg.disableRegenFullHealth = false;
	w.ForceSetStat(BCS_Vitality, w.GetStatMax(BCS_Vitality) * 0.5);
	w.MeditationRestoring(0);
	bad += PrepTestCheck(w.GetStat(BCS_Vitality) == w.GetStatMax(BCS_Vitality), "'Disable full health regen' off: full heal (difficulty " + theGame.GetDifficultyMode() + ")");
	cfg.disableRegenFullHealth = true;

	// quest refill off: no time passed restores nothing
	cfg.disableAutorefillQuest = true;
	PrepTestDrinkCat();
	thePlayer.inv.SingletonItemSetAmmo(potion, 0);
	w.MeditationRestoring(0);
	bad += PrepTestCheck(w.HasBuff(EET_PrepAlchemyTable) && thePlayer.inv.SingletonItemGetAmmo(potion) == 0, "'Disable quest autorefill': no restore, no refill");
	RecoverGeralt(true);
	bad += PrepTestCheck(thePlayer.inv.SingletonItemGetAmmo(potion) == 0, "'Disable quest autorefill': RecoverGeralt does not refill");
	cfg.disableAutorefillQuest = false;
	RecoverGeralt(true);
	bad += PrepTestCheck(thePlayer.inv.SingletonItemGetAmmo(potion) == thePlayer.inv.SingletonItemGetMaxAmmo(potion), "RecoverGeralt refills otherwise");

	w.RemoveAllBuffsOfType(EET_PrepAlchemyTable);
	w.ForceSetStat(BCS_Toxicity, 0);
	cfg.UpdateUserSettings();
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_rest");
	else
		LogChannel('PREPTest', "FAIL preptest_rest: " + bad + " failed");
}
