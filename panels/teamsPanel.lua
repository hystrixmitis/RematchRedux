local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.teamsPanel = rematchRedux.frame.TeamsPanel ---@diagnostic disable-line: undefined-field
rematchRedux.frame:Register("teamsPanel")

local teamList = {} -- ordered list of all groupIDs and teamIDs to display

rematchRedux.events:Register(rematchRedux.teamsPanel,"PLAYER_LOGIN",function(self)
    self.Top.SearchBox.Instructions:SetText(L["Search Teams"])
    self.Top.TeamsButton:SetText(L["Teams"])

    -- setup autoScrollBox
    self.List:Setup({
        allData = teamList,
        normalTemplate = "RematchReduxNormalTeamListButtonTemplate",
        normalFill = self.FillNormal,
        normalHeight = 44,
        compactTemplate = "RematchReduxCompactTeamListButtonTemplate",
        compactFill = self.FillCompact,
        compactHeight = 26,
        isCompact = settings.CompactTeamList,
        headerTemplate = "RematchReduxHeaderTeamListButtonTemplate",
        headerFill = self.FillHeader,
        headerCriteria = self.IsHeader,
        headerHeight = 26,
        placeholderTemplate = "RematchReduxPlaceholderListButtonTemplate",
        placeholderFill = self.FillPlaceholder,
        placeholderCriteria = self.IsPlaceholder,
        placeholderHeight = 26,
        selects = {
            Loaded = {color={1,0.82,0}, parentKey="Back", padding=0, drawLayer="ARTWORK"},
            Moving = {color={0,0,0,0.65}, tint=true, drawLayer="ARTWORK"}
        },
        expandedHeaders = settings.ExpandedGroups,
        allButton = self.Top.AllButton,
        searchBox = self.Top.SearchBox,
        searchHit = self.SearchHit,
        onScroll = rematchRedux.menus.Hide,
    })

    -- after autoscrollbox setup, hook OnTextChanged to set color if a direct petID being searched
    self.Top.SearchBox:HookScript("OnTextChanged",function(self)
        local text = self:GetText()
        if text and text:match(C.PET_ID_PATTERN) then
            self:SetTextColor(0.5,0.5,0.5) -- searching BattlePet-0-etc; color grey
        else
            self:SetTextColor(1,1,1) -- otherwise set to standard white
        end
    end)

    -- set receive script for autoScrollBox's CaptureButton
    self.List.CaptureButton:SetScript("OnClick",function(self) rematchRedux.dragFrame:HandleReceiveDrag(self) end)

end)

-- wipes and fills the given table with an ordered list of all IDs (used for teamList here and also dialog's TeamPicker)
function rematchRedux.teamsPanel:PopulateTeamList(otable)
    wipe(otable)
    for _,groupID in ipairs(settings.GroupOrder) do
        tinsert(otable,groupID)
        local group = rematchRedux.savedGroups[groupID]
        if group then
            if #group.teams>0 then
                for _,teamID in ipairs(group.teams) do
                    tinsert(otable,teamID)
                end
            else -- if group has no teams, add a placeholder
                tinsert(otable,"placeholder:"..group.groupID)
            end
        end
    end
end

function rematchRedux.teamsPanel:Update()
    rematchRedux.teamsPanel:PopulateTeamList(teamList)
    self.List:Select("Loaded",settings.currentTeamID,true)
    self.List:Update()
end

-- for updating the list visuals (such as loaded team changing) without any data changing
function rematchRedux.teamsPanel:Refresh()
    --self.List:Select("Loaded",C_PetJournal.GetSummonedPetGUID(),true)
    self.List:Refresh()
end

function rematchRedux.teamsPanel:OnShow()
    if self.List.needsRefresh then
        self.List:Refresh()
        self.List.needsRefresh = nil
    end
    rematchRedux.events:Register(self,"REMATCHREDUX_TEAM_LOADED",self.SelectLoadedTeam)
end

function rematchRedux.teamsPanel:OnHide()
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TEAM_LOADED")
end

function rematchRedux.teamsPanel:SelectLoadedTeam()
    self.List:Select("Loaded",settings.currentTeamID)
end

-- click of the Teams button at top of panel
function rematchRedux.teamsPanel.Top.TeamsButton:OnClick()
    rematchRedux.dialog:HideDialog()
    rematchRedux.menus:Toggle("TeamsButtonMenu",self)
end

--[[ autoscrollbox functions ]]

function rematchRedux.teamsPanel:FillHeader(id)
    self:Fill(id)
end

function rematchRedux.teamsPanel:FillPlaceholder(id)
    if id=="placeholder:group:favorites" then
        self.Text:SetText(L["No favorite teams"])
    elseif id=="placeholder:group:none" then
        self.Text:SetText(L["No ungrouped teams"])
    else
        self.Text:SetText(L["No teams in this group"])
    end
end

function rematchRedux.teamsPanel:FillNormal(id)
    self:Fill(id)
end

function rematchRedux.teamsPanel:FillCompact(id)
    self:Fill(id)
end

function rematchRedux.teamsPanel:IsHeader(id)
    return type(id)=="string" and id:match("^group:") and true or false
end

function rematchRedux.teamsPanel:IsPlaceholder(id)
    return type(id)=="string" and id:match("^placeholder:") and true or false
end

-- returns true if data matches the search mask
function rematchRedux.teamsPanel:SearchHit(mask,data)
    if rematchRedux.savedGroups[data] then
        return rematchRedux.utils:match(mask,rematchRedux.savedGroups[data].name)
    else
        local team = rematchRedux.savedTeams[data]
        if team then
            -- we're searching for a specific petID (BattlePet-0-000000000000)
            if mask:match(C.PET_ID_PATTERN) then
                for i=1,3 do
                    if team.pets[i]==mask then
                        return true
                    end
                end
                return false -- didn't find the pet in this team, leave immediately
            end
            -- check if team name matches
            if rematchRedux.utils:match(mask,team.name) then
                return true
            end
            -- check if any pet name matches
            for i=1,3 do
                local petInfo = rematchRedux.petInfo:Fetch(team.pets[i])
                if petInfo.customName and rematchRedux.utils:match(mask,petInfo.customName) then
                    return true
                end
                if petInfo.speciesName then
                    if rematchRedux.utils:match(mask,petInfo.speciesName) then
                        return true
                    end
                else -- species name wasn't found, this is an invalid pet, possibly caged (if a search it, fill will rebuild it)
                    local speciesID = rematchRedux.petTags:GetSpecies(team.tags[i])
                    petInfo = rematchRedux.petInfo:Fetch(speciesID)
                    if petInfo.speciesName and rematchRedux.utils:match(mask,petInfo.speciesName) then
                        return true
                    end
                end
            end
            -- check if any target name matches
            if team.targets then
                for _,targetID in ipairs(team.targets) do
                    local name = rematchRedux.targetInfo:GetNpcName(targetID,true)
                    if rematchRedux.utils:match(mask,name) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

--[[ listbutton script handlers (called from teamListButton.lua mixins) ]]

-- click of group header
function rematchRedux.teamsPanel.List:HeaderOnClick(button)
    if rematchRedux.dragFrame:HandleReceiveDrag(self,button) then
        return -- something was on cursor and was handled
    elseif button=="RightButton" and not self.noPickup then -- if right-clicking a group, show menu
        rematchRedux.dialog:Hide()
        rematchRedux.menus:Show("GroupMenu",self,self.groupID,"cursor")
    else -- otherwise toggle group
        rematchRedux.teamsPanel.List:ToggleHeader(self.groupID)
        PlaySound(C.SOUND_HEADER_CLICK)
    end
end

-- dragging from a group header
function rematchRedux.teamsPanel.List:HeaderOnDragStart()
    if self.groupID and settings.EnableDrag and not self.noPickup then
        rematchRedux.dragFrame:PickupGroup(self.groupID,true)
    end
end

-- click of team list button
function rematchRedux.teamsPanel.List:TeamOnClick(button)
    if rematchRedux.dragFrame:HandleReceiveDrag(self,button) then
        return -- something was on cursor and handled
    elseif button=="RightButton" and not self.noPickup then -- if right-clicking a team, show menu
        rematchRedux.dialog:Hide()
        rematchRedux.menus:Show("TeamMenu",self,self.teamID,"cursor")
    else -- left-click of team loads it
        rematchRedux.loadTeam:LoadTeamID(self.teamID)
        PlaySound(C.SOUND_TEAM_LOAD)
    end
end

-- dragging from a team list button
function rematchRedux.teamsPanel.List:TeamOnDragStart()
    if self.teamID and settings.EnableDrag and not self.noPickup then
        rematchRedux.dragFrame:PickupTeam(self.teamID,true)
    end
end

-- for programmatically setting search, to handle instructions properly
function rematchRedux.teamsPanel:SetSearch(text)
    text = (text or ""):trim()
    self.Top.SearchBox:SetFocus(true)
    self.Top.SearchBox:SetText(text)
    self.Top.SearchBox:ClearFocus()
end
