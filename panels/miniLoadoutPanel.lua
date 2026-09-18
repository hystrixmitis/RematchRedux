local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.miniLoadoutPanel = rematchRedux.frame.MiniLoadoutPanel ---@diagnostic disable-line: undefined-field
rematchRedux.frame:Register("miniLoadoutPanel")

function rematchRedux.miniLoadoutPanel:Configure()
    local width = self:GetWidth() -- width can change for this panel (minimized 85px, 2-panel 92px, 1-panel 112px)
    local loadoutWidth = floor((width-4)/3+0.5) -- width of each of three loadouts, 2px gap between left/center and right/center
    local gap = floor((loadoutWidth-44-26)/3+0.5) -- gap between sides/middle for each loadout around pet and abilityBar
    for i=1,3 do
        self.Loadouts[i]:SetSize(loadoutWidth,C.PANEL_MINILOADOUT_HEIGHT)
        self.Loadouts[i].Icon:SetPoint("TOPLEFT",gap+2+1,-8-3) -- pet icon
        self.Loadouts[i].AbilityBar:SetPoint("TOPRIGHT",-gap,-8-1)
        self.Loadouts[i].neverDim = true -- never desaturate a loaded pet
    end
    -- due to potential rounding errors, centering middle loadout and positioning other two 2px to left and right
    self.Loadouts[2]:SetPoint("CENTER")
    self.Loadouts[1]:SetPoint("RIGHT",self.Loadouts[2],"LEFT",-2,0)
    self.Loadouts[3]:SetPoint("LEFT",self.Loadouts[2],"RIGHT",2,0)
end

function rematchRedux.miniLoadoutPanel:Update()
    for i=1,3 do
        local petID,ability1,ability2,ability3,locked = C_PetJournal.GetPetLoadOutInfo(i)
        self.Loadouts[i].petID = petID
        if C_PetBattles.IsInBattle() then
            petID = "battle:1:"..i -- if in a pet battle, use the battle petID to get health updates during battle
        end
        self.Loadouts[i]:FillPet(petID)
        self.Loadouts[i].AbilityBar:FillAbilityBar(petID,ability1,ability2,ability3)
        self:FillStatusBars(self.Loadouts[i],petID)

        rematchRedux.loadoutPanel:FillSpecial(self.Loadouts[i],i)

        local showGlow = rematchRedux.utils:IsPetOnCursor()
        if showGlow then
            self.Loadouts[i].Animation:Play()
        else
            self.Loadouts[i].Animation:Stop()
        end
        self.Loadouts[i].Glow:SetShown(showGlow)
        self.Loadouts[i].LockOverlay:SetShown(rematchRedux.utils:IsJournalLocked() or rematchRedux.loadouts:IsSlotLocked(i))

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

function rematchRedux.miniLoadoutPanel:UpdateGlow()
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

-- OnUpdate closes flyout after C.FLYOUT_OPEN_TIMER passes with mouse not on the flyout or ability that opened it
local flyoutTimer = 0
function rematchRedux.miniLoadoutPanel.AbilityFlyout:OnUpdate(elapsed)
    if self.anchoredTo and (self.anchoredTo:IsMouseOver() or self:IsMouseOver()) then
        flyoutTimer = 0
    else
        flyoutTimer = flyoutTimer + elapsed
        if flyoutTimer > C.FLYOUT_OPEN_TIMER then
            self:Hide()
        end
    end
end

-- updates the two statusbars on the loadout slot
function rematchRedux.miniLoadoutPanel:FillStatusBars(loadout,petID)
    if not petID then -- if there's no pet in this slot
        self:SetTopStatusBarShown(loadout,true)
        rematchRedux.utils:UpdateStatusBar(loadout.TopStatusBar,0,100,C.MINILOADOUT_STATUSBAR_WIDTH,0,0,0)
        rematchRedux.utils:UpdateStatusBar(loadout.BottomStatusBar,0,100,C.MINILOADOUT_STATUSBAR_WIDTH,0,0,0)
    else -- there's a pet slotted
        if C_PetBattles.IsInBattle() then
            petID = "battle:1:"..loadout:GetID()
        end
        local petInfo = rematchRedux.petInfo:Fetch(petID)
        local health,maxHealth = petInfo.health,petInfo.maxHealth
        if petInfo.level==25 then -- this pet is max level, use bottom status bar for health and display a numerical health at top
            self:SetTopStatusBarShown(loadout,false)
            loadout.HealthText:SetText(petInfo.shortHealthStatus) -- display text health (Dead, 75% or 1400)
            rematchRedux.utils:UpdateStatusBar(loadout.BottomStatusBar,health,maxHealth,C.MINILOADOUT_STATUSBAR_WIDTH,C.HP_BAR_COLOR.r,C.HP_BAR_COLOR.g,C.HP_BAR_COLOR.b)
        else -- this pet is under 25, use top statusbar for health and bottom for xp
            self:SetTopStatusBarShown(loadout,true)
            rematchRedux.utils:UpdateStatusBar(loadout.TopStatusBar,health,maxHealth,C.MINILOADOUT_STATUSBAR_WIDTH,C.HP_BAR_COLOR.r,C.HP_BAR_COLOR.g,C.HP_BAR_COLOR.b)
            rematchRedux.utils:UpdateStatusBar(loadout.BottomStatusBar,petInfo.xp,petInfo.maxXp,C.MINILOADOUT_STATUSBAR_WIDTH,C.XP_BAR_COLOR.r,C.XP_BAR_COLOR.g,C.XP_BAR_COLOR.b)
        end
    end
end

-- shows or hide the top status bar (and display heart icon and health text if not shown)
-- (should be called before UpdateStatusBar in case the TopStatusBar is hidden at 0 value)
function rematchRedux.miniLoadoutPanel:SetTopStatusBarShown(loadout,show)
    loadout.TopStatusBarBack:SetShown(show)
    loadout.TopStatusBar:SetShown(show)
    loadout.TopStatusBarBorder:SetShown(show)
    loadout.HeartIcon:SetShown(not show)
    loadout.HealthText:SetShown(not show)
end

function rematchRedux.miniLoadoutPanel:OnShow()
    rematchRedux.events:Register(self,"REMATCHREDUX_LOADOUTS_CHANGED",self.Update)
    rematchRedux.events:Register(self,"REMATCHREDUX_ABILITIES_CHANGED",self.Update)
    rematchRedux.events:Register(self,"REMATCHREDUX_PET_PICKED_UP_ON_CURSOR",self.Update)
    rematchRedux.events:Register(self,"REMATCHREDUX_PET_DROPPED_FROM_CURSOR",self.Update)
    rematchRedux.events:Register(self,"PET_BATTLE_HEALTH_CHANGED",self.Update) -- health changing during battle
    rematchRedux.events:Register(self,"REMATCHREDUX_TEAM_LOADED",self.REMATCHREDUX_TEAM_LOADED) -- team loaded, flash pets
    self:UpdateGlow()
end

function rematchRedux.miniLoadoutPanel:OnHide()
    self.AbilityFlyout:Hide()
    rematchRedux.events:Unregister(self,"REMATCHREDUX_LOADOUTS_CHANGED")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_ABILITIES_CHANGED")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_PET_PICKED_UP_ON_CURSOR")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_PET_DROPPED_FROM_CURSOR")
    rematchRedux.events:Unregister(self,"PET_BATTLE_HEALTH_CHANGED")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TEAM_LOADED")
end

-- when a team loads, update panel and flash the three loadout slots
function rematchRedux.miniLoadoutPanel:REMATCHREDUX_TEAM_LOADED()
    self:Update()
    self:BlingLoadouts()
end

function rematchRedux.miniLoadoutPanel:BlingLoadouts()
    for i=1,3 do
        self.Loadouts[i].Bling:Show()
    end
end

function rematchRedux.miniLoadoutPanel:LoadoutOnEnter()
    rematchRedux.textureHighlight:Show(self.Back,self.Icon)
    rematchRedux.cardManager:OnEnter(rematchRedux.petCard,self,self.petID)
end

function rematchRedux.miniLoadoutPanel:LoadoutOnLeave()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.cardManager:OnLeave(rematchRedux.petCard)
end

function rematchRedux.miniLoadoutPanel:LoadoutOnMouseDown()
    if rematchRedux.utils:IsJournalUnlocked() then
        rematchRedux.textureHighlight:Hide()
    end
end

function rematchRedux.miniLoadoutPanel:LoadoutOnMouseUp()
    if self:IsMouseMotionFocus() and rematchRedux.utils:IsJournalUnlocked() then
        rematchRedux.textureHighlight:Show(self.Back,self.Icon)
    end
end

function rematchRedux.miniLoadoutPanel:LoadoutOnClick(button)
    if rematchRedux.utils:IsJournalLocked() then
        rematchRedux.cardManager:OnClick(rematchRedux.petCard,self,self.petID)
    elseif button=="RightButton" then
        if rematchRedux.petInfo:Fetch(self.petID).idType=="pet" then
            rematchRedux.menus:Show("LoadoutMenu",self,{slot=self:GetID(),petID=self.petID},"cursor")
        end
    else
        if rematchRedux.utils:IsPetOnCursor() then -- if pet is on the cursor then drop pet into this loadout
            rematchRedux.miniLoadoutPanel.LoadoutOnReceiveDrag(self)
        else -- otherwise lock/unlock pet card
            rematchRedux.cardManager:OnClick(rematchRedux.petCard,self,self.petID)
        end
    end
end

function rematchRedux.miniLoadoutPanel:LoadoutOnDoubleClick(button)
    if not settings.NoSummonOnDblClick then
        C_PetJournal.SummonPetByGUID(self.petID)
        rematchRedux.petCard:Hide()
    end
end

function rematchRedux.miniLoadoutPanel:LoadoutOnDragStart()
    if rematchRedux.utils:IsJournalUnlocked() then
        local petInfo = rematchRedux.petInfo:Fetch(self.petID)
        if petInfo.isOwned and petInfo.idType=="pet" then
            C_PetJournal.PickupPet(self.petID)
        end
    end
end

function rematchRedux.miniLoadoutPanel:LoadoutOnReceiveDrag()
    if rematchRedux.utils:IsJournalUnlocked() then
        local petID = rematchRedux.utils:GetPetCursorInfo()
        if petID then
            ClearCursor()
            rematchRedux.loadouts:SlotPet(self:GetID(),petID)
            rematchRedux.petCard:Hide()
            rematchRedux.miniLoadoutPanel.LoadoutOnEnter(self)
            PlaySound(C.SOUND_DRAG_STOP)
        end
    end
end

--[[ script handlers for special buttons at the top of loadout slots (leveling, random, ignored)

    these ended up being the same as the main loadout
]]

rematchRedux.miniLoadoutPanel.SpecialOnEnter = rematchRedux.loadoutPanel.SpecialOnEnter
rematchRedux.miniLoadoutPanel.SpecialOnLeave = rematchRedux.loadoutPanel.SpecialOnLeave
rematchRedux.miniLoadoutPanel.SpecialOnMouseDown = rematchRedux.loadoutPanel.SpecialOnMouseDown
rematchRedux.miniLoadoutPanel.SpecialOnMouseUp = rematchRedux.loadoutPanel.SpecialOnMouseUp
rematchRedux.miniLoadoutPanel.SpecialOnClick = rematchRedux.loadoutPanel.SpecialOnClick

--[[ script handlers for lock overlay same as main loadouts ]]

rematchRedux.miniLoadoutPanel.LockOnEnter = rematchRedux.loadoutPanel.LockOnEnter
rematchRedux.miniLoadoutPanel.LockOnLeave = rematchRedux.loadoutPanel.LockOnLeave