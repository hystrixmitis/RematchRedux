local _, rematchRedux = ...
local defaultSettings = rematchRedux.defaultSettings
rematchRedux.settings = {} -- permanently empty shell; never reassigned again

_G.RematchReduxSettings = {} -- actual savedvar

-- eagerly fill any missing defaults once, at ADDON_LOADED
rematchRedux.events:Register(rematchRedux.settings,"ADDON_LOADED",function(self,addon)
    if addon == "RematchRedux" then
        for key,defaultValue in pairs(defaultSettings) do
            if RematchReduxSettings[key] == nil then
                RematchReduxSettings[key] = type(defaultValue) == "table" and CopyTable(defaultValue) or defaultValue
            end
        end
        rematchRedux.events:Unregister(self,"ADDON_LOADED")
    end
end)

-- metatable must remain empty of real settings data for this to reliably work
local function getter(self,key)
    return RematchReduxSettings[key]
end

local function setter(self,key,value)
    RematchReduxSettings[key] = value -- write through to the real savedvar
end
setmetatable(rematchRedux.settings,{__index=getter,__newindex=setter})

-- returns a copy of the defaultSettings (computed once per session)
local copyOfDefaultSettings
function rematchRedux.settings:GetDefaults()
    if not copyOfDefaultSettings then
        copyOfDefaultSettings = CopyTable(defaultSettings)
    end

    return copyOfDefaultSettings
end

-- on login do savedvar maintenance
rematchRedux.events:Register(rematchRedux.settings,"PLAYER_LOGIN",function(self)
    if rematchRedux.settings.ResetFilters then -- if Reset Filters On Login checked, clear filters on login
        rematchRedux.filters:ClearAll()
        if rematchRedux.settings.ResetExceptSearch then -- if Don't Reset Search With Filters, still reset search
            rematchRedux.filters:SetSearch("")
        end
    end
end)
