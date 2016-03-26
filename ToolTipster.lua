local MAJOR, MINOR = 'ToolTipster', 1;
local TT, oldminor = LibStub:NewLibrary(MAJOR, MINOR);
-- Do not load this file if the same version (or newer) of the library has been found.
if not TT then
  return;
end

------------------------------------------------------------
-- PRIVATE CONSTANTS
------------------------------------------------------------
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
  { ItemTooltip, 'SetLink', function(itemLink) return itemLink end },
  { PopupTooltip, 'SetLink', function(itemLink) return itemLink end },
  { PopupTooltip, 'SetLink', function(itemLink) return itemLink end },
  { ZO_AlchemyTopLevelTooltip, 'SetPendingAlchemyItem', GetAlchemyResultingItemLink },
  { ZO_ProvisionerTopLevelTooltip, 'SetProvisionerResultItem', GetRecipeResultItemLink },
  { ZO_SmithingTopLevelImprovementPanelResultTooltip, 'SetSmithingImprovementResult', GetSmithingImprovedItemLink }
};

local EVENTS = {
  TT_EVENT_ITEM_TOOLTIP = 'TT_EVENT_ITEM_TOOLTIP',
};
TT.events = EVENTS;

------------------------------------------------------------
-- PRIVATE VARIABLES
------------------------------------------------------------
local CM = ZO_CallbackObject:New(); -- our custom callback manager.

------------------------------------------------------------
-- PRIVATE METHODS
------------------------------------------------------------

------------------------------------------------------------
-- Fires an event to notify registered listeners that an item tooltip
-- has been opened and ready to be modified.
--
-- @param control the item tooltip control to modify.
-- @param link    the itemlink of the item.
local function showToolTip(control, link)
  -- For now, just fire off the callbacks.
  CM:FireCallbacks(EVENTS.TT_EVENT_ITEM_TOOLTIP, control, link);
end

------------------------------------------------------------
-- Inserts hooks into all applicable occurrences of item tooltips.
local function setupToolTipHooks()
  for i = 1, #HOOKS do
    local control = HOOKS[i][1];        -- the tooltip control 
    local method = HOOKS[i][2];         -- the name of the method we're hooking into
    local linkFunc = HOOKS[i][3];       -- generates an itemLink from the method's arguments
    
    -- Redefine the original method so that it makes an additional
    -- call to showToolTip().
    local origMethod = control[method];
    control[method] = function(self, ...)
        origMethod(self, ...);
        local itemLink = linkFunc(...);
        showToolTip(control, itemLink);
    end
  end
end

------------------------------------------------------------
-- PUBLIC UTILITY METHODS
------------------------------------------------------------

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
function TT:CreateItemIndex(itemLink)
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
-- Used for copying values to/from account-wide settings and
-- character-specific settings. Useful as a callback for when
-- the user toggles a 'Use settings for account' option in the
-- settings menu.
-- This method does not do a deepcopy and will only copy sub-tables
-- one level deep.
-- 
-- @param isAccountWide if true, then values shall be copied from charSettings
--                      to acctSettings, otherwise values shall be copied from
--                      acctSettings to charSettings.
-- @param acctSettings  a table containing the account-wide settings.
-- @param charSettings  a table containing the character-specific settings.
function TT:CopyAddonSettings(isAccountWide, acctSettings, charSettings)
  local sourceSettings = charSettings;
  local targetSettings = acctSettings;
  
  if not isAccountWide then
    sourceSettings = acctSettings;
    targetSettings = charSettings;
  end
  
  for key, value in pairs(sourceSettings) do
    if (type(value) == 'table') then
      for t_key, t_value in pairs(value) do
        targetSettings[key][t_key] = t_value;
      end
    else
      targetSettings[key] = value;
    end
  end
end

------------------------------------------------------------
-- Adds a character name to a list.
-- The list does not allow duplicates and the names are sorted
-- in alphabetical order.
-- 
-- @param   charList  the list to add to.
-- @param   charName  the character name to add.
-- 
-- @return  true if the name was added as a new entry, otherwise returns false.
function TT:AddCharacterToList(charList, charName)
  for index, name in pairs(charList) do
    if (name == charName) then
      return false;
    end
  end
  
  table.insert(charList, charName);
  table.sort(charList);
  return true;
end

------------------------------------------------------------
-- Removes a character name from a list.
-- 
-- @param   charList  the list to remove from.
-- @param   charName  the character name to remove.
-- 
-- @return  true if the name was removed, otherwise returns false. 
function TT:RemoveCharacterFromList(knownCharList, tgtCharName)
  for index, charName in pairs(knownCharList) do
    if (charName == tgtCharName) then
      table.remove(knownCharList, index);
      return true;
    end
  end
  return false;
end

------------------------------------------------------------
-- PUBLIC METHODS
------------------------------------------------------------

------------------------------------------------------------
-- Registers a callback for one of this library's custom events.
-- 
-- @param   the name of the event.
-- @param   the callback function.
function TT:RegisterCallback(event, callback)
  local validEvent = false;
  for e, name in pairs(EVENTS) do
    if (name == event) then
      validEvent = true;
      break;
    end
  end
  
  if not validEvent then
    return
  end
  
  if (type(callback) == 'function') then
    CM:RegisterCallback(event, callback);
  end
end

setupToolTipHooks();