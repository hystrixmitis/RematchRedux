local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
rematchRedux.main = {}

local inWorld -- returned by IsPlayerInWorld; true/false if player is in the world (not in a loading screen)

rematchRedux.events:Register(rematchRedux.main,"PLAYER_LOGIN",function(self)
    hooksecurefunc(C_PetJournal,"SetAbility",function(slotIndex,spellIndex,petSpellID)
        rematchRedux.timer:Start(0,rematchRedux.main.FireAbilitiesChanged)
    end)

    hooksecurefunc(C_PetJournal,"SetPetLoadOutInfo",function(slotIndex,petID)
        rematchRedux.timer:Start(0,rematchRedux.main.FireLoadoutsChanged)
    end)

    hooksecurefunc(C_PetJournal,"PickupPet",function(petID)
        rematchRedux.events:Fire("REMATCHREDUX_PET_PICKED_UP_ON_CURSOR",petID)
        rematchRedux.events:Register(rematchRedux.main,"CURSOR_CHANGED",rematchRedux.main.CURSOR_CHANGED)
    end)

    rematchRedux.events:Register(self,"PLAYER_LEAVING_WORLD",self.PLAYER_LEAVING_WORLD)
    rematchRedux.events:Register(self,"PLAYER_ENTERING_WORLD",self.PLAYER_ENTERING_WORLD)
    rematchRedux.events:Register(self,"PET_BATTLE_CLOSE",self.PET_BATTLE_CLOSE)
    rematchRedux.events:Register(self,"UNIT_SPELLCAST_SUCCEEDED",self.UNIT_SPELLCAST_SUCCEEDED)

	-- add launcher button for LDB if it exists
	local ldb = LibStub and LibStub:GetLibrary("LibDataBroker-1.1",true)
	if ldb then
	  ldb:NewDataObject("RematchRedux",{ type="launcher", icon="Interface\\Icons\\PetJournalPortrait", iconCoords={0.075,0.925,0.075,0.925}, tooltiptext=L["Toggle RematchRedux"], OnClick=rematchRedux.frame.Toggle	})
	end

end)

function rematchRedux.main:CURSOR_CHANGED()
    if not rematchRedux.utils:IsPetOnCursor() then
        rematchRedux.events:Fire("REMATCHREDUX_PET_DROPPED_FROM_CURSOR")
        rematchRedux.events:Unregister(rematchRedux.main,"CURSOR_CHANGED")
    end
end

-- called a frame after abilities changed (in case multiple abilities changing at once)
function rematchRedux.main:FireAbilitiesChanged()
    rematchRedux.events:Fire("REMATCHREDUX_ABILITIES_CHANGED")
end

-- called a frame after loadouts changed (in case multiple loadouts changing at once)
function rematchRedux.main:FireLoadoutsChanged()
    rematchRedux.events:Fire("REMATCHREDUX_LOADOUTS_CHANGED")
end

-- returns true if player is not in a loading screen
function rematchRedux.main:IsPlayerInWorld()
    return inWorld
end

function rematchRedux.main:PLAYER_ENTERING_WORLD()
    inWorld = true
end

function rematchRedux.main:PLAYER_LEAVING_WORLD()
    inWorld = false
end

-- post-battle processing: for load healthiest pet and also to process queue
function rematchRedux.main:ProcessHealthChange()
    rematchRedux.main:StopPostBattleTimer()
    if rematchRedux.settings.LoadHealthiest and rematchRedux.settings.LoadHealthiestAfterBattle then
        rematchRedux.loadTeam:AssertHealthiestPet()
    end
    rematchRedux.queue:Process()
end

-- this usually fires in pairs; begin watching for PET_JOURNAL_LIST_UPDATE (health/xp changes) for a little while
-- to do a bit of post-battle processing
function rematchRedux.main:PET_BATTLE_CLOSE()
    rematchRedux.events:Register(self,"PET_JOURNAL_LIST_UPDATE",self.PET_JOURNAL_LIST_UPDATE)
    rematchRedux.timer:Start(C.POST_BATTLE_TIMER,self.StopPostBattleTimer,self)
end

-- fired in the POST_BATTLE_TIMER window (a few seconds), presumably pet health/xp changed
function rematchRedux.main:PET_JOURNAL_LIST_UPDATE()
    rematchRedux.events:Unregister(self,"PET_JOURNAL_LIST_UPDATE")
    rematchRedux.timer:Start(C.QUEUE_PROCESS_WAIT,rematchRedux.main.ProcessHealthChange)
end

-- stops watching for PET_JOURNAL_LIST_UPDATE; called when a pet is slotted too
function rematchRedux.main:StopPostBattleTimer()
    rematchRedux.events:Unregister(self,"PET_JOURNAL_LIST_UPDATE")
end

-- when revive or bandage used to heal pets, trigger a LoadHealthiest bit (if enabled) and process queue
function rematchRedux.main:UNIT_SPELLCAST_SUCCEEDED(unit,cast,spellID)
    if unit=="player" and (spellID==C.REVIVE_SPELL_ID or spellID==C.BANDAGE_SPELL_ID) then
        rematchRedux.timer:Start(C.QUEUE_PROCESS_WAIT,rematchRedux.main.ProcessHealthChange)
    end
end
