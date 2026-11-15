// PREP-REFILL: potions, decoctions, bombs and oils are refilled one item at a time in the alchemy menu, by
// "brewing" an item Geralt already holds, at a cost set per type by the refill modes; meditation and the other
// vanilla refills only refill the types whose mode is Autorefill.
//
// Legacy changed W3AlchemyManager.CanCookRecipe and CookItem. Ghost Mode replaces CookItem (FOOD-07), which
// would drop a wrapper of it, so the refill itself runs from CR4AlchemyMenu.CreateItem (prepAlchemy.ws) and
// CookItem is never reached for a refill; CanCookRecipe is wrapped (Ghost Mode does not touch it).

// ---------------- the refill rules (legacy's W3AlchemyManager helpers) ----------------

// A refill: a singleton potion, decoction, bomb or oil held exactly once with charges missing (oils only while
// they have charges, PREP-OIL). An item hidden with 'NoShow' is not a refill: 5.x's own brewing handles it
// (legacy treats it as a re-brew too).
@addMethod(W3AlchemyManager)
function PrepIsRefillNeeded(recipe : SAlchemyRecipe) : bool
{
	var ids : array<SItemUniqueId>;
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	if(!cfg)
		return false;
	if(recipe.cookedItemType == EACIT_Oil && !cfg.OilsHaveAmmo())
		return false;
	if(!theGame.GetDefinitionsManager().IsItemSingletonItem(recipe.cookedItemName))
		return false;
	if(recipe.cookedItemType != EACIT_Potion && recipe.cookedItemType != EACIT_MutagenPotion
		&& recipe.cookedItemType != EACIT_Bomb && recipe.cookedItemType != EACIT_Oil)
		return false;
	ids = thePlayer.inv.GetItemsByName(recipe.cookedItemName);
	if(ids.Size() != 1 || thePlayer.inv.ItemHasTag(ids[0], 'NoShow'))
		return false;
	return thePlayer.inv.SingletonItemGetAmmo(ids[0]) < thePlayer.inv.SingletonItemGetMaxAmmo(ids[0]);
}

// The refill mode of a recipe's type: 0 Autorefill, 1 corresponding base, 2-4 one base, 5 full recipe,
// 6 base and herbs, 7 (decoctions) all but the mutagen; -1 for other types.
@addMethod(W3AlchemyManager)
function PrepRefillMode(recipe : SAlchemyRecipe) : int
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	switch(recipe.cookedItemType)
	{
		case EACIT_Bomb:		return cfg.bombsRefillMode;
		case EACIT_Oil:			return cfg.oilsRefillMode;
		case EACIT_MutagenPotion:	return cfg.mutagensRefillMode;
		case EACIT_Potion:		return cfg.potionsRefillMode;
	}
	return -1;
}

@addMethod(W3AlchemyManager)
function PrepIsAlcohol(item : name) : bool
{
	return item == 'Dwarven spirit' || item == 'Alcohest' || item == 'White Gull 1';
}

@addMethod(W3AlchemyManager)
function PrepIsPowder(item : name) : bool
{
	return item == 'Saltpetre' || item == 'Stammelfords dust' || item == 'Alchemists powder';
}

@addMethod(W3AlchemyManager)
function PrepIsFat(item : name) : bool
{
	return item == 'Dog tallow' || item == 'Bear fat' || item == 'Alchemical paste';
}

// The base of a recipe's type: alcohol for potions and decoctions, powder for bombs, fat for oils.
@addMethod(W3AlchemyManager)
function PrepIsBaseForRecipe(recipe : SAlchemyRecipe, itemName : name) : bool
{
	if((recipe.cookedItemType == EACIT_Potion || recipe.cookedItemType == EACIT_MutagenPotion) && PrepIsAlcohol(itemName))
		return true;
	if(recipe.cookedItemType == EACIT_Bomb && PrepIsPowder(itemName))
		return true;
	if(recipe.cookedItemType == EACIT_Oil && PrepIsFat(itemName))
		return true;
	return false;
}

// The recipe's own base (the first ingredient that is one), 'None' if it has none.
@addMethod(W3AlchemyManager)
function PrepRefillBaseFromRecipe(recipe : SAlchemyRecipe) : name
{
	var i : int;

	for(i = 0; i < recipe.requiredIngredients.Size(); i += 1)
		if(PrepIsBaseForRecipe(recipe, recipe.requiredIngredients[i].itemName))
			return recipe.requiredIngredients[i].itemName;
	return 'None';
}

// The one base a "one base" mode names for the recipe's type.
@addMethod(W3AlchemyManager)
function PrepCommonRefillBase(recipe : SAlchemyRecipe) : name
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	switch(recipe.cookedItemType)
	{
		case EACIT_Bomb:		return cfg.bombsRefillBase;
		case EACIT_Oil:			return cfg.oilsRefillBase;
		case EACIT_MutagenPotion:	return cfg.mutagensRefillBase;
		case EACIT_Potion:		return cfg.potionsRefillBase;
	}
	return 'None';
}

// What a refill costs, by mode (legacy's CanCookRecipe/CookItem/UpdateItemsById branches):
// 1: one of the recipe's own base; 2-4: one of the named base; 5: every ingredient but a lower tier of the
// same item; 6: the base and the herbs; 7 (decoctions): every ingredient but those named "mutagen"; anything
// else (Autorefill, which has no menu refill in legacy either): the whole recipe.
@addMethod(W3AlchemyManager)
function PrepRefillCost(recipe : SAlchemyRecipe, out names : array<name>, out quantities : array<int>)
{
	var i, mode : int;
	var itemName : name;

	names.Clear();
	quantities.Clear();
	mode = PrepRefillMode(recipe);
	if(mode == 1)
	{
		names.PushBack(PrepRefillBaseFromRecipe(recipe));
		quantities.PushBack(1);
		return;
	}
	if(mode >= 2 && mode <= 4)
	{
		names.PushBack(PrepCommonRefillBase(recipe));
		quantities.PushBack(1);
		return;
	}
	for(i = 0; i < recipe.requiredIngredients.Size(); i += 1)
	{
		itemName = recipe.requiredIngredients[i].itemName;
		if(mode == 5 && GetItemNameWithoutLevelAsString(recipe.cookedItemName) == GetItemNameWithoutLevelAsString(itemName))
			continue;
		if(mode == 6 && !PrepIsBaseForRecipe(recipe, itemName) && !theGame.GetDefinitionsManager().ItemHasTag(itemName, 'HerbGameplay'))
			continue;
		if(mode == 7 && recipe.cookedItemType == EACIT_MutagenPotion && (StrContains(itemName, "mutagen") || StrContains(itemName, "Mutagen")))
			continue;
		names.PushBack(itemName);
		quantities.PushBack(recipe.requiredIngredients[i].quantity);
	}
}

// Whether Geralt holds the refill's cost.
@addMethod(W3AlchemyManager)
function PrepCanRefill(recipe : SAlchemyRecipe) : EAlchemyExceptions
{
	var names : array<name>;
	var quantities : array<int>;
	var i, cnt : int;

	PrepRefillCost(recipe, names, quantities);
	for(i = 0; i < names.Size(); i += 1)
	{
		if(theGame.GetDefinitionsManager().ItemHasTag(names[i], 'MutagenIngredient'))
			cnt = thePlayer.inv.GetUnusedMutagensCount(names[i]);
		else
			cnt = thePlayer.inv.GetItemQuantityByName(names[i]);
		if(cnt < quantities[i])
			return EAE_NotEnoughIngredients;
	}
	return EAE_NoException;
}

// The refill itself: the item back to its max (or one charge with "Refilling restores only one charge"),
// then the cost taken, as 5.x's CookItem takes ingredients.
@addMethod(W3AlchemyManager)
function PrepRefill(recipe : SAlchemyRecipe)
{
	var names : array<name>;
	var quantities : array<int>;
	var ids, alchIngs : array<SItemUniqueId>;
	var i, j, removed : int;
	var witcher : W3PlayerWitcher;
	var dm : CDefinitionsManagerAccessor;

	witcher = GetWitcherPlayer();
	dm = theGame.GetDefinitionsManager();
	ids = thePlayer.inv.GetItemsByName(recipe.cookedItemName);
	if(ids.Size() != 1)
		return;
	PrepRefillCost(recipe, names, quantities);
	if(GetPreparationsConfig().refillOne)
		thePlayer.inv.SingletonItemSetAmmo(ids[0], thePlayer.inv.SingletonItemGetAmmo(ids[0]) + 1);
	else
		thePlayer.inv.SingletonItemSetAmmo(ids[0], thePlayer.inv.SingletonItemGetMaxAmmo(ids[0]));
	for(i = 0; i < names.Size(); i += 1)
	{
		if(dm.ItemHasTag(names[i], 'MutagenIngredient'))
		{
			thePlayer.inv.RemoveUnusedMutagensCount(names[i], quantities[i]);
		}
		else if(dm.IsItemAlchemyItem(names[i]))
		{
			removed = 0;
			alchIngs = thePlayer.inv.GetItemsByName(names[i]);
			for(j = 0; j < alchIngs.Size() && removed < quantities[i]; j += 1)
			{
				if(witcher.GetItemSlot(alchIngs[j]) != EES_InvalidSlot)
					witcher.UnequipItem(alchIngs[j]);
				removed += 1;
				thePlayer.inv.RemoveItem(alchIngs[j], 1);
			}
		}
		else
		{
			thePlayer.inv.RemoveItemByName(names[i], quantities[i]);
		}
	}
}

// A refill is not refused as "cannot brew more": its cost is checked instead (legacy's CanCookRecipe branch).
@wrapMethod(W3AlchemyManager)
function CanCookRecipe(recipeName : name, optional ignorePlayerState : bool) : EAlchemyExceptions
{
	var recipe : SAlchemyRecipe;

	if(GetRecipe(recipeName, recipe) && PrepIsRefillNeeded(recipe))
	{
		if(!ignorePlayerState)
		{
			if(isPlayerMounted)
				return EAE_Mounted;
			if(isPlayerInCombat)
				return EAE_InCombat;
		}
		return PrepCanRefill(recipe);
	}
	return wrappedMethod(recipeName, ignorePlayerState);
}

// ---------------- vanilla refills only for the Autorefill types ----------------

// Set while a refill must not be filtered (legacy's skipPrepCheck): 5.x's no-alcohol refill, and later the
// quest refill and New Game+ (PREP-REST).
@addField(CInventoryComponent)
var prepSkipRefillFilter : bool;

// Whether vanilla's refills refill this item: its type is in Autorefill mode (or the filter is off).
@addMethod(CInventoryComponent)
function PrepAutorefills(item : SItemUniqueId) : bool
{
	var cfg : CModPreparationsConfig;

	cfg = GetPreparationsConfig();
	if(prepSkipRefillFilter || !cfg || GetEntity() != GetWitcherPlayer())
		return true;
	if(IsItemBomb(item))
		return cfg.bombsRefillMode == 0;
	if(IsItemOil(item))
		return cfg.oilsRefillMode == 0;
	if(IsItemMutagenPotion(item))
		return cfg.mutagensRefillMode == 0;
	if(IsItemPotion(item))
		return cfg.potionsRefillMode == 0;
	return false;
}

// 5.x's body; the loop refills only the Autorefill types, so the alcohol is taken only when one of them needs it.
@replaceMethod(CInventoryComponent)
function SingletonItemsRefillAmmo(optional alchemyTableUsed : bool) : bool
{
	var i : int;
	var singletonItems : array<SItemUniqueId>;
	var alco : SItemUniqueId;
	var arrStr : array<string>;
	var witcher : W3PlayerWitcher;
	var itemLabel : string;

	witcher = GetWitcherPlayer();
	if(GetEntity() == witcher && HasNotFilledSingletonItem( alchemyTableUsed ) )
	{
		alco = witcher.GetAlcoholForAlchemicalItemsRefill();
		if(!IsIdValid(alco))
		{
			theGame.GetGuiManager().ShowNotification(GetLocStringByKeyExt("message_common_alchemy_items_cannot_refill"));
			theSound.SoundEvent("gui_global_denied");
			return false;
		}
		else
		{
			arrStr.PushBack(GetItemName(alco));
			itemLabel = GetLocStringByKeyExt(GetItemLocalizedNameByUniqueID(alco));
			theGame.GetGuiManager().ShowNotification( itemLabel + " - " + GetLocStringByKeyExtWithParams("message_common_alchemy_items_refilled", , , arrStr));
			theSound.SoundEvent("gui_alchemy_brew");
			if(!ItemHasTag(alco, theGame.params.TAG_INFINITE_USE))
				RemoveItem(alco);
		}
	}
	singletonItems = GetSingletonItems();
	for(i=0; i<singletonItems.Size(); i+=1)
	{
		if(PrepAutorefills(singletonItems[i]))	// modPreparations
			SingletonItemRefillAmmo( singletonItems[i], alchemyTableUsed );
	}
	return true;
}

// 5.x's body; only the Autorefill types count as "not filled".
@replaceMethod(CInventoryComponent)
function HasNotFilledSingletonItem(optional alchemyTableUsed : bool) : bool
{
	var i : int;
	var singletonItems : array<SItemUniqueId>;
	var hasLab : bool;
	var l_bed : W3WitcherBed;

	hasLab = false;
	if( FactsQuerySum( "PlayerInsideOuterWitcherHouse" ) >= 1 && FactsQuerySum( "AlchemyTableExists" ) >= 1 )
	{
		l_bed = (W3WitcherBed)theGame.GetEntityByTag( 'witcherBed' );
		if( l_bed.GetWasUsed() || alchemyTableUsed )
		{
			hasLab = true;
		}
	}
	singletonItems = GetSingletonItems();
	for(i=0; i<singletonItems.Size(); i+=1)
	{
		if(!PrepAutorefills(singletonItems[i]))	// modPreparations
			continue;
		if( hasLab && !IsItemMutagenPotion( singletonItems[i] ) )
		{
			if(SingletonItemGetAmmo(singletonItems[i]) <= SingletonItemGetMaxAmmo(singletonItems[i]))
			{
				return true;
			}
		}
		else if(SingletonItemGetAmmo(singletonItems[i]) < SingletonItemGetMaxAmmo(singletonItems[i]))
		{
			return true;
		}
	}
	return false;
}

// 5.x's refill without alcohol refills everything; its message checks every item too (legacy's
// HasNotFilledSingletonItem(, true) there).
@wrapMethod(CInventoryComponent)
function SingletonItemsRefillAmmoNoAlco(optional dontUpdateUI : bool)
{
	var before : bool;

	before = prepSkipRefillFilter;
	prepSkipRefillFilter = true;
	wrappedMethod(dontUpdateUI);
	prepSkipRefillFilter = before;
}
