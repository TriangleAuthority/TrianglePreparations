// Slice 0 (test only): shows that this mod's compiled scripts load in game.
//   preptest_ping()  logs one line on channel 'PREPTest'.

exec function preptest_ping()
{
	LogChannel('PREPTest', "PASS preptest_ping: modPreparations scripts are loaded");
}
