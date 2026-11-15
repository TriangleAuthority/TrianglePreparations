// PREP-TIME: actions cost game time (legacy's AdvanceTimeSeconds): the clock jumps forward and the effects on
// Geralt run for that time, so potions and toxicity wear off as if the time had passed. Minutes per action are
// the "Time intervals" options (create, repair, upgrade, buy a skill, equip a skill, equip a mutagen); charged
// whether meditating or not, as in legacy.
@addMethod(W3PlayerWitcher)
function PrepAdvanceTimeSeconds(seconds : int)
{
	if(seconds <= 0)
		return;
	theGame.SetGameTime(theGame.GetGameTime() + GameTimeCreateFromGameSeconds(seconds), false);
	effectManager.PerformUpdate(ConvertGameSecondsToRealTimeSeconds(seconds));
}

// Shown by a menu when Preparations refuses an action there (legacy: a notification and the "denied" sound).
@addMethod(CR4MenuBase)
function PrepMenuRefuse(key : string)
{
	var w : W3PlayerWitcher;

	w = GetWitcherPlayer();
	if(w)
		w.prepLastMessage = key;
	showNotification(GetLocStringByKeyExt(key));
	OnPlaySoundEvent("gui_global_denied");
}
