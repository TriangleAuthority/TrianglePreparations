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
