local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.targetsPanel = rematchRedux.frame.TargetsPanel ---@diagnostic disable-line: undefined-field
rematchRedux.frame:Register("targetsPanel")

local targetList = {} -- ordered list of all headerIDs and teamIDs to display

rematchRedux.events:Register(rematchRedux.targetsPanel,"PLAYER_LOGIN",function(self)
    self.Top.SearchBox.Instructions:SetText(L["Search Targets"])
    -- setup autoScrollBox
    self.List:Setup({
        allData = targetList,
        normalTemplate = "RematchReduxNormalTeamListButtonTemplate",
        normalFill = self.FillNormal,
        normalHeight = 44,
        compactTemplate = "RematchReduxCompactTeamListButtonTemplate",
        compactFill = self.FillCompact,
        compactHeight = 26,
        isCompact = settings.CompactTargetList,
        headerTemplate = "RematchReduxHeaderTeamListButtonTemplate",
        headerFill = self.FillHeader,
        headerCriteria = self.IsHeader,
        headerHeight = 26,
        placeholderTemplate = "RematchReduxPlaceholderListButtonTemplate",
        placeholderFill = self.FillPlaceholder,
        placeholderCriteria = self.IsPlaceholder,
        placeholderHeight = 26,
        expandedHeaders = settings.ExpandedTargets,
        allButton = self.Top.AllButton,
        searchBox = self.Top.SearchBox,
        searchHit = self.SearchHit,
        onScroll = rematchRedux.menus.Hide,
    })
end)

-- fills otable with recent targets and notable npcs, used for targetList here and dialog's TeamPicker)
function rematchRedux.targetsPanel:PopulateTargetList(otable)
    -- if this list isn't populated yet, then fill it with headers and notable npcIDs (only recent targets ever change)
    local headerID
    if #otable==0 then
        tinsert(otable,"header:Recent Targets")
        tinsert(otable,"placeholder:0") -- only one placeholder ever in otable: "No recent targets"
        for _,info in ipairs(rematchRedux.targetData.notableTargets) do
            if headerID~=info[1] then -- new header found
                tinsert(otable,"header:"..info[1])
                headerID = info[1]
            end
            tinsert(otable,"target:"..info[2])
        end
    end
    -- update recent targets without recreating whole list
    -- first remove previous recent targets
    local index = 2
    while not self:IsHeader(otable[index]) do
        index = index + 1 -- find the index of the header after recent targets
    end
    for i=index-1,2,-1 do
        tremove(otable,i) -- remove everything before the second header and after recent targets header
    end
    -- then add current recent targets
    local history = rematchRedux.targetInfo:GetTargetHistory()
    if #history==0 then
        tinsert(otable,2,"placeholder:0")
    else
        for _,npcID in ipairs(history) do
            tinsert(otable,2,"target:"..npcID)
        end
    end
end

function rematchRedux.targetsPanel:Update()
    self:PopulateTargetList(targetList)
    self.List:Update()
end

function rematchRedux.targetsPanel:OnShow()
    rematchRedux.events:Register(self,"REMATCHREDUX_TARGET_CHANGED",self.REMATCHREDUX_TARGET_CHANGED)
end

function rematchRedux.targetsPanel:OnHide()
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TARGET_CHANGED")
end

function rematchRedux.targetsPanel:REMATCHREDUX_TARGET_CHANGED()
    if UnitExists("target") then
        self:Update() -- recent targets has changed
    end
end

--[[ autoscrollbox functions ]]

function rematchRedux.targetsPanel:FillNormal(targetID)
    self:Fill(targetID)
end

function rematchRedux.targetsPanel:FillCompact(targetID)
    self:Fill(targetID)
end

function rematchRedux.targetsPanel:FillHeader(headerID)
    self:Fill(headerID)
end

function rematchRedux.targetsPanel:FillPlaceholder(placeholderID)
    self.Text:SetText(L["No recent targets"])
end

function rematchRedux.targetsPanel:IsHeader(id)
    return type(id)=="string" and id:match("^header:") and true or false
end

function rematchRedux.targetsPanel:IsPlaceholder(id)
    return type(id)=="string" and id:match("^placeholder:") and true or false
end

-- target search skips recent targets because if the player has less than 3 recents, selecting targets shifts stuff down
-- (if there's demand this can be an option to enable recent search hits)
local skipRecent = true
function rematchRedux.targetsPanel:SearchHit(mask,data)
    if data=="header:Recent Targets" then
        skipRecent = true
    elseif rematchRedux.targetsPanel:IsHeader(data) then
        skipRecent = false
        if rematchRedux.utils:match(mask,rematchRedux.targetInfo:GetHeaderName(data)) then -- only searching name if a header
            return true
        end
    elseif skipRecent then
        -- do nothing if skipping
    elseif not rematchRedux.targetsPanel:IsPlaceholder(data) then
        local npcID = rematchRedux.targetInfo:GetNpcID(data)
        if rematchRedux.utils:match(mask,rematchRedux.targetInfo:GetNpcName(npcID)) then
            return true
        elseif rematchRedux.utils:match(mask,rematchRedux.targetInfo:GetQuestName(npcID)) then
            return true
        end
        -- search for pets that contain the name
        local pets = rematchRedux.targetInfo:GetNpcPets(npcID)
        for _,petID in ipairs(pets) do
            local petInfo = rematchRedux.petInfo:Fetch(petID)
            if rematchRedux.utils:match(mask,petInfo.name) then
                return true
            end
        end
        -- search for team names
        if rematchRedux.savedTargets[npcID] then
            for _,teamID in ipairs(rematchRedux.savedTargets[npcID]) do
                local team = rematchRedux.savedTeams[teamID]
                if rematchRedux.utils:match(mask,team.name) then
                    return true
                end
            end
        end
    end
    return false -- if reached here, not a search hit
end

--[[ list button script handlers ]]

function rematchRedux.targetsPanel.List:HeaderOnClick(button)
    if button~="RightButton" then
        rematchRedux.targetsPanel.List:ToggleHeader(self.headerID)
        PlaySound(C.SOUND_HEADER_CLICK)
    end
end

-- click of target list button
function rematchRedux.targetsPanel.List:TeamOnClick(button)
    if button=="RightButton" and not self.noPickup then -- if right-clicking a target, show menu
        rematchRedux.dialog:Hide()
        rematchRedux.menus:Show("TargetMenu",self,self.targetID,"cursor")
    else
        local npcID = rematchRedux.targetInfo:GetNpcID(self.targetID)
        if npcID then
            rematchRedux.loadedTargetPanel:SetTarget(npcID,true)
            PlaySound(C.SOUND_TEAM_LOAD)
        end
    end
end