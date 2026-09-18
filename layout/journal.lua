local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.journal = {}

local enteringCombat = false

-- PetJournal OnShow if UseDefaultJournal is false, then hide PetJournal and configure RematchRedux in its place with mode 3
-- frame OnHide if attached to journal, then unparent it and show PetJournal

rematchRedux.events:Register(rematchRedux.journal,"PLAYER_LOGIN",function(self)
    if not C_AddOns.IsAddOnLoaded("Blizzard_Collections") then -- if journal isn't already loaded, wait for it to load
        rematchRedux.events:Register(rematchRedux.journal,"ADDON_LOADED",rematchRedux.journal.ADDON_LOADED)
    else -- if for some crazy reason journal is already loaded by another addon, go through the motions of it just being loaded
        rematchRedux.journal:ADDON_LOADED("Blizzard_Collections")
    end
    rematchRedux.events:Register(rematchRedux.journal,"PLAYER_REGEN_DISABLED",rematchRedux.journal.PLAYER_REGEN_DISABLED)
    rematchRedux.events:Register(rematchRedux.journal,"PLAYER_REGEN_ENABLED",rematchRedux.journal.PLAYER_REGEN_ENABLED)

    -- hook of the "Click here to view in journal" on the floating battle pet "tooltip" (itemref) does a search for the species
    -- (there is a speciesID but not a specific petID (battlePetID is 0000etc) to show a pet card)
    FloatingBattlePetTooltip.JournalClick:HookScript("OnClick",function(self)
        if rematchRedux.journal:IsActive() then
            local speciesName = rematchRedux.petInfo:Fetch(self:GetParent().speciesID).speciesName
            if speciesName then
                speciesName = format("\"%s\"",speciesName)
                rematchRedux.petsPanel.Top.SearchBox:SetText(speciesName)
                rematchRedux.filters:SetSearch(speciesName)
                rematchRedux.petsPanel:Update()
            end
        end
    end)

end)

-- rematch can't be on screen in combat; if we're in journal mode and we enter combat, hide rematch and restore default journal
function rematchRedux.journal:PLAYER_REGEN_DISABLED()
    if rematchRedux.journal:IsActive() then
        enteringCombat = true
        rematchRedux.frame:Hide()
        rematchRedux.frame:SetParent(UIParent)
        PetJournal:Show()
        enteringCombat = false
    end
    if PetJournal and PetJournal:IsVisible() then
        rematchRedux.journal.UseRematchReduxCheckButton:Disable()
    end
end

-- if we leave combat while journal on screen, show rematch (go through motions as if journal just shown)
function rematchRedux.journal:PLAYER_REGEN_ENABLED()
    if PetJournal and PetJournal:IsVisible() then
        rematchRedux.journal.UseRematchReduxCheckButton:Enable()
        rematchRedux.journal:PetJournalOnShow() -- go through motions as if journal just shown
    end
end

function rematchRedux.journal:ADDON_LOADED(addon)
    if addon=="Blizzard_Collections" then
        rematchRedux.events:Unregister(rematchRedux.journal,"ADDON_LOADED")
        -- watching for an actual hide of PetJournal isn't sufficient; we want to watch for *intent* to hide;
        -- because rematch will have already hidden it and something may be trying to hide it again
        hooksecurefunc(PetJournal,"Show",rematchRedux.journal.PetJournalOnShow)
        hooksecurefunc(PetJournal,"Hide",rematchRedux.journal.PetJournalOnHide)
        hooksecurefunc(PetJournal,"SetShown",rematchRedux.journal.PetJournalOnSetShown)
        -- but since rematch never hides CollectionsJournal itself, it's okay to watch for an actual hide
        CollectionsJournal:HookScript("OnHide",rematchRedux.journal.PetJournalOnHide)

        -- for both the alert and floating battle pet tooltip (itemref) "Click here to view in journal"
        hooksecurefunc("PetJournal_SelectPet",function(self,petID)
            if rematchRedux.journal:IsActive() then
                -- if any filters/search happening, clear them
                if not rematchRedux.filters:IsAllClear() or not rematchRedux.filters:IsClear("Search") then
                    rematchRedux.filters:ClearAll()
                    local speciesName = rematchRedux.petInfo:Fetch(petID).speciesName
                    local exactSearch = speciesName and '"'..speciesName..'"' or ""
                    rematchRedux.filters:SetSearch(exactSearch)
                    rematchRedux.petsPanel.Top.SearchBox:SetText(exactSearch)
                    rematchRedux.petsPanel:Update()
                end
                -- then scroll to the petID and show its pet card
                rematchRedux.petsPanel.List:ScrollDataIntoView(petID)
                local frame = rematchRedux.petsPanel.List:GetDataFrame(petID)
                if frame then
                    rematchRedux.cardManager:HideCard(rematchRedux.petCard)
                    rematchRedux.cardManager:OnEnter(rematchRedux.petCard,frame,petID)
                    rematchRedux.cardManager:OnClick(rematchRedux.petCard,frame,petID)
                    rematchRedux.petsPanel.List:Select("PetCard",petID)
                end

            end
        end)

        rematchRedux.journal:DisablePriorUseRematchReduxCheckButtons()
        rematchRedux.journal.UseRematchReduxCheckButton = CreateFrame("CheckButton",nil,PetJournal,"RematchReduxCheckButtonTemplate,RematchReduxTooltipScripts")
        local button = rematchRedux.journal.UseRematchReduxCheckButton
        button:SetText(L["RematchRedux"])
        button:SetPoint("LEFT",PetJournalSummonButton,"RIGHT",0,-1)
        button:SetScript("OnClick",function(self)
            self:SetChecked(false) -- this version of the checkbutton is when UseDefaultJournal is true, and always false
            rematchRedux.settings.UseDefaultJournal = false
            rematchRedux.journal.PetJournalOnShow(rematchRedux.journal) -- mimic journal being shown to set everything up
        end)
        button.tooltipTitle = L["Use RematchRedux In Journal"]
        button.tooltipBody = L["Check this to restore RematchRedux to the journal.\n\nYou can always use RematchRedux in its standalone window, accessed via key binding, /rematch command or from the Minimap button if enabled in options."]
    end
end

-- takes over the pet journal by hiding PetJournal and putting rematch in its place
function rematchRedux.journal:PetJournalOnShow()
    rematchRedux.journal:DisablePriorUseRematchReduxCheckButtons()
    if not settings.UseDefaultJournal and not InCombatLockdown() and not enteringCombat then
        PetJournal:Hide()
        rematchRedux.frame:SetParent(CollectionsJournal)
        rematchRedux.frame:SetFrameLevel(CollectionsJournal:GetFrameLevel()+600)
        rematchRedux.frame:Configure(C.JOURNAL)
        rematchRedux.journal.UseRematchReduxCheckButton:Enable()
        rematchRedux.frame:Show()
    elseif InCombatLockdown() or enteringCombat then
        rematchRedux.journal.UseRematchReduxCheckButton:Disable()
    end
end

function rematchRedux.journal:PetJournalOnHide()
    if rematchRedux.journal:IsActive() then
        rematchRedux.frame:Hide()
        rematchRedux.frame:SetParent(UIParent)
    end
end

-- this is the primary way PetJournal is shown/hidden, via CollectionsJournal tabs
function rematchRedux.journal:PetJournalOnSetShown(shown)
    rematchRedux.journal[shown and "PetJournalOnShow" or "PetJournalOnHide"](rematchRedux.journal)
end

-- returns true if the journal is currently taken over by rematch
function rematchRedux.journal:IsActive()
    return CollectionsJournal and rematchRedux.frame:GetParent()==CollectionsJournal
end

-- temporary; to disable rematch 4 and rematch 5old journal Rematch checkbuttons
function rematchRedux.journal:DisablePriorUseRematchReduxCheckButtons()
    -- one-time setup of the Rematch checkbutton beside the summon button to enable rematch
    if _G.UseRematchButton and not _G.UseRematchButton.overriden then -- disable the 4.x Rematch checkbutton beside the summon button
        _G.UseRematchButton:Hide()
        _G.UseRematchButton:HookScript("OnShow",function(self) self:Hide() end)
        _G.UseRematchButton.overriden = true
    end
end
