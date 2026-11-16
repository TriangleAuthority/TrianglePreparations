// PREP-FMED: Preparations' side of the link with Friendly Meditation. The two mods are separate blobs compiled
// against vanilla, so they share no declarations; they meet at runtime only (names agreed in both repositories'
// docs):
// - "May FM make its campfire here?": FM sets the fact fmed_campfire_query and calls CanMeditate(); Preparations'
//   wrapper answers in the fact prep_fmed_campfire_ok (2 yes, 1 no) with legacy's CanSpawnCampfire (no fire near,
//   FM's option on, not refused in interiors or settlements, enough timber). FM removes both facts. Without
//   Preparations the answer stays 0 and FM uses its own rule.
// - FM starts these timers by name: PrepCampFireResourcesTimer (takes the timber once the fire is made) and
//   PrepCampFireErrorMessageTimer (says why no fire could be made, unless one is near anyway).
// - FM's campfire is tagged fmed_campfire and counts as a fire whatever the options say.
// - Hourly refill during FM's fast-forward: FM calls SingletonItemsRefillAmmo, which Preparations' refill rules
//   filter by type (legacy's fmedAutorefillAlchemy switch is not needed).
// - With FM installed, Preparations' options default to legacy's "Friendly Meditation" preset (prepConfig.ws).

@addMethod(W3PlayerWitcher)
function PrepAnswerFMCampFireQuery()
{
	if(FactsQuerySum('fmed_campfire_query') <= 0)
		return;
	if(PrepCanSpawnCampfire())
		FactsSet('prep_fmed_campfire_ok', 2);
	else
		FactsSet('prep_fmed_campfire_ok', 1);
}

@addMethod(W3PlayerWitcher)
function PrepFMCampFireNear(dist : float) : bool
{
	var fire : CEntity;

	fire = theGame.GetEntityByTag('fmed_campfire');
	return fire && VecDistanceSquared2D(fire.GetWorldPosition(), GetWorldPosition()) <= dist * dist;
}

@addMethod(W3PlayerWitcher)
timer function PrepCampFireResourcesTimer(dt : float, id : int)
{
	if(prepConfig)
		prepConfig.RemoveResourcesForCampfire();
}

@addMethod(W3PlayerWitcher)
timer function PrepCampFireErrorMessageTimer(dt : float, id : int)
{
	if(prepConfig && !PrepHasCampfire())
		PrepShowRefusal(prepConfig.GetSpawnCampfireError());
}
