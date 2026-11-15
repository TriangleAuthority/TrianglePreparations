// PREP-MENU (test only).
//   preptest_menu()  logs every option as the settings file holds it and as CModPreparationsConfig read it,
//                    then whether Preparations' DLC is mounted. Channel 'PREPTest'.

exec function preptest_menu()
{
	var cfgw : CInGameConfigWrapper;
	var cfg : CModPreparationsConfig;
	var groups, options : array<name>;
	var i, bad : int;
	var raw : string;

	cfgw = theGame.GetInGameConfigWrapper();
	PrepOptionList(groups, options);
	for(i = 0; i < options.Size(); i += 1)
	{
		raw = cfgw.GetVarValue(groups[i], options[i]);
		if(PrepOptionUnset(options[i], raw))
		{
			bad += 1;
			LogChannel('PREPTest', "FAIL unset " + groups[i] + "." + options[i] + " (default " + PrepOptionDefault(groups[i], options[i]) + ")");
		}
		else
			LogChannel('PREPTest', "INFO " + groups[i] + "." + options[i] + " = '" + raw + "' (default " + PrepOptionDefault(groups[i], options[i]) + ")");
	}

	cfg = GetPreparationsConfig();
	if(!cfg)
	{
		LogChannel('PREPTest', "FAIL no CModPreparationsConfig on the player");
		return;
	}
	LogChannel('PREPTest', "INFO config: disallowMeditation=" + cfg.disallowMeditation + " npcDistance=" + cfg.npcDistance
		+ " maxOilCharges=" + cfg.maxOilCharges + " refill modes bombs/oils/decoctions/potions="
		+ cfg.bombsRefillMode + "/" + cfg.oilsRefillMode + "/" + cfg.mutagensRefillMode + "/" + cfg.potionsRefillMode
		+ " timeToCreateItemSec=" + cfg.timeToCreateItemSec + " disableRegenFullHealth=" + cfg.disableRegenFullHealth
		+ " blockInventoryInCombat=" + cfg.blockInventoryInCombat + " potionsRefillBase=" + cfg.potionsRefillBase);

	LogChannel('PREPTest', "INFO dlc_preparations available=" + theGame.GetDLCManager().IsDLCAvailable('dlc_preparations')
		+ " enabled=" + theGame.GetDLCManager().IsDLCEnabled('dlc_preparations'));
	if(!theGame.GetDLCManager().IsDLCEnabled('dlc_preparations'))
		bad += 1;

	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_menu: " + options.Size() + " options set, config read, DLC mounted");
	else
		LogChannel('PREPTest', "FAIL preptest_menu: " + bad + " problems");
}
