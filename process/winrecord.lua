local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.winrecord = {}

local playerForfeit -- true when the player forfeits a match

rematchRedux.events:Register(rematchRedux.winrecord,"PLAYER_LOGIN",function(self)
    self:Update() -- register/unregister based on settings
    hooksecurefunc(C_PetBattles,"ForfeitGame",function() playerForfeit=true end) -- watch for player forfeiting match
end)

function rematchRedux.winrecord:Update()
    if settings.AutoWinRecord then
        rematchRedux.events:Register(self,"PET_BATTLE_FINAL_ROUND",self.PET_BATTLE_FINAL_ROUND)
        rematchRedux.events:Register(self,"PET_BATTLE_OPENING_START",self.PET_BATTLE_OPENING_START)
    else
        rematchRedux.events:Unregister(self,"PET_BATTLE_FINAL_ROUND")
    end
end

local function teamAlive(player)
    local numPets = C_PetBattles.GetNumPets(player)
    for i=1,3 do
        local health = C_PetBattles.GetHealth(player,i)
        if health and health>0 and i<numPets then
            return true
        end
    end
    return false
end

function rematchRedux.winrecord:PET_BATTLE_OPENING_START()
    playerForfeit = nil
end

function rematchRedux.winrecord:PET_BATTLE_FINAL_ROUND(winner)
    self.wasInPVP = not C_PetBattles.IsPlayerNPC(Enum.BattlePetOwner.Enemy)

    if settings.AutoWinRecord and (not settings.AutoWinRecordPVPOnly or self.wasInPVP) and rematchRedux.savedTeams:IsUserTeam(settings.currentTeamID) then
        local team = rematchRedux.savedTeams[rematchRedux.settings.currentTeamID]
        if not team.winrecord then
            team.winrecord = {}
        end
        -- when the player doesn't win (and even if opponent forfeits) winner appears to be 2.
        -- if player didn't win, see why they didn't win (could be a draw, could be one side forfeit)
        if winner~=Enum.BattlePetOwner.Ally then
            local allyAlive = teamAlive(Enum.BattlePetOwner.Ally)
            local enemyAlive = teamAlive(Enum.BattlePetOwner.Enemy)

            if allyAlive and enemyAlive then -- if both teams alive, someone forfeit tsk tsk
                if playerForfeit then
                    winner = Enum.BattlePetOwner.Enemy -- player forfeit match in progress, mark as loss
                else
                    winner = Enum.BattlePetOwner.Ally -- opponent likely forfeit match in progress, mark as win
                end
            elseif not allyAlive and not enemyAlive then
                winner = nil -- both teams dead, it was a draw
            else
                winner = Enum.BattlePetOwner.Enemy -- any other reason mark as a loss
            end
        end

        if winner==Enum.BattlePetOwner.Ally then
            team.winrecord.wins = (team.winrecord.wins or 0) + 1
        elseif winner==Enum.BattlePetOwner.Enemy then
            team.winrecord.losses = (team.winrecord.losses or 0) + 1
        else
            team.winrecord.draws = (team.winrecord.draws or 0) + 1
        end
        team.winrecord.battles = (team.winrecord.battles or 0)+ 1

    end
end