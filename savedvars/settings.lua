local _, rematchRedux = ...
local defaultSettings = rematchRedux.defaultSettings
rematchRedux.settings = {}

_G.RematchReduxSettings = {} -- actual savedvar

-- returns a copy of the defaults at the top of this file (only creates one copy for session to reduce overhead)
-- We declare it first so the rematchRedux.settings.GetDefaults assignment operates on the proper table, not a copy of the table. 
-- This is important because the settings table is used to store the actual savedvar, and we want to make sure
-- that the defaults are only used to fill in missing keys, not to overwrite existing keys.

local copyOfDefaultSettings
local function GetDefaults()
    if not copyOfDefaultSettings then
        copyOfDefaultSettings = CopyTable(defaultSettings)
    end
    return copyOfDefaultSettings
end

rematchRedux.events:Register(rematchRedux.settings,"ADDON_LOADED",function(self,addon)
    if addon == "RematchRedux" then
        for key,defaultValue in pairs(defaultSettings) do
            if RematchReduxSettings[key] == nil then
                RematchReduxSettings[key] = type(defaultValue) == "table" and CopyTable(defaultValue) or defaultValue
            end
        end
        rematchRedux.settings = RematchReduxSettings -- same table from here on, not a copy
        rematchRedux.settings.GetDefaults = GetDefaults -- attach now that rematchRedux.settings points at the real table
        rematchRedux.events:Unregister(self,"ADDON_LOADED")
    end
end)

-- on login do savedvar maintenance
rematchRedux.events:Register(rematchRedux.settings,"PLAYER_LOGIN",function(self)
    if rematchRedux.settings.ResetFilters then -- if Reset Filters On Login checked, clear filters on login
        rematchRedux.filters:ClearAll()
        if rematchRedux.settings.ResetExceptSearch then -- if Don't Reset Search With Filters, still reset search
            rematchRedux.filters:SetSearch("")
        end
    end
end)
