local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings

rematchRedux.teamTabs = rematchRedux.frame.TeamTabs
rematchRedux.frame:Register("teamTabs")

rematchRedux.events:Register(rematchRedux.teamTabs,"PLAYER_LOGIN",function(self)
    self.Tabs = {}
    for i=1,C.MAX_TEAM_TABS+1 do
        self.Tabs[i] = CreateFrame("Button",nil,self,"RematchReduxTeamTabTemplate")
        self.Tabs[i]:SetPoint("TOPLEFT",0,-(i-1)*44)
    end
    self.GlowTab.Animation:Play()
end)

function rematchRedux.teamTabs:Configure()
    self:SetShown(rematchRedux.layout:GetMode()~=0 and (settings.AlwaysTeamTabs or rematchRedux.layout:GetView()=="teams") and not settings.NeverTeamTabs)
end

function rematchRedux.teamTabs:Update()
    local numTabs = rematchRedux.savedGroups:GetNumTeamTabs()
    local tabIndex = 1
    for _,groupID in ipairs(settings.GroupOrder) do
        local group = rematchRedux.savedGroups[groupID]
        if group and group.showTab then
            if tabIndex <= C.MAX_TEAM_TABS then
                self.Tabs[tabIndex].Icon:SetTexture(group.icon)
                self.Tabs[tabIndex]:Show()
                self.Tabs[tabIndex].groupID = groupID
                tabIndex = tabIndex + 1
            else
                group.showTab = nil -- more than max number of tabs want to be shown; turn off rest of tabs
            end
        end
    end
    -- if space permits, add the yellow + tab to create a new tab/group
    if tabIndex < C.MAX_TEAM_TABS+1 and settings.ShowNewGroupTab then
        -- last tab is the yellow + to create a new tab/group
        self.Tabs[tabIndex].Icon:SetTexture(C.NEW_TAB_ICON)
        self.Tabs[tabIndex].groupID = nil
        self.Tabs[tabIndex]:Show()
        tabIndex = tabIndex + 1
    end
    -- hide remaining tabs
    for i=tabIndex,#self.Tabs do
        self.Tabs[i]:Hide()
    end
    -- scale the tabs depending on number of them
    local numTabs = rematchRedux.savedGroups:GetNumTeamTabs() -- in case any were dropped
    local scale, yoff
    if numTabs<=11 then
        scale,yoff = 1,-64
    elseif numTabs==12 then
        scale,yoff = 1,-24
    elseif numTabs==13 then
        scale,yoff = 0.9,-42
    elseif numTabs==14 then
        scale,yoff = 0.85,-32
    else
        scale,yoff = 0.8,-32
    end
    self:SetScale(scale)
    self:SetPoint("TOPLEFT",rematchRedux.frame,"TOPRIGHT",-1,yoff)
    self:SetHeight((numTabs+1)*44)
end