local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.frame = RematchReduxFrame

local modules = {} -- ordered list of modules (should be table/frames with Configure, Resize and/or Update functions)
local showAfterCombat = false -- flag that becomes true when RematchRedux was hidden due to combat and should return after combat
local chromeModules = {"titlebar","toolbar","bottombar","panelTabs","teamTabs"} -- for looping over these modules

-- when configure/resize/update happens, these fire after RematchRedux has finished its own configure/resize/update
local frameFuncEvents = {
    Configure = "REMATCHREDUX_UI_CONFIGURE",
    Resize = "REMATCHREDUX_UI_RESIZE",
    Update = "REMATCHREDUX_UI_UPDATE"
}

--[[
    rematchRedux.frame:Register(module)
    - Adds a module to an ordered list. If the module has a function named Configure, Resize or Update,
      those functions will be called (in the order the module was registered) when one of the following
      Configure, Resize or Updates happen in this module.

    rematchRedux.frame:Configure(layoutName)
    - Arranges all panels/chrome to the frame for the given layout (and whether it's for the journal), and
      calls all configure, resize and update functions for registered modules.

    rematchRedux.frame:Resize()
    - Calls all resize and update functions for registered modules to allow panels/chrome to adjust their
      content based on size changes.

    rematchRedux.frame:Update()
    - Calls all update functions for registered modules to update panel/chrome content.
]]

-- as described above, every panel or chrome that wants to run their Configure/Resize/Update needs to register here
-- module should be a parentKey of rematchRedux namespace
function rematchRedux.frame:Register(module)
    assert(type(module)=="string" and rematchRedux[module] and type(rematchRedux[module])=="table","Attempt to register an invalid module: "..tostring(module))
    tinsert(modules,rematchRedux[module])
end

rematchRedux.events:Register(rematchRedux.frame,"PLAYER_LOGIN",function(self)
    rematchRedux.events:Register(self,"PLAYER_ENTERING_WORLD",self.PLAYER_ENTERING_WORLD)
    rematchRedux.events:Register(self,"PET_BATTLE_OPENING_START",self.PET_BATTLE_OPENING_START)
    rematchRedux.events:Register(self,"REMATCHREDUX_PETS_LOADED",self.REMATCHREDUX_PETS_LOADED)
    rematchRedux.events:Register(self,"PLAYER_LOGOUT",self.PLAYER_LOGOUT)
    self.CloseButton:Hide() -- using titlebar's close button
end)

--[[ script handlers ]]

function rematchRedux.frame:OnMouseDown()
    if not rematchRedux.journal:IsActive() and (not settings.LockPosition or IsShiftKeyDown()) then
        self:StartMoving()
    end
end

function rematchRedux.frame:OnMouseUp()
    if not rematchRedux.journal:IsActive() then
        self:StopMovingOrSizing()
        self:SetUserPlaced(false)
        self:SavePosition()
    end
end

function rematchRedux.frame:OnShow()
    rematchRedux.events:Register(self,"PLAYER_TARGET_CHANGED",self.PLAYER_TARGET_CHANGED)
    rematchRedux.events:Register(rematchRedux.frame,"PLAYER_REGEN_DISABLED",rematchRedux.frame.PLAYER_REGEN_DISABLED)
    rematchRedux.events:Register(rematchRedux.frame,"PET_JOURNAL_LIST_UPDATE",rematchRedux.frame.PET_JOURNAL_LIST_UPDATE)
    if not rematchRedux.journal:IsActive() then
        PlaySound(C.SOUND_REMATCHREDUX_OPEN)
    end
end

function rematchRedux.frame:OnHide()
    rematchRedux.events:Unregister(self,"PLAYER_TARGET_CHANGED")
    rematchRedux.events:Unregister(rematchRedux.frame,"PLAYER_REGEN_DISABLED")
    rematchRedux.events:Unregister(rematchRedux.frame,"PET_JOURNAL_LIST_UPDATE")
    rematchRedux.utils:HideWidgets()
    rematchRedux.dialog:HideDialog() -- is there any reason for a dialog to remain up? if so, use version of uncommented code below
    -- local openDialog = rematchRedux.dialog:GetOpenDialog()
    -- if openDialog=="CustomScaleDialog" then
    --     rematchRedux.dialog.CancelButton:Click() -- if frame scale change is happening, cancel it if the frame hides before the dialog does
    -- end
    if rematchRedux.sort:ClearStickiedPetIDs() then
        rematchRedux.filters:ForceUpdate()
    end
    -- check if we need to prompt to backup teams
    rematchRedux.timer:Start(0.1,rematchRedux.teamStrings.CheckForBackup)
    if not rematchRedux.journal:IsActive() then
        PlaySound(C.SOUND_REMATCHREDUX_CLOSE)
    end
end

--[[ toggles ]]

-- toggles the RematchRedux window; if auto is true then it was summoned by interact or safari hat reminder
-- (or any "unattented" behavior)
function rematchRedux.frame:Toggle(auto)
    if rematchRedux.frame:IsVisible() then
        if rematchRedux.journal:IsActive() then
            ToggleCollectionsJournal()
        else
            rematchRedux.frame:Hide()
        end
    elseif not InCombatLockdown() then
        rematchRedux.frame:Show()
        rematchRedux.frame:Configure((auto and settings.PreferMinimized) and "0-minimized" or rematchRedux.layout:GetLayout(C.STANDALONE))
    else
        rematchRedux.utils:Write(L["RematchRedux can't be summoned during combat. Try again later"])
    end
end

_G.RematchReduxToggleWindow = rematchRedux.frame.Toggle

-- minimizes or maximizes the frame (if in standalone mode); optionally maximizes to the given layoutName
function rematchRedux.frame:ToggleMinimized(layoutName)
    if rematchRedux.journal:IsActive() then
        return -- in journal mode, do nothing
    elseif rematchRedux.layout:GetMode(C.CURRENT)==0 then -- currently minimized, restore maximized layout
        PlaySound(C.SOUND_PANEL_TAB)
        rematchRedux.frame:Configure(layoutName or rematchRedux.layout:GetLayout(C.MAXIMIZED))
    else -- not minimized, go to minimized layout
        PlaySound(C.SOUND_PANEL_TAB)
        rematchRedux.frame:Configure("0-minimized")
    end
end

--[[ events ]]

-- this event just handles whether the LoadedTargetPanel appears in layouts where it only sometimes shows (minimized, single-panel,
-- or 2-queue where there's no space for a persistent LoadedTargetPanel). if the target panel needs to show or hide, this adjusts
-- the current layout and does a Configure
function rematchRedux.frame:PLAYER_TARGET_CHANGED()
    local def = rematchRedux.layout:GetDefinition(C.CURRENT)
    if def and def.hasTempTarget then -- we're in a layout where the target panel can come and go depending on target
        local shouldShowTarget = rematchRedux.loadedTargetPanel:ShouldShowTarget()
        if shouldShowTarget and not def.subview then -- not showing target now but should show it
            rematchRedux.frame:Configure(format("%d-%s-target",def.mode,def.view))
        elseif not shouldShowTarget and def.subview=="target" then -- showing target now but shoundn't show it
            rematchRedux.frame:Configure(format("%d-%s",def.mode,def.view))
        end
    end
end

-- if LockWindow (Keep Window On Screen) is not checked, then hide the window when we get a loading screen (instances)
function rematchRedux.frame:PLAYER_ENTERING_WORLD()
    if not settings.LockWindow and not rematchRedux.journal:IsActive() then
        self:Hide()
    end
end

-- on entering a pet battle, close window unless both LockWindow and StayForBattle enabled
local lastNotedTeamID -- the currentTeamID that had notes last displayed (for Show Notes In Battle -> Only Once Per Team)
function rematchRedux.frame:PET_BATTLE_OPENING_START()
    if (not settings.LockWindow or not settings.StayForBattle) and not rematchRedux.journal:IsActive() then
        self:Hide()
    end
    -- if Show Notes In Battle enabled, show notes
    local teamID = settings.currentTeamID
    if teamID and rematchRedux.savedTeams[teamID] and rematchRedux.savedTeams[teamID].notes and settings.ShowNotesInBattle then
        if not settings.ShowNotesOnce or lastNotedTeamID~=teamID then
            rematchRedux.cardManager:ShowCard(rematchRedux.notes,teamID)
        end
    end
    lastNotedTeamID = teamID
end

-- on login after pets are loaded, open window if LockWindow and StayOnLogout enabled
function rematchRedux.frame:REMATCHREDUX_PETS_LOADED()
    if settings.LockWindow and settings.StayOnLogout and not rematchRedux.frame:IsVisible() and settings.WasShownOnLogout then
        self:Toggle()
    end
end

function rematchRedux.frame:PLAYER_LOGOUT()
    settings.WasShownOnLogout = rematchRedux.frame:IsVisible()
end

-- RematchRedux can't remain on screen during combat; if it's up as player enters combat, hide it but set a flag to bring it back after
function rematchRedux.frame:PLAYER_REGEN_DISABLED()
    if rematchRedux.frame:IsVisible() and not rematchRedux.journal:IsActive() then -- journal will handle combat on its own
        rematchRedux.frame:Hide()
        showAfterCombat = true
        -- register for leaving combat to know to bring window back
        rematchRedux.events:Register(rematchRedux.frame,"PLAYER_REGEN_ENABLED",rematchRedux.frame.PLAYER_REGEN_ENABLED)
    end
end

-- after combat ends, if flag was set when RematchRedux was hidden entering combat, then bring the window back
function rematchRedux.frame:PLAYER_REGEN_ENABLED()
    if showAfterCombat then
        showAfterCombat = false
        -- can stop watching for this event until next showAfterCombat happens
        rematchRedux.events:Unregister(rematchRedux.frame,"PLAYER_REGEN_ENABLED")
        -- show the window in its last standalone state
        rematchRedux.frame:Toggle()
    end
end

-- this can fire for pets changing (level, rarity, name, etc) as well as gaining/losing pets
function rematchRedux.frame:PET_JOURNAL_LIST_UPDATE()
    if not rematchRedux.filters:IsAllClear() then
        rematchRedux.filters:ForceUpdate() -- in case any pets fall out of filtering criteria
    end
    rematchRedux.timer:Start(0,self.Update)
end

--[[ Configure ]]

-- returns the layoutName,definition from the given layoutName (or current if none given)
-- if the view is invalid (like 3-pets) it will adjust to a valid view
local function negotiateLayout(layoutName)
    layoutName = rematchRedux.layout:GetLayout(layoutName) -- validating layoutName and adjusting if needed
    local def = rematchRedux.layout:GetDefinition(layoutName)

    -- if this is a layout with a TargetPanel only displayed while something saved is targeted, change layout if needed
    if def and def.hasTempTarget then
        local shouldShowTarget = rematchRedux.loadedTargetPanel:ShouldShowTarget()
        if shouldShowTarget and not def.subview then
            layoutName = rematchRedux.layout:GetLayout(format("%d-%s-target",def.mode,def.view))
            def = rematchRedux.layout:GetDefinition(layoutName)
        elseif not shouldShowTarget and def.subview=="target" then
            layoutName = rematchRedux.layout:GetLayout(format("%d-%s",def.mode,def.view))
            def = rematchRedux.layout:GetDefinition(layoutName)
        end
    end

    return layoutName,def
end

-- anchors chrome frames
local function anchorChrome(layoutName,def)
    local chromeHeight,chromeYOffset
    if def.mode==0 then -- toolbar at bottom always minimized and never in 3-panel mode
        chromeHeight = C.TOOLBAR_HEIGHT + 5
        chromeYOffset = C.TOOLBAR_HEIGHT + 5
        rematchRedux.toolbar:SetPoint("TOPLEFT",rematchRedux.frame.Canvas,"BOTTOMLEFT",0,-2)
        rematchRedux.toolbar:SetPoint("BOTTOMRIGHT",rematchRedux.frame.Canvas,"BOTTOMRIGHT",0,-C.TOOLBAR_HEIGHT-2)
        rematchRedux.bottombar:Hide()
    else
        chromeHeight = C.TOOLBAR_HEIGHT + 2 + C.BOTTOMBAR_HEIGHT + 2
        chromeYOffset = C.BOTTOMBAR_HEIGHT + 2
        rematchRedux.toolbar:SetPoint("TOPLEFT",rematchRedux.frame.Canvas,"TOPLEFT",0,C.TOOLBAR_HEIGHT+2)
        rematchRedux.toolbar:SetPoint("BOTTOMRIGHT",rematchRedux.frame.Canvas,"TOPRIGHT",0,2)
        rematchRedux.bottombar:SetPoint("TOPLEFT",rematchRedux.frame.Canvas,"BOTTOMLEFT",0,-2)
        rematchRedux.bottombar:SetPoint("BOTTOMRIGHT",rematchRedux.frame.Canvas,"BOTTOMRIGHT",0,-C.BOTTOMBAR_HEIGHT-2)
        rematchRedux.bottombar:Show()
    end
    return chromeHeight,chromeYOffset
end


-- anchors panels to the canvas for the given layout
local function applyLayout(layoutName,def)
    -- hide all known panels that aren't used in this layout definition
    rematchRedux.layout:HidePanels(def)

    -- set size of canvas from layout definition
    rematchRedux.frame.Canvas:SetSize(def.width,def.height)

    -- anchor and show all panels that are in this layout definition
    for _,info in ipairs(def.panels) do
        local panel = rematchRedux.frame[info[1]]
        if panel then -- we've already asserted all elements of the panel are defined when registering
            panel:SetPoint(info[2],rematchRedux.frame[info[3]],info[4],info[5],info[6])
            panel:SetPoint(info[7],rematchRedux.frame[info[8]],info[9],info[10],info[11])
            panel:Show()
        end
    end

    -- saving layouts
    settings.CurrentLayout = def.layoutName -- regardless of journal/standalone, save new layout
    if rematchRedux.journal:IsActive() then -- if in journal, save new journal layout
        settings.JournalLayout = def.layoutName
        settings.LastOpenLayout = def.layoutName
        settings.LastOpenJournal = true
    else -- not in journal
        settings.StandaloneLayout = def.layoutName -- regardless of minimize state, save standalone layout
        if def.mode~=0 then
            settings.MaximizedLayout = def.layoutName -- for unminimized views, saved maximized layout
            settings.LastOpenLayout = def.layoutName
            settings.LastOpenJournal = false
        end
    end
end

-- runs the Configure/Resize/Update function for all chrome and all panels used in the layout definition
local function runFrameFuncs(func,def)
    for _,chrome in ipairs(chromeModules) do
        if rematchRedux[chrome] and type(rematchRedux[chrome][func])=="function" then
            rematchRedux[chrome][func](rematchRedux[chrome])
        end
    end
    -- then again for panels that are used
    for _,module in ipairs(modules) do
        if def.panelsUsed[module] then
            if type(module[func])=="function" then
                module[func](module)
            end
        end
    end
    if frameFuncEvents[func] then
        rematchRedux.events:Fire(frameFuncEvents[func])
    end
end

-- can call this without any parameter to re-configure current layout; or pass a layoutName to configure
-- to the given layout (it's ok if layout is slightly off like 3-pets, it will adjust to a valid layout if possible)
function rematchRedux.frame:Configure(newLayoutName)

    -- validate/adjust layoutName,definition
    local layoutName,def = negotiateLayout(newLayoutName)
    if layoutName and def then

        rematchRedux.utils:HideWidgets()

        -- handle the toolbar and bottombar
        local chromeHeight,chromeYOffset = anchorChrome(layoutName,def)
        -- size the parent frame based on the canvas size of the layout
        rematchRedux.frame:SetSize(def.width + C.FRAME_LEFT_MARGIN + C.FRAME_RIGHT_MARGIN, def.height + C.FRAME_TOP_MARGIN + C.FRAME_BOTTOM_MARGIN + chromeHeight)
        -- position canvas; for now ignoring toolbar and bottombuttons
        rematchRedux.frame.Canvas:SetPoint("BOTTOMLEFT",rematchRedux.frame,"BOTTOMLEFT",C.FRAME_LEFT_MARGIN,3+chromeYOffset)
        -- apply the layout (position frames)
        applyLayout(layoutName,def)
        -- run config/resize/update for all chrome and used panels
        runFrameFuncs("Configure",def)
        runFrameFuncs("Resize",def)
        runFrameFuncs("Update",def)
        -- anchor frame depending on saved
        if rematchRedux.journal:IsActive() then
            rematchRedux.frame:ClearAllPoints()
            rematchRedux.frame:SetPoint("BOTTOMLEFT",CollectionsJournal,"BOTTOMLEFT",-1,0)
        else
            rematchRedux.frame:RestorePosition()
            rematchRedux.frame:SetFrameStrata(settings.LowerStrata and "LOW" or "MEDIUM")
        end
    else
        assert(false,"Layout "..(newLayoutName or "nil").." can't resolve to valid layout.")
    end
    rematchRedux.frame:UpdateScale()
    self:EnableMouse(not rematchRedux.journal:IsActive())
end

-- runs resize and update funcs for all chrome and all panels used in current layout
function rematchRedux.frame:Resize()
    local def = rematchRedux.layout:GetDefinition(C.CURRENT)
    runFrameFuncs("Resize",def)
    runFrameFuncs("Update",def)
end

-- runs update for all chrome and all panels used in current layout
function rematchRedux.frame:Update()
    local def = rematchRedux.layout:GetDefinition(C.CURRENT)
    runFrameFuncs("Update",def)
    if rematchRedux.petCard:IsVisible() then
        rematchRedux.petCard:Update()
    end
end

--[[ anchoring ]]

-- saves the current position of the frame with respect to its anchor in settings
function rematchRedux.frame:SavePosition()
    if not self:IsVisible() or not self:GetLeft() or rematchRedux.journal:IsActive() then
        return -- only save position if it's on screen, anchored and not in journal mode
    end
    local anchor = settings.Anchor
    if anchor=="BOTTOMLEFT" then
        settings.XPos,settings.YPos = self:GetLeft(),self:GetBottom()
    elseif anchor=="TOPLEFT" then
        settings.XPos,settings.YPos = self:GetLeft(),self:GetTop()
    elseif anchor=="TOP" then
        settings.XPos,settings.YPos = (self:GetCenter()),self:GetTop()
    elseif anchor=="TOPRIGHT" then
        settings.XPos,settings.YPos = self:GetRight(),self:GetTop()
    elseif anchor=="BOTTOMRIGHT" then
        settings.XPos,settings.YPos = self:GetRight(),self:GetBottom()
    elseif anchor=="BOTTOM" then
        settings.XPos,settings.YPos = (self:GetCenter()),self:GetBottom()
    end
end

-- called when frame configured or shown, it positions the frame to savedsettings, or saves position if none saved
function rematchRedux.frame:RestorePosition()
    if settings.XPos and settings.YPos then
        self:ClearAllPoints()
        self:SetPoint(settings.Anchor,UIParent,"BOTTOMLEFT",settings.XPos,settings.YPos)
    else
        self:SavePosition()
    end
end

-- changes the Anchor setting to one of "BOTTOMLEFT", "TOPLEFT", "TOP", "TOPRIGHT", "BOTTOMRIGHT" or "BOTTOM"
function rematchRedux.frame:ChangeAnchor(anchor)
    assert(anchor=="BOTTOMLEFT" or anchor=="TOPLEFT" or anchor=="TOP" or anchor=="TOPRIGHT" or anchor=="BOTTOMRIGHT" or anchor=="BOTTOM","Anchor "..(anchor or nil).." is invalid.")
    rematchRedux.settings.Anchor = anchor
    rematchRedux.settings.PanelTabAnchor = anchor
    if rematchRedux.frame:IsVisible() and not rematchRedux.journal:IsActive() then
        rematchRedux.frame:SavePosition()
        rematchRedux.frame:Configure(C.CURRENT)
    end
end

-- only standalone window can scale; call this for each configure and when scale settings change
function rematchRedux.frame:UpdateScale()
    if settings.CustomScale and not rematchRedux.journal:IsActive() then
        local scale = max(50,min(tonumber(settings.CustomScaleValue) or 100,200))/100
        rematchRedux.frame:SetScale(scale)
    else
        rematchRedux.frame:SetScale(1)
    end
    if rematchRedux.frame:IsVisible() then
        rematchRedux.frame:SavePosition()
    end
end