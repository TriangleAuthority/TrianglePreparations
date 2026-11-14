//---=== modPreparations ===---
class CModPreparationsConfig
{
	//config options:

	//meditation options:
	//disallow meditation away from fire
	public var disallowMeditation : bool;
	//disallow meditation near existing campfires
	public var disallowCampFire : bool;
	//disallow meditation near fire sources (campfires are not fire sources)
	public var disallowFireSource : bool;
	//disallow meditation near any light source (campfires and fire sources are also light sources)
	public var disallowLightSource : bool;
	//disallows meditating in interior
	public var disallowInterior : bool;
	//disallows meditating in settlements
	public var disallowSettlement : bool;
	//disallows meditating near non-allied NPCs
	public var disallowNPCs : bool;
	//min distance to NPC
	public var npcDistance : float;
	
	//Friendly Meditation related options:
	//disallow spawning campfire in interiors
	public var disallowCampFireInInterior : bool;
	//disallow spawning campfire in settlements
	public var disallowCampFireInSettlement : bool;
	//amount of timber needed to spawn campfire
	public var timberAmount : int;
	//amount of hardened timber needed to spawn campfire (if player has no timber)
	public var hardTimberAmount : int;

	//alchemy options:
	//alchemy requires meditation (FMed)
	public var alchemyMeditation : bool;
	//alchemy requires campfire
	public var alchemyCampfire : bool;
	//disable quest triggered autorefill of alchemy
	public var disableAutorefillQuest : bool;
	//refill items one by one
	public var refillOne : bool;
	//max oil charges
	public var maxOilCharges : int;
	//refill modes
	public var bombsRefillMode : int;
	public var oilsRefillMode : int;
	public var mutagensRefillMode : int;
	public var potionsRefillMode : int;
	
	//character options:
	public var buySkillMeditation : bool;
	public var buySkillCampfire : bool;
	public var equipSkillMeditation : bool;
	public var equipSkillCampfire : bool;
	public var equipMutagenMeditation : bool;
	public var equipMutagenCampfire : bool;
	public var disableRegenFullHealth : bool;
	public var disableCleanupCharStatus : bool;
	
	//inventory options:
	public var repairMeditation : bool;
	public var repairCampfire : bool;
	public var upgradeMeditation : bool;
	public var upgradeCampfire : bool;
	//disallows applying oils in combat
	public var disallowOilsInCombat : bool;
	//disallows using edibles and drinks in combat
	public var disallowEdiblesInCombat : bool;
	//disallows inventory access in combat
	public var blockInventoryInCombat : bool;
	
	//time intervals:
	//time in seconds to create alchemy item
	public var timeToCreateItemSec : int;
	//time in seconds to repair an item
	public var timeToRepairItemSec : int;
	//time in seconds to upgrade an item
	public var timeToUpgradeItemSec : int;
	//time in seconds to buy skill
	public var timeToBuySkillSec : int;
	//time in seconds to equip skill (unequip/swap takes no time)
	public var timeToEquipSkillSec : int;
	//time in seconds to equip mutagen (unequipping takes no time)
	public var timeToEquipMutagenSec : int;

	//-----------------------------------------------------------------
	
	//use one common base for all item levels when refilling
	public var bombsRefillBase : name;
	public var oilsRefillBase : name;
	public var mutagensRefillBase : name;
	public var potionsRefillBase : name;
	
	private var witcher : W3PlayerWitcher;
	
	//configs
	public function Init( owner : W3PlayerWitcher )
	{
		witcher = owner;
		UpdateUserSettings();
	}
	
	public function UpdateUserSettings()
	{
		//[preparationsMeditation]
		disallowMeditation = theGame.GetInGameConfigWrapper().GetVarValue('preparationsMeditation', 'prepDisallowMeditation');
		disallowCampFire = theGame.GetInGameConfigWrapper().GetVarValue('preparationsMeditation', 'prepDisallowCampFire');
		disallowFireSource = theGame.GetInGameConfigWrapper().GetVarValue('preparationsMeditation', 'prepDisallowFireSource');
		disallowLightSource = theGame.GetInGameConfigWrapper().GetVarValue('preparationsMeditation', 'prepDisallowLightSource');
		disallowInterior = theGame.GetInGameConfigWrapper().GetVarValue('preparationsMeditation', 'prepDisallowInterior');
		disallowSettlement = theGame.GetInGameConfigWrapper().GetVarValue('preparationsMeditation', 'prepDisallowSettlement');
		disallowNPCs = theGame.GetInGameConfigWrapper().GetVarValue('preparationsMeditation', 'prepDisallowNPCs');
		npcDistance = StringToFloat(theGame.GetInGameConfigWrapper().GetVarValue('preparationsMeditation', 'prepNpcDistance'));
		//[preparationsFriendlyMeditation]
		disallowCampFireInInterior = theGame.GetInGameConfigWrapper().GetVarValue('preparationsFriendlyMeditation', 'prepDisallowCampFireInInterior');
		disallowCampFireInSettlement = theGame.GetInGameConfigWrapper().GetVarValue('preparationsFriendlyMeditation', 'prepDisallowCampFireInSettlement');
		timberAmount = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsFriendlyMeditation', 'prepTimberAmount'));
		hardTimberAmount = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsFriendlyMeditation', 'prepHardTimberAmount'));
		//[preparationsAlchemy]
		alchemyMeditation = theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'prepAlchemyMeditation');
		alchemyCampfire = theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'prepAlchemyCampfire');
		disableAutorefillQuest = theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'prepDisableAutorefillQuest');
		refillOne = theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'prepRefillOne');
		maxOilCharges = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'prepMaxOilCharges'));
		bombsRefillMode = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'Virtual_prepBombsRefillMode'));
		oilsRefillMode = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'Virtual_prepOilsRefillMode'));
		mutagensRefillMode = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'Virtual_prepMutagensRefillMode'));
		potionsRefillMode = StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsAlchemy', 'Virtual_prepPotionsRefillMode'));
		//[preparationsCharacter]
		buySkillMeditation = theGame.GetInGameConfigWrapper().GetVarValue('preparationsCharacter', 'prepBuySkillMeditation');
		buySkillCampfire = theGame.GetInGameConfigWrapper().GetVarValue('preparationsCharacter', 'prepBuySkillCampfire');
		equipSkillMeditation = theGame.GetInGameConfigWrapper().GetVarValue('preparationsCharacter', 'prepEquipSkillMeditation');
		equipSkillCampfire = theGame.GetInGameConfigWrapper().GetVarValue('preparationsCharacter', 'prepEquipSkillCampfire');
		equipMutagenMeditation = theGame.GetInGameConfigWrapper().GetVarValue('preparationsCharacter', 'prepEquipMutagenMeditation');
		equipMutagenCampfire = theGame.GetInGameConfigWrapper().GetVarValue('preparationsCharacter', 'prepEquipMutagenCampfire');
		disableRegenFullHealth = theGame.GetInGameConfigWrapper().GetVarValue('preparationsCharacter', 'prepDisableRegenFullHealth');
		disableCleanupCharStatus = theGame.GetInGameConfigWrapper().GetVarValue('preparationsCharacter', 'prepDisableCleanupCharStatus');
		//[preparationsInventory]
		repairMeditation = theGame.GetInGameConfigWrapper().GetVarValue('preparationsInventory', 'prepRepairMeditation');
		repairCampfire = theGame.GetInGameConfigWrapper().GetVarValue('preparationsInventory', 'prepRepairCampfire');
		upgradeMeditation = theGame.GetInGameConfigWrapper().GetVarValue('preparationsInventory', 'prepUpgradeMeditation');
		upgradeCampfire = theGame.GetInGameConfigWrapper().GetVarValue('preparationsInventory', 'prepUpgradeCampfire');
		disallowOilsInCombat = theGame.GetInGameConfigWrapper().GetVarValue('preparationsInventory', 'prepDisallowOilsInCombat');
		disallowEdiblesInCombat = theGame.GetInGameConfigWrapper().GetVarValue('preparationsInventory', 'prepDisallowEdiblesInCombat');
		blockInventoryInCombat = theGame.GetInGameConfigWrapper().GetVarValue('preparationsInventory', 'prepBlockInventoryInCombat');
		//[preparationsTime]
		timeToCreateItemSec = 60 * StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsTime', 'prepTimeToCreateItemMins'));
		timeToRepairItemSec = 60 * StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsTime', 'prepTimeToRepairItemMins'));
		timeToUpgradeItemSec = 60 * StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsTime', 'prepTimeToUpgradeItemMins'));
		timeToBuySkillSec = 60 * StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsTime', 'prepTimeToBuySkillMins'));
		timeToEquipSkillSec = 60 * StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsTime', 'prepTimeToEquipSkillMins'));
		timeToEquipMutagenSec = 60 * StringToInt(theGame.GetInGameConfigWrapper().GetVarValue('preparationsTime', 'prepTimeToEquipMutagenMins'));

		bombsRefillBase = GetBombsRefillBase(bombsRefillMode);
		oilsRefillBase = GetOilsRefillBase(oilsRefillMode);
		mutagensRefillBase = GetMutagensRefillBase(mutagensRefillMode);
		potionsRefillBase = GetPotionsRefillBase(potionsRefillMode);
		witcher.SetupFHUD();
		witcher.SetupFMed();
		witcher.inv.ModPrepCheckAmmo( OilsHaveAmmo() );
	}
	
	public function GetBombsRefillBase(cfgVal : int) : name
	{
		switch( cfgVal )
		{
			case 2:
				return 'Saltpetre';
			case 3:
				return 'Stammelfords dust';
			case 4:
				return 'Alchemists powder';
		}
		return 'None';
	}
	
	public function GetOilsRefillBase(cfgVal : int) : name
	{
		switch( cfgVal )
		{
			case 2:
				return 'Dog tallow';
			case 3:
				return 'Bear fat';
			case 4:
				return 'Alchemical paste';
		}
		return 'None';
	}

	public function GetMutagensRefillBase(cfgVal : int) : name
	{
		switch( cfgVal )
		{
			case 2:
				return 'Dwarven spirit';
			case 3:
				return 'Alcohest';
			case 4:
				return 'White Gull 1';
		}
		return 'None';
	}

	public function GetPotionsRefillBase(cfgVal : int) : name
	{
		switch( cfgVal )
		{
			case 2:
				return 'Dwarven spirit';
			case 3:
				return 'Alcohest';
			case 4:
				return 'White Gull 1';
		}
		return 'None';
	}
	
	//restrictions
	
	public function IsAlchemyAllowed() : bool
	{
		return	(!alchemyMeditation || witcher.IsMeditating()) &&
				(!alchemyCampfire || witcher.HasCampfire());
	}
	
	public function BombsAutorefillEnabled() : bool
	{
		return bombsRefillMode == 0;
	}
	
	public function BombsTierBased() : bool
	{
		return bombsRefillMode == 1;
	}
	
	public function BombsUseCommonBase() : bool
	{
		return bombsRefillMode >= 2 && bombsRefillMode <= 4;
	}
	
	public function BombsFullRecipe() : bool
	{
		return bombsRefillMode == 5;
	}
	
	public function BombsBaseAndHerbs() : bool
	{
		return bombsRefillMode == 6;
	}
	
	public function OilsAutorefillEnabled() : bool
	{
		return oilsRefillMode == 0;
	}
	
	public function OilsTierBased() : bool
	{
		return oilsRefillMode == 1;
	}
	
	public function OilsUseCommonBase() : bool
	{
		return oilsRefillMode >= 2 && oilsRefillMode <= 4;
	}
	
	public function OilsFullRecipe() : bool
	{
		return oilsRefillMode == 5;
	}
	
	public function OilsBaseAndHerbs() : bool
	{
		return oilsRefillMode == 6;
	}
	
	public function MutagensAutorefillEnabled() : bool
	{
		return mutagensRefillMode == 0;
	}
	
	public function MutagensTierBased() : bool
	{
		return mutagensRefillMode == 1;
	}
	
	public function MutagensUseCommonBase() : bool
	{
		return mutagensRefillMode >= 2 && mutagensRefillMode <= 4;
	}
	
	public function MutagensFullRecipe() : bool
	{
		return mutagensRefillMode == 5;
	}
	
	public function MutagensBaseAndHerbs() : bool
	{
		return mutagensRefillMode == 6;
	}
	
	public function ExcludeMutagenForRefill() : bool
	{
		return mutagensRefillMode == 7;
	}
	
	public function PotionsAutorefillEnabled() : bool
	{
		return potionsRefillMode == 0;
	}
	
	public function PotionsTierBased() : bool
	{
		return potionsRefillMode == 1;
	}
	
	public function PotionsUseCommonBase() : bool
	{
		return potionsRefillMode >= 2 && potionsRefillMode <= 4;
	}
	
	public function PotionsFullRecipe() : bool
	{
		return potionsRefillMode == 5;
	}
	
	public function PotionsBaseAndHerbs() : bool
	{
		return potionsRefillMode == 6;
	}
	
	public function IsBuySkillAllowed() : bool
	{
		return	(!buySkillMeditation || witcher.IsMeditating()) &&
				(!buySkillCampfire || witcher.HasCampfire());
	}
	
	public function IsEquipSkillAllowed() : bool
	{
		return	(!equipSkillMeditation || witcher.IsMeditating()) &&
				(!equipSkillCampfire || witcher.HasCampfire());
	}
	
	public function IsEquipMutagenAllowed() : bool
	{
		return	(!equipMutagenMeditation || witcher.IsMeditating()) &&
				(!equipMutagenCampfire || witcher.HasCampfire());
	}
	
	public function IsRepairAllowed() : bool
	{
		return	(!repairMeditation || witcher.IsMeditating()) &&
				(!repairCampfire || witcher.HasCampfire());
	}
	
	public function IsUpgradeAllowed() : bool
	{
		return	(!upgradeMeditation || witcher.IsMeditating()) &&
				(!upgradeCampfire || witcher.HasCampfire());
	}
	
	public function OilsHaveAmmo() : bool
	{
		return maxOilCharges > 0;
	}
	
	//Friendly Meditation
	
	public function fmedSpawnCampFire() : bool
	{
		return (bool)theGame.GetInGameConfigWrapper().GetVarValue('modFriendlyMeditation', 'fmedSpawnCampfire');
	}
	
	public function HasResourcesForCampfire() : bool
	{
		if( witcher.inv.GetItemQuantityByName( 'Timber' ) < timberAmount &&
			witcher.inv.GetItemQuantityByName( 'Hardened timber' ) < hardTimberAmount )
				return false;
		return true;
	}
	
	public function RemoveResourcesForCampfire()
	{
		if( witcher.inv.GetItemQuantityByName( 'Timber' ) >= timberAmount )
		{
			witcher.inv.RemoveItemByName( 'Timber', timberAmount );
		}
		else if( witcher.inv.GetItemQuantityByName( 'Hardened timber' ) >= hardTimberAmount )
		{
			witcher.inv.RemoveItemByName( 'Hardened timber', hardTimberAmount );
		}
	}
	
	//messages
	
	public function GetMeditationError() : string
	{
		var curState : name = witcher.GetCurrentStateName();
		
		if(theGame.IsGameTimePaused())
			return "prep_error_time_paused";
		
		if(witcher.GetUsedVehicle())
			return "prep_error_horse_boat";
		
		if(!witcher.IsActionAllowed(EIAB_MeditationWaiting))
			return "prep_error_action_disallowed";
		
		if(curState != 'Exploration' && curState != 'Meditation' && curState != 'MeditationWaiting')
			return "prep_error_disallowed_now";
		
		if(curState == 'Exploration' && !witcher.CanPerformPlayerAction())
			return "prep_error_disallowed_now";
		
		if(witcher.IsThreatened())
			return "prep_error_enemies_nearby";
		
		if(((CMovingPhysicalAgentComponent)witcher.GetMovingAgentComponent()).GetSubmergeDepth() < 0)
			return "prep_error_submerged";
		
		if(disallowNPCs && witcher.HasNonAlliedActorsNearby())
			return "prep_error_nonallied_npcs";
		
		if(disallowSettlement && witcher.IsInSettlement() && !witcher.IsInInterior())
			return "prep_error_disallowed_settlement";
		
		if(disallowInterior && witcher.IsInInterior())
			return "prep_error_disallowed_interior";
		
		if(disallowMeditation && !witcher.HasCampfire() && !witcher.CanSpawnCampfire())
			return "prep_error_no_campfire_found";
		
		return "prep_error_undefined";
	}
	
	public function GetSpawnCampfireError() : string
	{
		if(disallowCampFireInInterior && witcher.IsInInterior())
			return "prep_error_campfire_interior";
		if(disallowCampFireInSettlement && witcher.IsInSettlement())
			return "prep_error_campfire_settlement";
		if(!HasResourcesForCampfire())
			return "prep_error_no_timber";
		
		return "prep_error_undefined";
	}
	
	public function GetAlchemyError() : string
	{
		if(alchemyMeditation && !witcher.IsMeditating())
			return "prep_error_meditation_required";
		if(alchemyCampfire && !witcher.HasCampfire())
			return "prep_error_campfire_required";
		
		return "prep_error_undefined";
	}
	
	public function GetBuySkillError() : string
	{
		if(buySkillMeditation && !witcher.IsMeditating())
			return "prep_error_meditation_required";
		if(buySkillCampfire && !witcher.HasCampfire())
			return "prep_error_campfire_required";
		
		return "prep_error_undefined";
	}
	
	public function GetEquipSkillError() : string
	{
		if(equipSkillMeditation && !witcher.IsMeditating())
			return "prep_error_meditation_required";
		if(equipSkillCampfire && !witcher.HasCampfire())
			return "prep_error_campfire_required";
		
		return "prep_error_undefined";
	}
	
	public function GetEquipMutagenError() : string
	{
		if(equipMutagenMeditation && !witcher.IsMeditating())
			return "prep_error_meditation_required";
		if(equipMutagenCampfire && !witcher.HasCampfire())
			return "prep_error_campfire_required";
		
		return "prep_error_undefined";
	}
	
	public function GetRepairError() : string
	{
		if(repairMeditation && !witcher.IsMeditating())
			return "prep_error_meditation_required";
		if(repairCampfire && !witcher.HasCampfire())
			return "prep_error_campfire_required";
		
		return "prep_error_undefined";
	}
	
	public function GetUpgradeError() : string
	{
		if(upgradeMeditation && !witcher.IsMeditating())
			return "prep_error_meditation_required";
		if(upgradeCampfire && !witcher.HasCampfire())
			return "prep_error_campfire_required";
		
		return "prep_error_undefined";
	}
}

function GetPreparationsConfig() : CModPreparationsConfig
{
	return GetWitcherPlayer().prepConfig;
}
//---=== modPreparations ===---