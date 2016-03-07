------------------------------------------------------------
-- NAMESPACE INITIALIZATION
------------------------------------------------------------
ToolTipster = {};
ToolTipster.name = 'ToolTipster';
ToolTipster.accountData = nil;
ToolTipster.charData = nil;
ToolTipster.submodules = {};

------------------------------------------------------------
-- LOCAL CONSTANTS
------------------------------------------------------------
local TT = ToolTipster;
local HOOKS = {
  { ItemTooltip, 'SetBagItem', GetItemLink },
  { ItemTooltip, 'SetWornItem', function(equipSlot) return GetItemLink(BAG_WORN, equipSlot) end },
  { ItemTooltip, 'SetTradeItem', GetTradeItemLink },
  { ItemTooltip, 'SetBuybackItem', GetBuybackItemLink },
  { ItemTooltip, 'SetStoreItem', GetStoreItemLink },
  { ItemTooltip, 'SetAttachedMailItem', GetAttachedItemLink },
  { ItemTooltip, 'SetLootItem', GetLootItemLink },
  { ItemTooltip, 'SetTradingHouseItem', GetTradingHouseSearchResultItemLink },
  { ItemTooltip, 'SetTradingHouseListing', GetTradingHouseListingItemLink },
  { ItemTooltip, 'SetQuestReward', GetQuestRewardItemLink },
  { PopupTooltip, 'SetLink', function(itemLink) return itemLink end },
  { ZO_AlchemyTopLevelTooltip, 'SetPendingAlchemyItem', GetAlchemyResultingItemLink },
  { ZO_SmithingTopLevelCreationPanelResultTooltip, 'SetPendingSmithingItem', GetSmithingPatternResultLink },
  { ZO_SmithingTopLevelImprovementPanelResultTooltip, 'SetSmithingImprovementResult', GetSmithingImprovedItemLink }
};

------------------------------------------------------------
-- PRIVATE METHODS
------------------------------------------------------------

-- Allows the submodules to insert their respective tips into
-- an item's tooltip.
--
-- @param control the item tooltip control to modify.
-- @param link    the itemlink of the item.
local function showToolTip(control, link)
  for name, module in pairs(ToolTipster.submodules) do
    module:ShowToolTip(control, link);
  end
end

-- Inserts hooks into all applicable occurrences of item tooltips.
local function setupToolTipHooks()
  for i = 1, #HOOKS do
    local control = HOOKS[i][1];
    local method = HOOKS[i][2];
    local linkFunc = HOOKS[i][3];
    local origMethod = control[method];
    
    -- Redefine the original method so that it makes an additional
    -- call to showToolTip().
    control[method] = function(self, ...)
        origMethod(self, ...);
        local itemLink = linkFunc(...);
        showToolTip(control, itemLink);
    end
  end
end

-- This method is called whenever any addon is loaded.
--
-- @param event     the EVENT_ADD_ON_LOADED object.
-- @param addonName the name of the addon.
local function onAddOnLoaded(event, addonName)
  -- Do nothing if it's some other addon that was loaded.
  if (addonName ~= TT.name) then
    return;
  end
  
  setupToolTipHooks();
  EVENT_MANAGER:UnregisterForUpdate(EVENT_ADD_ON_LOADED);
end

------------------------------------------------------------
-- PUBLIC METHODS
------------------------------------------------------------

-- Creates a 'unique' key that can be used to index items.
-- The generated index should be general enough to identify
-- items as being the same even if they come from different
-- sources (eg. Cotton listed in the Guild Store versus Cotton
-- found in the backpack), yet specific enough to distinguish
-- between similar items that differ in level requirement.
--
-- @param   itemLink  the link for the item.
-- @return  the generated index.
function ToolTipster.CreateItemIndex(itemLink)
  local itemId = select(4, ZO_LinkHandler_ParseLink(itemLink));
  local level = GetItemLinkRequiredLevel(itemLink);
  local vRank = GetItemLinkRequiredVeteranRank(itemLink);
  local quality = GetItemLinkQuality(itemLink);
  local trait = GetItemLinkTraitInfo(itemLink);
  local potionEffect = string.match(itemLink, '|H.-:item:.-:(%d-)|h') or 0;
  
  if not itemId then
    return nil;
  end
  
  local index = itemId..':'..level..':'..vRank..':'..quality..':'..trait..':'..potionEffect;

  return index;
end

------------------------------------------------------------
-- REGISTER WITH THE GAME'S EVENTS
------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent(TT.name, EVENT_ADD_ON_LOADED, onAddOnLoaded);
