local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.queuePanel = rematchRedux.frame.QueuePanel ---@diagnostic disable-line: undefined-field
rematchRedux.frame:Register("queuePanel")

local queueIndexes = {} -- for autoscrollbox, list of numeric indexes into settings.LevelingQueue

rematchRedux.events:Register(rematchRedux.queuePanel,"PLAYER_LOGIN",function(self)
    self.Top.QueueButton:SetText(L["Queue"])

    -- in case something weird happens, set sort order to default ascending
    if settings.QueueSortOrder~=C.QUEUE_SORT_ASC and settings.QueueSortOrder~=C.QUEUE_SORT_DESC and settings.QueueSortOrder~=C.QUEUE_SORT_MID then
        settings.QueueSortOrder = C.QUEUE_SORT_ASC
    end
    self.showingActiveSort = -1 -- ensure this is different than QueueActiveSort on first update

    self.List:Setup({
        allData = queueIndexes,
        normalTemplate = "RematchReduxNormalQueueListButtonTemplate",
        normalFill = self.FillNormal,
        normalHeight = 44,
        compactTemplate = "RematchReduxCompactQueueListButtonTemplate",
        compactFill = self.FillCompact,
        compactHeight = 26,
        isCompact = settings.CompactQueueList,
        selects = {
            PetCard = {color={0.33,0.66,1}, parentKey="Back", padding=0, drawLayer="ARTWORK"},
            Moving = {color={0,0,0,0.65}, tint=true, drawLayer="ARTWORK"}
        },
        onScroll = function(self,percent) if not rematchRedux.menus:IsMenuOpen("PetFilterMenu") and not rematchRedux.menus:IsMenuOpen("QueueMenu") then rematchRedux.menus:Hide() end end
    })

    self.List.Help:SetText(L["This is the leveling queue. Drag pets you want to level here.\n\nRight click any of the three battle pet slots and choose 'Put Leveling Pet Here' to mark it as a leveling slot you want controlled by the queue.\n\nWhile a leveling slot is active, the queue will fill the slot with the top-most pet in the queue. When this pet reaches level 25 (gratz!) it will leave the queue and the next pet in the queue will take its place.\n\nTeams saved with a leveling slot will reserve that slot for future leveling pets."])

end)

function rematchRedux.queuePanel:Update()
    self.Top.Label:SetText(format(L["Leveling Pets: %s%d"],C.HEX_WHITE,#settings.LevelingQueue))

    if settings.PreferencesPaused then -- if preferences paused, red X version of blue gear icon
        self.PreferencesFrame.PreferencesButton:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\badges-borderless",0.87890625,0.99609375,0.12890625,0.24609375)
    else -- preferences are not paused, regular blue gear icon
        self.PreferencesFrame.PreferencesButton:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\badges-borderless",0.75390625,0.87109375,0.12890625,0.24609375)
    end

    -- minor reconfiguration if gaining/losing active sort: show/hide status bar
    if self.showingActiveSort~=settings.QueueActiveSort then
        if settings.QueueActiveSort then
            self.StatusBar:Show()
            self.List:SetPoint("TOPLEFT",self.StatusBar,"BOTTOMLEFT",0,-2)
        else
            self.StatusBar:Hide()
            self.List:SetPoint("TOPLEFT",self.PreferencesFrame,"BOTTOMLEFT",0,-2)
        end
        self.showingActiveSort = settings.QueueActiveSort
    end
    -- if active sort enabled, update to display which sort
    if settings.QueueActiveSort then
        local sortText,sortIcon
        if settings.QueueSortOrder==C.QUEUE_SORT_ASC then
            sortText = L["Ascending Level"]
            sortIcon = rematchRedux.utils:GetBadgeAsText(24,18)
        elseif settings.QueueSortOrder==C.QUEUE_SORT_DESC then
            sortText = L["Descending Level"]
            sortIcon = rematchRedux.utils:GetBadgeAsText(26,18)
        elseif settings.QueueSortOrder==C.QUEUE_SORT_MID then
            sortText = L["Median Level"]
            sortIcon = rematchRedux.utils:GetBadgeAsText(25,18)
        end
        if sortText and sortIcon then
            self.StatusBar.Text:SetText(format(L["Active Sort:  %s %s%s"],sortIcon,C.HEX_WHITE,sortText))
        end
    end

    -- update queue
    rematchRedux.queue:Update()

    -- if queue size has changed, recreated indexes
    if #queueIndexes ~= #settings.LevelingQueue then
        wipe(queueIndexes)
        for i=1,#settings.LevelingQueue do
            tinsert(queueIndexes,i)
        end
    end

    self:UpdateGlow(true) -- true to skip refresh since about to do an Update

    -- update autoscrollbox list
    self.List:Update()
    -- show help text if queue is empty and Hide Extra Help disabled
    self.List.Help:SetShown(#settings.LevelingQueue==0 and not settings.HideMenuHelp)

    -- if any queue-related dialog is on screen when queue updates, close it in case indexes change
    self:CloseQueueDialogs()

end

function rematchRedux.queuePanel:UpdateGlow(skipRefresh)
    -- show GlowFrame is a pet is on cursor
    local petID,canLevel = rematchRedux.utils:GetPetCursorInfo(true)
    self.List.GlowFrame:SetShown(canLevel)
    self.List:Select("Moving",rematchRedux.queue:GetPetIndex(petID),skipRefresh)
end

function rematchRedux.queuePanel:OnShow()
    rematchRedux.events:Register(self,"REMATCHREDUX_TEAM_LOADED",self.Update)
    rematchRedux.events:Register(self,"REMATCHREDUX_PET_PICKED_UP_ON_CURSOR",self.REMATCHREDUX_PET_PICKED_UP_ON_CURSOR)
    rematchRedux.events:Register(self,"REMATCHREDUX_PET_DROPPED_FROM_CURSOR",self.REMATCHREDUX_PET_DROPPED_FROM_CURSOR)
    self:CloseQueueDialogs()
    self:UpdateGlow()
end

function rematchRedux.queuePanel:OnHide()
    rematchRedux.events:Unregister(self,"REMATCHREDUX_TEAM_LOADED")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_PET_PICKED_UP_ON_CURSOR")
    rematchRedux.events:Unregister(self,"REMATCHREDUX_PET_DROPPED_FROM_CURSOR")
    self:CloseQueueDialogs()
end

-- we need to be a little careful that dialogs don't remain on the screen when the queue indexes can be changing
function rematchRedux.queuePanel:CloseQueueDialogs()
    local openDialog = rematchRedux.dialog:GetOpenDialog()
    if openDialog=="StopActiveSort" or openDialog=="RemoveFromQueue" or openDialog=="FillQueue" or openDialog=="EmptyQueue" then
        rematchRedux.dialog:HideDialog()
    end
end

-- autoscrollbox fill
function rematchRedux.queuePanel:FillNormal(index)
    local info = settings.LevelingQueue[index]
    if info then
        --self.forQueue = true
        local notPreferred = not rematchRedux.preferences:IsPetPreferred(info.petID)
        self:Fill(info.petID,notPreferred)
        self:SetAlpha(notPreferred and 0.65 or 1)
    end
end

-- autoscrollbox fill
function rematchRedux.queuePanel:FillCompact(index)
    local info = settings.LevelingQueue[index]
    if info then
        --self.forQueue = true
        local notPreferred = not rematchRedux.preferences:IsPetPreferred(info.petID)
        self:Fill(info.petID,notPreferred)
        self:SetAlpha(notPreferred and 0.65 or 1)
    end
end

-- click of preferences button in topleft to edit or pause preferences for the loaded team
function rematchRedux.queuePanel.PreferencesFrame.PreferencesButton:OnClick(button)
    if button=="RightButton" then -- right click pauses/unpauses preferences
        rematchRedux.preferences:TogglePause()
    else -- left click opens current preferences dialog to change preferences
        local teamID = settings.currentTeamID
        local groupID = teamID and rematchRedux.savedTeams[teamID] and rematchRedux.savedTeams[teamID].groupID
        rematchRedux.dialog:ToggleDialog("CurrentPreferences",{teamID=teamID,groupID=groupID})
    end
end

-- onenter of preferences button shows the tooltip
function rematchRedux.queuePanel.PreferencesFrame.PreferencesButton:OnEnter()
    rematchRedux.tooltip:ShowSimpleTooltip(self,L["Leveling Preferences"],rematchRedux.preferences:GetTooltipBody())
end

-- onleave of preferences button
function rematchRedux.queuePanel.PreferencesFrame.PreferencesButton:OnLeave()
    rematchRedux.tooltip:Hide()
end

-- click of Queue button in topright to open the menu
function rematchRedux.queuePanel.Top.QueueButton:OnClick()
    rematchRedux.menus:Toggle("QueueMenu",self)
end

-- clear button on statusbar turns off active sort
function rematchRedux.queuePanel.StatusBar.Clear:OnClick()
    settings.QueueActiveSort = false
    if rematchRedux.menus:IsMenuOpen("QueueMenu") then
        rematchRedux.menus:Hide()
    end
    rematchRedux.queuePanel:Update()
end


--[[ queue drag and drop ]]

function rematchRedux.queuePanel:REMATCHREDUX_PET_PICKED_UP_ON_CURSOR()
    local petID,canLevel = rematchRedux.utils:GetPetCursorInfo(true)
    if canLevel then
        self.List.GlowFrame:Show()
        self.List:Select("Moving",rematchRedux.queue:GetPetIndex(petID))
    end
    if rematchRedux.dialog:GetOpenDialog()=="StopActiveSort" then
        rematchRedux.dialog:HideDialog()
    end
end

function rematchRedux.queuePanel:REMATCHREDUX_PET_DROPPED_FROM_CURSOR()
    self.List.GlowFrame:Hide()
    self.List:Select("Moving",nil)
    if rematchRedux.dialog:GetOpenDialog()=="StopActiveSort" then
        rematchRedux.dialog:HideDialog()
    end
end

function rematchRedux.queuePanel.List.GlowFrame:OnShow()
    if rematchRedux.layout:GetMode()==1 then
        self.GlowLine:SetWidth(C.LIST_BUTTON_WIDE_WIDTH-2)
    else
        self.GlowLine:SetWidth(C.LIST_BUTTON_NORMAL_WIDTH-2)
    end
    self.GlowLine:Hide()
    self.GlowLine.Animation:Play()
    rematchRedux.queuePanel.List.CaptureButton:SetScript("OnClick",rematchRedux.queuePanel.List.CaptureButton.OnClick)
    rematchRedux.queuePanel.List.CaptureButton:SetScript("OnReceiveDrag",rematchRedux.queuePanel.List.CaptureButton.OnClick) -- same as OnClick behavior
end

function rematchRedux.queuePanel.List.GlowFrame:OnHide()
    rematchRedux.queuePanel.List.CaptureButton:SetScript("OnClick",nil)
    rematchRedux.queuePanel.List.CaptureButton:SetScript("OnReceiveDrag",nil)
end

function rematchRedux.queuePanel.List.GlowFrame:OnUpdate(elapsed)
    local focus = GetMouseFoci()[1]
    if not focus then
        return -- while scrolling, focus becomes nil at times
    end
    if focus:GetObjectType()=="Texture" then
        focus = focus:GetParent() -- for script-enabled textures, get the parent listbutton
    end

    local cursorX,cursorY = GetCursorPosition()
    local scale = focus:GetEffectiveScale()
    local centerX,centerY = focus:GetCenter()

    local isMouseOver = self:IsMouseOver() -- is mouse over GlowFrame

    self.GlowLine.direction = nil -- potentially one of C.DRAG_DIRECTION_PREV/NEXT/END

    if isMouseOver then
        if focus and focus.petID then
            if (cursorY/scale)>centerY then -- if cursor is in top half of button, anchor to top
                self.GlowLine:SetPoint("CENTER",focus,"TOP")
                self.GlowLine.direction = C.DRAG_DIRECTION_PREV
            else -- otherwise anchor to bottom of button
                self.GlowLine:SetPoint("CENTER",focus,"BOTTOM")
                self.GlowLine.direction = C.DRAG_DIRECTION_NEXT
            end
            self.GlowLine:Show()
        elseif focus==rematchRedux.queuePanel.List.CaptureButton then -- cursor is over capture area, anchor to top
            self.GlowLine:SetPoint("CENTER",focus,"TOP")
            self.GlowLine:Show()
        end

    else
        self.GlowLine:Hide()
    end
end

-- click of capture area adds a pet to the queue (OnReceiveDrag also uses this same function)
function rematchRedux.queuePanel.List.CaptureButton:OnClick()
    local petID,canLevel = rematchRedux.utils:GetPetCursorInfo(true)
    if petID and canLevel then
        rematchRedux.queuePanel:ReceivePetID(petID,#settings.LevelingQueue+1)
    end
end

RematchReduxQueueListButtonMixin = {}

-- click override for queue listbutton: rightbutton for menu, if a pet that can level on cursor, receive in queue, otherwise pet card click
function RematchReduxQueueListButtonMixin:OnClick(button)
    local petID,canLevel = rematchRedux.utils:GetPetCursorInfo(true)
    if rematchRedux.petHerder:IsTargeting() then -- targeting with pet herder takes priority on clicks
        if button=="RightButton" then
            rematchRedux.dialog:Hide()
        else
            rematchRedux.petHerder:HerdPetID(self.petID)
        end
    elseif button=="RightButton" then
        rematchRedux.menus:Show("QueueListMenu",self,self.petID,"cursor")
    elseif petID and canLevel then
        self:OnReceiveDrag()
    else
        rematchRedux.cardManager:OnClick(rematchRedux.petCard,self,self.petID)
    end
end

-- called from OnClick too if leveling pet on mouse
function RematchReduxQueueListButtonMixin:OnReceiveDrag()
    local petID,canLevel = rematchRedux.utils:GetPetCursorInfo(true)
    local direction = rematchRedux.queuePanel.List.GlowFrame.GlowLine.direction
    if petID and canLevel then
        rematchRedux.queuePanel:ReceivePetID(petID,self.data+max(0,direction))
    end
end

-- for both capture button and list buttons, this puts the petID at the newIndex (moving from oldIndex if already in queue)
function rematchRedux.queuePanel:ReceivePetID(petID,newIndex)
    local isActiveSort = settings.QueueActiveSort
    local oldIndex = rematchRedux.queue:GetPetIndex(petID) -- if already in queue, then this pet is moving from one position to another
    if not isActiveSort and not oldIndex then
        rematchRedux.queue:InsertPetID(petID,newIndex) -- if not active sort and not in the queue, insert at position
    elseif not isActiveSort and oldIndex then
        rematchRedux.queue:MoveIndex(oldIndex,newIndex) -- if not active sort and in the queue, move from old to new position
    elseif isActiveSort and not oldIndex then
        rematchRedux.queue:InsertPetID(petID,newIndex) -- if active sort and not in the queue, simply add to queue and let it sort
        --rematchRedux.queue:AddPetID(petID)
    elseif isActiveSort and oldIndex then
        if settings.DontConfirmActiveSort then -- if Don't Ask To Stop Active Sort is enabled, can stop active sort and move right away
            settings.QueueActiveSort = false -- if active sort and in the queue, turn off active sort and move to new position
            rematchRedux.queue:MoveIndex(oldIndex,newIndex)
        else -- otherwise show a dialog and leave
            rematchRedux.dialog:ShowDialog("StopActiveSort",{petID=petID,newIndex=newIndex})
            return
        end
    end
    rematchRedux.queue:BlingPetID(petID)
    ClearCursor()
end