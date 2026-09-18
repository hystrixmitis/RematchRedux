local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.loadedTeamPanel = rematchRedux.frame.LoadedTeamPanel ---@diagnostic disable-line: undefined-field
rematchRedux.frame:Register("loadedTeamPanel")

function rematchRedux.loadedTeamPanel:Update()
    -- if loaded team is not a valid team, unload it
    if settings.currentTeamID and not rematchRedux.savedTeams[settings.currentTeamID] then
        settings.currentTeamID = nil
    end
    local teamID = settings.currentTeamID
    local team = rematchRedux.savedTeams[teamID]
    self.teamID = teamID
    self.TeamButton.teamID = teamID

    local isPetLeveling
    for i=1,3 do
        if rematchRedux.loadouts:GetSpecialSlotType(i)=="leveling" then
            isPetLeveling = true
            break
        end
    end

    -- PreferencesFrame is only shown if Show Extra Preferences Button enabled and a leveling slot is loaded
    if settings.ShowLoadedTeamPreferences and isPetLeveling then
        self.PreferencesFrame:Show()
        self.TeamButton:SetPoint("TOPLEFT",self.PreferencesFrame,"TOPRIGHT",2,0)
        if settings.PreferencesPaused then -- if preferences paused, red X version of blue gear icon
            self.PreferencesFrame.PreferencesButton:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\badges-borderless",0.87890625,0.99609375,0.12890625,0.24609375)
        else -- preferences are not paused, regular blue gear icon
            self.PreferencesFrame.PreferencesButton:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\badges-borderless",0.75390625,0.87109375,0.12890625,0.24609375)
        end
    else
        self.PreferencesFrame:Hide()
        self.TeamButton:SetPoint("TOPLEFT")
    end

    if teamID=="loadonly" then -- for loadonly, display notes only if team has notes
        if rematchRedux.savedTeams.loadonly.notes then
            self.NotesFrame:Show()
            self.NotesFrame.NotesButton:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\badges-borderless",0.62890625,0.74609375,0.12890625,0.24609375)
            self.TeamButton:SetPoint("TOPRIGHT",self.NotesFrame,"TOPLEFT",-2,0)
        else
            self.NotesFrame:Hide()
            self.TeamButton:SetPoint("TOPRIGHT")
        end
        self.TeamButton.Name:SetText(rematchRedux.savedTeams.loadonly.name)
        self.TeamButton.Favorite:Hide()
    elseif teamID=="counter" then -- for counter, name team after target it's countering (if applicable)
        self.NotesFrame:Hide()
        self.TeamButton:SetPoint("TOPRIGHT")
        local name
        if team.targets and #team.targets==1 then -- this is a counter of a specific target
            name = format(L["Counter to %s"],rematchRedux.utils:GetFormattedTargetName(team.targets[1]))
        else
            name = rematchRedux.utils:GetFormattedTeamName(teamID) or BATTLE_PET_SLOTS
        end
        self.TeamButton.Name:SetText(name)
        self.TeamButton.Favorite:Hide()
    elseif teamID then -- this is likely a user team
        -- NotesFrame is always shown if a team is loaded
        self.NotesFrame:Show()
        if rematchRedux.savedTeams[teamID].notes then -- team has notes, show normal note icon
            self.NotesFrame.NotesButton:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\badges-borderless",0.62890625,0.74609375,0.12890625,0.24609375)
        else -- team doesn't have notes, show the icon with green + symbol to add a note
            self.NotesFrame.NotesButton:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\badges-borderless",0.25390625,0.37109375,0.62890625,0.74609375)
        end
        self.TeamButton:SetPoint("TOPRIGHT",self.NotesFrame,"TOPLEFT",-2,0)
        self.TeamButton.Name:SetText(rematchRedux.utils:GetFormattedTeamName(teamID))
        self.TeamButton.Favorite:SetShown(team.favorite and true or false)
    else -- no team is loaded
        self.NotesFrame:Hide()
        self.TeamButton:SetPoint("TOPRIGHT")
        self.TeamButton.Name:SetText(BATTLE_PET_SLOTS)
        self.TeamButton.Favorite:Hide()
    end
end

function rematchRedux.loadedTeamPanel:BlingTeam()
    self:Update()
    self.TeamButton.Bling:Show()
end

function rematchRedux.loadedTeamPanel:OnShow()
    rematchRedux.events:Register( self,"REMATCHREDUX_TEAM_LOADED",self.BlingTeam )
end

function rematchRedux.loadedTeamPanel:OnHide()
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TEAM_LOADED")
end

--[[ TeamButton]]

function rematchRedux.loadedTeamPanel.TeamButton:OnEnter()
    rematchRedux.textureHighlight:Show(self.Back)
    if not settings.HideTruncatedTooltips and self.Name:IsTruncated() then
        rematchRedux.tooltip:ShowSimpleTooltip(self,nil,self.Name:GetText() or "","BOTTOM",self.Name,"TOP",0,-4,true)
    end
end

function rematchRedux.loadedTeamPanel.TeamButton:OnLeave()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.tooltip:Hide()
end

function rematchRedux.loadedTeamPanel.TeamButton:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function rematchRedux.loadedTeamPanel.TeamButton:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematchRedux.textureHighlight:Show(self.Back)
    end
end

function rematchRedux.loadedTeamPanel.TeamButton:OnClick(button)
    if button=="RightButton" and self.teamID then
        rematchRedux.menus:Show("LoadedTeamMenu",self,self.teamID,"cursor")
    elseif self.teamID then
        -- if reloading a random counter team, update team with a new set of random pets
        if self.teamID=="counter" then
            -- if no recent target, use the one saved in the last counter team, if any (it's ok if nil; a full random chosen then)
            local npcID = rematchRedux.targetInfo.recentTarget or (rematchRedux.savedTeams.counter.targets and rematchRedux.savedTeams.counter.targets[1])
            rematchRedux.randomPets:BuildCounterTeam(npcID)
        end
        rematchRedux.loadTeam:LoadTeamID(self.teamID)
    end
end

--[[ NotesFrame ]]

function rematchRedux.loadedTeamPanel.NotesFrame.NotesButton:OnEnter()
    rematchRedux.cardManager:OnEnter(rematchRedux.notes,self,self:GetParent():GetParent().teamID)
end

function rematchRedux.loadedTeamPanel.NotesFrame.NotesButton:OnLeave()
    rematchRedux.cardManager:OnLeave( rematchRedux.notes )
end

function rematchRedux.loadedTeamPanel.NotesFrame.NotesButton:OnClick(button)
    local teamID = self:GetParent():GetParent().teamID
    rematchRedux.cardManager:OnClick(rematchRedux.notes,self,teamID)
    if teamID and rematchRedux.savedTeams[teamID] and not rematchRedux.savedTeams[teamID].notes then
        rematchRedux.notes:SetFocus() -- if no existing notes, set focus to start writing new one
    end
end

--[[ PreferencesFrame ]]

function rematchRedux.loadedTeamPanel.PreferencesFrame.PreferencesButton:OnEnter()
    rematchRedux.tooltip:ShowSimpleTooltip(self,L["Leveling Preferences"],rematchRedux.preferences:GetTooltipBody())
end

function rematchRedux.loadedTeamPanel.PreferencesFrame.PreferencesButton:OnLeave()
    rematchRedux.tooltip:Hide()
end

function rematchRedux.loadedTeamPanel.PreferencesFrame.PreferencesButton:OnClick(button)
    if button=="RightButton" then -- right click pauses/unpauses preferences
        rematchRedux.preferences:TogglePause()
    else -- left click opens current preferences dialog to change preferences
        local teamID = settings.currentTeamID
        local groupID = teamID and rematchRedux.savedTeams[teamID] and rematchRedux.savedTeams[teamID].groupID
        rematchRedux.dialog:ToggleDialog("CurrentPreferences",{teamID=teamID,groupID=groupID})
    end
end
