local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.targetMenu = {}
local tm = rematchRedux.targetMenu

rematchRedux.events:Register(rematchRedux.targetMenu,"PLAYER_LOGIN",function(self)

    -- menu when you right-click a target in the target list
    local targetMenu = {
        {title=tm.GetTargetName},
        {text=L["Edit Target"], func=tm.SetTeams},
        {text=L["Load Random Pets"], func=tm.LoadRandomTeam},
        {text=L["Load Team"], hidden=tm.HasNoTeam, func=tm.LoadSavedTeam, subMenu="TargetLoadTeamMenu", subMenuFunc=tm.BuildLoadTeamSubMenu},
        {text=L["Edit Team"], hidden=tm.HasNoTeam, func=tm.EditSavedTeam, subMenu="TargetEditTeamMenu", subMenuFunc=tm.BuildEditTeamSubMenu},
        {text=CANCEL},
    }
    rematchRedux.menus:Register("TargetMenu",targetMenu)

    -- submenus have just title, subMenuFuncs fill them in
    rematchRedux.menus:Register("TargetEditTeamMenu",{{title=L["Teams"]}})
    rematchRedux.menus:Register("TargetLoadTeamMenu",{{title=L["Teams"]}})

    rematchRedux.dialog:Register("SetTargetTeams",{
        title=L["Edit Target"],
        accept=SAVE,
        cancel=CANCEL,
        width = 290,
        layout={"Text","TeamPicker","Help"},
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                rematchRedux.dialog:SetTitle(rematchRedux.targetInfo:GetNpcName(subject.targetID))
                self.Text:SetText(format(L["These are the teams saved for %s."],rematchRedux.utils:GetFormattedTargetName(subject.targetID)))
                self.Help:SetText(L["The topmost team is the preferred team to load when you interact with this target."])
                self.TeamPicker:SetList(subject.listType,subject.list)
            end
        end,
        acceptFunc = function(self,info,subject)
            local npcID = rematchRedux.targetInfo:GetNpcID(subject.targetID)
            if npcID then
                rematchRedux.savedTargets:Set(npcID,self.TeamPicker:GetList())
                rematchRedux.targetsPanel.List:BlingData(subject.targetID)
            end
        end
    })

end)

function rematchRedux.targetMenu:GetTargetName(npcID)
    return rematchRedux.targetInfo:GetNpcName(npcID)
end

function rematchRedux.targetMenu:SetTeams(targetID)
    local list = {}
    if rematchRedux.savedTargets[targetID] then
        for _,npcID in ipairs(rematchRedux.savedTargets[targetID]) do
            tinsert(list,npcID)
        end
    end
    rematchRedux.dialog:ShowDialog("SetTargetTeams",{targetID=targetID, listType=C.LIST_TYPE_TEAM, list=list})
end

function rematchRedux.targetMenu:LoadRandomTeam(targetID)
    local npcID = rematchRedux.targetInfo:GetNpcID(targetID)
    if npcID then
        rematchRedux.loadedTargetPanel:SetTarget(npcID,true)
    end
    rematchRedux.randomPets:BuildCounterTeam(npcID)
    rematchRedux.loadTeam:LoadTeamID("counter")
end

function rematchRedux.targetMenu:HasNoTeam(targetID)
    return not rematchRedux.savedTargets:GetTeams(targetID)
end

-- BuildLoadTeamSubMenu
-- BuildEditTeamSubMenu

function rematchRedux.targetMenu:BuildTeamSubMenu(targetID,menu,func)
    local def = rematchRedux.menus:GetDefinition(menu)
    -- remove any existing teams
    for i=#def,2,-1 do
        tremove(def,i)
    end
    local teams = rematchRedux.savedTargets:GetTeams(targetID)
    if teams and #teams>0 then
        for _,teamID in ipairs(teams) do
            local name = rematchRedux.utils:GetFormattedTeamName(teamID)
            tinsert(def,{text=name,teamID=teamID,func=func})
        end
    else
        tinsert(def,{text=L["No teams :("]})
    end
    tinsert(def,{text=CANCEL})
    rematchRedux.menus:Register(menu,def)
end

function rematchRedux.targetMenu:BuildLoadTeamSubMenu(targetID)
    rematchRedux.targetMenu:BuildTeamSubMenu(targetID,"TargetLoadTeamMenu",tm.LoadTargetTeam)
end

function rematchRedux.targetMenu:BuildEditTeamSubMenu(targetID)
    rematchRedux.targetMenu:BuildTeamSubMenu(targetID,"TargetEditTeamMenu",tm.EditTargetTeam)
end

function rematchRedux.targetMenu:LoadTargetTeam(targetID)
    rematchRedux.loadTeam:LoadTeamID(self.teamID)
end

function rematchRedux.targetMenu:EditTargetTeam(targetID)
    rematchRedux.teamMenu:EditTeam(self.teamID)
end

-- this loads the preferred teamID for the target (click of Load Team menu button that shows teams submenu)
function rematchRedux.targetMenu:LoadSavedTeam(targetID)
    local teams,index = rematchRedux.savedTargets:GetTeams(targetID)
    if teams and index and teams[index] then
        rematchRedux.loadTeam:LoadTeamID(teams[index])
    end
    rematchRedux.menus:Hide()
end

function rematchRedux.targetMenu:EditSavedTeam(targetID)
    local teams,index = rematchRedux.savedTargets:GetTeams(targetID)
    if teams and index and teams[index] then
        rematchRedux.teamMenu:EditTeam(teams[index])
    end
    rematchRedux.menus:Hide()
end
