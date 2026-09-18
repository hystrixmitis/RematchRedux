local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings

local updates = {} -- functions indexed by button name to update button's state/content
local preClicks = {} -- functions indexed by button name to modify attributes/behavior before a click
local tooltips = {} -- functions indexed by button name to show a tooltip

-- for heal and bandage buttons to determine if any pet needs healed
local function isAnyPetInjured()
    for petID in rematchRedux.roster:AllOwnedPets() do
        local petInfo = rematchRedux.petInfo:Fetch(petID)
        if petInfo.isDead or petInfo.isInjured then -- at least one pet is injured
            return true
        end
    end
    return false
end

-- generic function for Bandage, LesserPetTreat, PetTreat (and at end of LevelingStone/RarityStone) buttons
-- to update the item count and dim when it's at 0
local function itemUpdate(self)
    local count = C_Item.GetItemCount(self:GetAttribute("item"))
    self.Count:SetText(count)
    if count==0 then
        self.Icon:SetVertexColor(0.5,0.5,0.5)
    else
        self.Icon:SetVertexColor(1,1,1)
    end
end

-- called by a timer, to rerun a tooltip
local function repeatTooltip(self)
    if type(tooltips[self.button])=="function" then
        tooltips[self.button](self)
    end
end

-- stops any pending tooltip waiting to be shown
local function stopTooltip()
    rematchRedux.timer:Stop(repeatTooltip)
end

-- call before filling a toolbar tooltip, returns false if a tooltip shouldn't be shown
local function preTooltip(self)
    stopTooltip()
    if settings.HideToolbarTooltips then
        rematchRedux.tooltip:Hide()
        return false
    else
        rematchRedux.tooltip:SetOwner(self)
        return true
    end
end

-- call after filling a toolbar tooltip to actually show and anchor the tooltip
local function postTooltip(self,repeatDelay)
    if rematchRedux.tooltip:GetNumLines()>0 then
        local corner,opposite = rematchRedux.utils:GetCorner(rematchRedux.frame,UIParent)
        rematchRedux.tooltip:SetPoint(corner,self,opposite)
        rematchRedux.tooltip:Show()
        if repeatDelay then
            rematchRedux.timer:Start(repeatDelay,repeatTooltip,self)
        end
    end
end

--[[ updates ]]

function updates:SafariHatButton()
    local buffName = rematchRedux.utils:GetItemBuff(C.SAFARI_HAT_ITEM_ID)
    if buffName then
        self.Cancel:Show()
        self:SetAttribute("type","cancelaura")
        self:SetAttribute("unit","player")
        self:SetAttribute("spell",buffName)
    else -- safari hat is not active, set attributes to use it
        self.Cancel:Hide()
        self:SetAttribute("type","item")
        self:SetAttribute("item","item:"..C.SAFARI_HAT_ITEM_ID)
    end
    -- if they don't have a safari hat, then dim the button
    local hasHat = PlayerHasToy(C.SAFARI_HAT_ITEM_ID)
    if not hasHat then
        self.Icon:SetVertexColor(0.5,0.5,0.5)
    else
        self.Icon:SetVertexColor(1,1,1)
    end
    -- Safari Hat Reminder
    if settings.SafariHatShine and hasHat and not buffName and rematchRedux.loadouts:NotAllMaxLevel() then
        self.Shine:Show()
    else
        self.Shine:Hide()
    end
end

updates.BandageButton = itemUpdate
updates.LesserPetTreatButton = itemUpdate
updates.PetTreatButton = itemUpdate

function updates:SummonPetButton()
    local petID = C_PetJournal.GetSummonedPetGUID()
    if self.petID~=petID then
        self.petID = petID
        local petInfo = rematchRedux.petInfo:Fetch(petID)
        if petInfo.isValid then -- a pet is summoned
            self.Icon:SetTexture(petInfo.icon)
            self.Cancel:Show()
        else
            self.Icon:SetTexture(C.SUMMON_RANDOM_ICON)
            self.Cancel:Hide()
        end
    end
end

function updates:RandomTeamButton()
--    self.Icon:SetDesaturated(true)
    --self.Icon:SetVertexColor(0.5,0.5,0.5)
end

function updates:FindBattleButton()
    self.Cancel:SetShown(C_PetBattles.GetPVPMatchmakingInfo() and true)
end

function updates:LevelingStoneButton()
    local itemID = rematchRedux.toolbar:PickBestStone(C.LEVELING_STONES,C.DEFAULT_LEVELING_STONE_ITEM_ID)
    self.Icon:SetTexture((select(5,C_Item.GetItemInfoInstant(itemID))))
    self:SetAttribute("item","item:"..itemID)
    itemUpdate(self)
end

function updates:RarityStoneButton()
    local itemID = rematchRedux.toolbar:PickBestStone(C.RARITY_STONES,C.DEFAULT_RARITY_STONE_ITEM_ID)
    self.Icon:SetTexture((select(5,C_Item.GetItemInfoInstant(itemID))))
    self:SetAttribute("item","item:"..itemID)
    itemUpdate(self)
end

--[[ preClicks ]]

function preClicks:PetSatchelButton(button)
    settings.PetSatchelIndex = settings.PetSatchelIndex%#rematchRedux.toolbar.petSatchelButtons + 1
    rematchRedux.toolbar:Configure()
    rematchRedux.toolbar:Update()
    PlaySound(C.SOUND_SATCHEL)
end

function preClicks:SummonPetButton(button)
    local petID = C_PetJournal.GetSummonedPetGUID()
    if petID then -- pet was out, dismiss it
        C_PetJournal.SummonPetByGUID(petID)
    else -- pet not out, true=random favorites, false=random all (unless ToolbarDismiss enabled)
        C_PetJournal.SummonRandomPet(settings.ToolbarDismiss or button~="RightButton")
    end
end

function preClicks:HealButton(button)
    if isAnyPetInjured() then
        self:SetAttribute("type","spell") -- something needs healed, turn on the spell
    else
        self:SetAttribute("type",nil) -- all pets healed, turn off the spell
        self.tooltipNotice = L["All pets are at full health."]
        tooltips.HealButton(self) -- refresh tooltip immediately
    end
end

function preClicks:BandageButton(button)
    if isAnyPetInjured() then
        self:SetAttribute("type","item") -- something needs healed, turn on the item
    else
        self:SetAttribute("type",nil) -- all pets healed, turn off the item
        self.tooltipNotice = L["All pets are at full health."]
        tooltips.BandageButton(self) -- refresh tooltip immediately
    end
end

function preClicks:FindBattleButton(button)
    local queueState = C_PetBattles.GetPVPMatchmakingInfo()
    if queueState=="proposal" then
        C_PetBattles.DeclineQueuedPVPMatch()
    elseif queueState then
        C_PetBattles.StopPVPMatchmaking()
    else
        C_PetBattles.StartPVPMatchmaking()
    end
end

function preClicks:RandomTeamButton(button)
    rematchRedux.randomPets:BuildCounterTeam(rematchRedux.targetInfo.recentTarget)
    rematchRedux.loadTeam:LoadTeamID("counter")
    PlaySound(C.SOUND_TEAM_LOAD)
end

-- clicking the Save As toolbar button should behave identically to clicking the bottombar SaveAsButton
function preClicks:SaveAsButton(button)
    rematchRedux.bottombar.SaveAsButton:OnClick()
end

-- export button for loaded teams will sideline the loaded pets with the current team if one loaded
function preClicks:ExportTeamButton(button)
    rematchRedux.saveDialog:SidelineLoadouts(newTeam)
    rematchRedux.dialog:ShowDialog("ExportSingleTeam",{teamID="sideline"})
end

function preClicks:ImportTeamButton(button)
    rematchRedux.dialog:ShowDialog("ImportTeams")
end

--[[ tooltips ]]

function tooltips:SummonPetButton()
    if preTooltip(self) then
        local tooltipTitle,tooltipBody
        local petInfo = rematchRedux.petInfo:Fetch(C_PetJournal.GetSummonedPetGUID())
        if petInfo.isValid then -- a pet is summoned
            rematchRedux.tooltip:AddLine(petInfo.name,petInfo.color.r,petInfo.color.g,petInfo.color.b)
            if petInfo.customName then
                rematchRedux.tooltip:AddLine(petInfo.speciesName,1,1,1)
            end
            rematchRedux.tooltip:AddLine(format(L["Pet Level %d %s"],petInfo.level,petInfo.petTypeName),1,1,1)
            rematchRedux.tooltip:AddLine(format(L["%s Dismiss Pet"],C.LMB_TEXT_ICON))
        else -- a pet isn't summoned
            rematchRedux.tooltip:AddLine(L["Summon Random Pet"])
            if settings.ToolbarDismiss then
                rematchRedux.tooltip:AddLine(format("%s %s",C.LMB_TEXT_ICON,L["Random favorite pet"]))
            else
                rematchRedux.tooltip:AddLine(format("%s %s\n%s %s",C.LMB_TEXT_ICON,L["Random favorite pet"],C.RMB_TEXT_ICON,L["Random from all pets"]))
            end
        end
        postTooltip(self)
    end
end

-- for buttons with onlya tooltipTitle and tooltipBody
function tooltips:SimpleTooltip()
    if preTooltip(self) then
        rematchRedux.tooltip:AddLine(_G[self.tooltipTitle] or L[self.tooltipTitle])
        rematchRedux.tooltip:AddLine(_G[self.tooltipBody] or L[self.tooltipBody])
        postTooltip(self)
    end
end
tooltips.FindBattleButton = tooltips.SimpleTooltip
tooltips.ImportTeamButton = tooltips.SimpleTooltip
tooltips.ExportTeamButton = tooltips.SimpleTooltip
tooltips.PetSatchelButton = tooltips.SimpleTooltip
tooltips.RandomTeamButton = tooltips.SimpleTooltip
tooltips.SaveAsButton = tooltips.SimpleTooltip

function tooltips:HealButton()
    if preTooltip(self) then
        local spellID = self:GetAttribute("spell")
        rematchRedux.tooltip:SetSpellByID(spellID)
        if self.tooltipNotice then
            rematchRedux.tooltip:AddLine(format(L["%s%s"],C.HEX_BLUE,self.tooltipNotice))
        end
        local cooldown = C_Spell.GetSpellCooldown(C.REVIVE_SPELL_ID)
        local repeatDelay = (cooldown and cooldown.startTime and cooldown.startTime>0) and 1 or nil
        postTooltip(self,repeatDelay) -- repeat tooltip every second if it's on cooldown
    end
end

function tooltips:SafariHatButton()
    if preTooltip(self) then
        local _,spellID = rematchRedux.utils:GetItemBuff(C.SAFARI_HAT_ITEM_ID)
        if spellID then -- safari hat is active, set buff tooltip
            rematchRedux.tooltip:SetUnitBuff("player",rematchRedux.utils:GetBuffIndex(spellID))
        else -- safari hat is not active, set toy tooltip
            rematchRedux.tooltip:SetToyByItemID(C.SAFARI_HAT_ITEM_ID)
        end
        postTooltip(self)
    end
end

function tooltips:ItemTooltip()
    if preTooltip(self) then
        local repeatDelay
        local itemID = self:GetAttribute("item")
        local _,spellID = rematchRedux.utils:GetItemBuff(itemID)
        if spellID then -- if the item grants a buff, display buff tooltip if it's up
            rematchRedux.tooltip:SetUnitBuff("player",rematchRedux.utils:GetBuffIndex(spellID))
            repeatDelay = 1 -- if tooltip for a buff, update it every second
        else -- display item tooltip otherwise
            rematchRedux.tooltip:SetItemByID(itemID)
            if not C_Item.IsItemDataCachedByID(itemID) or rematchRedux.tooltip:GetNumLines()<=2 then
                repeatDelay = 0.2 -- if tooltip for an item that's not cached or fully loaded, update again in 0.2 seconds
            end
        end
        if self.tooltipNotice then
            rematchRedux.tooltip:AddLine(format(L["%s%s"],C.HEX_BLUE,self.tooltipNotice))
        end
        postTooltip(self,repeatDelay)
    end
end
tooltips.BandageButton = tooltips.ItemTooltip
tooltips.PetTreatButton = tooltips.ItemTooltip
tooltips.LesserPetTreatButton = tooltips.ItemTooltip
tooltips.LevelingStoneButton = tooltips.ItemTooltip
tooltips.RarityStoneButton = tooltips.ItemTooltip

--[[ button mixin ]]

RematchReduxToolbarButtonMixin = {}

function RematchReduxToolbarButtonMixin:OnLoad()
    if self.icon then
        self.Icon:SetTexture(self.icon)
    end
    self.Cooldown:SetHideCountdownNumbers(true)
end

function RematchReduxToolbarButtonMixin:OnEnter()
    rematchRedux.textureHighlight:Show(self.Icon)
    local button = self.button
    if button and rematchRedux.toolbar[button] and tooltips[button] then
        tooltips[button](rematchRedux.toolbar[button])
    end
end

function RematchReduxToolbarButtonMixin:OnLeave()
    stopTooltip()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.tooltip:Hide()
    self.tooltipNotice = nil -- remove any notice added to tooltip
end

function RematchReduxToolbarButtonMixin:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxToolbarButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematchRedux.textureHighlight:Show(self.Icon)
    end
end

function RematchReduxToolbarButtonMixin:PreClick(mouseButton,down)
    local button = self.button
    if button and rematchRedux.toolbar[button] and preClicks[button] and GetCVarBool("ActionButtonUseKeyDown")==down then
        preClicks[button](rematchRedux.toolbar[button],mouseButton,down)
    end
end

function RematchReduxToolbarButtonMixin:PostClick(mouseButton,down)
    if mouseButton=="RightButton" and settings.ToolbarDismiss and rematchRedux.frame:IsVisible() then
        rematchRedux.frame:Toggle()
    end
end

function RematchReduxToolbarButtonMixin:OnDragStart()
    if self:GetAttribute("item") then
        C_Item.PickupItem(self:GetAttribute("item"))
    elseif self:GetAttribute("spell") then
        C_Spell.PickupSpell(self:GetAttribute("spell"))
    end
end

-- all buttons share this Update which calls the updates[] function indexed by button parentKey (self.button)
function RematchReduxToolbarButtonMixin:Update(fromEvent)
    local button = self.button
    if (not fromEvent or self.needsUpdate or self.alwaysUpdate) and button and rematchRedux.toolbar[button] and updates[button] then
        updates[button](rematchRedux.toolbar[button])
        self.needsUpdate = nil
    end
end

