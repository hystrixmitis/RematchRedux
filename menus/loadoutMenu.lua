local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.loadoutMenu = {}
local lm = rematchRedux.loadoutMenu

rematchRedux.events:Register(rematchRedux.loadoutMenu,"PLAYER_LOGIN",function(self)

    -- for loadout menus, subect is info={slot=1-3, petID=petID in slot}

    -- menu for the SpecialButton to change the special slot type
    local specialMenu = {
        {title=lm.GetSlotName},
        {text=L["Put Leveling Pet Here"], specialType="leveling", petID=0, hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Stop Leveling This Slot"], specialType="leveling", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Put Random Pet Here"], specialType="random", hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, subMenu="SpecialSubMenu" },
        {text=L["Stop Randomizing This Slot"], specialType="random", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Ignore This Slot"], specialType="ignored", petID="ignored", hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Stop Ignoring This Slot"], specialType="ignored", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=CANCEL},
    }
    rematchRedux.menus:Register("SpecialMenu",specialMenu)

    -- submenu for SpecialMenu is a list of random types
    local specialSubMenu = {
        {text=L["Any Type"], var=0, icon="Interface\\Icons\\INV_Misc_Dice_02", iconCoords={0.075,0.925,0.075,0.925}, petID="random:0", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_1, var=1, icon=lm.GetIcon, petID="random:1", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_2, var=2, icon=lm.GetIcon, petID="random:2", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_3, var=3, icon=lm.GetIcon, petID="random:3", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_4, var=4, icon=lm.GetIcon, petID="random:4", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_5, var=5, icon=lm.GetIcon, petID="random:5", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_6, var=6, icon=lm.GetIcon, petID="random:6", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_7, var=7, icon=lm.GetIcon, petID="random:7", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_8, var=8, icon=lm.GetIcon, petID="random:8", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_9, var=9, icon=lm.GetIcon, petID="random:9", func=lm.SetSpecialSlot },
        {text=BATTLE_PET_NAME_10, var=10, icon=lm.GetIcon, petID="random:10", func=lm.SetSpecialSlot },
    }
    rematchRedux.menus:Register("SpecialSubMenu",specialSubMenu)


    local loadoutMenu = {
        {title=lm.GetPetName},
        {text=L["Put Leveling Pet Here"], specialType="leveling", petID=0, hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Stop Leveling This Slot"], specialType="leveling", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Put Random Pet Here"], specialType="random", hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, subMenu="SpecialSubMenu" },
        {text=L["Stop Randomizing This Slot"], specialType="random", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Ignore This Slot"], specialType="ignored", petID="ignored", hidden=lm.IsSpecialEnabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {text=L["Stop Ignoring This Slot"], specialType="ignored", hidden=lm.IsSpecialDisabled, highlight=lm.IsSpecialEnabled, func=lm.SetSpecialSlot },
        {spacer=8},
        {text=function(self,info) return C_PetJournal.GetSummonedPetGUID()==info.petID and PET_ACTION_DISMISS or SUMMON end, func=function(self,info) C_PetJournal.SummonPetByGUID(info.petID) end},
        {text=L["Set Notes"], func=lm.SetNotes},
        {text=L["Find Similar"], func=lm.FindSimilar},
        {text=L["Find Teams"], isDisabled=function(self,info) local numTeams = rematchRedux.petInfo:Fetch(info.petID).numTeams return not numTeams or numTeams==0 end, func=lm.ListTeams},
        {text=BATTLE_PET_RENAME, func=function(self,info) rematchRedux.dialog:ShowDialog("RenameDialog",info.petID) end},
        {text=function(self,info) return rematchRedux.petInfo:Fetch(info.petID).isFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE end, func=lm.SetFavorite},
        {spacer=8},
        {text=CANCEL},
    }
    rematchRedux.menus:Register("LoadoutMenu",loadoutMenu)

end)

-- returns slot number as a name "Battle Pet Slot 1/2/3"
function rematchRedux.loadoutMenu:GetSlotName(info)
    return format(L["Battle Pet Slot %d"],info.slot)
end

-- returns name of the pet instead of the slot
function rematchRedux.loadoutMenu:GetPetName(info)
    return rematchRedux.petInfo:Fetch(info.petID).name
end

-- self.specialType is either "leveling", "random" or "ignored"
function rematchRedux.loadoutMenu:IsSpecialEnabled(info)
    return rematchRedux.loadouts:GetSpecialSlotType(info.slot)==self.specialType
end

-- self.specialType is either "leveling", "random" or "ignored"
function rematchRedux.loadoutMenu:IsSpecialDisabled(info)
    return rematchRedux.loadouts:GetSpecialSlotType(info.slot)~=self.specialType
end

-- gets the icon for the pet type where self.var is the pet type
function rematchRedux.loadoutMenu:GetIcon()
    if self.var then
        return "Interface\\Icons\\Icon_PetFamily_"..PET_TYPE_SUFFIX[self.var]
    end
end

-- info.slot is the slot to slot the pet, self.petID is either a special petID (0 or "random:8") or nil for a normal pet
local excludePetIDs = {}
function rematchRedux.loadoutMenu:SetSpecialSlot(info)
    if self.petID then
        local specialType = rematchRedux.loadouts:GetSpecialPetIDType(self.petID)
        if specialType=="leveling" then
            rematchRedux.loadouts:SlotPet(info.slot,self.petID)
        elseif specialType=="random" then
            local petType = tonumber(self.petID:match("^random:(%d+)"))
            wipe(excludePetIDs)
            for _,petID in ipairs({rematchRedux.loadouts:GetOtherPetIDs(info.slot)}) do
                excludePetIDs[petID] = true
            end
            local randomPetID = rematchRedux.randomPets:PickRandomPetID({petType=petType,excludePetIDs=excludePetIDs})
            rematchRedux.loadouts:SlotPet(info.slot,randomPetID,self.petID)
        elseif specialType=="ignored" then
            rematchRedux.loadouts:SlotPet(info.slot,self.petID)
        end
    else -- no petID given in menu, this is reverting to a normal slot, get the petID for whatever is slotted
        local petID = C_PetJournal.GetPetLoadOutInfo(info.slot)
        rematchRedux.loadouts:SetSlotPetID(info.slot,petID)
    end
    rematchRedux.queue:Process()
    rematchRedux.frame:Update()
end

function rematchRedux.loadoutMenu:FindSimilar(info)
    local speciesID = rematchRedux.petInfo:Fetch(info.petID).speciesID
    if speciesID then
        rematchRedux.layout:SummonView("pets") -- open pets panel if not already there (maximizes too if needed)
        rematchRedux.filters:SetSimilarFilter(speciesID)
        rematchRedux.filters:ForceUpdate()
        rematchRedux.petsPanel:Update()
    end
end

function rematchRedux.loadoutMenu:SetFavorite(info)
    C_PetJournal.SetFavorite(info.petID,rematchRedux.petInfo:Fetch(info.petID).isFavorite and 0 or 1)
    rematchRedux.filters:ForceUpdate()
    rematchRedux.frame:Update()
end

function rematchRedux.loadoutMenu:SetNotes(info)
    if info.petID then
        rematchRedux.cardManager:ShowCard(rematchRedux.notes,info.petID)
    end
end

function rematchRedux.loadoutMenu:ListTeams(info)
    if info.petID and info.petID:match(C.PET_ID_PATTERN) then
        rematchRedux.layout:SummonView("teams")
        rematchRedux.teamsPanel:SetSearch(info.petID)
    end
end