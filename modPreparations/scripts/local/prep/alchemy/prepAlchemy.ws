// PREP-ALCH: brewing only where the options allow (at a fire, while meditating), with legacy's exemptions:
// quest recipes, the forced Thunderbolt tutorial, and brewing at a herbalist's or alchemist's (the menu opened
// from that NPC). Brewing or refilling costs game time ("Time to create one item"), except quest recipes and
// at a herbalist. The refill itself (PREP-REFILL, prepRefill.ws) runs here instead of CookItem.

// The menu was opened from a herbalist or an alchemist (legacy's bHerbalist: the NPC's merchant map pin).
@addMethod(CR4AlchemyMenu)
function PrepIsHerbalist() : bool
{
	var merchant : W3MerchantComponent;

	if(!m_npc)
		return false;
	merchant = (W3MerchantComponent)m_npc.GetComponentByClassName('W3MerchantComponent');
	if(!merchant)
		return false;
	return merchant.GetMapPinType() == 'Herbalist' || merchant.GetMapPinType() == 'Alchemic';
}

// 5.x's CreateItem with legacy's gate, the refill branch and the time cost. Ghost Mode does not touch it.
@replaceMethod(CR4AlchemyMenu)
function CreateItem( recipeIndex : int )
{
	var recipe			: SAlchemyRecipe;
	var exception		: EAlchemyExceptions;
	var cookedItemName	: string;
	var cfg				: CModPreparationsConfig;	// modPreparations
	var exempt, refill	: bool;						// modPreparations
	recipe  = m_recipeList[ recipeIndex ];

	exception = EAE_CookNotAllowed;

	LogChannel( 'Alchemy', "OnCreateItem - " + recipeIndex + " " + recipe.recipeName );

	// modPreparations: brewing only where allowed, but quest recipes, the forced tutorial and herbalists are exempt
	cfg = GetPreparationsConfig();
	exempt = recipe.cookedItemType == EACIT_Quest || PrepIsHerbalist() || (m_forcedThunderbolt && recipe.recipeName == 'Recipe for Thunderbolt 1');
	if(cfg && !exempt && !cfg.IsAlchemyAllowed())
	{
		PrepMenuRefuse(cfg.GetAlchemyError());
		return;
	}

	if( bCouldCraft )
	{
		GetWitcherPlayer().StartInvUpdateTransaction();

		exception = m_alchemyManager.CanCookRecipe( recipe.recipeName );
		if( exception == EAE_NoException )
		{
			// modPreparations: a held item with charges missing is refilled, not brewed again
			refill = m_alchemyManager.PrepIsRefillNeeded( recipe );
			if( refill )
				m_alchemyManager.PrepRefill( recipe );
			else
				m_alchemyManager.CookItem( recipe.recipeName );
			if( cfg && recipe.cookedItemType != EACIT_Quest && !PrepIsHerbalist() )
				GetWitcherPlayer().PrepAdvanceTimeSeconds( cfg.timeToCreateItemSec );

			if (recipe.level > 1)
			{

				m_recipeList = m_alchemyManager.GetRecipes(false);
			}

			PopulateData();
			UpdateItemsById(recipeIndex);
			cookedItemName = GetLocStringByKeyExt(m_definitionsManager.GetItemLocalisationKeyName( recipe.cookedItemName ));
			showNotification(GetLocStringByKeyExt("panel_crafting_successfully_crafted") + ": " + cookedItemName);
			OnPlaySoundEvent("gui_crafting_craft_item_complete");
		}

		GetWitcherPlayer().FinishInvUpdateTransaction();
	}

	if (exception != EAE_NoException)
	{
		showNotification(GetLocStringByKeyExt(AlchemyExceptionToString(exception)));
		OnPlaySoundEvent("gui_global_denied");
	}
}

// 5.x's UpdateItemsById; for a refill the ingredient list shows the refill's cost (legacy).
@replaceMethod(CR4AlchemyMenu)
function UpdateItemsById( id : int ) : void
{
	var itemsFlashArray	: CScriptedFlashArray;
	var i : int;
	var costNames : array<name>;	// modPreparations
	var costQuantities : array<int>;	// modPreparations

	itemsNames.Clear();
	itemsQuantity.Clear();
	if( m_alchemyManager.PrepIsRefillNeeded( m_recipeList[id] ) )	// modPreparations
	{
		m_alchemyManager.PrepRefillCost( m_recipeList[id], costNames, costQuantities );
		for( i = 0; i < costNames.Size(); i += 1 )
		{
			itemsNames.PushBack(costNames[i]);
			itemsQuantity.PushBack(costQuantities[i]);
		}
	}
	else
	for( i = 0; i < m_recipeList[id].requiredIngredients.Size(); i += 1 )
	{
		itemsNames.PushBack(m_recipeList[id].requiredIngredients[i].itemName);
		itemsQuantity.PushBack(m_recipeList[id].requiredIngredients[i].quantity);
	}
	itemsFlashArray = CreateItems(itemsNames);

	if( itemsFlashArray )
	{
		m_flashValueStorage.SetFlashArray( DATA_BINDING_NAME_SUBLIST, itemsFlashArray );
	}
}

// ---------------- charges in recipe names (legacy's PopulateData change), with wrappers only ----------------
// Legacy appended " | charges/max |" to the name of every singleton recipe whose item Geralt holds once.
// 5.x's PopulateData builds each name from GetLocStringByKeyExt(<the item's name key>) into a local, so while
// PopulateData runs, a wrapper of GetLocStringByKeyExt appends the charges to those keys. Keys shared by two
// recipes' items are left alone (the suffix could land on the wrong one).

@addField(CR4Game)
var prepTitleKeys : array<string>;

@addField(CR4Game)
var prepTitleSuffixes : array<string>;

@addField(CR4Game)
var prepTitlesActive : bool;

// How many names got their charges in the last PopulateData (for the tests).
@addField(CR4Game)
var prepTitlesApplied : int;

@wrapMethod(CR4AlchemyMenu)
function PopulateData()
{
	var i, j : int;
	var key : string;
	var keys, shared : array<string>;
	var ids : array<SItemUniqueId>;

	theGame.prepTitleKeys.Clear();
	theGame.prepTitleSuffixes.Clear();
	for(i = 0; i < m_recipeList.Size(); i += 1)
	{
		key = m_definitionsManager.GetItemLocalisationKeyName(m_recipeList[i].cookedItemName);
		if(keys.Contains(key))
			shared.PushBack(key);
		keys.PushBack(key);
	}
	for(i = 0; i < m_recipeList.Size(); i += 1)
	{
		if(!m_definitionsManager.IsItemSingletonItem(m_recipeList[i].cookedItemName) || shared.Contains(keys[i]))
			continue;
		ids = thePlayer.inv.GetItemsByName(m_recipeList[i].cookedItemName);
		if(ids.Size() != 1)
			continue;
		theGame.prepTitleKeys.PushBack(keys[i]);
		theGame.prepTitleSuffixes.PushBack(" | " + IntToString(thePlayer.inv.SingletonItemGetAmmo(ids[0])) + "/"
			+ IntToString(thePlayer.inv.SingletonItemGetMaxAmmo(ids[0])) + " |");
	}
	theGame.prepTitlesActive = theGame.prepTitleKeys.Size() > 0;
	theGame.prepTitlesApplied = 0;
	wrappedMethod();
	theGame.prepTitlesActive = false;
}

@wrapMethod
function GetLocStringByKeyExt(stringKey : string) : string
{
	var i : int;

	if(theGame && theGame.prepTitlesActive)
	{
		i = theGame.prepTitleKeys.FindFirst(stringKey);
		if(i >= 0)
		{
			theGame.prepTitlesApplied += 1;
			return wrappedMethod(stringKey) + theGame.prepTitleSuffixes[i];
		}
	}
	return wrappedMethod(stringKey);
}
