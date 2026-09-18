local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.toolbar = rematchRedux.frame.ToolBar
rematchRedux.frame:Register("toolbar")

-- toolbarLayout is the toolbar layout used by each mode (0-minimized, 1-single, etc.). Notes:
-- These are listed in the displayed order but put in reverse in workingLayout because buttons are built from right to left.
-- If an entry is a string ("HealButton") it refers to the RematchRedux.toolbar[String] button: RematchRedux.toolbar.HealButton
-- If an entry is a number, it refers to an index into a PetSatchelButtons record. (should be 1-2 for now, but may expand later)
local toolbarLayouts = {
    [0] = {"HealButton","BandageButton","SafariHatButton",1,2,"PetSatchelButton","SummonPetButton","FindBattleButton"},
    [1] = {"HealButton","BandageButton","SafariHatButton",1,2,"PetSatchelButton","SummonPetButton"},
    [2] = {"HealButton","BandageButton","SafariHatButton","LesserPetTreatButton","PetTreatButton","LevelingStoneButton","RarityStoneButton","ImportTeamButton","ExportTeamButton","RandomTeamButton","SummonPetButton"},
    [3] = {"HealButton","BandageButton","SafariHatButton","LesserPetTreatButton","PetTreatButton","LevelingStoneButton","RarityStoneButton","ImportTeamButton","ExportTeamButton","RandomTeamButton","SummonPetButton"}
}

-- the toolbar layout currently being used, based on the above layouts and adjusted for PetSatchelIndex and ReverseToolbar
local displayLayout = {}

-- for toolbars that have the PetSatchelButton, the button will cycle through these buttons
rematchRedux.toolbar.petSatchelButtons = {
    {"LesserPetTreatButton","PetTreatButton"},
    {"LevelingStoneButton","RarityStoneButton"},
    {"ImportTeamButton","ExportTeamButton"},
    {"RandomTeamButton","SaveAsButton"},
}

rematchRedux.events:Register(rematchRedux.toolbar,"PLAYER_LOGIN",function(self)
    -- steal the TopTileStreaks inherited from BasicFrameTemplate and put them behind the toolbar
    rematchRedux.frame.TopTileStreaks:SetParent(rematchRedux.toolbar)
    rematchRedux.frame.TopTileStreaks:SetPoint("TOPLEFT")
    rematchRedux.frame.TopTileStreaks:SetPoint("TOPRIGHT")

    rematchRedux.events:Register(self,"REMATCHREDUX_TEAM_LOADED",REMATCHREDUX_TEAM_LOADEDOADED)
    rematchRedux.timer:Start(0.1,rematchRedux.toolbar.CacheSafariHat)
end)

function rematchRedux.toolbar:Configure()
    local layout = self:GetToolbarLayout()
    local mode = rematchRedux.layout:GetMode(C.CURRENT)
    local leftMostButton

    for _,button in ipairs(rematchRedux.toolbar.Buttons) do
        button:Hide()
    end

    -- reversed toolbar changes the order the layout is traversed
    local from,to,step = 1,#layout,1
    if settings.ReverseToolbar then
        from,to,step = #layout,1,-1
    end

    if layout then
        local xoff = -2
        for i=from,to,step do
            local button = rematchRedux.toolbar[layout[i]]
            button:SetPoint("RIGHT",xoff,0)
            button:Show()
            button.Border:SetShown(i~=to or mode~=0) -- hide leftmost left border when minimized, show otherwise
            xoff = xoff - C.TOOLBAR_BUTTON_SIZE
            leftMostButton = button
        end
    end

    self.TotalsButton:SetShown(mode~=0) -- show totals button in all but minimized mode
    self.TotalsButton.Border:SetShown(mode>1) -- show border to right of totals button in 2- and 3-panel modes
    self.TotalsButton:SetPoint("LEFT",rematchRedux.journal:IsActive() and 56 or 3,0) -- need to nudge totals to right in journal

    self.AchievementTotal:SetShown(mode>1)
    self.AchievementTotal:SetPoint("LEFT",self.TotalsButton,"RIGHT",2,0)
    self.AchievementTotal:SetPoint("RIGHT",leftMostButton,"LEFT",-2,0)
    local showFlair = mode==3 or (settings.AlwaysUsePetSatchel and mode==2)
    self.AchievementTotal.LeftFlair:SetShown(showFlair)
    self.AchievementTotal.RightFlair:SetShown(showFlair)
end

function rematchRedux.toolbar:Update(fromEvent)
    -- go through each button in the present layout and run their update if they have one
    local layout = self:GetToolbarLayout()
    for _,buttonName in ipairs(layout) do
        local button = rematchRedux.toolbar[buttonName]
        if button and button.Update then
            button:Update(fromEvent)
        end
        if button:IsMouseMotionFocus() then
            button:GetScript("OnEnter")(button)
        end
    end
    -- update cooldowns
    --self:SPELL_UPDATE_COOLDOWN()
    -- update totals button
    if settings.DisplayUniqueTotal then
        self.TotalsButton.Text:SetText(format("%s \124cffffffff%d",L["UNIQUE_PETS"],rematchRedux.roster:GetNumUniqueOwned()))
    else
        self.TotalsButton.Text:SetText(format("%s \124cffffffff%d",L["TOTAL_PETS"],(select(2,C_PetJournal.GetNumPets()))))
    end
    -- update the achievement total
    self.AchievementTotal.Text:SetText(GetCategoryAchievementPoints(C.PET_ACHIEVEMENT_CATEGORY,true))
end

-- builds a list of parentKeys for toolbar buttons to be shown depending on mode and pet satchel
function rematchRedux.toolbar:GetToolbarLayout()
    wipe(displayLayout)
    local mode = rematchRedux.layout:GetMode(C.CURRENT)
    -- if Always Use Pet Satchel is enabled, then dual and triple-panel modes should use single-panel layout
    if mode>1 and settings.AlwaysUsePetSatchel then
        mode=1
    end
    local layout = mode and toolbarLayouts[mode]
    assert(layout,"No toolbar layout for mode "..(mode or "nil"))

    for i=#layout,1,-1 do
        if type(layout[i])=="string" then
            tinsert(displayLayout,layout[i])
        elseif type(layout[i])=="number" then
            local satchelIndex = settings.PetSatchelIndex
            if not satchelIndex or satchelIndex<1 or satchelIndex > #rematchRedux.toolbar.petSatchelButtons then
                satchelIndex = 1
                settings.PetSatchelIndex = 1
            end
            tinsert(displayLayout,rematchRedux.toolbar.petSatchelButtons[satchelIndex][layout[i]])
        end
    end
    return displayLayout
end

function rematchRedux.toolbar:OnShow()
    rematchRedux.events:Register(self,"COMPANION_UPDATE",self.COMPANION_UPDATE)
    rematchRedux.events:Register(self,"SPELL_UPDATE_COOLDOWN",self.SPELL_UPDATE_COOLDOWN)
    rematchRedux.events:Register(self,"UNIT_AURA",self.UNIT_AURA)
    rematchRedux.events:Register(self,"BAG_UPDATE_DELAYED",self.BAG_UPDATE_DELAYED)
    rematchRedux.events:Register(self,"PET_BATTLE_QUEUE_STATUS",self.PET_BATTLE_QUEUE_STATUS)
    rematchRedux.events:Register(self,"REMATCHREDUX_LOADOUTS_CHANGED",REMATCHREDUX_ATCH_LOADOUTS_CHANGED)
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TEAM_LOADED") -- only register while toolbar not shown
    rematchRedux.toolbar:SPELL_UPDATE_COOLDOWN()
end

function rematchRedux.toolbar:OnHide()
    rematchRedux.events:Unregister(self,"COMPANION_UPDATE")
    rematchRedux.events:Unregister(self,"SPELL_UPDATE_COOLDOWN")
    rematchRedux.events:Unregister(self,"UNIT_AURA")
    rematchRedux.events:Unregister(self,"BAG_UPDATE_DELAYED")
    rematchRedux.events:Unregister(self,"PET_BATTLE_QUEUE_STATUS")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_LOADOUTS_CHANGED")
    rematchRedux.events:Register(self,"REMATCHREDUX_TEAM_LOADED",REMATCHREDUX_TEAM_LOADEDOADED)
end

-- safari hat is a toy and needs to be applied by name; forcing a cache on login to get the name
function rematchRedux.toolbar:CacheSafariHat()
    if not C_Item.GetItemInfo(C.SAFARI_HAT_ITEM_ID) then
        rematchRedux.timer:Start(0.1,rematchRedux.toolbar.CacheSafariHat)
    end
end

--[[ events ]]

function rematchRedux.toolbar:SPELL_UPDATE_COOLDOWN()
    self:SetCooldown(self.HealButton.Cooldown,"spell",C.REVIVE_SPELL_ID)
    self:SetCooldown(self.SummonPetButton.Cooldown,"spell",C.GCD_SPELL_ID)
    self:SetCooldown(self.SafariHatButton.Cooldown,"item",C.SAFARI_HAT_ITEM_ID)
    self:SetCooldown(self.BandageButton.Cooldown,C.BANDAGE_ITEM_ID)
    if self.LevelingStoneButton:IsVisible() then
        self:SetCooldown(self.LevelingStoneButton.Cooldown,"item",self.LevelingStoneButton:GetAttribute("item"))
        self:SetCooldown(self.RarityStoneButton.Cooldown,"item",self.RarityStoneButton:GetAttribute("item"))
    end
end

function rematchRedux.toolbar:COMPANION_UPDATE()
    self.SummonPetButton.needsUpdate = true
    self.LevelingStoneButton.needsUpdate = true
    self.RarityStoneButton.needsUpdate = true
    self:Update(true)
end

function rematchRedux.toolbar:UNIT_AURA(unit)
    if unit=="player" then
        self.SafariHatButton.needsUpdate = true
        self.LesserPetTreatButton.needsUpdate = true
        self.PetTreatButton.needsUpdate = true
        self:Update(true)
    end
end

function rematchRedux.toolbar:BAG_UPDATE_DELAYED()
    self.BandageButton.needsUpdate = true
    self.LesserPetTreatButton.needsUpdate = true
    self.PetTreatButton.needsUpdate = true
    self.LevelingStoneButton.needsUpdate = true
    self.RarityStoneButton.needsUpdate = true
    self:Update(true)
end

function rematchRedux.toolbar:PET_BATTLE_QUEUE_STATUS()
    self.FindBattleButton.needsUpdate = true
    rematchRedux.frame:Update() -- update loadouts too
    self:Update(true)
end

-- for Safari Hat Reminder, update safari hat button when loadouts change
function rematchRedux.toolbar:REMATCHREDUX_LOADOUTS_CHANGED()
    self.SafariHatButton.needsUpdate = true
    self:Update()
end

-- for Safari Hat Reminder, should only fire when frame is not shown
function rematchRedux.toolbar:REMATCHREDUX_TEAM_LOADED()
    if settings.SafariHatShine and not rematchRedux.frame:IsVisible() and not rematchRedux.utils:GetItemBuff(C.SAFARI_HAT_ITEM_ID) and PlayerHasToy(C.SAFARI_HAT_ITEM_ID) and rematchRedux.loadouts:NotAllMaxLevel() then
        rematchRedux.frame:Toggle(true)
    end
end

-- picks the best suited leveling or rarity stone depending on what pet is summoned
-- stoneList is either C.RARITY_STONES or C.LEVELING_STONES
-- defaultStone is either C.DEFAULT_LEVELING_STONE_ITEM_ID or C.DEFAULT_RARITY_STONE_ITEM_ID
-- if a pet is summoned, it will look for any itemIDs in the list for that type (first 10 entries)
-- if a pet is not summoned or one of the type-specific stones is not in inventory, it will display
-- the first itemID found in inventory in the remainer of the stoneList, or the given default if none
function rematchRedux.toolbar:PickBestStone(stoneList,defaultStone)
    local petID = C_PetJournal.GetSummonedPetGUID()
    local petInfo = rematchRedux.petInfo:Fetch(petID)
    local numTypes = C_PetJournal.GetNumPetTypes() -- going to be 10 until they add a pet type
    if petInfo.isValid then -- this pet is summoned, look for a battle-training stone for the summoned type
        local itemID = stoneList[petInfo.petType]
        if itemID and C_Item.GetItemCount(itemID)>0 then
            return itemID
        end
    end
    -- if here, either no pet was summoned or we ran out of pet type-specific battle-training stones
    -- look for one of the generic ones
    for i=numTypes+1,#stoneList do
        local itemID = stoneList[i]
        if C_Item.GetItemCount(itemID)>0 then
            return itemID
        end
    end
    -- none of the generic stones are in inventory either, return the "none found" default stone itemID given as an argument
    return defaultStone
end

-- wrapper for ever-changing cooldown methods (id is spellID for "spell", itemID for "item")
function rematchRedux.toolbar:SetCooldown(cooldown,cooldownType,id)
    if cooldownType=="spell" then
        local info = C_Spell.GetSpellCooldown(id)
        if info then
            cooldown:SetCooldown(info.startTime,info.duration,info.modRate)
        end
    elseif cooldownType=="item" then
        local startTime,duration = C_Item.GetItemCooldown(id)
        cooldown:SetCooldown(startTime,duration)
    end
end

--[[ achievment total ]]

function rematchRedux.toolbar.AchievementTotal:OnClick()
    ToggleAchievementFrame()
    if AchievementFrame:IsVisible() then
        -- some of this is lifted out of AchievementFrameCategories_SelectDefaultElementData() in Blizzard_AchievementUI.lua
        if not AchievementFrameCategories.ScrollBox:HasDataProvider() then
            AchievementFrameCategories_UpdateDataProvider()
        end
        -- find the Pet Battles index in the data provider
        local categoryIndex
        for index,info in AchievementFrameCategories.ScrollBox:GetDataProvider():Enumerate() do
            if info.id==C.PET_ACHIEVEMENT_CATEGORY then
                categoryIndex = index
            end
        end
        -- go to that category if it exists
        if categoryIndex then
            local elementData = AchievementFrameCategories.ScrollBox:ScrollToElementDataIndex(categoryIndex, ScrollBoxConstants.AlignCenter);
            if elementData then
                AchievementFrameCategories_SelectElementData(elementData)
            end
        end
    end
end

--[[ totals button ]]

function rematchRedux.toolbar.TotalsButton:OnEnter()
    self.Highlight:Show()
    local stats = rematchRedux.collectionInfo:GetCollectionStats()
    local tooltipBody = format(L["Unique Pets: %s%d\124r\nTotal Pets: %s%d\124r\nUncollected Pets: %s%d\124r\nAverage Level: %s%.1f\124r%s"],C.HEX_WHITE,stats.numCollectedUnique,C.HEX_WHITE,stats.numCollectedTotal,C.HEX_WHITE,stats.numUncollected,C.HEX_WHITE,stats.averageLevel,settings.HideMenuHelp and "" or format(L["\n\n%s Click for details"],C.LMB_TEXT_ICON))
    rematchRedux.tooltip:ShowSimpleTooltip(self,nil,tooltipBody)
end

function rematchRedux.toolbar.TotalsButton:OnLeave()
    self.Highlight:Hide()
    rematchRedux.tooltip:Hide()
end

function rematchRedux.toolbar.TotalsButton:OnMouseDown()
    self.Back:SetTexCoord(0,0.421875,0.125,0.234375)
    self.Text:SetPoint("CENTER",-1,-2)
end

function rematchRedux.toolbar.TotalsButton:OnMouseUp()
    if self:IsMouseMotionFocus() then
        self.Highlight:Show()
    end
    self.Back:SetTexCoord(0,0.421875,0,0.109375)
    self.Text:SetPoint("CENTER")
end

function rematchRedux.toolbar.TotalsButton:OnClick()
    rematchRedux.dialog:ToggleDialog(settings.MinimizePetSummary and "PetSummaryMinimized" or "PetSummary")
end


