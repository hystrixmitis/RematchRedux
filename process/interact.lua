local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.interact = {}

local lastInteract -- npcID that was last interacted
local pendingInteract -- if something targeting while mouseover/soft interact, the mode (C.INTERACT_PROMPT) waiting to run

-- priority list of settings if multiple enabled, only first one remains enabled
local interactPriority = {"InteractOnMouseover","InteractOnSoftInteract","InteractOnTarget"}

rematchRedux.events:Register(rematchRedux.interact,"PLAYER_LOGIN",function(self)

    -- subject is npcID, dialog with a target's team(s) and a Load button to load it
    rematchRedux.dialog:Register("PromptToLoadDialog",{
        title = L["Prompt To Load"],
        accept = L["Load"],
        cancel = CANCEL,
        layout = {"Text","MultiTeam"},
        prompt = L["Load this team?"],
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                local name = rematchRedux.utils:GetFormattedTargetName(subject)
                if not name or name==C.CACHE_RETRIEVING then
                    name = L["This target"]
                end
                self.Text:SetText(format(L["%s has a saved team"],name))
                self.MultiTeam:SetTeams(rematchRedux.savedTargets:GetTeams(subject))
            end
        end,
        acceptFunc = function(self,info,subject)
            local teamID = self.MultiTeam:GetTeamID()
            if teamID then
                rematchRedux.interact:LoadTeamID(teamID)
            end
        end
    })

    self:Update()
end)

-- registers/unregisters events based on interact settings
function rematchRedux.interact:Update()

    -- only one interact can be possible at a time; priority mouseover > soft > target
    local foundInteract = false
    for _,var in ipairs(interactPriority) do
        if not settings[var] or foundInteract then
            settings[var] = C.INTERACT_NONE
        elseif settings[var]~=C.INTERACT_NONE then
            foundInteract = true
        end
    end

    -- all interacts register for target changes
    if not foundInteract then
        rematchRedux.events:Unregister(self,"REMATCHREDUX_TARGET_CHANGED")
    else
        rematchRedux.events:Register(self,"REMATCHREDUX_TARGET_CHANGED",self.REMATCHREDUX_TARGET_CHANGED)
    end
    -- register for mouseover interact
    if settings.InteractOnMouseover==C.INTERACT_NONE then
        rematchRedux.events:Unregister(self,"UPDATE_MOUSEOVER_UNIT")
    else
        rematchRedux.events:Register(self,"UPDATE_MOUSEOVER_UNIT",self.UPDATE_MOUSEOVER_UNIT)
    end
    -- register for soft target interact
    if settings.InteractOnSoftInteract==C.INTERACT_NONE then
        rematchRedux.events:Unregister(self,"PLAYER_SOFT_INTERACT_CHANGED")
    else
        rematchRedux.events:Register(self,"PLAYER_SOFT_INTERACT_CHANGED",self.PLAYER_SOFT_INTERACT_CHANGED)
    end
end

-- returns true if something should happen with the given npcID
function rematchRedux.interact:ShouldInteract(npcID)
    if not npcID then
        return false -- not targeting anything, don't interact
    end
    if npcID==lastInteract and not settings.InteractAlways then
        return false -- already interacted with this target, don't interact
    end
    local teams = rematchRedux.savedTargets[npcID]
    if not teams then
        return false -- no teams for this target, don't interact
    end
    if InCombatLockdown() then
        return false -- in combat (can't swap pets in combat), don't interact
    end
    local currentTeamID = settings.currentTeamID
    if settings.InteractAlways then
        local teams,index = rematchRedux.savedTargets:GetTeams(npcID)
        if index and (settings.InteractAlwaysEvenLoaded or teams[index]~=currentTeamID) then
            return true -- if Interact Always enabled and a different team would load, interact
        end
    end
    if currentTeamID and tContains(teams,currentTeamID) then
        return false -- a team for this target is already loaded, don't interact
    end
    -- if we reached here, then there is a target with saved teams not already loaded, we should interact
    return true
end

-- call this instead of rematchRedux.loadTeam:LoadTeamID() so it can handle the post-loading interact options
function rematchRedux.interact:LoadTeamID(teamID)
    if settings.InteractShowAfterLoad and not rematchRedux.frame:IsVisible() then
        rematchRedux.events:Register(self,"REMATCHREDUX_TEAM_LOADED",self.AfterTeamLoaded)
    end
    rematchRedux.loadTeam:LoadTeamID(teamID)
end

-- fired after a team loaded from an interaction; show the preferred window mode (can be Journal, Maximized or Minimized)
function rematchRedux.interact:AfterTeamLoaded()
    if not rematchRedux.frame:IsVisible() and settings.InteractShowAfterLoad then
        local anyInjured = false
        for i=1,3 do
            anyInjured = anyInjured or rematchRedux.petInfo:Fetch((rematchRedux.loadouts:GetLoadoutInfo(i))).isInjured
        end
        if anyInjured or not settings.InteractOnlyWhenInjured then
            rematchRedux.frame:Toggle(true)
            -- if any pets were injured, flash their status
            for slot=1,3 do
                local petInfo = rematchRedux.petInfo:Fetch(rematchRedux.loadouts:GetLoadoutInfo(slot))
                if petInfo.isInjured then
                    if rematchRedux.miniLoadoutPanel:IsVisible() then
                        rematchRedux.miniLoadoutPanel.Loadouts[slot].InjuredFlash:Play()
                    else
                        rematchRedux.loadoutPanel.Loadouts[slot].Pet.InjuredFlash:Play()
                    end
                end
            end
        end
    end
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TEAM_LOADED")
end

-- triggered when InteractOnTarget is not INTERACT_NONE and player's target changes
-- (rematchRedux.targetInfo.currentTarget is the current numeric npcID targeted; nil for no target; nil for a player target)
function rematchRedux.interact:REMATCHREDUX_TARGET_CHANGED()
    local npcID = rematchRedux.targetInfo.currentTarget
    if not rematchRedux.interact:ShouldInteract(npcID) then
        return
    end
    lastInteract = npcID
    if settings.InteractOnTarget==C.INTERACT_PROMPT or pendingInteract==C.INTERACT_PROMPT then
        rematchRedux.dialog:ShowDialog("PromptToLoadDialog",npcID)
    elseif (settings.InteractOnTarget==C.INTERACT_WINDOW or pendingInteract==C.INTERACT_WINDOW) and not rematchRedux.frame:IsVisible() then
        rematchRedux.frame:Toggle(true)
    elseif settings.InteractOnTarget==C.INTERACT_AUTOLOAD or pendingInteract==C.INTERACT_AUTOLOAD then
        local teams,index = rematchRedux.savedTargets:GetTeams(npcID)
        if index and teams[index] then
            rematchRedux.interact:LoadTeamID(teams[index])
        end
    end
    pendingInteract = nil
end

-- triggered when InteractOnMouseover is not INTERACT_DONE and mouseover changes
function rematchRedux.interact:UPDATE_MOUSEOVER_UNIT()
    local npcID = rematchRedux.targetInfo:GetUnitNpcID("mouseover")
    if not rematchRedux.interact:ShouldInteract(npcID) then
        return
    end
    -- special rule for mouseover interact: if current actual target is an npc with a saved team, don't react to mouseover
    -- for cases like darkmoon faire or garrison where multiple targets can be on screen at once
    local currentTarget = rematchRedux.targetInfo.currentTarget
    if currentTarget and rematchRedux.savedTargets[currentTarget] then
        pendingInteract = settings.InteractOnMouseover
        return
    end
    lastInteract = npcID
    if settings.InteractOnMouseover==C.INTERACT_PROMPT then
        rematchRedux.dialog:ShowDialog("PromptToLoadDialog",npcID)
    elseif settings.InteractOnMouseover==C.INTERACT_WINDOW and not rematchRedux.frame:IsVisible() then
        rematchRedux.frame:Toggle(true)
    elseif settings.InteractOnMouseover==C.INTERACT_AUTOLOAD then
        local teams,index = rematchRedux.savedTargets:GetTeams(npcID)
        if index and teams[index] then
            rematchRedux.interact:LoadTeamID(teams[index])
        end
    end
end

function rematchRedux.interact:PLAYER_SOFT_INTERACT_CHANGED(...)
    local npcID = rematchRedux.targetInfo:GetUnitNpcID("softinteract")
    if not rematchRedux.interact:ShouldInteract(npcID) then
        return
    end
    -- special rule for soft interact: if current actual target is an npc with a saved team, don't react to soft interact
    -- for cases like darkmoon faire or garrison where multiple targets can be on screen at once
    local currentTarget = rematchRedux.targetInfo.currentTarget
    if currentTarget and rematchRedux.savedTargets[currentTarget] then
        pendingInteract = settings.InteractOnSoftInteract
        return
    end
    lastInteract = npcID
    if settings.InteractOnSoftInteract==C.INTERACT_PROMPT then
        rematchRedux.dialog:ShowDialog("PromptToLoadDialog",npcID)
    elseif settings.InteractOnSoftInteract==C.INTERACT_WINDOW and not rematchRedux.frame:IsVisible() then
        rematchRedux.frame:Toggle(true)
    elseif settings.InteractOnSoftInteract==C.INTERACT_AUTOLOAD then
        local teams,index = rematchRedux.savedTargets:GetTeams(npcID)
        if index and teams[index] then
            rematchRedux.interact:LoadTeamID(teams[index])
        end
    end
end