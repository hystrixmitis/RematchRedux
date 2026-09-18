local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.bottombar = rematchRedux.frame.BottomBar
rematchRedux.frame:Register("bottombar")

rematchRedux.events:Register(rematchRedux.bottombar,"PLAYER_LOGIN",function(self)
    self.SummonButton:SetText(SUMMON)
    self.FindBattleButton:SetText(FIND_BATTLE)
    self.SaveAsButton:SetText(L["Save As"])
    self.SaveButton:SetText(SAVE)

    self.UseRematchReduxCheckButton:SetText(L["RematchRedux"])
    self.UseRematchReduxCheckButton.tooltipTitle = L["Remove RematchRedux From Journal"]
    self.UseRematchReduxCheckButton.tooltipBody = L["Uncheck this to restore the default pet journal.\n\nYou can still use RematchRedux in its standlone window, accessed via key bindings or the /rematchredux command or from the Minimap button if enabled in options."]

    self.SummonButton.tooltipTitle = SUMMON
    self.SummonButton.tooltipBody = format("%s\n\n%s",BATTLE_PETS_SUMMON_TOOLTIP,L["You can also double-click a pet to summon or dismiss it."])
    self.FindBattleButton.tooltipTitle = FIND_BATTLE
    self.FindBattleButton.tooltipBody = BATTLE_PETS_FIND_BATTLE_TOOLTIP
    self.SaveAsButton.tooltipTitle = L["Save As..."]
    self.SaveAsButton.tooltipBody = L["Save the currently loaded pets to a new team."]
    self.SaveButton.tooltipTitle = SAVE
    self.SaveButton.tooltipBody = L["Quickly save the currently loaded pets and abilities to the loaded team."]
end)

function rematchRedux.bottombar:Configure()
    local mode = rematchRedux.layout:GetMode(C.CURRENT)
    local barWidth = self:GetWidth()
    if mode==3 then -- 3-panel mode: summon and find battle buttons match journal
        self.SummonButton:SetWidth(160)
        self.SummonButton:Show()
        self.SaveButton:SetWidth(140)
        self.SaveAsButton:SetWidth(140)
        self.FindBattleButton:SetWidth(140)
    elseif mode==2 then -- 2-panel mode: fit all four to fit
        local width = barWidth/4
        self.SummonButton:SetWidth(width)
        self.SummonButton:Show()
        self.SaveAsButton:SetWidth(width)
        self.SaveButton:SetWidth(width)
        self.FindBattleButton:SetWidth(width)
    elseif mode==1 then -- 1-panel mode: hide summon button, fit remaining 3 to fit
        local width = barWidth/3
        self.SummonButton:Hide()
        rematchRedux.bottombar.SaveButton:SetWidth(width)
        rematchRedux.bottombar.SaveAsButton:SetWidth(width)
        rematchRedux.bottombar.FindBattleButton:SetWidth(width)
    end
    rematchRedux.bottombar.UseRematchReduxCheckButton:SetShown(mode==3 and rematchRedux.journal:IsActive())
    rematchRedux.bottombar.UseRematchReduxCheckButton:SetChecked(true) -- always checked if journal vieRematchReduxmatch is visible
end

function rematchRedux.bottombar:Update()
    -- update summon/dismiss panel button
    if rematchRedux.petCard:IsVisible() and rematchRedux.cardManager:IsCardLocked(rematchRedux.petCard) then
        local petID = C_PetJournal.GetSummonedPetGUID()
        self.SummonButton:Enable()
        if rematchRedux.petCard.petID==petID then
            self.SummonButton:SetText(PET_DISMISS)
            self.SummonButton.tooltipTitle = PET_DISMISS
        elseif rematchRedux.petInfo:Fetch(rematchRedux.petCard.petID).isOwned then
            self.SummonButton:SetText(BATTLE_PET_SUMMON)
            self.SummonButton.tooltipTitle = BATTLE_PET_SUMMON
        else
            self.SummonButton:Disable()
            self.SummonButton.tooltipTitle = BATTLE_PET_SUMMON
        end
    else
        self.SummonButton:Disable()
        self.SummonButton.tooltipTitle = BATTLE_PET_SUMMON
    end
    -- update find battle button
    if C_PetBattles.GetPVPMatchmakingInfo() then
        self.FindBattleButton:SetText(LEAVE_QUEUE)
    else
        self.FindBattleButton:SetText(FIND_BATTLE)
    end
    -- update save button (only enabled if a user team loaded)
    self.SaveButton:SetEnabled(rematchRedux.savedTeams:IsUserTeam(settings.currentTeamID))
end

function rematchRedux.bottombar:OnShow()
    rematchRedux.events:Register(self,"PET_BATTLE_QUEUE_STATUS",self.PET_BATTLE_QUEUE_STATUS)
    rematchRedux.events:Register(self,"REMATCHREDUX_TEAM_LOADED",self.Update)
end

function rematchRedux.bottombar:OnHide()
    rematchRedux.events:Unregister(self,"PET_BATTLE_QUEUE_STATUS")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TEAM_LOADED")
end

function rematchRedux.bottombar:PET_BATTLE_QUEUE_STATUS()
    rematchRedux.frame:Update() -- need to update loadout slots as well as panel button
end

function rematchRedux.bottombar.SummonButton:OnClick()
    self:GetScript("OnLeave")(self) -- force the mouse to leave to unhighlight
    if rematchRedux.petCard.petID then
        C_PetJournal.SummonPetByGUID(rematchRedux.petCard.petID)
        rematchRedux.petCard:Hide()
    end
end

-- the "Save As" button summons a save dialog to potentially create a new team (if team renamed) or update some aspect of current
function rematchRedux.bottombar.SaveAsButton:OnClick()
    rematchRedux.saveDialog:SidelineLoadouts()
    -- if sidelining a loaded user team, add its teamID to subject
    if rematchRedux.savedTeams:IsUserTeam(settings.currentTeamID) then
        rematchRedux.dialog:ShowDialog("SaveTeam",{saveMode=C.SAVE_MODE_SAVEAS, teamID=settings.currentTeamID})
    else
        rematchRedux.dialog:ShowDialog("SaveTeam",{saveMode=C.SAVE_MODE_SAVEAS})
    end
end

-- the "Save" button resaves the loaded team, potentially from a change in pets or abilities
function rematchRedux.bottombar.SaveButton:OnClick()
    if not rematchRedux.savedTeams:IsUserTeam(settings.currentTeamID) then
        return -- a user team is not loaded, do nothing
    end
    rematchRedux.saveDialog:SidelineLoadouts()
    -- if pets are the same, immediately save the updates to the current team
    if rematchRedux.utils:AreSame(rematchRedux.savedTeams.sideline.pets,rematchRedux.savedTeams[settings.currentTeamID].pets) then
        rematchRedux.savedTeams[settings.currentTeamID] = rematchRedux.savedTeams.sideline
        rematchRedux.saveDialog:BlingLoadedTeam()
    else -- pets are different, confirm the save
        rematchRedux.dialog:ShowDialog("SaveOverwrite",settings.currentTeamID)
    end
end

-- clicking the RematchRedux checkbutton on the bottombar means we're in journal mode; so always disabling.
-- there's another RematchRedux checkbutton on the PetJournal that does the opposite
function rematchRedux.bottombar.UseRematchReduxCheckButton:OnClick()
    self:SetChecked(true)
    rematchRedux.settings.UseDefaultJournal = true
    rematchRedux.frame:Hide()
    rematchRedux.frame:SetParent(UIParent)
    PetJournal:Show()
    PetJournal_UpdatePetLoadOut() -- in case journal wasn't keeping up while RematchRedux was doing stuff
end

function rematchRedux.bottombar.FindBattleButton:OnClick()
    local queueState = C_PetBattles.GetPVPMatchmakingInfo()
    if queueState=="proposal" then
        C_PetBattles.DeclineQueuedPVPMatch()
    elseif queueState then
        C_PetBattles.StopPVPMatchmaking()
    else
        C_PetBattles.StartPVPMatchmaking()
    end
end