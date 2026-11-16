// The effect-type check (2026-11-15). Preparations adds one member to the game's EEffectType (prepTable.ws, after a
// copy of Ghost Mode's 18). The game merges every mod's members by name at load and numbers them in load order, so
// another compiled mod that adds effect types (or a newer Ghost Mode whose list the copy does not follow) can shift
// Preparations' number, and its alchemy-table effect then does not work. A class default is resolved by name against
// the merged list, while a number in the code keeps its compiled value: when the two differ, the mods clash. The fix
// is TriangleGhostMode's tools/enum_sync.py (README, "Using it with other mods"). Checked a few seconds after a save
// loads; a clash is shown as a notification and written to the script log.

@addField(W3PlayerWitcher)
var prepEffectTypeClash : string;	// "" when the numbers agree (read by the tests)

@addMethod(W3PlayerWitcher)
function PrepCheckEffectTypes() : bool
{
	var eff : W3PrepEffect_AlchemyTable;

	eff = new W3PrepEffect_AlchemyTable in this;
	prepEffectTypeClash = "";
	if((int)eff.GetEffectType() != (int)EET_PrepAlchemyTable)
		prepEffectTypeClash = "EET_PrepAlchemyTable compiled " + (int)EET_PrepAlchemyTable + ", in game " + (int)eff.GetEffectType();
	delete eff;
	return prepEffectTypeClash == "";
}

@wrapMethod(W3PlayerWitcher)
function OnSpawned(spawnData : SEntitySpawnData)
{
	wrappedMethod(spawnData);
	AddTimer('PrepEffectTypeCheckTimer', 5.0, false);
}

@addMethod(W3PlayerWitcher)
timer function PrepEffectTypeCheckTimer(dt : float, id : int)
{
	if(PrepCheckEffectTypes())
	{
		LogChannel('Preparations', "effect types: numbers agree with the game's");
		return;
	}
	LogChannel('Preparations', "effect types CLASH with another mod: " + prepEffectTypeClash);
	theGame.GetGuiManager().ShowNotification("Preparations: another installed mod also adds effect types, and their numbers clash, so the"
		+ " alchemy table's effect will not work. Run enum_sync.py after installing mods (see Preparations' README).", 15.0);
}
