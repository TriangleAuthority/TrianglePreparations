// PREP-REST: what meditation restores. Legacy's rules:
// - "Disable full health regen after meditation" (default on): no full heal; with it off, a full heal on every
//   difficulty (5.x heals only below Blood and Broken Bones).
// - After time passed, "Disable effects cleanup after meditation" (default on): potions, toxicity and focus run
//   their course over the skipped time instead of being cleared; then the filtered refill (PREP-REFILL: only
//   the Autorefill types).
// - With no time passed (5.x's clock menu while a quest pauses time): the full restore and an unfiltered
//   refill, unless "Disable quest autorefill".
// The bed (Corvo Bianco) also drains toxicity and focus. MeditationRestoring always ends with
// ApplyWitcherHouseBuffs (Ghost Mode's exhaustion clear and Preparations' table effect hang on it).

@replaceMethod(W3PlayerWitcher)
function MeditationRestoring(simulatedTime : float)
{
	var cfg : CModPreparationsConfig;
	var skipBefore : bool;

	cfg = prepConfig;
	if(!cfg)
	{
		// no config yet (cannot happen in play): 5.x's own restore
		if(theGame.GetDifficultyMode() != EDM_Hard && theGame.GetDifficultyMode() != EDM_Hardcore)
			Heal(GetStatMax(BCS_Vitality));
		abilityManager.DrainToxicity(abilityManager.GetStat(BCS_Toxicity));
		abilityManager.DrainFocus(abilityManager.GetStat(BCS_Focus));
		inv.SingletonItemsRefillAmmo();
		SimulateBuffTimePassing(simulatedTime);
		ApplyWitcherHouseBuffs();
		return;
	}

	if(!cfg.disableRegenFullHealth)
		Heal(GetStatMax(BCS_Vitality));

	if(simulatedTime > 0)
	{
		if(cfg.disableCleanupCharStatus)
		{
			SimulateBuffTimePassing(simulatedTime);
		}
		else
		{
			abilityManager.DrainToxicity(abilityManager.GetStat(BCS_Toxicity));
			abilityManager.DrainFocus(abilityManager.GetStat(BCS_Focus));
			FinishQuen(true);
			RemoveAllNonAutoBuffs();
		}
		inv.SingletonItemsRefillAmmo();
	}
	else if(!cfg.disableAutorefillQuest)
	{
		abilityManager.DrainToxicity(abilityManager.GetStat(BCS_Toxicity));
		abilityManager.DrainFocus(abilityManager.GetStat(BCS_Focus));
		FinishQuen(true);
		RemoveAllNonAutoBuffs();
		skipBefore = inv.prepSkipRefillFilter;
		inv.prepSkipRefillFilter = true;
		inv.SingletonItemsRefillAmmo(, true);
		inv.prepSkipRefillFilter = skipBefore;
	}

	ApplyWitcherHouseBuffs();
}

// Legacy's SimulateBuffTimePassing: the effects updated in 0.1 s steps over the skipped time (real seconds), so
// potions, toxicity and focus run their course ("the game can't handle updating effects over a long period"),
// instead of 5.x's: every timed effect removed, Quen finished.
@replaceMethod(W3PlayerWitcher)
function SimulateBuffTimePassing(simulatedTime : float)
{
	var t, dt : float;

	dt = 0.1f;
	t = 0.0f;
	while(t < simulatedTime)
	{
		effectManager.PerformUpdate(dt);
		t += dt;
	}
}

// The bed: toxicity and focus drained too (legacy), with 5.x's bed effects after.
@addMethod(W3PlayerWitcher)
function PrepBedUsed() : bool
{
	var bed : W3WitcherBed;

	if(FactsQuerySum("PlayerInsideInnerWitcherHouse") <= 0)
		return false;
	bed = (W3WitcherBed)theGame.GetEntityByTag('witcherBed');
	if(!bed)
		return false;
	return bed.GetWasUsed();
}

// New Game+: 5.x refills with alcohol and Preparations' filter; legacy refills everything without alcohol.
@wrapMethod(W3PlayerWitcher)
function NewGamePlusInitialize()
{
	wrappedMethod();
	inv.SingletonItemsRefillAmmoNoAlco(true);
}

// The quest refill (RecoverGeralt): skipped with "Disable quest autorefill" (legacy).
@replaceMethod
function RecoverGeralt(dontUpdateUI : bool)
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	if(!cfg || !cfg.disableAutorefillQuest)
		thePlayer.inv.SingletonItemsRefillAmmoNoAlco(dontUpdateUI);
	thePlayer.Heal(thePlayer.GetStatMax(BCS_Vitality));

	if(GetWitcherPlayer())
	{
		thePlayer.ForceSetStat(BCS_Toxicity, 0.f);
	}
}

// PREP-FIX: the Tawny Owl recipe, missing from some games, granted once (legacy's fact; Ghost Mode grants it too).
@addMethod(W3PlayerWitcher)
function PrepApplyFixes()
{
	if(FactsQuerySum("MissingTawnyOwlRecipeAdded") < 1)
	{
		AddAlchemyRecipe('Recipe for Tawny Owl 1', true, true);
		FactsAdd("MissingTawnyOwlRecipeAdded");
	}
}
