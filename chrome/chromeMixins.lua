local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings

--[[ Panel Tabs ]]

RematchReduxPanelTabMixin = {}

function RematchReduxPanelTabMixin:OnLoad()
    self.isSelected = false
    self:Update()
end

function RematchReduxPanelTabMixin:OnEnter()
    self.Highlight:Show()
    self.Text:SetTextColor(1,1,1)
end

function RematchReduxPanelTabMixin:OnLeave()
    self.Highlight:Hide()
    if self.isSelected then
        self.Text:SetTextColor(1,1,1)
    else
        self.Text:SetTextColor(1,0.82,0)
    end
end

function RematchReduxPanelTabMixin:OnMouseDown()
    self.Highlight:Hide()
    self.isDown = true
    self:Update()
end

function RematchReduxPanelTabMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        self.Highlight:Show()
    end
    self.isDown = false
    self:Update()
end

-- Top = tabs flipped to top of dialog; Selected = current active tab; Down = mouse is down on the tab
-- {anchor,left,right,top,bottom,yoff}
local tabLayouts = {
    Top =    {Selected =   {Down = {"BOTTOMLEFT",0,0.53125,0.328125,0,6},
                            Up =   {"BOTTOMLEFT",0,0.53125,0.328125,0,4}},
              Unselected = {Down = {"BOTTOMLEFT",0,0.53125,0.703125,0.375,1},
                            Up =   {"BOTTOMLEFT",0,0.53125,0.703125,0.375,-1}}},
    Bottom = {Selected =   {Down = {"TOPLEFT",0,0.53125,0,0.328125,-5},
                            Up =   {"TOPLEFT",0,0.53125,0,0.328125,-3}},
              Unselected = {Down = {"TOPLEFT",0,0.53125,0.375,0.703125,0},
                            Up =   {"TOPLEFT",0,0.53125,0.375,0.703125,2}}}
}

function RematchReduxPanelTabMixin:Update()
    local layout = tabLayouts[self.isTopTab and "Top" or "Bottom"][self.isSelected and "Selected" or "Unselected"][self.isDown and "Down" or "Up"]
    local anchor,left,right,top,bottom,yoff = layout[1],layout[2],layout[3],layout[4],layout[5],layout[6]
    if self.anchor~=anchor then -- don't reanchor textures every update, just when it's moving from bottom to top or vice versa
        self.anchor = anchor
        self.Back:ClearAllPoints()
        self.Highlight:ClearAllPoints()
        self.Back:SetPoint(anchor)
        self.Highlight:SetPoint(anchor)
    end
    if self.isSelected or self.isDown or self:IsMouseMotionFocus() then
        self.Text:SetTextColor(1,1,1)
    else
        self.Text:SetTextColor(1,0.82,0)
    end
    self.Back:SetTexCoord(left,right,top,bottom)
    self.Highlight:SetTexCoord(left,right,top,bottom)
    self.Text:SetPoint("CENTER",0,yoff)
end

--[[ Team Tabs ]]

RematchReduxTeamTabMixin = {}

function RematchReduxTeamTabMixin:OnEnter()
    rematchRedux.textureHighlight:Show(self.Icon,self.Background)
    local group = self.groupID and rematchRedux.savedGroups[self.groupID]
    if group then
        local numTeams = group.teams and #group.teams or 0
        rematchRedux.tooltip:ShowSimpleTooltip(self,rematchRedux.utils:GetFormattedGroupName(self.groupID),format(L["%s%d %s"],C.HEX_WHITE,numTeams,numTeams==1 and L["Team"] or L["Teams"]))
    end
    if self.groupID and rematchRedux.dragFrame:GetCursorInfo()==C.CURSOR_TYPE_TEAM then
        rematchRedux.teamTabs.GlowTab:SetPoint("TOPLEFT",self,"TOPLEFT")
        rematchRedux.teamTabs.GlowTab:Show()
    end
end

function RematchReduxTeamTabMixin:OnLeave()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.tooltip:Hide()
    rematchRedux.teamTabs.GlowTab:Hide()
end

function RematchReduxTeamTabMixin:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxTeamTabMixin:OnMouseUp(button)
    if self:IsMouseMotionFocus() then
        rematchRedux.textureHighlight:Show(self.Icon,self.Background)
    end
end

function RematchReduxTeamTabMixin:OnClick(button)
    if rematchRedux.dragFrame:GetCursorInfo() then -- if either team or group on cursor
        if self.groupID and rematchRedux.dragFrame:GetCursorInfo()==C.CURSOR_TYPE_TEAM then -- but only handle teams (can't drop groups on tabs)
            rematchRedux.dragFrame:HandleReceiveDrag(self)
        else
            rematchRedux.dragFrame:ClearCursor() -- group is on cursor, clear it off cursor
        end
        return
    elseif button=="RightButton" and self.groupID then
        rematchRedux.dialog:Hide()
        rematchRedux.menus:Show("GroupMenu",self,self.groupID,"cursor")
    elseif self.groupID and rematchRedux.savedGroups[self.groupID] then
        -- clicking team tab with a groupID expands that group
        if rematchRedux.layout:GetView()~="teams" then
            rematchRedux.layout:ChangeView("teams") -- go to teams tab if not already there
        end
        local wasSearching = rematchRedux.teamsPanel.List:IsSearching()
        -- team tabs should collapse if they're expanded and in view
        if rematchRedux.teamsPanel.List:IsHeaderExpanded(self.groupID) and rematchRedux.teamsPanel.List:IsDataInView(self.groupID) then
            rematchRedux.teamsPanel.List:ToggleHeader(self.groupID)
        else -- otherwise they should be expanded and blinged
            rematchRedux.teamsPanel.List:ExpandHeader(self.groupID,true)
            rematchRedux.teamsPanel.List:BlingData(self.groupID)
        end
        if wasSearching then -- ExpandHeader will forcibly clear search; this resets it cleanly
            rematchRedux.teamsPanel.Top.SearchBox.Clear:Click()
        end
        PlaySound(C.SOUND_HEADER_CLICK)
    elseif not self.groupID then
        -- this is a new group tab, show dialog
        rematchRedux.dialog:ShowDialog("EditGroup",{})
    end
end
