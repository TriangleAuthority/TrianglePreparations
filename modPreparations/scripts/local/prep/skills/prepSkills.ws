// PREP-SKILL and PREP-TIME in the character menus: buying and equipping skills, mutations and mutagens only
// where the options allow (at a fire, while meditating), and their time costs. Both menus are covered, the
// classic tree's CR4CharacterMenu (5.x's hidden setting) and the new tree's CR4CharacterDupeMenu (which Ghost
// Mode also uses for the classic tree); the wrappers below are the same for both. Ghost Mode wraps
// CR4CharacterDupeMenu.OnSwapSkill; wrappers of both mods chain.
// Vanilla's combat refusal comes first, as in legacy: in combat the wrapped event shows its own message.

// The reason Preparations refuses a character-menu action now ("" when allowed, or in combat, where 5.x's own
// refusal runs). kind: 0 buy a skill or research a mutation, 1 equip a skill or mutation, 2 equip a mutagen.
function PrepCharacterRefusal(kind : int) : string
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	if(!cfg || thePlayer.IsInCombat())
		return "";
	if(kind == 0 && !cfg.IsBuySkillAllowed())
		return cfg.GetBuySkillError();
	if(kind == 1 && !cfg.IsEquipSkillAllowed())
		return cfg.GetEquipSkillError();
	if(kind == 2 && !cfg.IsEquipMutagenAllowed())
		return cfg.GetEquipMutagenError();
	return "";
}

function PrepChargeTime(seconds : int)
{
	if(GetWitcherPlayer())
		GetWitcherPlayer().PrepAdvanceTimeSeconds(seconds);
}

// ---------------- CR4CharacterMenu ----------------

// Research a mutation (skill points or greater mutagens): the buy rule; buy time when something was put in.
@wrapMethod(CR4CharacterMenu)
function OnResearchMutation(mutationId : int, points : int, red : int, green : int, blue : int)
{
	var refusal : string;
	var result : bool;

	refusal = PrepCharacterRefusal(0);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	result = wrappedMethod(mutationId, points, red, green, blue);
	if(!thePlayer.IsInCombat() && (points > 0 || red > 0 || green > 0 || blue > 0))
		PrepChargeTime(GetPreparationsConfig().timeToBuySkillSec);
	return result;
}

// Equip a mutation: the equip rule when it changes the mutation; equip time when it did.
@wrapMethod(CR4CharacterMenu)
function OnEquipMutation(mutationId : int)
{
	var refusal : string;
	var result, changing : bool;

	changing = GetWitcherPlayer().GetEquippedMutationType() != mutationId;
	if(changing)
	{
		refusal = PrepCharacterRefusal(1);
		if(refusal != "")
		{
			PrepMenuRefuse(refusal);
			return false;
		}
	}
	result = wrappedMethod(mutationId);
	if(changing && GetWitcherPlayer().GetEquippedMutationType() == mutationId)
		PrepChargeTime(GetPreparationsConfig().timeToEquipSkillSec);
	return result;
}

// Unequip the mutation: the equip rule, no time.
@wrapMethod(CR4CharacterMenu)
function OnUnequipMutation()
{
	var refusal : string;

	if(GetWitcherPlayer().GetEquippedMutationType() != EPMT_None)
	{
		refusal = PrepCharacterRefusal(1);
		if(refusal != "")
		{
			PrepMenuRefuse(refusal);
			return false;
		}
	}
	return wrappedMethod();
}

// Buy and equip an unlearned skill in one drag: the buy rule; buy time when it was bought.
@wrapMethod(CR4CharacterMenu)
function OnBuySkill(skill : ESkill, slotID : int)
{
	var refusal : string;
	var result : bool;
	var levelBefore : int;

	refusal = PrepCharacterRefusal(0);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	levelBefore = thePlayer.GetSkillLevel(skill);
	result = wrappedMethod(skill, slotID);
	if(thePlayer.GetSkillLevel(skill) > levelBefore)
		PrepChargeTime(GetPreparationsConfig().timeToBuySkillSec);
	return result;
}

// Swap two equipped skills: the equip rule, no time.
@wrapMethod(CR4CharacterMenu)
function OnSwapSkill(skill1 : ESkill, slotID1 : int, skill2 : ESkill, slotID2 : int)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(1);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(skill1, slotID1, skill2, slotID2);
}

// Equip a skill: the equip rule; equip time when the skill is on the slot afterwards (legacy also charges a
// skill dropped on its own slot).
@wrapMethod(CR4CharacterMenu)
function OnEquipSkill(skill : ESkill, slotID : int)
{
	var refusal : string;
	var result : bool;
	var onSlot : ESkill;

	refusal = PrepCharacterRefusal(1);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	result = wrappedMethod(skill, slotID);
	if(!thePlayer.IsInCombat() && thePlayer.GetSkillOnSlot(slotID, onSlot) && onSlot == skill)
		PrepChargeTime(GetPreparationsConfig().timeToEquipSkillSec);
	return result;
}

// Unequip a skill: the equip rule, no time.
@wrapMethod(CR4CharacterMenu)
function OnUnequipSkill(slotID : int)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(1);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(slotID);
}

// Upgrade a skill (the classic tree opens a confirmation popup, the new tree buys at once): the buy rule.
@wrapMethod(CR4CharacterMenu)
function OnUpgradeSkill(skillID : ESkill)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(0);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(skillID);
}

// The purchase itself (the popup's confirm, or the new tree's upgrade): buy time when the level went up.
// Charged on confirm, not when the popup opens (owner, 2026-11-14).
@wrapMethod(CR4CharacterMenu)
function handleBuySkillConfirmation(skill : ESkill)
{
	var levelBefore : int;

	levelBefore = thePlayer.GetSkillLevel(skill);
	wrappedMethod(skill);
	if(thePlayer.GetSkillLevel(skill) > levelBefore)
		PrepChargeTime(GetPreparationsConfig().timeToBuySkillSec);
}

// Mutagens: moving one to an empty slot and unequipping need the mutagen rule; equipping also costs time.
@wrapMethod(CR4CharacterMenu)
function OnMoveMutagenToEmptySlot(itemID : SItemUniqueId, slotFrom : EEquipmentSlots, slotTo : EEquipmentSlots)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(2);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(itemID, slotFrom, slotTo);
}

@wrapMethod(CR4CharacterMenu)
function OnEquipMutagen(itemID : SItemUniqueId, slotId : EEquipmentSlots)
{
	var refusal : string;
	var result : bool;
	var onSlot : SItemUniqueId;

	refusal = PrepCharacterRefusal(2);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	result = wrappedMethod(itemID, slotId);
	if(!thePlayer.IsInCombat() && GetWitcherPlayer().GetItemEquippedOnSlot(slotId, onSlot) && onSlot == itemID)
		PrepChargeTime(GetPreparationsConfig().timeToEquipMutagenSec);
	return result;
}

@wrapMethod(CR4CharacterMenu)
function OnUnequipMutagen(slotID : int)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(2);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(slotID);
}

// ---------------- CR4CharacterDupeMenu ----------------

// Research a mutation (skill points or greater mutagens): the buy rule; buy time when something was put in.
@wrapMethod(CR4CharacterDupeMenu)
function OnResearchMutation(mutationId : int, points : int, red : int, green : int, blue : int)
{
	var refusal : string;
	var result : bool;

	refusal = PrepCharacterRefusal(0);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	result = wrappedMethod(mutationId, points, red, green, blue);
	if(!thePlayer.IsInCombat() && (points > 0 || red > 0 || green > 0 || blue > 0))
		PrepChargeTime(GetPreparationsConfig().timeToBuySkillSec);
	return result;
}

// Equip a mutation: the equip rule when it changes the mutation; equip time when it did.
@wrapMethod(CR4CharacterDupeMenu)
function OnEquipMutation(mutationId : int)
{
	var refusal : string;
	var result, changing : bool;

	changing = GetWitcherPlayer().GetEquippedMutationType() != mutationId;
	if(changing)
	{
		refusal = PrepCharacterRefusal(1);
		if(refusal != "")
		{
			PrepMenuRefuse(refusal);
			return false;
		}
	}
	result = wrappedMethod(mutationId);
	if(changing && GetWitcherPlayer().GetEquippedMutationType() == mutationId)
		PrepChargeTime(GetPreparationsConfig().timeToEquipSkillSec);
	return result;
}

// Unequip the mutation: the equip rule, no time.
@wrapMethod(CR4CharacterDupeMenu)
function OnUnequipMutation()
{
	var refusal : string;

	if(GetWitcherPlayer().GetEquippedMutationType() != EPMT_None)
	{
		refusal = PrepCharacterRefusal(1);
		if(refusal != "")
		{
			PrepMenuRefuse(refusal);
			return false;
		}
	}
	return wrappedMethod();
}

// Buy and equip an unlearned skill in one drag: the buy rule; buy time when it was bought.
@wrapMethod(CR4CharacterDupeMenu)
function OnBuySkill(skill : ESkill, slotID : int)
{
	var refusal : string;
	var result : bool;
	var levelBefore : int;

	refusal = PrepCharacterRefusal(0);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	levelBefore = thePlayer.GetSkillLevel(skill);
	result = wrappedMethod(skill, slotID);
	if(thePlayer.GetSkillLevel(skill) > levelBefore)
		PrepChargeTime(GetPreparationsConfig().timeToBuySkillSec);
	return result;
}

// Swap two equipped skills: the equip rule, no time.
@wrapMethod(CR4CharacterDupeMenu)
function OnSwapSkill(skill1 : ESkill, slotID1 : int, skill2 : ESkill, slotID2 : int)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(1);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(skill1, slotID1, skill2, slotID2);
}

// Equip a skill: the equip rule; equip time when the skill is on the slot afterwards (legacy also charges a
// skill dropped on its own slot).
@wrapMethod(CR4CharacterDupeMenu)
function OnEquipSkill(skill : ESkill, slotID : int)
{
	var refusal : string;
	var result : bool;
	var onSlot : ESkill;

	refusal = PrepCharacterRefusal(1);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	result = wrappedMethod(skill, slotID);
	if(!thePlayer.IsInCombat() && thePlayer.GetSkillOnSlot(slotID, onSlot) && onSlot == skill)
		PrepChargeTime(GetPreparationsConfig().timeToEquipSkillSec);
	return result;
}

// Unequip a skill: the equip rule, no time.
@wrapMethod(CR4CharacterDupeMenu)
function OnUnequipSkill(slotID : int)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(1);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(slotID);
}

// Upgrade a skill (the classic tree opens a confirmation popup, the new tree buys at once): the buy rule.
@wrapMethod(CR4CharacterDupeMenu)
function OnUpgradeSkill(skillID : ESkill)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(0);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(skillID);
}

// The purchase itself (the popup's confirm, or the new tree's upgrade): buy time when the level went up.
// Charged on confirm, not when the popup opens (owner, 2026-11-14).
@wrapMethod(CR4CharacterDupeMenu)
function handleBuySkillConfirmation(skill : ESkill)
{
	var levelBefore : int;

	levelBefore = thePlayer.GetSkillLevel(skill);
	wrappedMethod(skill);
	if(thePlayer.GetSkillLevel(skill) > levelBefore)
		PrepChargeTime(GetPreparationsConfig().timeToBuySkillSec);
}

// Mutagens: moving one to an empty slot and unequipping need the mutagen rule; equipping also costs time.
@wrapMethod(CR4CharacterDupeMenu)
function OnMoveMutagenToEmptySlot(itemID : SItemUniqueId, slotFrom : EEquipmentSlots, slotTo : EEquipmentSlots)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(2);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(itemID, slotFrom, slotTo);
}

@wrapMethod(CR4CharacterDupeMenu)
function OnEquipMutagen(itemID : SItemUniqueId, slotId : EEquipmentSlots)
{
	var refusal : string;
	var result : bool;
	var onSlot : SItemUniqueId;

	refusal = PrepCharacterRefusal(2);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	result = wrappedMethod(itemID, slotId);
	if(!thePlayer.IsInCombat() && GetWitcherPlayer().GetItemEquippedOnSlot(slotId, onSlot) && onSlot == itemID)
		PrepChargeTime(GetPreparationsConfig().timeToEquipMutagenSec);
	return result;
}

@wrapMethod(CR4CharacterDupeMenu)
function OnUnequipMutagen(slotID : int)
{
	var refusal : string;

	refusal = PrepCharacterRefusal(2);
	if(refusal != "")
	{
		PrepMenuRefuse(refusal);
		return false;
	}
	return wrappedMethod(slotID);
}
