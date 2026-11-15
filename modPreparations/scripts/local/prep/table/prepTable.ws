// PREP-TABLE: Corvo Bianco's alchemy table gives an effect for an hour that adds one charge to every potion,
// bomb and oil (not decoctions), instead of 5.x's "refilled above the max" when the bed is used.
//
// The effect type is an EEffectType extension. The game merges every mod's extension members by name at load
// and resolves class defaults against the merged list, so this extension first declares Ghost Mode's effect
// type names, by the same names and in Ghost Mode's order (modGhostMode/scripts/local/gm/effects/
// gmEffectTypes.ws), then its own member, which stays last (owner, 2026-11-14; docs/ghost-mode-compatibility.md).
// Update the copy whenever Ghost Mode adds an effect type.

enum EEffectType
{
	// Ghost Mode's effect types, mirrored (do not edit except to follow Ghost Mode)
	EET_GMAardCooldown,
	EET_GMAxiiCooldown,
	EET_GMIgniCooldown,
	EET_GMQuenCooldown,
	EET_GMYrdenCooldown,
	EET_GMWhirlCooldown,
	EET_GMRendCooldown,
	EET_GMUndyingImmortal,
	EET_GMUndyingCooldown,
	EET_GMMeltArmorDebuff,
	EET_GMMeltArmorTimer,
	EET_GMMutation5,
	EET_GMMutationTrigger,
	EET_GMKaerMorhenSetBonus,
	EET_GMRuneword4,
	EET_GMRuneword11,
	EET_GMPhantomWeapon,
	EET_GMDimeritium,
	// Preparations
	EET_PrepAlchemyTable
}

class W3PrepEffect_AlchemyTable extends CBaseGameplayEffect
{
	default effectType = EET_PrepAlchemyTable;
	default isPositive = true;
}

function PrepHasAlchemyTableEffect() : bool
{
	return thePlayer && thePlayer.HasBuff(EET_PrepAlchemyTable);
}

// ---- registration (Ghost Mode's pattern: wrappers of the vanilla registration functions) ----

@wrapMethod(W3GameEffectManager)
function Initialize()
{
	wrappedMethod();
	if(effects.Size() <= (int)EET_PrepAlchemyTable)
		effects.Grow((int)EET_PrepAlchemyTable + 1 - effects.Size());
}

@wrapMethod(W3GameEffectManager)
function HACK_NO_MEMORY_TO_COMPILE_CacheEffect_Part1(effect : EEffectType) : bool
{
	if(effect == EET_PrepAlchemyTable)
	{
		effects[effect] = new W3PrepEffect_AlchemyTable in this;
		return true;
	}
	return wrappedMethod(effect);
}

@wrapMethod
function HACK_NO_MEMORY_TO_COMPILE_EffectNameToType_Part1(effectName : name, out type : EEffectType, out abilityName : name) : bool
{
	if(effectName == 'PrepAlchemyTableEffect')
	{
		type = EET_PrepAlchemyTable;
		abilityName = effectName;
		return true;
	}
	return wrappedMethod(effectName, type, abilityName);
}

@wrapMethod
function EffectTypeToName(effectType : EEffectType) : name
{
	if(effectType == EET_PrepAlchemyTable)
		return 'PrepAlchemyTableEffect';
	return wrappedMethod(effectType);
}

// ---- applying it ----

// Legacy's ManageAlchemyTableBonus: the effect and the "gained an additional charge" message.
@addMethod(W3PlayerWitcher)
function PrepManageAlchemyTableBonus()
{
	AddEffectDefault(EET_PrepAlchemyTable, this, "Alchemy Table");
	theGame.GetGuiManager().ShowNotification(GetLocStringByKeyExt("message_common_alchemy_table_buff_applied"), , true);
}

// Sleeping in Corvo Bianco's bed with the alchemy table built: the effect (legacy's ApplyWitcherHouseBuffs
// change). Ghost Mode wraps this too (STAM-10); wrappers chain.
@wrapMethod(W3PlayerWitcher)
function ApplyWitcherHouseBuffs()
{
	var bed : W3WitcherBed;

	wrappedMethod();
	if(FactsQuerySum("PlayerInsideInnerWitcherHouse") > 0 && FactsQuerySum("AlchemyTableExists") > 0)
	{
		bed = (W3WitcherBed)theGame.GetEntityByTag('witcherBed');
		if(bed && bed.GetWasUsed())
			PrepManageAlchemyTableBonus();
	}
}

// The quest that builds the table applies the effect instead of 5.x's refill bonus.
@replaceMethod
function ApplyAlchemyTableBuff()
{
	GetWitcherPlayer().PrepManageAlchemyTableBonus();
}

// 5.x's SingletonItemRefillAmmo without its alchemy table branch (refill above the max when the bed was used):
// the table's bonus is the effect now. As in legacy, a refill sets the item to its max, also down from above
// it (charges left from an expired table effect).
@replaceMethod(CInventoryComponent)
function SingletonItemRefillAmmo(id : SItemUniqueId, optional alchemyTableUsed : bool)
{
	SetItemModifierInt(id, 'ammo_current', SingletonItemGetMaxAmmo(id));
	theGame.GetGlobalEventsManager().OnScriptedEvent(SEC_OnAmmoChanged);
}
