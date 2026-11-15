// PREP-MENU: Preparations' options. The menu is modPreparations/menu/modPreparationsConfig.xml
// (Options > Mods > Preparations, legacy 6.2's groups and ids); values live in Documents\The Witcher 3's
// user settings file. Legacy shipped its defaults as user.settings lines the player pasted by hand; here every
// option has its default in PrepOptionDefault (legacy's "Defaults" preset, the same values as its
// user.settings.part.txt), written when a save loads into options that were never set, and the reads fall
// back to it while an option is empty.

// Default value of a Preparations option ("" if unknown). Add new options here, to PrepOptionList and to the menu.
function PrepOptionDefault(group : name, option : name) : string
{
	switch(group)
	{
		case 'preparationsMeditation' :
			switch(option)
			{
				case 'prepDisallowMeditation' :		return "true";
				case 'prepDisallowCampFire' :		return "false";
				case 'prepDisallowFireSource' :		return "false";
				case 'prepDisallowLightSource' :	return "true";
				case 'prepDisallowInterior' :		return "false";
				case 'prepDisallowSettlement' :		return "false";
				case 'prepDisallowNPCs' :		return "false";
				case 'prepNpcDistance' :		return "20";
			}
			break;
		case 'preparationsFriendlyMeditation' :
			switch(option)
			{
				case 'prepDisallowCampFireInInterior' :		return "false";
				case 'prepDisallowCampFireInSettlement' :	return "false";
				case 'prepTimberAmount' :			return "0";
				case 'prepHardTimberAmount' :			return "0";
			}
			break;
		case 'preparationsAlchemy' :
			switch(option)
			{
				case 'prepAlchemyMeditation' :		return "false";
				case 'prepAlchemyCampfire' :		return "true";
				case 'prepDisableAutorefillQuest' :	return "false";
				case 'prepRefillOne' :			return "false";
				case 'prepMaxOilCharges' :		return "4";
				// the refill modes are OPTIONS lists: their virtual variables hold the chosen entry
				// ("Corresponding base" = 1)
				case 'Virtual_prepBombsRefillMode' :	return "1";
				case 'Virtual_prepOilsRefillMode' :	return "1";
				case 'Virtual_prepMutagensRefillMode' :	return "1";
				case 'Virtual_prepPotionsRefillMode' :	return "1";
			}
			break;
		case 'preparationsCharacter' :
			switch(option)
			{
				case 'prepBuySkillMeditation' :		return "false";
				case 'prepBuySkillCampfire' :		return "true";
				case 'prepEquipSkillMeditation' :	return "false";
				case 'prepEquipSkillCampfire' :		return "true";
				case 'prepEquipMutagenMeditation' :	return "false";
				case 'prepEquipMutagenCampfire' :	return "true";
				case 'prepDisableRegenFullHealth' :	return "true";
				case 'prepDisableCleanupCharStatus' :	return "true";
			}
			break;
		case 'preparationsInventory' :
			switch(option)
			{
				case 'prepRepairMeditation' :		return "false";
				case 'prepRepairCampfire' :		return "true";
				case 'prepUpgradeMeditation' :		return "false";
				case 'prepUpgradeCampfire' :		return "true";
				case 'prepDisallowOilsInCombat' :	return "true";
				case 'prepDisallowEdiblesInCombat' :	return "true";
				case 'prepBlockInventoryInCombat' :	return "false";
			}
			break;
		case 'preparationsTime' :
			switch(option)
			{
				case 'prepTimeToCreateItemMins' :	return "15";
				case 'prepTimeToRepairItemMins' :	return "15";
				case 'prepTimeToUpgradeItemMins' :	return "15";
				case 'prepTimeToBuySkillMins' :		return "15";
				case 'prepTimeToEquipSkillMins' :	return "15";
				case 'prepTimeToEquipMutagenMins' :	return "15";
			}
			break;
	}
	return "";
}

// Every option with a default, for PrepApplyDefaultOptions.
function PrepOptionList(out groups : array<name>, out options : array<name>)
{
	groups.Clear();
	options.Clear();
	groups.PushBack('preparationsMeditation');	options.PushBack('prepDisallowMeditation');
	groups.PushBack('preparationsMeditation');	options.PushBack('prepDisallowCampFire');
	groups.PushBack('preparationsMeditation');	options.PushBack('prepDisallowFireSource');
	groups.PushBack('preparationsMeditation');	options.PushBack('prepDisallowLightSource');
	groups.PushBack('preparationsMeditation');	options.PushBack('prepDisallowInterior');
	groups.PushBack('preparationsMeditation');	options.PushBack('prepDisallowSettlement');
	groups.PushBack('preparationsMeditation');	options.PushBack('prepDisallowNPCs');
	groups.PushBack('preparationsMeditation');	options.PushBack('prepNpcDistance');
	groups.PushBack('preparationsFriendlyMeditation');	options.PushBack('prepDisallowCampFireInInterior');
	groups.PushBack('preparationsFriendlyMeditation');	options.PushBack('prepDisallowCampFireInSettlement');
	groups.PushBack('preparationsFriendlyMeditation');	options.PushBack('prepTimberAmount');
	groups.PushBack('preparationsFriendlyMeditation');	options.PushBack('prepHardTimberAmount');
	groups.PushBack('preparationsAlchemy');	options.PushBack('prepAlchemyMeditation');
	groups.PushBack('preparationsAlchemy');	options.PushBack('prepAlchemyCampfire');
	groups.PushBack('preparationsAlchemy');	options.PushBack('prepDisableAutorefillQuest');
	groups.PushBack('preparationsAlchemy');	options.PushBack('prepRefillOne');
	groups.PushBack('preparationsAlchemy');	options.PushBack('prepMaxOilCharges');
	groups.PushBack('preparationsAlchemy');	options.PushBack('Virtual_prepBombsRefillMode');
	groups.PushBack('preparationsAlchemy');	options.PushBack('Virtual_prepOilsRefillMode');
	groups.PushBack('preparationsAlchemy');	options.PushBack('Virtual_prepMutagensRefillMode');
	groups.PushBack('preparationsAlchemy');	options.PushBack('Virtual_prepPotionsRefillMode');
	groups.PushBack('preparationsCharacter');	options.PushBack('prepBuySkillMeditation');
	groups.PushBack('preparationsCharacter');	options.PushBack('prepBuySkillCampfire');
	groups.PushBack('preparationsCharacter');	options.PushBack('prepEquipSkillMeditation');
	groups.PushBack('preparationsCharacter');	options.PushBack('prepEquipSkillCampfire');
	groups.PushBack('preparationsCharacter');	options.PushBack('prepEquipMutagenMeditation');
	groups.PushBack('preparationsCharacter');	options.PushBack('prepEquipMutagenCampfire');
	groups.PushBack('preparationsCharacter');	options.PushBack('prepDisableRegenFullHealth');
	groups.PushBack('preparationsCharacter');	options.PushBack('prepDisableCleanupCharStatus');
	groups.PushBack('preparationsInventory');	options.PushBack('prepRepairMeditation');
	groups.PushBack('preparationsInventory');	options.PushBack('prepRepairCampfire');
	groups.PushBack('preparationsInventory');	options.PushBack('prepUpgradeMeditation');
	groups.PushBack('preparationsInventory');	options.PushBack('prepUpgradeCampfire');
	groups.PushBack('preparationsInventory');	options.PushBack('prepDisallowOilsInCombat');
	groups.PushBack('preparationsInventory');	options.PushBack('prepDisallowEdiblesInCombat');
	groups.PushBack('preparationsInventory');	options.PushBack('prepBlockInventoryInCombat');
	groups.PushBack('preparationsTime');	options.PushBack('prepTimeToCreateItemMins');
	groups.PushBack('preparationsTime');	options.PushBack('prepTimeToRepairItemMins');
	groups.PushBack('preparationsTime');	options.PushBack('prepTimeToUpgradeItemMins');
	groups.PushBack('preparationsTime');	options.PushBack('prepTimeToBuySkillMins');
	groups.PushBack('preparationsTime');	options.PushBack('prepTimeToEquipSkillMins');
	groups.PushBack('preparationsTime');	options.PushBack('prepTimeToEquipMutagenMins');
}

// An option that was never set reads "", a virtual OPTIONS variable "-1" (as in Ghost Mode's port).
function PrepOptionUnset(option : name, value : string) : bool
{
	return value == "" || (value == "-1" && StrBeginsWith(NameToString(option), "Virtual_"));
}

// Give every unset option its default, keeping values the player has set.
function PrepApplyDefaultOptions()
{
	var cfg : CInGameConfigWrapper;
	var groups, options : array<name>;
	var i : int;
	var changed : bool;

	cfg = theGame.GetInGameConfigWrapper();
	PrepOptionList(groups, options);
	for(i = 0; i < options.Size(); i += 1)
	{
		if(PrepOptionUnset(options[i], cfg.GetVarValue(groups[i], options[i])))
		{
			cfg.SetVarValue(groups[i], options[i], PrepOptionDefault(groups[i], options[i]));
			changed = true;
		}
	}
	if(changed)
		theGame.SaveUserSettings();
}

// An option's value, or its default while it is unset.
function PrepGetOption(group : name, option : name) : string
{
	var value : string;

	value = theGame.GetInGameConfigWrapper().GetVarValue(group, option);
	if(PrepOptionUnset(option, value))
		value = PrepOptionDefault(group, option);
	return value;
}

function PrepGetOptionBool(group : name, option : name) : bool
{
	return PrepGetOption(group, option) == "true";
}

function PrepGetOptionInt(group : name, option : name) : int
{
	return StringToInt(PrepGetOption(group, option));
}

function PrepGetOptionFloat(group : name, option : name) : float
{
	return StringToFloat(PrepGetOption(group, option));
}

// Legacy's CModPreparationsConfig: the options read into fields, refreshed whenever the options menu saves.
// The rules that use them (Is<Action>Allowed, the error texts, the Friendly Meditation setup) come with the
// slices that port those features.
class CModPreparationsConfig
{
	// [preparationsMeditation]
	public var disallowMeditation : bool;		// no meditation away from fire
	public var disallowCampFire : bool;		// existing campfires do not count as fire
	public var disallowFireSource : bool;		// fire sources (not campfires) do not count
	public var disallowLightSource : bool;		// light sources do not count
	public var disallowInterior : bool;		// no meditation in interiors
	public var disallowSettlement : bool;		// no meditation outdoors in settlements
	public var disallowNPCs : bool;			// no meditation near non-allied NPCs
	public var npcDistance : float;			// how near counts, in metres

	// [preparationsFriendlyMeditation]
	public var disallowCampFireInInterior : bool;
	public var disallowCampFireInSettlement : bool;
	public var timberAmount : int;			// Timber needed to make a campfire
	public var hardTimberAmount : int;		// or Hardened timber, if there is not enough Timber

	// [preparationsAlchemy]
	public var alchemyMeditation : bool;
	public var alchemyCampfire : bool;
	public var disableAutorefillQuest : bool;	// no refill from quests (RecoverGeralt)
	public var refillOne : bool;			// refill one charge at a time
	public var maxOilCharges : int;			// applications per oil jar, 0 = unlimited (vanilla)
	public var bombsRefillMode : int;		// 0 Autorefill, 1 corresponding base, 2-4 one base, 5 full recipe,
	public var oilsRefillMode : int;		// 6 base and herbs, 7 (decoctions only) all but the mutagen
	public var mutagensRefillMode : int;
	public var potionsRefillMode : int;

	// [preparationsCharacter]
	public var buySkillMeditation : bool;
	public var buySkillCampfire : bool;
	public var equipSkillMeditation : bool;
	public var equipSkillCampfire : bool;
	public var equipMutagenMeditation : bool;
	public var equipMutagenCampfire : bool;
	public var disableRegenFullHealth : bool;	// meditation does not heal fully
	public var disableCleanupCharStatus : bool;	// effects run their course instead of being cleared

	// [preparationsInventory]
	public var repairMeditation : bool;
	public var repairCampfire : bool;
	public var upgradeMeditation : bool;
	public var upgradeCampfire : bool;
	public var disallowOilsInCombat : bool;
	public var disallowEdiblesInCombat : bool;
	public var blockInventoryInCombat : bool;

	// [preparationsTime], in seconds (the menu sets minutes)
	public var timeToCreateItemSec : int;
	public var timeToRepairItemSec : int;
	public var timeToUpgradeItemSec : int;
	public var timeToBuySkillSec : int;
	public var timeToEquipSkillSec : int;		// unequipping and swapping take no time
	public var timeToEquipMutagenSec : int;		// unequipping takes no time

	// the one base a "one base" refill mode uses for every tier, 'None' otherwise
	public var bombsRefillBase : name;
	public var oilsRefillBase : name;
	public var mutagensRefillBase : name;
	public var potionsRefillBase : name;

	private var witcher : W3PlayerWitcher;

	public function Init(owner : W3PlayerWitcher)
	{
		witcher = owner;
		UpdateUserSettings();
	}

	public function UpdateUserSettings()
	{
		disallowMeditation = PrepGetOptionBool('preparationsMeditation', 'prepDisallowMeditation');
		disallowCampFire = PrepGetOptionBool('preparationsMeditation', 'prepDisallowCampFire');
		disallowFireSource = PrepGetOptionBool('preparationsMeditation', 'prepDisallowFireSource');
		disallowLightSource = PrepGetOptionBool('preparationsMeditation', 'prepDisallowLightSource');
		disallowInterior = PrepGetOptionBool('preparationsMeditation', 'prepDisallowInterior');
		disallowSettlement = PrepGetOptionBool('preparationsMeditation', 'prepDisallowSettlement');
		disallowNPCs = PrepGetOptionBool('preparationsMeditation', 'prepDisallowNPCs');
		npcDistance = PrepGetOptionFloat('preparationsMeditation', 'prepNpcDistance');

		disallowCampFireInInterior = PrepGetOptionBool('preparationsFriendlyMeditation', 'prepDisallowCampFireInInterior');
		disallowCampFireInSettlement = PrepGetOptionBool('preparationsFriendlyMeditation', 'prepDisallowCampFireInSettlement');
		timberAmount = PrepGetOptionInt('preparationsFriendlyMeditation', 'prepTimberAmount');
		hardTimberAmount = PrepGetOptionInt('preparationsFriendlyMeditation', 'prepHardTimberAmount');

		alchemyMeditation = PrepGetOptionBool('preparationsAlchemy', 'prepAlchemyMeditation');
		alchemyCampfire = PrepGetOptionBool('preparationsAlchemy', 'prepAlchemyCampfire');
		disableAutorefillQuest = PrepGetOptionBool('preparationsAlchemy', 'prepDisableAutorefillQuest');
		refillOne = PrepGetOptionBool('preparationsAlchemy', 'prepRefillOne');
		maxOilCharges = PrepGetOptionInt('preparationsAlchemy', 'prepMaxOilCharges');
		bombsRefillMode = PrepGetOptionInt('preparationsAlchemy', 'Virtual_prepBombsRefillMode');
		oilsRefillMode = PrepGetOptionInt('preparationsAlchemy', 'Virtual_prepOilsRefillMode');
		mutagensRefillMode = PrepGetOptionInt('preparationsAlchemy', 'Virtual_prepMutagensRefillMode');
		potionsRefillMode = PrepGetOptionInt('preparationsAlchemy', 'Virtual_prepPotionsRefillMode');

		buySkillMeditation = PrepGetOptionBool('preparationsCharacter', 'prepBuySkillMeditation');
		buySkillCampfire = PrepGetOptionBool('preparationsCharacter', 'prepBuySkillCampfire');
		equipSkillMeditation = PrepGetOptionBool('preparationsCharacter', 'prepEquipSkillMeditation');
		equipSkillCampfire = PrepGetOptionBool('preparationsCharacter', 'prepEquipSkillCampfire');
		equipMutagenMeditation = PrepGetOptionBool('preparationsCharacter', 'prepEquipMutagenMeditation');
		equipMutagenCampfire = PrepGetOptionBool('preparationsCharacter', 'prepEquipMutagenCampfire');
		disableRegenFullHealth = PrepGetOptionBool('preparationsCharacter', 'prepDisableRegenFullHealth');
		disableCleanupCharStatus = PrepGetOptionBool('preparationsCharacter', 'prepDisableCleanupCharStatus');

		repairMeditation = PrepGetOptionBool('preparationsInventory', 'prepRepairMeditation');
		repairCampfire = PrepGetOptionBool('preparationsInventory', 'prepRepairCampfire');
		upgradeMeditation = PrepGetOptionBool('preparationsInventory', 'prepUpgradeMeditation');
		upgradeCampfire = PrepGetOptionBool('preparationsInventory', 'prepUpgradeCampfire');
		disallowOilsInCombat = PrepGetOptionBool('preparationsInventory', 'prepDisallowOilsInCombat');
		disallowEdiblesInCombat = PrepGetOptionBool('preparationsInventory', 'prepDisallowEdiblesInCombat');
		blockInventoryInCombat = PrepGetOptionBool('preparationsInventory', 'prepBlockInventoryInCombat');

		timeToCreateItemSec = 60 * PrepGetOptionInt('preparationsTime', 'prepTimeToCreateItemMins');
		timeToRepairItemSec = 60 * PrepGetOptionInt('preparationsTime', 'prepTimeToRepairItemMins');
		timeToUpgradeItemSec = 60 * PrepGetOptionInt('preparationsTime', 'prepTimeToUpgradeItemMins');
		timeToBuySkillSec = 60 * PrepGetOptionInt('preparationsTime', 'prepTimeToBuySkillMins');
		timeToEquipSkillSec = 60 * PrepGetOptionInt('preparationsTime', 'prepTimeToEquipSkillMins');
		timeToEquipMutagenSec = 60 * PrepGetOptionInt('preparationsTime', 'prepTimeToEquipMutagenMins');

		bombsRefillBase = GetBombsRefillBase(bombsRefillMode);
		oilsRefillBase = GetOilsRefillBase(oilsRefillMode);
		mutagensRefillBase = GetMutagensRefillBase(mutagensRefillMode);
		potionsRefillBase = GetPotionsRefillBase(potionsRefillMode);

		// PREP-OIL: oils full again with charges off, none above the max
		if(witcher)
			witcher.inv.PrepCheckOilAmmo(OilsHaveAmmo());
	}

	public function GetBombsRefillBase(cfgVal : int) : name
	{
		switch(cfgVal)
		{
			case 2: return 'Saltpetre';
			case 3: return 'Stammelfords dust';
			case 4: return 'Alchemists powder';
		}
		return 'None';
	}

	public function GetOilsRefillBase(cfgVal : int) : name
	{
		switch(cfgVal)
		{
			case 2: return 'Dog tallow';
			case 3: return 'Bear fat';
			case 4: return 'Alchemical paste';
		}
		return 'None';
	}

	public function GetMutagensRefillBase(cfgVal : int) : name
	{
		switch(cfgVal)
		{
			case 2: return 'Dwarven spirit';
			case 3: return 'Alcohest';
			case 4: return 'White Gull 1';
		}
		return 'None';
	}

	public function GetPotionsRefillBase(cfgVal : int) : name
	{
		switch(cfgVal)
		{
			case 2: return 'Dwarven spirit';
			case 3: return 'Alcohest';
			case 4: return 'White Gull 1';
		}
		return 'None';
	}

	public function OilsHaveAmmo() : bool
	{
		return maxOilCharges > 0;
	}

	// ---- restrictions (legacy's Is<Action>Allowed): every required condition must hold ----

	public function IsAlchemyAllowed() : bool
	{
		return !Ready() || (!alchemyMeditation || witcher.PrepIsMeditating()) && (!alchemyCampfire || witcher.PrepHasCampfire());
	}

	public function IsBuySkillAllowed() : bool
	{
		return !Ready() || (!buySkillMeditation || witcher.PrepIsMeditating()) && (!buySkillCampfire || witcher.PrepHasCampfire());
	}

	public function IsEquipSkillAllowed() : bool
	{
		return !Ready() || (!equipSkillMeditation || witcher.PrepIsMeditating()) && (!equipSkillCampfire || witcher.PrepHasCampfire());
	}

	public function IsEquipMutagenAllowed() : bool
	{
		return !Ready() || (!equipMutagenMeditation || witcher.PrepIsMeditating()) && (!equipMutagenCampfire || witcher.PrepHasCampfire());
	}

	public function IsRepairAllowed() : bool
	{
		return !Ready() || (!repairMeditation || witcher.PrepIsMeditating()) && (!repairCampfire || witcher.PrepHasCampfire());
	}

	public function IsUpgradeAllowed() : bool
	{
		return !Ready() || (!upgradeMeditation || witcher.PrepIsMeditating()) && (!upgradeCampfire || witcher.PrepHasCampfire());
	}

	// Before the init timer has run there is no player: nothing is refused.
	private function Ready() : bool
	{
		if(witcher)
			return true;
		return false;
	}

	// The string key of the reason an action is refused (legacy's Get<Action>Error).
	private function GateError(needMeditation : bool, needCampfire : bool) : string
	{
		if(needMeditation && !witcher.PrepIsMeditating())
			return "prep_error_meditation_required";
		if(needCampfire && !witcher.PrepHasCampfire())
			return "prep_error_campfire_required";
		return "prep_error_undefined";
	}

	public function GetAlchemyError() : string		{ return GateError(alchemyMeditation, alchemyCampfire); }
	public function GetBuySkillError() : string		{ return GateError(buySkillMeditation, buySkillCampfire); }
	public function GetEquipSkillError() : string		{ return GateError(equipSkillMeditation, equipSkillCampfire); }
	public function GetEquipMutagenError() : string	{ return GateError(equipMutagenMeditation, equipMutagenCampfire); }
	public function GetRepairError() : string		{ return GateError(repairMeditation, repairCampfire); }
	public function GetUpgradeError() : string		{ return GateError(upgradeMeditation, upgradeCampfire); }

	// ---- Friendly Meditation's campfire (read at run time: Friendly Meditation's blob may be absent) ----

	// Friendly Meditation's own "spawn a campfire" option; false without Friendly Meditation (the option reads "").
	public function FMSpawnCampFire() : bool
	{
		return theGame.GetInGameConfigWrapper().GetVarValue('modFriendlyMeditation', 'fmedSpawnCampfire') == "true";
	}

	public function HasResourcesForCampfire() : bool
	{
		return witcher.inv.GetItemQuantityByName('Timber') >= timberAmount
			|| witcher.inv.GetItemQuantityByName('Hardened timber') >= hardTimberAmount;
	}
}

// ---- the config object on the player ----

@addField(W3PlayerWitcher)
public var prepConfig : CModPreparationsConfig;

// Legacy creates the config in OnSpawned and initializes it from a timer, because GetWitcherPlayer() is
// not set yet while OnSpawned runs. The timer is not saveable (legacy's was): every load starts it again.
@wrapMethod(W3PlayerWitcher)
function OnSpawned(spawnData : SEntitySpawnData)
{
	wrappedMethod(spawnData);
	PrepApplyDefaultOptions();
	prepConfig = new CModPreparationsConfig in this;
	AddTimer('PrepDelayedInit', 0.00001, true);
}

@addMethod(W3PlayerWitcher)
timer function PrepDelayedInit(dt : float, id : int)
{
	if(!GetWitcherPlayer())
		return;
	prepConfig.Init(this);
	PrepApplyFixes();
	RemoveTimer('PrepDelayedInit');
}

function GetPreparationsConfig() : CModPreparationsConfig
{
	var w : W3PlayerWitcher;

	w = GetWitcherPlayer();
	if(!w)
		return NULL;
	return w.prepConfig;
}

// The options menu saved its settings: read them again (legacy's hook in SaveChangedSettings). Read on
// every save of the menu, changed or not: it is cheap, and a preset applied counts too.
@wrapMethod(CR4IngameMenu)
function SaveChangedSettings()
{
	var cfg : CModPreparationsConfig;

	wrappedMethod();
	if(GetWitcherPlayer())
	{
		cfg = GetPreparationsConfig();
		if(cfg)
			cfg.UpdateUserSettings();
	}
}
