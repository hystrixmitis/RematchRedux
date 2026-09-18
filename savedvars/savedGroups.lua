local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.savedGroups = {}

--[[
    Groups were in settings in previous versions but is now mostly in its own savedvar RematchReduxSavedGroups.
    (order of groupIDs is still in settings under settings.GroupOrder)

    rematchRedux.savedGroups[groupID] - {
        groupID = "group:0", -- unique identifier of the group (required and persistent)
        name = "",  -- name of the group (required, can be duplicate name)
        icon = "", -- icon for the group (not used right now; may come back if huge demand)
        color = nil/"FFFFFF", -- hex color value for group text (and teams in this group) or nil to use gold header/white team names
        sortMode = C.GROUP_SORT_WINS/ALPHA/CUSTOM -- sort by win record, by alpha or custom sort
        teams = {teamID,teamID,teamID,etc}, -- order of teams within the group
        preferences = {minHP=0,maxHP=0,etc}, -- preferences for all teams within the group
        isExpanded = true/false, -- whether the group is expanded or not
    }
]]

RematchReduxSavedGroups = {} -- savedvar, unordered table of group definitions indexed by groupID

--[[ local functions ]]

-- returns the first unused groupID to be used as a unique indentifier
local function getNewUniqueGroupID()
    local groupID = 1
    while rematchRedux.savedGroups["group:"..groupID] do
        groupID = groupID + 1
    end
    return "group:"..groupID
end

-- rematchRedux.savedGroups[groupID] will return the savedGroup
local function getter(self,groupID)
    if groupID then
        return RematchReduxSavedGroups[groupID]
    end
end

-- rematchRedux.savedGroups[groupID] = {group} will copy the contents of {group} to rematchRedux.savedGroups[groupID]
local function setter(self,groupID,value)
    if groupID=="group:favorites" or groupID=="group:none" then
        -- never set favorites or ungrouped teams (raw savedvar used when needed)
    elseif groupID and type(value)=="nil" then
        RematchReduxSavedGroups[groupID] = nil -- deleting a group
    elseif groupID and type(groupID)=="string" and type(value)=="table" and value.groupID==groupID then
        RematchReduxSavedGroups[groupID] = CopyTable(value) -- creating a group
    end
end

-- sort function for teams alphabetically: sort by favorite, name and then teamID
local function teamAlphaSort(e1,e2)
    if e1 and not e2 then
        return true
    elseif not e1 and e2 then
        return false
    end
    local team1 = rematchRedux.savedTeams[e1]
    local team2 = rematchRedux.savedTeams[e2]
    if team1 and not team2 then
        return true
    elseif not team1 and team2 then
        return false
    end
    local favorite1 = team1.favorite
    local favorite2 = team2.favorite
    if favorite1 and not favorite2 then
        return true
    elseif not favorite1 and favorite2 then
        return false
    end
    local name1 = (team1.name or ""):lower()
    local name2 = (team2.name or ""):lower()
    if name1~=name2 then
        return name1<name2
    else
        return e1<e2
    end
end

-- sort function for teams by winrecord: sort by favorite, wins, name and then teamID
local function teamWinSort(e1,e2)
    if e1 and not e2 then
        return true
    elseif not e1 and e2 then
        return false
    end
    local team1 = rematchRedux.savedTeams[e1]
    local team2 = rematchRedux.savedTeams[e2]
    if team1 and not team2 then
        return true
    elseif not team1 and team2 then
        return false
    end
    local favorite1 = team1.favorite
    local favorite2 = team2.favorite
    if favorite1 and not favorite2 then
        return true
    elseif not favorite1 and favorite2 then
        return false
    elseif team1.winrecord and not team2.winrecord then
        return true
    elseif not team1.winrecord and team2.winrecord then
        return false
    elseif team1.winrecord and team2.winrecord then
        local wins1 = team1.winrecord.wins or 0
        local wins2 = team2.winrecord.wins or 0
        if settings.AlternateWinRecord then -- sorting by raw wins instead of a calculation
            if wins1~=wins2 then
                return wins1>wins2
            end
        else
            local percent1 = wins1/team1.winrecord.battles
            local percent2 = wins2/team2.winrecord.battles
            if percent1~=percent2 then
                return percent1>percent2
            end
        end
    end
    -- if we reached here, teams are the same, sort by name first and then teamID last
    if team1.name~=team2.name then
        return team1.name<team2.name
    else
        return e1<e2
    end
end

--[[ public functions ]]

-- iterator for groups: for groupID,group in rematchRedux.savedGroups:AllGroups()
function rematchRedux.savedGroups:AllGroups()
    return next, RematchReduxSavedGroups, nil
end

-- creates a new group with the given name (can be same name as another group, it will still be a new separate group)
function rematchRedux.savedGroups:Create(name)
    name = name:trim()
    assert(type(name)=="string" and name:len()>0,"Created group must have a name.")
    local groupID = getNewUniqueGroupID()
    local group = {name=name, groupID=groupID, teams={}, sortMode=C.GROUP_SORT_ALPHA, isExpanded=true}
    rematchRedux.savedGroups[groupID] = group
    tinsert(settings.GroupOrder,groupID) -- add this new group to the group order
    return rematchRedux.savedGroups[groupID]
end

-- deletes a groupID; if andTeams is true, delete teams in the group too
function rematchRedux.savedGroups:Delete(groupID,andTeams)
    if groupID and groupID~="group:favorites" and groupID~="group:none" then
        for teamID,team in rematchRedux.savedTeams:AllTeams() do
            if team.groupID==groupID then
                if andTeams then
                    rematchRedux.savedTeams[teamID] = nil
                else
                    team.groupID = C.UNGROUPED_TEAMS_GROUPID
                end
            end
        end
        rematchRedux.utils:TableRemoveByValue(settings.GroupOrder,groupID)
        rematchRedux.savedGroups[groupID] = nil
        rematchRedux.savedTeams:TeamsChanged()
    end
end

-- returns the groupID of the given name
function rematchRedux.savedGroups:GetGroupIDByName(name)
    for groupID,group in rematchRedux.savedGroups:AllGroups() do
        if name:lower()==group.name:lower() then
            return groupID
        end
    end
end

-- confirms groups are properly set up and fixes any issues (called on login and should be called after a wipe/upgrade)
function rematchRedux.savedGroups:Validate()
    local savedvar = RematchReduxSavedGroups
    if type(savedvar)~="table" then
        RematchReduxSavedGroups = {}
        savedvar = RematchReduxSavedGroups
    end
    local group = savedvar["group:favorites"]
    if not group or group.groupID~="group:favorites" or group.name~=L["Favorite Teams"] then
        savedvar["group:favorites"] = {groupID="group:favorites", name=L["Favorite Teams"], teams={}, icon="Interface\\Icons\\ACHIEVEMENT_GUILDPERK_MRPOPULARITY_RANK2", sortMode=C.GROUP_SORT_ALPHA, isExpanded=true, meta=true}
    end
    local group = savedvar["group:none"]
    if not group or group.groupID~="group:none" then
        savedvar["group:none"] = {groupID="group:none", name=L["Ungrouped Teams"], teams={}, icon="Interface\\Icons\\INV_Pet_BattlePetTraining", sortMode=C.GROUP_SORT_ALPHA, isExpanded=true, meta=true}
    end
    -- validate order
    if type(settings.GroupOrder)~="table" then
        settings.GroupOrder = {}
    end
    -- make sure group:favorites is first
    if not tContains(settings.GroupOrder,"group:favorites") then
        tinsert(settings.GroupOrder,1,"group:favorites") -- insert at top
    end
    -- make sure group:none exists
    if not tContains(settings.GroupOrder,"group:none") then
        tinsert(settings.GroupOrder,2,"group:none") -- insert just below group:favorites
    end
end

-- fills all group.teams with the teams belonging to the group and their order
local teamsInGroups = {} -- lookup table for quickly knowing if a team is in a group
function rematchRedux.savedGroups:Update()

    -- update teamsInGroups for quick lookups to avoid a bazillion tContains running
    for groupID,group in rematchRedux.savedGroups:AllGroups() do
        if not teamsInGroups[groupID] then
            teamsInGroups[groupID] = {}
        else
            wipe(teamsInGroups[groupID])
        end
        if not group.teams then
            group.teams = {}
        end
        for _,teamID in ipairs(group.teams) do
            teamsInGroups[groupID][teamID] = true
        end
    end

    -- put teams in the ordered list group.teams that are not there
    for teamID,team in rematchRedux.savedTeams:AllTeams() do
        local groupID = team.groupID
        -- if team is in a group that doesn't exist, move team to ungrouped teams group
        if not groupID or not rematchRedux.savedGroups[groupID] then
            team.groupID = "group:none"
            groupID = "group:none"
        end
        -- if team is not in group.teams list, add to end
        if not teamsInGroups[groupID][teamID] then
            tinsert(rematchRedux.savedGroups[groupID].teams,teamID)
            teamsInGroups[groupID][teamID] = true
        end
    end

    -- now go through and remove any team that doesn't belong in the group (deleted or moved)
    for groupID,group in rematchRedux.savedGroups:AllGroups() do
        for i=#group.teams,1,-1 do
            local team = rematchRedux.savedTeams[group.teams[i]]
            if not team or team.groupID~=groupID then
                tremove(group.teams,i)
            end
        end
    end

    -- sort all groups that had a change in teams
    for groupID,group in rematchRedux.savedGroups:AllGroups() do
        rematchRedux.savedGroups:Sort(groupID)
    end

    -- turn off showTab on all groups beyond MAX_TEAM_TABS
    local numShownTabs = 0
    for _,groupID in ipairs(settings.GroupOrder) do
        local group = rematchRedux.savedGroups[groupID]
        if group then
            if group.showTab and numShownTabs < C.MAX_TEAM_TABS then
                numShownTabs = numShownTabs + 1
            elseif group.showTab then
                group.showTab = nil -- we've exceeded max tabs that can be shown, turn off showTab on excess groups
            end
        end
    end

end

-- sorts the group.teams in the given groupID based on the group's sortMode:
function rematchRedux.savedGroups:Sort(groupID)
    local group = groupID and rematchRedux.savedGroups[groupID]
    if group then
        if group.sortMode==C.GROUP_SORT_ALPHA then -- sort by name
            table.sort(group.teams,teamAlphaSort)
        elseif group.sortMode==C.GROUP_SORT_WINS then -- sort by win record
            table.sort(group.teams,teamWinSort)
        elseif group.sortMode==C.GROUP_SORT_CUSTOM then -- sort by user's chosen order
            -- do nothing, keep the order
        end
    end
end

-- returns the number of groups with a showTab enabled
function rematchRedux.savedGroups:GetNumTeamTabs()
    local count = 0
    for groupID,group in self:AllGroups() do
        if group.showTab then
            count = count + 1
        end
    end
    return count
end

-- this wipes all groups
function rematchRedux.savedGroups:Wipe()
    RematchReduxSavedGroups = {}
    wipe(settings.GroupOrder)
    wipe(settings.ExpandedGroups)
    rematchRedux.savedGroups:Validate()
    rematchRedux.savedTeams:TeamsChanged()
end

setmetatable(rematchRedux.savedGroups,{__index=getter,__newindex=setter})

-- on login, build out savedGroups structure (make sure this is called first, before savedTeams
-- tries to do anything with savedGroups)
rematchRedux.events:Register(rematchRedux.savedGroups,"PLAYER_LOGIN",function(self)
    rematchRedux.savedGroups:Validate()
    --rematchRedux.savedGroups:Update() -- this is done in savedTeams startup
end)
