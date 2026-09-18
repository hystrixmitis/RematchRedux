local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings

--[[
    *** Commands documented for end users ***
    *
    * /rematchredux               : no arguments, toggles the RematchRedux window
    * /rematchredux <team name>   : loads a team of the given name; if <team name> is not found, a message is printed to chat
    *
    * /redux can also be used as a shortcut for /rematchredux
    *
    *** End commands documented for end users ***

    **********************************************************************************************************
    *
    * HERE BE DRAGONS AND NOT GOOD ONES LIKE ALEXSTRASZA!
    *
    * The following commands are for development/testing purposes and are not documented in the UI.
    *
    * THEY ARE NOT FOR END USERS. They are for addon developers and testers and may be removed or changed at any time.
    *
    * IF YOU RUN THESE COMMANDS BECAUSE YOU READ THEM IN THE SOURCE CODE, YOU ARE ON YOUR OWN. YOU WILL LOSE ALL OF YOUR TEAMS, 
    * SETTINGS, AND/OR DATA. BACKUPS WILL BE YOUR ONLY HOPE. OBI-WAN WILL NOT BE ABLE TO HELP YOU.
    *
    * YOU HAVE BEEN WARNED.
    *
    * /rematchredux targetdata        : generates data for a new target to add to targetData.lua
    * /rematchredux delete all teams  : wipes all teams and groups
    * /rematchredux reset everything  : wipes all settings, teams, groups, etc. and restores addon to initial state
    * /rematchredux import options    : show a dialog to reset options and update to the ones provided
    *
    **********************************************************************************************************
]]

SLASH_REMATCHREDUX1 = "/rematchredux"
SLASH_REMATCHREDUX2 = "/redux"

SlashCmdList["REMATCHREDUX"] = function(msg)
    msg = (msg or ""):trim():lower()

    -- "/rematchredux" with no other command will toggle the RematchRedux window
    if msg == "" then
        rematchRedux.frame:Toggle()
        return
    end

    -- "/rematchredux <team name>" will attempt to load a team (if <team name> found)
    if rematchRedux.loadTeam:LoadTeamByName(msg) then
        return -- if LoadTeamByName found a teamID, then it's loading; leave
    end

    -- "/rematchredux reset everything" will wipe all settings with a dialog prompt to confirm
    if msg == "reset everything" then
        rematchRedux.dialog:Register("ResetEverything",{
            title = L["Reset Everything"],
            accept = YES,
            cancel = NO,
            prompt = L["Reset everything?"],
            layout = {"Icon","Text","Feedback"},
            refreshFunc = function(self,info,subject,firstRun)
                self.Icon:SetTexture("Interface\\ICONS\\Ability_Creature_Cursed_02")
                self.Icon:SetTexCoord(0.075,0.925,0.075,0.925)
                self.Text:SetText(L["This will wipe all settings, teams, queue, etc (absolutely everything), and then reload the UI to start RematchRedux from scratch."])
                self.Feedback:Set("warning",L["Warning: This cannot be undone!"])
            end,
            acceptFunc = function(self,info,subject)
                wipe(RematchReduxSettings)
                wipe(RematchReduxSavedTeams)
                wipe(RematchReduxSavedGroups)
                wipe(RematchReduxSavedTargets)
                ReloadUI()
            end
        })
        rematchRedux.dialog:ShowDialog("ResetEverything")
        return
    end

    -- "/rematchredux delete all teams" will wipe all teams and groups with a dialog prompt to confirm
    if msg == "delete all teams" then
        rematchRedux.dialog:Register("DeleteAllTeams",{
            title = L["Delete All Teams"],
            accept = YES,
            cancel = NO,
            prompt = L["Delete all teams?"],
            layout = {"Icon","Text","Feedback"},
            refreshFunc = function(self,info,subject,firstRun)
                self.Icon:SetTexture("Interface\\ICONS\\Ability_Creature_Cursed_02")
                self.Icon:SetTexCoord(0.075,0.925,0.075,0.925)
                self.Text:SetText(format(L["This will wipe all teams and groups.\n\nAre you sure you want to %sDELETE\124r all teams and groups permanently?"],C.HEX_WHITE))
                self.Feedback:Set("warning",L["Warning: This cannot be undone!"])
            end,
            acceptFunc = function(self,info,subject)
                rematchRedux.savedTeams:Wipe()
                rematchRedux.savedGroups:Wipe()
            end,
        })
        rematchRedux.dialog:ShowDialog("DeleteAllTeams")
        return
    end

    -- "/rematchredux targetdata" will create a new entry for new targets, to add to targetData.lua.
    -- To use: Target the target and enter battle (it's ok if you lose target, just don't target
    -- anything else) and once you're in battle and see opponent pets, enter "/rematchredux targetdata"
    if msg == "targetdata" then
        if not C_PetBattles.IsInBattle() or not rematchRedux.targetInfo.recentTarget then
            rematchRedux.utils:Write(L["Usage: Target an npc to create data for, enter a pet battle, and once in battle with opponent pets displayed, enter:\n\124cffffffff/rematchredux targetdata"])
            return
        end
        local npcID = rematchRedux.targetInfo.recentTarget
        local npcName = rematchRedux.targetInfo:GetNpcName(npcID)
        local mapID = C_Map.GetBestMapForUnit("player")
        local mapName = C_Map.GetMapInfo(mapID).name
        -- start with map and npcID; 0 is expansion that needs filled in manually, nill is questID
        -- (if the target is in a subzone and a parent mapID should be used, use first mapID for parent)
        local result = format("{%d,%d,%d,0,nil,",mapID,npcID,mapID)
        -- add pets with their stats
        local numPets = C_PetBattles.GetNumPets(Enum.BattlePetOwner.Enemy)
        for i=1,numPets do
            local petInfo = rematchRedux.petInfo:Fetch("battle:2:"..i)
            local speed = petInfo.speed
            if speed and petInfo.petType==3 then -- for flying opponents remember to get stats before it loses racial
                speed = speed/1.5
            end
            if petInfo.speciesID then
                result=result..format("\"battlepet:%d:%d:%d:%d:%d:%d\"%s",petInfo.speciesID,petInfo.level,petInfo.rarity and petInfo.rarity-1 or 0,petInfo.health,petInfo.power,speed or 0,i<numPets and "," or "")
            end
        end
        -- close off line
        result = result..format("}, -- %s, %s",mapName,npcName)
        -- send result to TinyPad if enabled
        if TinyPad then
            TinyPad.Insert(result)
        else -- otherwise print to chat
            rematchRedux.utils:Write(result)
            -- ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox)
            -- DEFAULT_CHAT_FRAME.editBox:Insert(result)
        end
        return
    end

    -- "/rematchredux import options" will show a dialog to reset options and update to the ones provided
    if msg == "import options" then
        rematchRedux.dialog:ShowDialog("ImportOptions")
        return
    end

    -- if reached here, the msg didn't resolve to a team or anything meaningful
    rematchRedux.utils:Write(format(L["The team named \"%s\" can't be found."],msg))

end
