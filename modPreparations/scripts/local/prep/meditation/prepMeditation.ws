// PREP-MED: where Geralt may meditate. Legacy replaced CanMeditate, CanMeditateWait and CanMeditateHere with
// IsMeditationAllowed, and each showed the reason as a notification. 5.x calls CanMeditate from the radial
// menu, the common menu and the input code, some on every UI update, so the checks here are silent and the
// reason shows only when the player tries to meditate (owner, 2026-11-14):
// - CanMeditate (wrapper): 5.x's own checks, then Preparations' rules (PrepMeditationError).
// - Meditate (wrapper): refused by Preparations' rules -> the reason (the N key's path, quests).
// - DisplayActionDisallowedHudMessage (wrapper): every 5.x path that refuses meditation with a message (the
//   radial menu and its key, the minimap's clock, the panels) shows Preparations' reason instead of 5.x's
//   generic one when Preparations' rules are what refused it.

// The fire Geralt meditated at last (legacy's openFireEnt): checked first, so a found fire is not searched again.
@addField(W3PlayerWitcher)
var prepOpenFireEnt : CGameplayEntity;

// The string key of the reason Preparations' rules refuse meditation now, "" when they allow it or when
// 5.x's own checks already refused. Set by CanMeditate.
@addField(W3PlayerWitcher)
var prepMeditationRefusal : string;

// The string key of the last refusal Preparations showed (for the tests).
@addField(W3PlayerWitcher)
var prepLastMessage : string;

// Legacy's IsMeditating (Friendly Meditation's too): the "requires meditation" options mean this state.
@addMethod(W3PlayerWitcher)
function PrepIsMeditating() : bool
{
	return GetCurrentStateName() == 'Meditation';
}

// Show a refusal as legacy did (a notification) and remember it for the tests.
@addMethod(W3PlayerWitcher)
function PrepShowRefusal(key : string)
{
	prepLastMessage = key;
	theGame.GetGuiManager().ShowNotification(GetLocStringByKeyExt(key));
}

// Legacy's HasCampfire: a fire within 3 m (1.5 m in interiors). Whether it burns is not checked.
@addMethod(W3PlayerWitcher)
function PrepHasCampfire() : bool
{
	var entities : array<CGameplayEntity>;
	var i : int;
	var dist : float;
	var cfg : CModPreparationsConfig;

	cfg = prepConfig;
	if(!cfg)
		return false;
	if(IsInInterior())
		dist = 1.5;
	else
		dist = 3.0;
	if(prepOpenFireEnt && VecDistanceSquared2D(prepOpenFireEnt.GetWorldPosition(), GetWorldPosition()) <= dist * dist)
		return true;
	if(!cfg.disallowCampFire)
	{
		FindGameplayEntitiesInRange(entities, this, dist, 1, , FLAG_ExcludePlayer, , 'W3Campfire');
		if(entities.Size() > 0)
		{
			prepOpenFireEnt = entities[0];
			return true;
		}
	}
	if(!cfg.disallowFireSource)
	{
		FindGameplayEntitiesInRange(entities, this, dist, 1, , FLAG_ExcludePlayer, , 'W3FireSource');
		if(entities.Size() > 0)
		{
			prepOpenFireEnt = entities[0];
			return true;
		}
	}
	if(!cfg.disallowLightSource)
	{
		FindGameplayEntitiesInRange(entities, this, dist, 10, , FLAG_ExcludePlayer, , 'CGameplayEntity');
		for(i = 0; i < entities.Size(); i += 1)
		{
			if((CGameplayLightComponent)entities[i].GetComponentByClassName('CGameplayLightComponent'))
			{
				prepOpenFireEnt = entities[i];
				return true;
			}
		}
	}
	prepOpenFireEnt = NULL;
	return false;
}

// Legacy's CanSpawnCampfire: Friendly Meditation may make a campfire here (its option on, no fire nearby, not
// refused in interiors or settlements, enough timber). Always false without Friendly Meditation.
@addMethod(W3PlayerWitcher)
function PrepCanSpawnCampfire() : bool
{
	var cfg : CModPreparationsConfig;

	cfg = prepConfig;
	if(!cfg || PrepHasCampfire() || !cfg.FMSpawnCampFire())
		return false;
	if(cfg.disallowCampFireInInterior && IsInInterior())
		return false;
	if(cfg.disallowCampFireInSettlement && IsInSettlement())
		return false;
	return cfg.HasResourcesForCampfire();
}

// Legacy's HasNonAlliedActorsNearby: a living actor within the option's distance, other than animals, horses
// and VIPs who are not hostile.
@addMethod(W3PlayerWitcher)
function PrepHasNonAlliedActorsNearby() : bool
{
	var entities : array<CGameplayEntity>;
	var i : int;
	var actor : CActor;

	FindGameplayEntitiesInRange(entities, this, prepConfig.npcDistance, 1000, , FLAG_ExcludePlayer + FLAG_OnlyAliveActors, , 'CActor');
	for(i = 0; i < entities.Size(); i += 1)
	{
		actor = (CActor)entities[i];
		if(actor.IsAnimal() || ((CNewNPC)actor).IsHorse() || GetAttitudeBetween(this, actor) != AIA_Hostile && ((CNewNPC)actor).IsVIP())
			continue;
		return true;
	}
	return false;
}

// Preparations' own meditation rules, in legacy's order: the string key of the first one broken, "" if none.
// Waiting blocked (by a quest moment, an elevator, ...) refuses meditation, as in legacy; this also closes 5.x's
// "replenish without meditating", which the radial menu offers only while waiting is blocked (owner, 2026-11-14).
// Legacy's other checks (on a horse or boat, the state, enemies) are 5.x's CanMeditate's own, which runs first;
// time paused by a quest and being under water are left to 5.x (deviation 3).
@addMethod(W3PlayerWitcher)
function PrepMeditationError() : string
{
	var cfg : CModPreparationsConfig;

	cfg = prepConfig;
	if(!cfg)
		return "";
	if(!IsActionAllowed(EIAB_MeditationWaiting))
		return "prep_error_action_disallowed";
	if(cfg.disallowNPCs && PrepHasNonAlliedActorsNearby())
		return "prep_error_nonallied_npcs";
	if(cfg.disallowSettlement && IsInSettlement() && !IsInInterior())
		return "prep_error_disallowed_settlement";
	if(cfg.disallowInterior && IsInInterior())
		return "prep_error_disallowed_interior";
	if(cfg.disallowMeditation && !PrepHasCampfire() && !PrepCanSpawnCampfire())
		return "prep_error_no_campfire_found";
	return "";
}

@wrapMethod(W3PlayerWitcher)
function CanMeditate() : bool
{
	prepMeditationRefusal = "";
	if(!wrappedMethod())
		return false;
	prepMeditationRefusal = PrepMeditationError();
	return prepMeditationRefusal == "";
}

@wrapMethod(W3PlayerWitcher)
function Meditate() : bool
{
	var started : bool;

	started = wrappedMethod();
	if(!started && prepMeditationRefusal != "")
		PrepShowRefusal(prepMeditationRefusal);
	return started;
}

@wrapMethod(CR4Player)
function DisplayActionDisallowedHudMessage(action : EInputActionBlock, optional isCombatLock : bool, optional isPlaceLock : bool, optional isTimeLock : bool, optional isDangerous : bool)
{
	var witcher : W3PlayerWitcher;

	witcher = (W3PlayerWitcher)this;
	if(action == EIAB_OpenMeditation && witcher)
	{
		witcher.CanMeditate();
		if(witcher.prepMeditationRefusal != "")
		{
			witcher.PrepShowRefusal(witcher.prepMeditationRefusal);
			return;
		}
	}
	wrappedMethod(action, isCombatLock, isPlaceLock, isTimeLock, isDangerous);
}
