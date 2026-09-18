local _,rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.saveDialog = {}

rematchRedux.events:Register(rematchRedux.saveDialog,"PLAYER_LOGIN",function(self)

    -- this dialog is used for Save As, Edit Team, and save from target panel
    -- subject = {
    --      saveMode = one of C.SAVE_MODE_EDIT, C.SAVE_MODE_SAVEAS or C.SAVE_MODE_RECEIVE,
    --      teamID = teamID of team being edited (only used on SAVE_MODE_EDIT)
    --      fromOverwrite = true if returning to this from a NameConflict dialog (keep sideline intact)
    -- }
    rematchRedux.dialog:Register("SaveTeam",{
        title = L["Save Team"], -- Saved As, Edit Team, Receiving Team
        accept = SAVE,
        cancel = CANCEL,
        other = RESET,
        width = 290,
        minHeight = 264,
        stayOnOther = true,
        layouts = {
            Default = {"LayoutTabs","Text","ComboBox","GroupSelect","Spacer","TeamWithAbilities","Feedback"},
            GroupPick = {"LayoutTabs","GroupPicker"},
            Targets = {"LayoutTabs","TeamPicker"},
            Preferences = {"LayoutTabs","Text","Line","Preferences","Help"},
            WinRecord = {"LayoutTabs","Text","Line","WinRecord"},
        },
        refreshFunc = rematchRedux.saveDialog.Refresh,
        changeFunc = rematchRedux.saveDialog.OnChange,
        otherFunc = rematchRedux.saveDialog.Reset,
        acceptFunc = rematchRedux.saveDialog.Accept,
    })

    -- this dialog is shown when SaveTeam dialog is accepted when another team shares the chosen name
    -- subject = {
    --      saveMode = saveMode of save dialog before this was summoned
    --      teamID = teamID of save dialog before this was summoned
    --      overwriteID = teamID that the save may overwrite
    -- }
    rematchRedux.dialog:Register("NameConflict",{
        title = L["Overwrite Team"],
        accept = L["New Copy"],
        cancel = CANCEL,
        other = L["Overwrite"],
        layout = {"Text","SmallText","TeamWithAbilities","SmallText2","OtherTeamWithAbilities"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(L["Another team already has this name. Overwrite it or create a new copy?"])
            self.SmallText:SetText(format(L["Old %s"],rematchRedux.utils:GetFormattedTeamName(subject.overwriteID)))
            self.TeamWithAbilities:FillFromTeamID(subject.overwriteID)
            self.SmallText2:SetText(format(L["New %s"],rematchRedux.utils:GetFormattedTeamName("sideline")))
            self.OtherTeamWithAbilities:FillFromTeamID("sideline")
        end,
        cancelFunc = rematchRedux.saveDialog.NameConflictCancel,
        acceptFunc = rematchRedux.saveDialog.NameConflictNewTeam,
        otherFunc = rematchRedux.saveDialog.NameConflictOverwrite,
    })

    -- this dialog is shown when the Save bottombar (not Save As) button is hit and at least one pet has changed
    rematchRedux.dialog:Register("SaveOverwrite",{
        title = L["Saving Loaded Team"],
        prompt = L["Save team?"],
        accept = YES,
        cancel = NO,
        layout = {"Text","SmallText","TeamWithAbilities","SmallText2","OtherTeamWithAbilities"},
        refreshFunc = function(self,info,subject,firstRun) -- subject is teamID being saved
            rematchRedux.dialog:SetTitle(rematchRedux.utils:GetFormattedTeamName(subject))
            self.Text:SetText(L["Pets have changed. Confirm you want to update the team with these new pets."])
            self.SmallText:SetText(L["Update team from this:"])
            self.TeamWithAbilities:FillFromTeamID(subject)
            self.SmallText2:SetText(L["To this:"])
            self.OtherTeamWithAbilities:FillFromTeamID("sideline")
        end,
        acceptFunc = function(self,info,subject)
            rematchRedux.savedTeams[subject] = rematchRedux.savedTeams.sideline
            rematchRedux.saveDialog:BlingLoadedTeam()
        end
    })

    rematchRedux.dialog:Register("SendDialog",{
        title = L["Sending Team"],
        accept = OKAY,
        layout = {"Icon","Spacer","Text","Spacer2"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Icon:SetTexture("Interface\\Icons\\spell_Mekkatorque_bot_redwrench")
            self.Icon:SetTexCoord(0.075,0.925,0.075,0.925)
            self.Text:SetText(L["Not yet implemented\n\nSending teams directly to other RematchRedux users will be added later in the beta."])
        end,
    })

end)

function rematchRedux.saveDialog:BlingTeamIDOrGroupID(data)
    -- if not minimized, open to team panel to teamID and bling it
    if rematchRedux.layout:GetMode()~=0 then
        rematchRedux.savedTeams:TeamsChanged(true) -- prior TeamsChanged were throttled; we need teams to be updated in the group/list before going to it
        rematchRedux.layout:SummonView("teams")
        rematchRedux.teamsPanel.List:ScrollDataIntoView(data)
        rematchRedux.teamsPanel.List:BlingData(data)
    end
end

-- this goes to the teamsPanel if it's not up, scrolls to the team, loads it if not loaded or blings loaded team if loaded
function rematchRedux.saveDialog:LoadAndBlingTeamID(subject)
    rematchRedux.saveDialog:BlingTeamIDOrGroupID(subject.teamID)
    -- minimized or not, load the team just saved unless in edit mode
    if subject.teamID~=settings.currentTeamID and subject.saveMode~=C.SAVE_MODE_EDIT then
        rematchRedux.loadTeam:LoadTeamID(subject.teamID)
    elseif subject.teamID==settings.currentTeamID then -- if we didn't load but team saved is loaded, bling it
        rematchRedux.saveDialog:BlingLoadedTeam()
    end
end

-- blings the loadedTeamPanel and the loadouts
function rematchRedux.saveDialog:BlingLoadedTeam()
    rematchRedux.loadedTeamPanel:BlingTeam()
    if rematchRedux.loadoutPanel:IsVisible() then
        rematchRedux.loadoutPanel:BlingLoadouts()
    elseif rematchRedux.miniLoadoutPanel:IsVisible() then
        rematchRedux.miniLoadoutPanel:BlingLoadouts()
    end
end

-- when NameConflict dialog is cancelled, return to SaveTeam dialog
function rematchRedux.saveDialog:NameConflictCancel(info,subject)
    rematchRedux.dialog:ShowDialog("SaveTeam",{saveMode=subject.saveMode, teamID=subject.teamID, fromOverwrite=true})
end

-- when saving a team that shares a name with another team and user chooses "New Copy", create a uniquely named team
function rematchRedux.saveDialog:NameConflictNewTeam(info,subject)
    -- make name unique
    rematchRedux.savedTeams.sideline.name = rematchRedux.savedTeams:GetUniqueName(rematchRedux.savedTeams.sideline.name)
    -- create a new team
    local team = rematchRedux.savedTeams:Create() -- this will call a TeamsChanged
    subject.teamID = team.teamID
    rematchRedux.saveDialog:LoadAndBlingTeamID(subject)
end

-- when saving a team that shares a name with another team and user chooses "Overwrite", replace with sideline team
function rematchRedux.saveDialog:NameConflictOverwrite(info,subject)
    rematchRedux.events:Fire("REMATCHREDUX_TEAM_OVERWRITTEN",subject.overwriteID,subject.teamID,subject.saveMode)
    if subject.saveMode==C.SAVE_MODE_EDIT then -- in SAVE_MODE_EDIT, delete overwriteID and update teamID with sideline
        rematchRedux.savedTeams[subject.overwriteID] = nil
        rematchRedux.savedTeams[subject.teamID] = rematchRedux.savedTeams.sideline
    else -- SAVE_MODE_SAVEAS/RECEIVE: overwrite overwriteID with sideline
        rematchRedux.savedTeams[subject.overwriteID] = rematchRedux.savedTeams.sideline
        subject.teamID = subject.overwriteID
    end
    rematchRedux.saveDialog:LoadAndBlingTeamID(subject)
end

-- clicking Save on the dialog will either summon an Overwrite dialog or save the team, either to the original teamID or creating a new teamID
-- if sideline name <> original name and sideline name is used by another team: show overwrite dialog; don't save yet
-- elseif edit savemode: save to teamID
-- elseif user teamID and sideline.name = original.name: save to teamID
-- else: save to new team
function rematchRedux.saveDialog:Accept(info,subject)
    if rematchRedux.saveDialog:IsTeamNameUsed() then -- if the team's name will overwrite another, bring up overwrite dialog
        local overwriteID = rematchRedux.savedTeams:GetTeamIDByName(rematchRedux.savedTeams.sideline.name)
        C_Timer.After(0,function() -- need to wait a frame since this accept will close the window after (accept can't run after hide due to resets onhide)
            rematchRedux.dialog:ShowDialog("NameConflict",{saveMode=subject.saveMode, teamID=subject.teamID, overwriteID=overwriteID})
        end)
        return
    elseif subject.saveMode==C.SAVE_MODE_EDIT then
        -- this is editing an existing team; save to same teamID
        assert(rematchRedux.savedTeams:IsUserTeam(subject.teamID),"Editing an invalid teamID: "..(subject.teamID or "nil"))
        rematchRedux.savedTeams[subject.teamID] = rematchRedux.savedTeams.sideline
        rematchRedux.savedTeams:TeamsChanged()
    elseif rematchRedux.savedTeams:IsUserTeam(subject.teamID) and rematchRedux.savedTeams.sideline.name:lower()==rematchRedux.savedTeams.original.name:lower() then
        -- a teamID is used and this is saving back to the original team name; this is a form of edit, save to same teamID
        rematchRedux.savedTeams[subject.teamID] = rematchRedux.savedTeams.sideline
        rematchRedux.savedTeams:TeamsChanged()
    else -- otherwise (not from a loaded team or name has changed) create a new teamID for this new team
        local team = rematchRedux.savedTeams:Create() -- this will call a TeamsChanged
        subject.teamID = team.teamID
    end
    rematchRedux.saveDialog:LoadAndBlingTeamID(subject)
    rematchRedux.queue:Process()
end

-- returns true if the sidelined team is different than the original team name and another team has that name
function rematchRedux.saveDialog:IsTeamNameUsed()
    if rematchRedux.savedTeams.sideline.name:lower()~=rematchRedux.savedTeams.original.name:lower() and rematchRedux.savedTeams:GetTeamIDByName(rematchRedux.savedTeams.sideline.name) then
        return true
    else
        return false
    end
end

function rematchRedux.saveDialog:Refresh(info,subject,firstRun)
    if firstRun then
        rematchRedux.dialog.OtherButton:Disable() -- -- disable Reset button
        self.LayoutTabs:SetTabs({
            {L["Team"],"Default"},
            {L["Targets"],"Targets",function() return rematchRedux.savedTeams.sideline.targets and true or false end, function() rematchRedux.dialog.Canvas.TeamPicker:Clear() end},
            {L["Preferences"],"Preferences",function() return rematchRedux.savedTeams.sideline.preferences and true or false end, function() rematchRedux.dialog.Canvas.Preferences:Set() end},
            {L["Wins"],"WinRecord",function() return rematchRedux.savedTeams.sideline.winrecord and true or false end, function() rematchRedux.dialog.Canvas.WinRecord:Set() end}
        })
        self.CheckButton:SetText(L["Create a new copy of this team"])
        self.Feedback:Set("warning",L["Another team has this name."])
        self.Feedback:SetAlpha(0)
        if subject.saveMode==C.SAVE_MODE_EDIT then
            rematchRedux.dialog:SetTitle(L["Edit Team"])
        elseif subject.saveMode==C.SAVE_MODE_SAVEAS then
            rematchRedux.dialog:SetTitle(L["Save Team"])
        elseif subject.saveMode==C.SAVE_MODE_RECEIVE then
            rematchRedux.dialog:SetTitle(L["Receiving Team"])
        end
        local team = rematchRedux.savedTeams.sideline
        local groupID = team.groupID
        if not groupID or not rematchRedux.savedGroups[groupID] then
            team.groupID = "group:none"
            groupID = "group:none"
        end
        -- name combobox setup
        self.ComboBox:SetLabel(L["Name:"])
        local names = {team.name}
        if team.targets then
            for _,npcID in ipairs(team.targets) do -- add targets for the team to list of names
                rematchRedux.utils:TableInsertDistinct(names,rematchRedux.targetInfo:GetNpcName(npcID),true)
                local questName = rematchRedux.targetInfo:GetQuestName(npcID)
                if questName then
                    rematchRedux.utils:TableInsertDistinct(names,questName,true)
                end
            end
        end
        for _,npcID in ipairs(rematchRedux.targetInfo:GetTargetHistory()) do -- add recent targets to list of names
            rematchRedux.utils:TableInsertDistinct(names,rematchRedux.targetInfo:GetNpcName(npcID),true)
        end
        rematchRedux.utils:TableInsertDistinct(names,L["New Team"]) -- and add a new team as options
        self.ComboBox:SetList(names)
        -- save this initial version in case a reset needed
        if not subject.fromOverwrite then
            rematchRedux.savedTeams.original = rematchRedux.savedTeams.sideline
        end
        -- update controls to sideline
        rematchRedux.saveDialog:UpdateControls("sideline")
        -- when returning from an overwrite, these may be enabled
        self.Feedback:SetAlpha(rematchRedux.saveDialog:IsTeamNameUsed() and 1 or 0)
        rematchRedux.dialog.OtherButton:SetEnabled(not rematchRedux.utils:AreSame(rematchRedux.savedTeams.sideline,rematchRedux.savedTeams.original,true))
        -- set group picker to return to default always in save dialog
        self.GroupPicker:SetReturn("Default")
    end
    -- all that follows happens every refresh (first or not)
    local layout = rematchRedux.dialog:GetOpenLayout()
    if layout=="Default" then
        self.Text:SetText(subject.saveMode==C.SAVE_MODE_RECEIVE and L["Someone sent you a group!"] or " ")
        self.GroupSelect:Fill(rematchRedux.savedTeams.sideline.groupID)
        self.ComboBox:SetTextColor(rematchRedux.utils:HexToRGB(settings.ColorTeamNames and rematchRedux.savedGroups[rematchRedux.savedTeams.sideline.groupID].color or "E8E8E8"))
    elseif layout=="Preferences" then
        self.Text:SetText(L["Leveling Preferences"])
        self.Help:SetText(L["Leveling preferences override which pets are picked first in the leveling queue. All criteria are optional."])
    elseif layout=="WinRecord" then
        self.Text:SetText(L["Battles Won By This Team"])
    end
    self.LayoutTabs:Update()
end

-- updates the dialog's contents from a metateam name ("sideline", "original", "temporary", etc.); called in firstRun or a reset
function rematchRedux.saveDialog:UpdateControls(metaTeam)
    local team = rematchRedux.savedTeams[metaTeam]
    local group = rematchRedux.savedGroups[team.groupID]
    local canvas = rematchRedux.dialog.Canvas

    canvas.TeamWithAbilities:FillFromTeamID(metaTeam)
    canvas.ComboBox:SetText(team.name)
    canvas.ComboBox:SetTextColor(rematchRedux.utils:HexToRGB(settings.ColorTeamNames and group.color or "E8E8E8"))
    canvas.GroupSelect:Fill(team.groupID)
    canvas.Preferences:Set(team.preferences or {})
    canvas.WinRecord:Set(team.winrecord or {})
    local targetList = {}
    if team.targets then -- targets are stored as numeric npcIDs, lists need a string target:npcID
        for _,npcID in ipairs(team.targets) do
            tinsert(targetList,"target:"..npcID)
        end
    end
    canvas.TeamPicker:SetList(C.LIST_TYPE_TARGET,targetList)
end

-- resets the save dialog to its original state
function rematchRedux.saveDialog:Reset()
    rematchRedux.savedTeams.sideline = rematchRedux.savedTeams.original -- copy original team back to sideline
    rematchRedux.saveDialog:UpdateControls("original") -- update dialog controls to original team
    rematchRedux.dialog.Canvas.LayoutTabs:GoToTab("Default")
end

-- any changes also changes the sidelined team
function rematchRedux.saveDialog:OnChange(info,subject)
    local sideline = rematchRedux.savedTeams.sideline
    sideline.name = self.ComboBox:GetText():trim()
    -- if another team (other than one originally picked) has the same name, show warning
    self.Feedback:SetAlpha(rematchRedux.saveDialog:IsTeamNameUsed() and 1 or 0)
    -- capture any potential changes in targets tab
    local targetList = self.TeamPicker:GetList()
    if #targetList>0 then
        if not sideline.targets then
            sideline.targets = {}
        end
        wipe(sideline.targets)
        for _,targetID in ipairs(targetList) do
            local npcID = rematchRedux.targetInfo:GetNpcID(targetID) -- convert target:123 to a numeric npcID 123
            if type(npcID)=="number" then
                tinsert(sideline.targets,npcID)
            end
        end
    else
        sideline.targets = nil
    end
    -- capture any potential changes in preferences tab
    local preferences = self.Preferences:Get()
    if next(preferences) then
        if not sideline.preferences then
            sideline.preferences = {}
        end
        wipe(sideline.preferences)
        for k,v in pairs(preferences) do
            sideline.preferences[k] = v
        end
    else
        sideline.preferences = nil
    end
    -- capture any potential changes in win record tab
    self.WinRecord:Update()
    local winrecord = self.WinRecord:Get()
    if winrecord.battles>0 then
        if not sideline.winrecord then
            sideline.winrecord = {}
        end
        wipe(sideline.winrecord)
        for k,v in pairs(winrecord) do
            sideline.winrecord[k] = v
        end
    else
        sideline.winrecord = nil -- no battles, delete winrecord
    end
    -- update layout tabs highlight for whether it has stuff and show clear button if so
    self.LayoutTabs:Update()
    -- update panel buttons at bottom of dialog
    rematchRedux.dialog.AcceptButton:SetEnabled((sideline.name or ""):trim():len()>0)
    rematchRedux.dialog.OtherButton:SetEnabled(not rematchRedux.utils:AreSame(rematchRedux.savedTeams.sideline,rematchRedux.savedTeams.original,true))
end

-- loads the currently loaded pets and abilities into the sideline
-- if newTeam is true, then it will not use targets/preferences/winrecord/notes of currently loaded team
function rematchRedux.saveDialog:SidelineLoadouts(newTeam)
    rematchRedux.savedTeams:Reset("sideline")
    if settings.currentTeamID=="counter" then -- if sidelining a counter team, use the target's name but otherwise blank
        local npcID = rematchRedux.savedTeams.counter.targets and rematchRedux.savedTeams.counter.targets[1]
        local name = npcID and rematchRedux.targetInfo:GetNpcName(npcID)
        if npcID then -- if a legitimate target, new team will contain the target and name of target
            rematchRedux.savedTeams.sideline.targets = {npcID}
            rematchRedux.savedTeams.sideline.name = rematchRedux.savedTeams:GetUniqueName(name)
        else
            rematchRedux.savedTeams.sideline.name = rematchRedux.savedTeams:GetUniqueName(L["New Team"])
        end
        rematchRedux.savedTeams.sideline.groupID = "group:none"
    elseif not newTeam and rematchRedux.savedTeams:IsUserTeam(settings.currentTeamID) then
        -- if sidelining loadouts with a team loaded, start with a copy of that team
        rematchRedux.savedTeams.sideline = rematchRedux.savedTeams[settings.currentTeamID]
    else -- for a new team, only fill in a name and group
        rematchRedux.savedTeams.sideline.name = rematchRedux.savedTeams:GetUniqueName(L["New Team"])
        rematchRedux.savedTeams.sideline.groupID = "group:none"
    end
    -- next fill in current loadouts
    for slot=1,3 do
        local petID,ability1,ability2,ability3 = rematchRedux.loadouts:GetSlotInfo(slot)
        rematchRedux.savedTeams.sideline.pets[slot] = petID
        rematchRedux.savedTeams.sideline.tags[slot] = rematchRedux.petTags:Create(petID,ability1,ability2,ability3)
    end
end

-- loads a teamID into the sideline (only user teams)
function rematchRedux.saveDialog:SidelineTeamID(teamID)
    assert(rematchRedux.savedTeams:IsUserTeam(teamID),"Attempting to sideline invalid teamID "..(teamID or "nil"))
    rematchRedux.savedTeams:Reset("sideline")
    rematchRedux.savedTeams.sideline = rematchRedux.savedTeams[teamID]
end

-- loads the string for a single team into the sideline
function rematchRedux.saveDialog:SidelineString(teamString)
    rematchRedux.savedTeams:Reset("sideline")
end
