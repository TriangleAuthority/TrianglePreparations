// Slice 3 (test only): PREP-ALCH and PREP-REFILL. Channel 'PREPTest'. Options are changed in memory only and
// read back at the end of each test.
//   preptest_refill()        the refill rules and the Autorefill filter, on the alchemy manager
//   preptest_alch_open()     a half-empty Swallow and its base in the bag; opens the alchemy menu
//   preptest_alch_menu()     with the alchemy menu open: refused away from fire, refill at a campfire with time

function PrepTestSwallow(potion : name, ammo : int) : SItemUniqueId
{
	var ids : array<SItemUniqueId>;

	thePlayer.inv.RemoveItemByName(potion, 100);
	ids = thePlayer.inv.AddAnItem(potion, 1);
	thePlayer.inv.SingletonItemSetAmmo(ids[0], ammo);
	return ids[0];
}

function PrepTestCostString(names : array<name>, quantities : array<int>) : string
{
	var s : string;
	var i : int;

	for(i = 0; i < names.Size(); i += 1)
		s += quantities[i] + " " + names[i] + "; ";
	return s;
}

exec function preptest_refill()
{
	var mgr : W3AlchemyManager;
	var cfg : CModPreparationsConfig;
	var inv : CInventoryComponent;
	var recipe, recipe2 : SAlchemyRecipe;
	var recipeNames : array<name>;
	var names : array<name>;
	var quantities : array<int>;
	var potion : SItemUniqueId;
	var i, bad, maxAmmo, spirits : int;
	var ok : bool;

	cfg = GetPreparationsConfig();
	inv = thePlayer.inv;
	recipeNames.PushBack('Recipe for Swallow 1');
	recipeNames.PushBack('Recipe for Swallow 2');
	mgr = new W3AlchemyManager in thePlayer;
	mgr.Init(recipeNames);
	mgr.GetRecipe('Recipe for Swallow 1', recipe);
	mgr.GetRecipe('Recipe for Swallow 2', recipe2);
	inv.RemoveItemByName('Dwarven spirit', 1000);
	inv.RemoveItemByName('Alcohest', 1000);

	potion = PrepTestSwallow('Swallow 1', 0);
	maxAmmo = inv.SingletonItemGetMaxAmmo(potion);
	bad += PrepTestCheck(mgr.PrepIsRefillNeeded(recipe), "a held Swallow with 0/" + maxAmmo + " charges needs a refill");

	// mode 1 (default): one of the recipe's own base
	bad += PrepTestCheck(cfg.potionsRefillMode == 1, "default potion refill mode: corresponding base");
	mgr.PrepRefillCost(recipe, names, quantities);
	bad += PrepTestCheck(names.Size() == 1 && quantities[0] == 1 && names[0] == mgr.PrepRefillBaseFromRecipe(recipe) && mgr.PrepIsAlcohol(names[0]),
		"mode 1 cost: " + PrepTestCostString(names, quantities));
	bad += PrepTestCheck(mgr.CanCookRecipe('Recipe for Swallow 1', true) == EAE_NotEnoughIngredients, "no base: refill refused (not enough ingredients)");
	inv.AddAnItem(names[0], 1);
	bad += PrepTestCheck(mgr.CanCookRecipe('Recipe for Swallow 1', true) == EAE_NoException, "with the base: refill allowed (not 'cannot brew more')");
	mgr.PrepRefill(recipe);
	bad += PrepTestCheck(inv.SingletonItemGetAmmo(potion) == maxAmmo && inv.GetItemQuantityByName(names[0]) == 0, "refilled to " + inv.SingletonItemGetAmmo(potion) + ", base used");
	bad += PrepTestCheck(!mgr.PrepIsRefillNeeded(recipe) && mgr.CanCookRecipe('Recipe for Swallow 1', true) == EAE_CannotCookMore, "full: no refill, 5.x's 'cannot brew more'");

	// one charge at a time
	inv.SingletonItemSetAmmo(potion, 0);
	cfg.refillOne = true;
	inv.AddAnItem(names[0], 1);
	mgr.PrepRefill(recipe);
	bad += PrepTestCheck(inv.SingletonItemGetAmmo(potion) == 1, "'restores only one charge': 0 -> " + inv.SingletonItemGetAmmo(potion));
	cfg.refillOne = false;

	// mode 3: one named base for every tier
	cfg.potionsRefillMode = 3;
	cfg.potionsRefillBase = cfg.GetPotionsRefillBase(3);
	mgr.PrepRefillCost(recipe, names, quantities);
	bad += PrepTestCheck(names.Size() == 1 && names[0] == 'Alcohest', "mode 3 cost: " + PrepTestCostString(names, quantities));

	// mode 5: the full recipe but the lower tier
	cfg.potionsRefillMode = 5;
	mgr.PrepRefillCost(recipe2, names, quantities);
	ok = names.Size() == recipe2.requiredIngredients.Size() - 1 && !names.Contains('Swallow 1');
	bad += PrepTestCheck(ok, "mode 5 cost for Swallow 2 (no Swallow 1): " + PrepTestCostString(names, quantities));

	// mode 6: the base and the herbs
	cfg.potionsRefillMode = 6;
	mgr.PrepRefillCost(recipe, names, quantities);
	ok = names.Size() > 0;
	for(i = 0; i < names.Size(); i += 1)
		ok = ok && (mgr.PrepIsAlcohol(names[i]) || theGame.GetDefinitionsManager().ItemHasTag(names[i], 'HerbGameplay'));
	bad += PrepTestCheck(ok, "mode 6 cost: " + PrepTestCostString(names, quantities));

	// vanilla refills only refill Autorefill types
	cfg.potionsRefillMode = 1;
	inv.SingletonItemSetAmmo(potion, 0);
	inv.AddAnItem('Dwarven spirit', 1);
	spirits = inv.GetItemQuantityByName('Dwarven spirit');
	inv.SingletonItemsRefillAmmo();
	bad += PrepTestCheck(inv.SingletonItemGetAmmo(potion) == 0 && inv.GetItemQuantityByName('Dwarven spirit') == spirits,
		"meditation's refill skips potions when their mode is not Autorefill, no alcohol taken");
	cfg.potionsRefillMode = 0;
	inv.SingletonItemsRefillAmmo();
	bad += PrepTestCheck(inv.SingletonItemGetAmmo(potion) == maxAmmo, "Autorefill mode: meditation's refill refills the Swallow");
	cfg.potionsRefillMode = 1;
	inv.SingletonItemSetAmmo(potion, 0);
	inv.SingletonItemsRefillAmmoNoAlco(true);
	bad += PrepTestCheck(inv.SingletonItemGetAmmo(potion) == maxAmmo, "5.x's refill without alcohol still refills everything");

	cfg.UpdateUserSettings();
	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_refill");
	else
		LogChannel('PREPTest', "FAIL preptest_refill: " + bad + " failed");
}

// test only: select a recipe and press "craft" in the open alchemy menu
@addMethod(CR4AlchemyMenu)
function PrepTestCraft(recipeName : name) : bool
{
	var i : int;

	for(i = 0; i < m_recipeList.Size(); i += 1)
	{
		if(m_recipeList[i].recipeName == recipeName)
		{
			ShowSelectedItemInfo(recipeName);
			CreateItem(i);
			return true;
		}
	}
	return false;
}

exec function preptest_alch_open()
{
	var recipeNames : array<name>;

	GetWitcherPlayer().AddAlchemyRecipe('Recipe for Swallow 1', true, true);
	PrepTestSwallow('Swallow 1', 0);
	thePlayer.inv.RemoveItemByName('Dwarven spirit', 1000);
	thePlayer.inv.AddAnItem('Dwarven spirit', 2);
	theGame.RequestMenuWithBackground('AlchemyMenu', 'CommonMenu');
	LogChannel('PREPTest', "INFO alchemy setup: Swallow 0 charges, Dwarven spirit=" + thePlayer.inv.GetItemQuantityByName('Dwarven spirit'));
}

exec function preptest_alch_menu()
{
	var common : CR4CommonMenu;
	var menu : CR4AlchemyMenu;
	var w : W3PlayerWitcher;
	var ids : array<SItemUniqueId>;
	var fire : CEntity;
	var t, bad : int;

	w = GetWitcherPlayer();
	common = (CR4CommonMenu)theGame.GetGuiManager().GetRootMenu();
	if(common)
		menu = (CR4AlchemyMenu)common.GetSubMenu();
	if(!menu)
	{
		LogChannel('PREPTest', "FAIL preptest_alch_menu: the alchemy menu is not open");
		return;
	}
	ids = thePlayer.inv.GetItemsByName('Swallow 1');
	w.prepOpenFireEnt = NULL;
	w.prepLastMessage = "";
	t = PrepTestNow();
	bad += PrepTestCheck(menu.PrepTestCraft('Recipe for Swallow 1'), "Swallow recipe in the menu");
	bad += PrepTestCheck(thePlayer.inv.SingletonItemGetAmmo(ids[0]) == 0 && w.prepLastMessage == "prep_error_campfire_required" && PrepTestNow() == t,
		"refill away from fire refused ('" + w.prepLastMessage + "'), no time");

	fire = PrepTestSpawnCampfire(1.5);
	t = PrepTestNow();
	menu.PrepTestCraft('Recipe for Swallow 1');
	bad += PrepTestCheck(thePlayer.inv.SingletonItemGetAmmo(ids[0]) == thePlayer.inv.SingletonItemGetMaxAmmo(ids[0])
		&& thePlayer.inv.GetItemsByName('Swallow 1').Size() == 1, "refilled at the fire in the menu (" + thePlayer.inv.SingletonItemGetAmmo(ids[0]) + " charges, one item)");
	bad += PrepTestCheck(thePlayer.inv.GetItemQuantityByName('Dwarven spirit') == 1, "one Dwarven spirit used (" + thePlayer.inv.GetItemQuantityByName('Dwarven spirit') + " left)");
	bad += PrepTestCheck(PrepTestNow() - t == 900, "create time charged (" + (PrepTestNow() - t) + " s)");
	fire.Destroy();
	w.prepOpenFireEnt = NULL;

	if(bad == 0)
		LogChannel('PREPTest', "PASS preptest_alch_menu");
	else
		LogChannel('PREPTest', "FAIL preptest_alch_menu: " + bad + " failed");
}
