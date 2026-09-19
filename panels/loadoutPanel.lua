local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.loadoutPanel = rematchRedux.frame.LoadoutPanel ---@diagnostic disable-line: undefined-field
rematchRedux.frame:Register("loadoutPanel")

function rematchRedux.loadoutPanel:Update()
    for i=1,3 do
        local petID,ability1,ability2,ability3,locked = C_PetJournal.GetPetLoadOutInfo(i)

        self.Loadouts[i].petID = petID -- before possibly changing petID to a battle:1:x, save petIDs to loadout/pet button
        self.Loadouts[i].Pet.petID = petID
        if C_PetBattles.IsInBattle() then
            petID = "battle:1:"..i -- if in a pet battle, use the battle petID to get health updates during battle
        end

        self:FillSpecial(self.Loadouts[i],self.Loadouts[i]:GetID()) -- fills back and special badge/button at top of loadout
        self:FillLoadout(self.Loadouts[i],petID) -- fills pet, including name and pet badges
        self.Loadouts[i].AbilityBar:FillAbilityBar(petID,ability1,ability2,ability3) -- fills abilities
        self:FillStatusBars(self.Loadouts[i],petID) -- fills status bars
        self:FillModelScene(self.Loadouts[i],petID) -- fills pet model

        -- hiding ability bar and showing requirements if slot is locked
        self.Loadouts[i].AbilityBar:SetShown(not locked)
        self.Loadouts[i].LockOverlay.RequirementsText:SetShown(locked)
        self.Loadouts[i].LockOverlay.RequirementsLink:SetShown(locked)

        -- showing overlay if either journal or just this slot is locked
        local isJournalLocked = rematchRedux.utils:IsJournalLocked()
        self.Loadouts[i].LockOverlay:SetShown(isJournalLocked or locked)

        -- when slotting a pet, the loadouts are updated; if the mouse is over a loadout when that happens and the pet card
        -- is unlocked and visible, then we need to change pets the card is showing (using the OnEnter to let focus handle it)
        if self.Loadouts[i]:IsMouseOver() and rematchRedux.petCard.petID~=petID and not rematchRedux.cardManager:IsCardLocked(rematchRedux.petCard) then
            local focus = GetMouseFoci()[1]
            if focus and focus.petID then
                focus:GetScript("OnEnter")(focus)
            end
        end
    end
    self.AbilityFlyout:Hide()
    self:UpdateGlow()
end

function rematchRedux.loadoutPanel:UpdateGlow()
    for i=1,3 do
        local showGlow = rematchRedux.utils:IsPetOnCursor()
        if showGlow then
            self.Loadouts[i].Animation:Play()
        else
            self.Loadouts[i].Animation:Stop()
        end
        self.Loadouts[i].Glow:SetShown(showGlow)
    end
end

-- updates background for special types (leveling, random, ignored) and handles special slot badge
function rematchRedux.loadoutPanel:FillSpecial(loadout,slot)
    if rematchRedux.loadouts:IsSlotSpecial(slot) then
        local altID = rematchRedux.loadouts:GetSlotInfo(slot)
        local altInfo = rematchRedux.altInfo:Fetch(altID)
        local color
        if altInfo.idType=="leveling" then
            color = C.LOADOUT_COLOR_LEVELING
            loadout.SpecialButton.tooltipTitle = L["Leveling Pet"]
            loadout.SpecialButton.tooltipBody = L["When this team loads, a pet from the leveling queue will go in this spot."]
            loadout.SpecialButton.Icon:SetTexCoord(0.375,0.5,0.125,0.25)
        elseif altInfo.idType=="random" then
            color = C.LOADOUT_COLOR_RANDOM
            loadout.SpecialButton.tooltipTitle = L["Random Pet"]
            loadout.SpecialButton.tooltipBody = L["When this team loads, a random high level pet will go in this spot."]
            loadout.SpecialButton.Icon:SetTexCoord(rematchRedux.utils:GetBadgeCoordsByPetType(altInfo.petType))
        elseif altInfo.idType=="ignored" then
            color = C.LOADOUT_COLOR_IGNORED
            loadout.SpecialButton.tooltipTitle = L["Ignored Slot"]
            loadout.SpecialButton.tooltipBody = L["When this team loads, this spot will be ignored."]
            loadout.SpecialButton.Icon:SetTexCoord(0.125,0.25,0.75,0.875)
        else
            -- normal loadout color; this shouldn't have run
            color = C.LOADOUT_COLOR_NORMAL
        end
        loadout.Back:SetDesaturated(true)
        loadout.Back:SetVertexColor(color[1],color[2],color[3])
        loadout.SpecialButton:Show()
    elseif rematchRedux.loadouts:IsSlotLocked(slot) then
        loadout.Back:SetDesaturated(true)
        loadout.Back:SetVertexColor(1,1,1)
        loadout.SpecialButton:Hide()
    else
        loadout.Back:SetDesaturated(false)
        loadout.Back:SetVertexColor(1,1,1)
        loadout.SpecialButton:Hide()
    end
end

-- fills a loadout slot for the petID: type decal, notes, breed, badges, names
function rematchRedux.loadoutPanel:FillLoadout(loadout,petID)
    local petInfo = rematchRedux.petInfo:Fetch(petID)
    local slot = loadout:GetID()

    loadout.Pet:FillPet(petID)

    -- pet type decal in the topright
    if petInfo.suffix then
        loadout.TypeDecal:SetTexture("Interface\\PetBattles\\PetIcon-"..petInfo.suffix)
        loadout.TypeDecal:Show()
    else
        loadout.TypeDecal:Hide()
    end

    -- notes button in the topright
    local showNotes = not settings.HideNotesBadges and petInfo.hasNotes
    loadout.NotesButton:SetShown(showNotes)

    -- breed in topright beneath notes button
    local breedXoff = -14
    if petInfo.breedName and not settings.HideBreedsLoadouts then
        loadout.Breed:SetFontObject(settings.LargerBreedText and "GameFontNormal" or "GameFontNormalSmall")
        loadout.Breed:SetText(petInfo.breedName)
        loadout.Breed:Show()
        breedXoff = breedXoff - ceil(loadout.Breed:GetStringWidth())
    else
        loadout.Breed:Hide()
    end

    -- badges in topright to left of notes button
    local right = showNotes and -34 or -12
    local badgesWidth = rematchRedux.badges:AddBadges(loadout.Badges,"pets",petID,"TOPRIGHT",loadout,"TOPRIGHT",right,-24,-1)

    if not rematchRedux.loadouts:IsSlotLocked(slot) then
        -- names between pet button and notes/badges/breed
        local nameXoff = min(right,breedXoff)
        local nameYoff = -21
        loadout.PetName:SetPoint("TOPLEFT",70,nameYoff)
        loadout.PetName:SetPoint("TOPRIGHT",nameXoff,nameYoff)
        loadout.PetName:SetText(petInfo.name)
        loadout.PetName:Show()
        local nameHeight = loadout.PetName:GetStringHeight()
        if petInfo.customName then
            loadout.SpeciesName:SetText(petInfo.speciesName)
            loadout.SpeciesName:Show()
            nameHeight = nameHeight + loadout.SpeciesName:GetStringHeight() + 2
        else
            loadout.SpeciesName:Hide()
        end
        -- if name+species name takes up less space than icon height, nudge it down
        if nameHeight < 46 then
            nameYoff = -21-floor((46-nameHeight)/2+0.5)+1
            loadout.PetName:SetPoint("TOPLEFT",70,nameYoff)
            loadout.PetName:SetPoint("TOPRIGHT",nameXoff,nameYoff)
        end
        -- color the name
        if settings.ColorPetNames and petInfo.color then
            loadout.PetName:SetTextColor(petInfo.color.r,petInfo.color.g,petInfo.color.b)
        else
            loadout.PetName:SetTextColor(1,0.82,0)
        end
    else
        loadout.PetName:Hide()
        loadout.SpeciesName:Hide()
        local text,link = rematchRedux.loadouts:GetSlotLockedDetails(slot)
        loadout.LockOverlay.RequirementsText:SetText(text)
        loadout.LockOverlay.RequirementsLink:SetText(link)
    end

end

-- unlike mini loadout, the regular loadout bars never move position; though the xp bar is still only visible for pets under 25
function rematchRedux.loadoutPanel:FillStatusBars(loadout,petID)
    local petInfo = rematchRedux.petInfo:Fetch(petID)
    local showXpBar = petInfo.level and petInfo.level<25
    loadout.XpBar:SetShown(showXpBar)
    loadout.XpBarBack:SetShown(showXpBar)
    loadout.XpBarBorder:SetShown(showXpBar)
    if petInfo.level and petInfo.level<25 then
        rematchRedux.utils:UpdateStatusBar(loadout.XpBar,petInfo.xp,petInfo.maxXp,C.LOADOUT_XPBAR_WIDTH,C.XP_BAR_COLOR.r,C.XP_BAR_COLOR.g,C.XP_BAR_COLOR.b)
    end
    local showHpBar = petInfo.health and petInfo.maxHealth
    loadout.HpBar:SetShown(showHpBar)
    loadout.HpBarBack:SetShown(showHpBar)
    loadout.HpBarBorder:SetShown(showHpBar)
    loadout.HeartIcon:SetShown(showHpBar)
    loadout.HealthText:SetShown(showHpBar)
    if showHpBar then
        rematchRedux.utils:UpdateStatusBar(loadout.HpBar,petInfo.health,petInfo.maxHealth,C.LOADOUT_HPBAR_WIDTH,C.HP_BAR_COLOR.r,C.HP_BAR_COLOR.g,C.HP_BAR_COLOR.bg)
        loadout.HealthText:SetText(petInfo.shortHealthStatus)
    end
end

-- updates loadout pet model
function rematchRedux.loadoutPanel:FillModelScene(loadout,petID)
    local petInfo = rematchRedux.petInfo:Fetch(petID)
    local displayID = petInfo.displayID
    if not displayID then
        loadout.ModelScene:Hide()
    else
        loadout.ModelScene:Show()
        if displayID ~= loadout.displayID then
            loadout.displayID = displayID
            local _,loadoutModelSceneID = C_PetJournal.GetPetModelSceneInfoBySpeciesID(petInfo.speciesID)
            loadout.ModelScene:TransitionToModelSceneID( loadoutModelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, false )
            local battlePetActor = loadout.ModelScene:GetActorByTag("pet")
            if battlePetActor then
                battlePetActor:SetModelByCreatureDisplayID(displayID)
                --battlePetActor:SetAnimationBlendOperation(LE_MODEL_BLEND_OPERATION_NONE)
            end
        end
    end
end

function rematchRedux.loadoutPanel:OnShow()
    rematchRedux.events:Register(self,"REMATCHREDUX_LOADOUTS_CHANGED",self.Update)
    rematchRedux.events:Register(self,"REMATCHREDUX_ABILITIES_CHANGED",self.Update)
    rematchRedux.events:Register(self,"REMATCHREDUX_PET_PICKED_UP_ON_CURSOR",self.Update)
    rematchRedux.events:Register(self,"REMATCHREDUX_PET_DROPPED_FROM_CURSOR",self.Update)
    rematchRedux.events:Register(self,"PET_BATTLE_HEALTH_CHANGED",self.Update) -- health changing during battle
    rematchRedux.events:Register(self,"REMATCHREDUX_TEAM_LOADED",self.REMATCHREDUX_TEAM_LOADED) -- team loaded, flash pets
    self:UpdateGlow()
end

function rematchRedux.loadoutPanel:OnHide()
    --self.AbilityFlyout:Hide()
    rematchRedux.events:Unregister(self,"REMATCHREDUX_LOADOUTS_CHANGED")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_ABILITIES_CHANGED")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_PET_PICKED_UP_ON_CURSOR")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_PET_DROPPED_FROM_CURSOR")
    rematchRedux.events:Unregister(self,"PET_BATTLE_HEALTH_CHANGED")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TEAM_LOADED")
end

-- flashes the three loadout slots when a team finishes loading
function rematchRedux.loadoutPanel:REMATCHREDUX_TEAM_LOADED()
    self:Update()
    self:BlingLoadouts()
end

function rematchRedux.loadoutPanel:BlingLoadouts()
    for i=1,3 do
        self.Loadouts[i].Bling:Show()
    end
end

--[[ script handlers for Loadout slots ]]

function rematchRedux.loadoutPanel:LoadoutOnEnter()
    self.Highlight:Show()
    rematchRedux.cardManager:OnEnter(rematchRedux.petCard,self,self.petID)
end

function rematchRedux.loadoutPanel:LoadoutOnLeave()
    self.Highlight:Hide()
    if GetMouseFoci()[1]~=self.Pet then -- don't dismiss card if moving onto pet button
        rematchRedux.cardManager:OnLeave( rematchRedux.petCard )
    end
end

function rematchRedux.loadoutPanel:LoadoutOnMouseDown()
    if rematchRedux.utils:IsJournalUnlocked() then
        self.Highlight:Hide()
    end
end

function rematchRedux.loadoutPanel:LoadoutOnMouseUp()
    if self:IsMouseMotionFocus() and rematchRedux.utils:IsJournalUnlocked() then
        self.Highlight:Show()
    end
end

function rematchRedux.loadoutPanel:LoadoutOnClick(button)
    if rematchRedux.utils:IsJournalLocked() then
        rematchRedux.cardManager:OnClick(rematchRedux.petCard,self,self.petID) -- if journal locked, only allow locking pet card
    elseif button=="RightButton" then
        if rematchRedux.petInfo:Fetch(self.petID).idType=="pet" then
            rematchRedux.menus:Show("LoadoutMenu",self,{slot=self:GetID(),petID=self.petID},"cursor")
        end
    else
        if rematchRedux.utils:IsPetOnCursor() then -- if pet is on the cursor then drop pet into this loadout
            rematchRedux.loadoutPanel.LoadoutOnReceiveDrag(self)
        else -- otherwise lock/unlock pet card
            rematchRedux.cardManager:OnClick(rematchRedux.petCard,self,self.petID)
        end
    end
end

function rematchRedux.loadoutPanel:LoadoutOnDoubleClick()
    if not settings.NoSummonOnDblClick then
        C_PetJournal.SummonPetByGUID(self.petID)
        rematchRedux.petCard:Hide()
    end
end

function rematchRedux.loadoutPanel:LoadoutOnDragStart()
    if rematchRedux.utils:IsJournalUnlocked() then
        local petInfo = rematchRedux.petInfo:Fetch(self.petID)
        if petInfo.isOwned and petInfo.idType=="pet" then
            C_PetJournal.PickupPet(self.petID)
        end
    end
end

function rematchRedux.loadoutPanel:LoadoutOnReceiveDrag()
    if rematchRedux.utils:IsJournalUnlocked() then
        local petID = rematchRedux.utils:GetPetCursorInfo()
        if petID then
            ClearCursor()
            rematchRedux.loadouts:SlotPet(self:GetID(),petID)
            rematchRedux.petCard:Hide()
            rematchRedux.loadoutPanel.LoadoutOnEnter(self) -- go through motions of entering since new pet here
            PlaySound(C.SOUND_DRAG_STOP)
        end
    end
end

--[[ script handlers for pet buttons within loadout slots ]]

function rematchRedux.loadoutPanel:PetOnEnter()
    self:GetParent().Highlight:Show()
    rematchRedux.textureHighlight:Show(self.Icon)
    rematchRedux.cardManager:OnEnter(rematchRedux.petCard,self:GetParent(),self.petID)
end

function rematchRedux.loadoutPanel:PetOnLeave()
    self:GetParent().Highlight:Hide()
    rematchRedux.textureHighlight:Hide()
    if GetMouseFoci()[1]~=self:GetParent() then
        rematchRedux.cardManager:OnLeave(rematchRedux.petCard)
    end
end

function rematchRedux.loadoutPanel:PetOnMouseDown()
    if rematchRedux.utils:IsJournalUnlocked() then
        self:GetParent().Highlight:Hide()
        rematchRedux.textureHighlight:Hide()
    end
end

function rematchRedux.loadoutPanel:PetOnMouseUp()
    if self:IsMouseMotionFocus() and rematchRedux.utils:IsJournalUnlocked() then
        self:GetParent().Highlight:Show()
        rematchRedux.textureHighlight:Show(self.Icon)
    end
end

function rematchRedux.loadoutPanel:PetOnClick(button)
    if rematchRedux.utils:IsJournalLocked() then
        rematchRedux.cardManager:OnClick(rematchRedux.petCard,self,self.petID) -- if journal locked, only allow locking pet card
    elseif rematchRedux.utils:IsPetOnCursor() then
        rematchRedux.loadoutPanel.PetOnReceiveDrag(self)
    else
        local petInfo = rematchRedux.petInfo:Fetch(self.petID)
        if petInfo.isOwned and petInfo.idType=="pet" then
            if button=="RightButton" then
                rematchRedux.menus:Show("LoadoutMenu",self,{slot=self:GetParent():GetID(),petID=self.petID},"cursor")
            elseif rematchRedux.utils:HandleSpecialPetClicks(self.petID) then
                -- if stone targeting or shift-clicking handled, do nothing
            else
                C_PetJournal.PickupPet(self.petID)
            end
        end
    end
end

function rematchRedux.loadoutPanel:PetOnDragStart()
    if rematchRedux.utils:IsJournalUnlocked() then
        local petInfo = rematchRedux.petInfo:Fetch(self.petID)
        if petInfo.isOwned and petInfo.idType=="pet" then
            C_PetJournal.PickupPet(self.petID)
        end
    end
end

function rematchRedux.loadoutPanel:PetOnReceiveDrag()
    if rematchRedux.utils:IsJournalUnlocked() then
        local petID = rematchRedux.utils:GetPetCursorInfo()
        if petID then
            ClearCursor()
            rematchRedux.loadouts:SlotPet(self:GetParent():GetID(),petID)
            rematchRedux.petCard:Hide()
            rematchRedux.loadoutPanel.PetOnEnter(self)
        end
    end
end

-- OnUpdate closes flyout after C.FLYOUT_OPEN_TIMER passes with mouse not on the flyout or ability that opened it
local flyoutTimer = 0
function rematchRedux.loadoutPanel.AbilityFlyout:OnUpdate(elapsed)
    if self.anchoredTo and (self.anchoredTo:IsMouseOver() or self:IsMouseOver()) then
        flyoutTimer = 0
    else
        flyoutTimer = flyoutTimer + elapsed
        if flyoutTimer > C.FLYOUT_OPEN_TIMER then
            self:Hide()
        end
    end
end

--[[ script handlers for special buttons at the top of loadout slots (leveling, random, ignored) ]]

function rematchRedux.loadoutPanel:SpecialOnEnter()
    rematchRedux.textureHighlight:Show(self.Icon)
    rematchRedux.tooltip:ShowSimpleTooltip(self) -- tooltip is updated in the loadout update
end

function rematchRedux.loadoutPanel:SpecialOnLeave()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.tooltip:Hide()
end

function rematchRedux.loadoutPanel:SpecialOnMouseDown()
    if rematchRedux.utils:IsJournalUnlocked() then
        rematchRedux.textureHighlight:Hide()
    end
end

function rematchRedux.loadoutPanel:SpecialOnMouseUp()
    if self:IsMouseMotionFocus() and rematchRedux.utils:IsJournalUnlocked() then
        rematchRedux.textureHighlight:Show(self.Icon)
    end
end

function rematchRedux.loadoutPanel:SpecialOnClick(button)
    if rematchRedux.utils:IsJournalUnlocked() then
        rematchRedux.menus:Show("SpecialMenu",self,{slot=self:GetParent():GetID()},"cursor")
    end
end

--[[ script handlers for lock in topleft corner when journal locked ]]

function rematchRedux.loadoutPanel:LockOnEnter()
    rematchRedux.textureHighlight:Show(self)
    if not C_PetJournal.IsJournalUnlocked() then
        rematchRedux.tooltip:ShowSimpleTooltip(self,LOCKED,PET_JOURNAL_READONLY_TEXT)
    elseif C_PetBattles.GetPVPMatchmakingInfo() then
        rematchRedux.tooltip:ShowSimpleTooltip(self,LOCKED,ERR_PETBATTLE_QUEUE_QUEUED)
    else
        local slot = self:GetParent():GetParent():GetID()
        if rematchRedux.loadouts:IsSlotLocked(slot) then
            local text,link,spellID,achievementID = rematchRedux.loadouts:GetSlotLockedDetails(slot)
            rematchRedux.tooltip:ShowSimpleTooltip(self,text.." "..link)
        end
    end
end

function rematchRedux.loadoutPanel:LockOnLeave()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.tooltip:Hide()
end

-- entering the requirements link ([Battle Pet Training], [Newbie] or [Just a Pup]) for locked slots
function rematchRedux.loadoutPanel:RequirementsOnEnter()
    local slot = self:GetParent():GetParent():GetID()
    local _,_,spellID,achievementID = rematchRedux.loadouts:GetSlotLockedDetails(slot)
    rematchRedux.tooltip:SetOwner(self)
    if spellID then
        rematchRedux.tooltip:SetSpellByID(spellID)
    elseif achievementID then
        rematchRedux.tooltip:SetAchievementByID(achievementID)
    else
        return
    end
    local corner,opposite = rematchRedux.utils:GetCorner(rematchRedux.frame,UIParent)
    rematchRedux.tooltip:SetPoint(corner,self,opposite)
    rematchRedux.tooltip:Show()
end

function rematchRedux.loadoutPanel:RequirementsOnLeave()
    rematchRedux.tooltip:Hide()
end