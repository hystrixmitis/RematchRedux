local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.optionsPanel = rematchRedux.frame.OptionsPanel
rematchRedux.frame:Register("optionsPanel")

-- ordered list of indexes into rematchRedux.optionsList to display
local optionIndexes = {}
-- indexed by var, sub-tables of ordered list of option indexes that are dependent on this index (for search hits)
local searchDependencies = {}

-- indexed by dropdown setting name (var in optionsList), the listbutton control made for the setting
local dropDownFrames = {}

rematchRedux.events:Register(rematchRedux.optionsPanel,"PLAYER_LOGIN",function(self)
    self.Top.SearchBox.Instructions:SetText(L["Search Options"])
    -- expanded headers savedvar
    if type(settings.ExpandedOptionsHeaders)~="table" then
        settings.ExpandedOptionsHeaders = {}
    end

    -- when no breed addon loaded, then remove breed options (do any list removal before autoscrollbox setup)
    if not rematchRedux.breedInfo:IsAnyBreedAddOnLoaded() then
        for index=#rematchRedux.optionsList,1,-1 do
            local info = rematchRedux.optionsList[index]
            if info.group==18 then -- remove all entries in Breed Options
                tremove(rematchRedux.optionsList,index)
                if info.type=="header" then -- and nil its expanded header if it was open
                    settings.ExpandedOptionsHeaders[index] = nil
                end
            end
            -- remove "Always Hide Possible Breeds" from Pet Card Options or "Prioritize Breed On Import" on Team Options
            if info.var=="PetCardHidePossibleBreeds" or info.var=="PrioritizeBreedOnImport" then
                tremove(rematchRedux.optionsList,index)
            end
        end
    end

    -- if soft target is not fully enabled (SoftTargetInteract is 3) then hide soft target dropdown
    if GetCVar("SoftTargetInteract")~="3" then
        for index=#rematchRedux.optionsList,1,-1 do
            local info = rematchRedux.optionsList[index]
            if info.var=="InteractOnSoftInteract" then
                tremove(rematchRedux.optionsList,index)
            end
        end
        settings.InteractOnSoftInteract = C.INTERACT_NONE
    end

    -- for autoScrollBox, using the indexes into optionsList
    for index in ipairs(rematchRedux.optionsList) do
        tinsert(optionIndexes,index)
    end
    -- for search hits, build dependency references
    for index,info in ipairs(rematchRedux.optionsList) do
        if info.dependency then
            if not searchDependencies[info.dependency] then
                searchDependencies[info.dependency] = {}
            end
            tinsert(searchDependencies[info.dependency],index)
        end
    end
    -- setup autoScrollBox
    self.List:Setup({
        allData = optionIndexes,
        normalTemplate = "RematchReduxOptionsNormalTemplate",
        normalFill = self.FillNormal,
        normalHeight = 26,
        headerTemplate = "RematchReduxOptionsHeaderTemplate",
        headerFill = self.FillHeader,
        headerCriteria = self.HeaderCriteria,
        headerHeight = 26,
        expandedHeaders = settings.ExpandedOptionsHeaders,
        allButton = self.Top.AllButton,
        searchBox = self.Top.SearchBox,
        searchHit = self.SearchHit,
    })
    -- setup widgets
    for widget,setup in pairs(self.widgetSetup) do
        setup(self[widget])
    end
    -- go through all options and if any have runOnLogin set, then run their functions (named func is a member of rematchRedux.optionsPanel.funcs)
    for _,info in ipairs(rematchRedux.optionsList) do
        if info.runOnLogin and rematchRedux.optionsPanel.funcs[info.runOnLogin] then
            rematchRedux.optionsPanel.funcs[info.runOnLogin](self,info)
        end
    end

    -- register CustomScaleDialog
    rematchRedux.dialog:Register("CustomScaleDialog",{
        title = L["Use Custom Scale"],
        accept = SAVE,
        cancel = CANCEL,
        other = RESET,
        layout = {"Text","Slider"},
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                self.Text:SetText(L["The standalone window can be scaled from 50% to 200% of its normal size:"])
                self.Slider:Setup(settings.CustomScaleValue or 100,50,200,30,"%d%%",function(self,value)
                    settings.CustomScaleValue=value
                    rematchRedux.frame:UpdateScale()
                    rematchRedux.optionsPanel:Update()
                end)
                self.originalValue = settings.CustomScaleValue
            end
        end,
        otherFunc = function(self,info,subject)
            settings.CustomScaleValue = 100
            rematchRedux.frame:UpdateScale()
            rematchRedux.optionsPanel:Update()
        end,
        cancelFunc = function(self,info,subject)
            settings.CustomScaleValue = self.originalValue
            rematchRedux.frame:UpdateScale()
            rematchRedux.optionsPanel:Update()
        end
    })

    rematchRedux.dialog:Register("ExportOptions",{
        title = L["Export Options"],
        accept = OKAY,
        layout = {"Text","MultiLineEditBox","Help"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(L["Press Ctrl+C to copy to clipboard"])
            self.Help:SetText(L["This is intended to help troubleshoot issues.\n\nMany options interact with other options. When reporting a problem this can help recreate the issue."])
            self.MultiLineEditBox:SetText(subject or "",true)
            self.MultiLineEditBox:ScrollToTop()
        end,
        changeFunc = function(self,info,subject)
            self.MultiLineEditBox:SetText(subject or "",true)
            self.MultiLineEditBox:ScrollToTop()
        end
    })

    rematchRedux.dialog:Register("ImportOptions",{
        title = L["Import Options"],
        accept = L["Import"],
        cancel = CANCEL,
        layout = {"Text","SmallText","MultiLineEditBox","Feedback"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Text:SetText(L["Press Ctrl+V to paste from clipboard"])
            self.SmallText:SetText(format(L["This will reset most options, set them to values pasted here, then reload the UI. %sUse this at your own risk!\124r Tinkering with these values can cause RematchRedux to become unstable and require a full reset."],C.HEX_RED))
            self.Feedback:Set("warning",L["This will reset most options!\nThis cannot be undone!"])
            rematchRedux.dialog.AcceptButton:Disable()
            self.MultiLineEditBox:SetText("")
        end,
        changeFunc = function(self,info,subject)
            local import = (self.MultiLineEditBox:GetText() or ""):trim()
            if import:len()>0 and not import:match("[A-Za-z0-9_]+=[A-Za-z0-9_%s]+") then
                self.Feedback:Set("warning","Invalid options")
                rematchRedux.dialog.AcceptButton:Disable()
            else
                self.Feedback:Set("warning",L["This will reset most options!\nThis cannot be undone!"])
                rematchRedux.dialog.AcceptButton:SetEnabled(import:len()>0)
            end
        end,
        acceptFunc = function(self,info,subject)
            local import = (self.MultiLineEditBox:GetText() or ""):trim()
            if import:len()>0 then
                rematchRedux.optionsPanel:ImportOptions(import)
            end
        end
    })

    rematchRedux.dialog:Register("ResetOptions",{
        title = L["Reset Options"],
        accept = YES,
        cancel = NO,
        prompt = L["Restore all options to default?"],
        layout = {"Icon","Text","Feedback"},
        refreshFunc = function(self,info,subject,firstRun)
            self.Icon:SetTexture("Interface\\ICONS\\Ability_Creature_Cursed_02")
            self.Icon:SetTexCoord(0.075,0.925,0.075,0.925)
            self.Text:SetText(L["This will restore all options in RematchRedux to default values and reload the UI.\n\nThis includes all settings in the Options panel but does not include teams, leveling queue or notes."])
            self.Feedback:Set("warning",L["Warning: This cannot be undone!"])
        end,
        acceptFunc = function(self,info,subject)
            for k,v in pairs(settings:GetDefaults()) do
                if type(v)~="table" then
                    settings[k] = v
                end
            end
            ReloadUI()
        end,
    })

end)

local function clearWidget(self)
    if self.widget and self.widget:GetParent()==self then
        self.widget:ClearAllPoints()
        self.widget:SetParent(rematchRedux.optionsPanel)
        self.widget:Hide()
        self.widget = nil
    end
end

-- updates the options panel
function rematchRedux.optionsPanel:Update()
    self.List:Update()
    for widget,update in pairs(self.widgetUpdate) do
        update(self[widget])
    end
end

-- returns the dropdown listbutton frame for the given variable, creating and initializing it if needed
function rematchRedux.optionsPanel:GetDropDownFrame(var)
    local frame = var and dropDownFrames[var]
    if frame then
        return frame
    elseif var then -- frame for this dropdown doesn't exist, go get its details and build it
        for _,info in ipairs(rematchRedux.optionsList) do
            if info.var==var then
                frame = CreateFrame("Button",nil,self,"RematchReduxOptionsDropDownTemplate")
                if info.tooltip then
                    frame.tooltipTitle = info.text
                    frame.tooltipBody = info.tooltip
                end
                frame.Label:SetText(info.text..":")
                frame.DropDown:BasicSetup(info.menu,function(value)
                    settings[var] = value
                    if info.func and self.funcs[info.func] then
                        self.funcs[info.func](frame,value)
                    end
                    if info.update then
                        rematchRedux.frame:Update()
                    end
                end)
                frame.DropDown:SetSelection(settings[var])
                dropDownFrames[var] = frame
                return frame
            end
        end
    end
end

-- when a dropdown affects other dropdowns, this should be called on those others to change their value
function rematchRedux.optionsPanel:UpdateDropDown(var)
    local frame = var and dropDownFrames[var]
    if frame then
        frame.DropDown:SetSelection(settings[var])
    end
end

-- returns true if the index is a header
function rematchRedux.optionsPanel:HeaderCriteria(index)
    local info = rematchRedux.optionsList[index]
    return info and info.type=="header" or false
end

-- fills a header button with details at index
function rematchRedux.optionsPanel:FillHeader(index)
    self.index = index
    self.info = rematchRedux.optionsList[index]
    if not self.info then return end
    self.Text:SetText(self.info.text)
    self:SetBack()
    self:SetExpanded(rematchRedux.optionsPanel.List:IsHeaderExpanded(index),rematchRedux.optionsPanel.List:IsSearching())
end

-- fills a normal (non-header) button with details at the index
function rematchRedux.optionsPanel:FillNormal(index)
    self.index = index
    self.info = rematchRedux.optionsList[index]
    if not self.info then return end
    if self.info.type=="check" then
        self.Check:Show()
        self.Text:Show()
        clearWidget(self)
        local xoff = settings[self.info.var] and 0.25 or 0
        self.Check:SetTexCoord(0+xoff,0.25+xoff,0.5,0.75)
        self.Check:SetDesaturated(self.info.dependency and not settings[self.info.dependency])
        self.Check:SetPoint("LEFT",self.info.dependency and 16 or 0,0)
        self.dependencyUnchecked = self.info.dependency and not settings[self.info.dependency]

        if settings[self.info.var]==nil then -- temporary, when a default doesn't exist for this setting, make it red
            self.Text:SetTextColor(1,0.5,0.5)
        elseif self.dependencyUnchecked then -- dependent option disabled, grey this one
            self.Text:SetTextColor(0.5,0.5,0.5)
        else -- for everything else, white text
            self.Text:SetTextColor(0.9,0.9,0.9)
        end
        self.Text:SetPoint("LEFT",self.Check,"RIGHT",2,0)
        self.Text:SetText(self.info.text)
    elseif self.info.type=="text" then
        self.Check:Hide()
        self.Text:Show()
        clearWidget(self)
        self.Text:SetTextColor(0.9,0.9,0.9)
        self.Text:SetPoint("LEFT",6,0)
        self.Text:SetText(self.info.text)
    elseif self.info.type=="dropdown" then
        self.Check:Hide()
        self.Text:Hide()
        clearWidget(self)
        local dropdown = rematchRedux.optionsPanel:GetDropDownFrame(self.info.var)
        dropdown:ClearAllPoints()
        dropdown:SetParent(self)
        dropdown:SetAllPoints(true)
        dropdown:Show()
        self.widget = dropdown
    elseif self.info.type=="widget" then
        self.Check:Hide()
        self.Text:Hide()
        clearWidget(self)
        local widget = rematchRedux.optionsPanel[self.info.parentKey]
        widget:ClearAllPoints()
        widget:SetParent(self)
        widget:SetAllPoints(true)
        widget:Show()
        self.widget = widget
    end
end

function rematchRedux.optionsPanel:SearchHit(mask,index)
    local info = rematchRedux.optionsList[index]
    if info.text and rematchRedux.utils:match(mask,info.text,info.tooltip) then
        return true -- this option was a search hit
    end
    -- while this option didn't match, see if it has dependants that do
    if info.var and searchDependencies[info.var] then
        for _,dependant in ipairs(searchDependencies[info.var]) do
            if rematchRedux.optionsPanel.SearchHit(self,mask,dependant) then
                return true -- if at least one dependant was a hit, list this dependency
            end
        end
    end
    return false
end

RematchReduxOptionsListButtonMixin = {}

function RematchReduxOptionsListButtonMixin:OnEnter()
    if self.info and not self.dependencyUnchecked and (not rematchRedux.optionsPanel.List:IsSearching() or self.info.type~="header") then
        if self.info.type=="header" then
            rematchRedux.textureHighlight:Show(self.Back,self.ExpandIcon)
        elseif self.info.type=="check" then
            rematchRedux.textureHighlight:Show(self.Check)
        end
    end
    if self.info and self.info.tooltip then
        if self.info.type=="check" then
            rematchRedux.tooltip:ShowSimpleTooltip(self,self.info.text,self.info.tooltip)
        end
    end
end

function RematchReduxOptionsListButtonMixin:OnLeave()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.tooltip:Hide()
end

function RematchReduxOptionsListButtonMixin:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxOptionsListButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        self:OnEnter()
    end
end

-- onclick shared by header and non-header
function RematchReduxOptionsListButtonMixin:OnClick()
    if not self.info or self.dependencyUnchecked then
        return -- don't click anything unknown or if dependency unchecked
    end
    if self.info.type=="header" then
        rematchRedux.optionsPanel.List:ToggleHeader(self.index)
        PlaySound(C.SOUND_HEADER_CLICK)
    elseif self.info.type=="check" then
        if settings[self.info.var]==nil then
            return -- for settings in development; don't update settings that don't have a default (they'll be colored red)
        end
        settings[self.info.var] = not settings[self.info.var]
        if self.info.func then -- if there's a function to run, run that
            rematchRedux.optionsPanel.funcs[self.info.func](self)
        end
        if self.info.update then -- if not and whole UI should be updated
            rematchRedux.frame:Update()
        else -- otherwise just update options panel
            rematchRedux.optionsPanel:Update()
        end
        PlaySound(C.SOUND_CHECKBUTTON)
    end
end

--[[ option funcs (to run when an option changes) ]]

rematchRedux.optionsPanel.funcs = {}

function rematchRedux.optionsPanel.funcs:InteractOnTarget(value)
    if value~=C.INTERACT_NONE then
        settings.InteractOnSoftInteract = C.INTERACT_NONE
        settings.InteractOnMouseover = C.INTERACT_NONE
        rematchRedux.optionsPanel:UpdateDropDown("InteractOnSoftInteract")
        rematchRedux.optionsPanel:UpdateDropDown("InteractOnMouseover")
    end
    rematchRedux.interact:Update()
end

function rematchRedux.optionsPanel.funcs:InteractOnSoftInteract(value)
    if value~=C.INTERACT_NONE then
        settings.InteractOnTarget = C.INTERACT_NONE
        settings.InteractOnMouseover = C.INTERACT_NONE
        rematchRedux.optionsPanel:UpdateDropDown("InteractOnTarget")
        rematchRedux.optionsPanel:UpdateDropDown("InteractOnMouseover")
    end
    rematchRedux.interact:Update()
end

function rematchRedux.optionsPanel.funcs:InteractOnMouseover(value)
    if value~=C.INTERACT_NONE then
        settings.InteractOnTarget = C.INTERACT_NONE
        settings.InteractOnSoftInteract = C.INTERACT_NONE
        rematchRedux.optionsPanel:UpdateDropDown("InteractOnTarget")
        rematchRedux.optionsPanel:UpdateDropDown("InteractOnSoftInteract")
    end
    rematchRedux.interact:Update()
end

function rematchRedux.optionsPanel.funcs:Anchor(anchor)
    -- changing anchor while in journal mode (or while window is not on screen) messes up anchoring
    if rematchRedux.journal:IsActive() then
        rematchRedux.frame:Toggle() -- hide journal
        rematchRedux.frame:Toggle() -- show standalone window
        if rematchRedux.layout:GetMode()==0 then
            rematchRedux.frame:ToggleMinimized()
        end
    end
    rematchRedux.frame:ChangeAnchor(anchor)
    rematchRedux.optionsPanel:UpdateDropDown("PanelTabAnchor")
end

function rematchRedux.optionsPanel.funcs:PanelTabAnchor(anchor)
    if rematchRedux.frame:IsVisible() and not rematchRedux.journal:IsActive() then
        rematchRedux.frame:Configure(C.CURRENT)
    end
end

-- when checking UseDefaultJournal while in the journal, turn off the journal (like bottombar's RematchRedux checkbutton)
function rematchRedux.optionsPanel.funcs:UseDefaultJournal()
    if settings.UseDefaultJournal and rematchRedux.journal:IsActive() then
        rematchRedux.frame:Hide()
        rematchRedux.frame:SetParent(UIParent)
        PetJournal:Show()
        PetJournal_UpdatePetLoadOut() -- in case journal wasn't keeping up while RematchRedux was doing stuff
    end
end

-- Standalone Window Options: Lower Window Behind UI; toggles the framestrata between LOW and MEDIUM
function rematchRedux.optionsPanel.funcs:LowerStrata()
    if not rematchRedux.journal:IsActive() then
        rematchRedux.frame:SetFrameStrata(settings.LowerStrata and "LOW" or "MEDIUM")
    end
end

function rematchRedux.optionsPanel.funcs:ConfigureToolbar()
    rematchRedux.toolbar:Configure()
end

function rematchRedux.optionsPanel.funcs:CompactPetList()
    rematchRedux.petsPanel.List:SetCompactMode(settings.CompactPetList)
    rematchRedux.petsPanel.List:Update()
end

function rematchRedux.optionsPanel.funcs:CompactTeamList()
    rematchRedux.teamsPanel.List:SetCompactMode(settings.CompactTeamList)
    rematchRedux.teamsPanel.List:Update()
end

function rematchRedux.optionsPanel.funcs:CompactTargetList()
    rematchRedux.targetsPanel.List:SetCompactMode(settings.CompactTargetList)
    rematchRedux.targetsPanel.List:Update()
end

function rematchRedux.optionsPanel.funcs:CompactQueueList()
    rematchRedux.queuePanel.List:SetCompactMode(settings.CompactQueueList)
    rematchRedux.queuePanel.List:Update()
end

-- any option that can change the results of the filtered list (including sort) should run this if the option changes
function rematchRedux.optionsPanel.funcs:UpdateFilters()
    rematchRedux.filters:ForceUpdate() -- sets the dirty flag so the filtered list is rerun in the update
    rematchRedux.petsPanel:Update()
end

-- Pet Filter Options: Allow Hidden Pets; turn off filter it was enabled
function rematchRedux.optionsPanel.funcs:UpdateHiddenPetFilter()
    rematchRedux.filters:Set("Other","Hidden",nil)
    rematchRedux.menus:Hide() -- in case Other filter menu is up (hide the Hidden Pets filter)
    rematchRedux.filters:ForceUpdate()
    rematchRedux.petsPanel:Update()
end

-- any option that can change the pet card
function rematchRedux.optionsPanel.funcs:UpdatePetCard()
    if rematchRedux.petCard:IsVisible() then
        rematchRedux.petCard:Update()
    end
end

-- Pet Card Options: Allow Pet Cards To Be Pinned; unpin it if option unchecked and snap card back to its relativeTo
function rematchRedux.optionsPanel.funcs:UpdatePetCardPin()
    if rematchRedux.petCard:IsVisible() and not rematchRedux.cardManager:IsCardPinned(rematchRedux.petCard) then
        rematchRedux.cardManager:Unpin(rematchRedux.petCard)
    end
end

-- Team Win Record Options: Display Total Wins Instead
function rematchRedux.optionsPanel.funcs:AlternateWinRecord()
    for groupID,group in rematchRedux.savedGroups:AllGroups() do
        if group.sortMode==C.GROUP_SORT_WINS then
            rematchRedux.savedGroups:Sort(groupID)
        end
    end
end

-- Team Options: Always Show Team Tabs
function rematchRedux.optionsPanel.funcs:AlwaysTeamTabs()
    settings.NeverTeamTabs = false
    rematchRedux.teamTabs:Configure()
end

-- Team Options: Never Show Team Tabs
function rematchRedux.optionsPanel.funcs:NeverTeamTabs()
    settings.AlwaysTeamTabs = false
    rematchRedux.teamTabs:Configure()
end

function rematchRedux.optionsPanel.funcs:ShowNewGroupTab()
    rematchRedux.teamTabs:Update()
end

-- for any options that may change queue/behavior
function rematchRedux.optionsPanel.funcs:ProcessQueue()
    rematchRedux.queue:Process()
end

-- for changes to win record options to register/unregister monitoring battles
function rematchRedux.optionsPanel.funcs:AutoWinRecord()
    rematchRedux.winrecord:Update()
end

function rematchRedux.optionsPanel.funcs:UseMinimapButton()
    rematchRedux.minimap:Configure()
end

-- if ExportPetsDialog is open when changing ExportSimplePetList option, then switch to new list
function rematchRedux.optionsPanel.funcs:ExportSimplePetList()
    if rematchRedux.dialog:GetOpenDialog()=="ExportPetsDialog" then
        rematchRedux.dialog.Canvas.CheckButton:SetChecked(settings.ExportSimplePetList)
        rematchRedux.dialog.Canvas.MultiLineEditBox:SetText(rematchRedux.petFilterMenu:GetPetExportData(),true)
    end
end

function rematchRedux.optionsPanel.funcs:HideNotesButtonInBattle()
    rematchRedux.battle.NotesButton:SetShown(not settings.HideNotesButtonInBattle)
end

function rematchRedux.optionsPanel.funcs:NotesFont()
    rematchRedux.notes:UpdateFont()
end

function rematchRedux.optionsPanel.funcs:BreedSource(value)
    if value=="BattlePetBreedID" and settings.BreedFormat==C.BREED_FORMAT_ICONS then
        settings.BreedFormat = C.BREED_FORMAT_LETTERS -- if changing to BattlePetBreedID and format is icons, change format to letters
    end
    rematchRedux.breedInfo:ResetBreedSource()
    rematchRedux.optionsPanel:UpdateDropDown("BreedSource") -- in case ResetBreedSource asserts a different one
    rematchRedux.optionsPanel:UpdateDropDown("BreedFormat")
    rematchRedux.frame:Update()
end

function rematchRedux.optionsPanel.funcs:BreedFormat(value)
    if value==C.BREED_FORMAT_ICONS and settings.BreedSource=="BattlePetBreedID" then
        settings.BreedSource = "PetTracker" -- if changing to Icons and source isn't PetTracker, change source to PetTracker
        rematchRedux.breedInfo:ResetBreedSource()
    end
    rematchRedux.optionsPanel:UpdateDropDown("BreedSource")
    rematchRedux.optionsPanel:UpdateDropDown("BreedFormat")
    rematchRedux.frame:Update()
end

function rematchRedux.optionsPanel.funcs:MousewheelSpeed(speed)
    rematchRedux.optionsPanel.List:SetSpeed(speed)
end

--[[ widget setups ]]

rematchRedux.optionsPanel.widgetSetup = {}

function rematchRedux.optionsPanel.widgetSetup:UseCustomScaleWidget()
    self.tooltipTitle = L["Use Custom Scale"]
    self.tooltipBody = L["Adjust the relative size of the standalone RematchRedux window by changing its scale."]
    self.Text:SetText(L["Use Custom Scale"])
    self.ScaleButton.Text:SetFontObject(GameFontHighlight)
end

function rematchRedux.optionsPanel.UseCustomScaleWidget:OnEnter()
    rematchRedux.textureHighlight:Show(self.Check)
    rematchRedux.tooltip:ShowSimpleTooltip(self,self.tooltipTitle,self.tooltipBody)
end

function rematchRedux.optionsPanel.UseCustomScaleWidget:OnLeave()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.tooltip:Hide()
end

function rematchRedux.optionsPanel.UseCustomScaleWidget:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function rematchRedux.optionsPanel.UseCustomScaleWidget:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematchRedux.textureHighlight:Show(self.Check)
    end
end

function rematchRedux.optionsPanel.UseCustomScaleWidget:OnClick()
    settings.CustomScale = not settings.CustomScale
    rematchRedux.frame:UpdateScale()
    rematchRedux.optionsPanel:Update()
    PlaySound(C.SOUND_CHECKBUTTON)
end

function rematchRedux.optionsPanel.UseCustomScaleWidget.ScaleButton:OnClick()
    rematchRedux.dialog:ShowDialog("CustomScaleDialog")
end

function rematchRedux.optionsPanel.widgetSetup:OptionsManagementWidget()
    self.Label:SetText(L["All Options:"])
    self.ResetButton:SetText(L["Reset"])
    self.ExportButton:SetText(L["Export"])
end

-- exports all non-default options in this format: var=value:var=value:etc=value:
-- settings that are tables are just the count of elements within the table
function rematchRedux.optionsPanel.OptionsManagementWidget.ExportButton:OnClick()
    -- building a table so it can be sorted
    local results = {}
    for k,v in pairs(settings:GetDefaults()) do
        if type(v)=="table" then -- table contents aren't saved, just a count of its contents
            tinsert(results,k.."="..rematchRedux.utils:GetSize(settings[k]))
        elseif v~=settings[k] then
            tinsert(results,k.."="..tostring(settings[k]))
        end
    end
    tinsert(results,"AllTeams="..rematchRedux.utils:GetSize(rematchRedux.savedTeams.AllTeams))
    tinsert(results,"Version="..(C_AddOns.GetAddOnMetadata("RematchRedux","Version") or ""))
    tinsert(results,"NumPets="..(rematchRedux.roster:GetNumOwned() or ""))
    tinsert(results,"NumTeams="..(rematchRedux.savedTeams:GetNumTeams() or ""))
    table.sort(results)

    rematchRedux.dialog:ShowDialog("ExportOptions",table.concat(results,"\n"))
end

function rematchRedux.optionsPanel.OptionsManagementWidget.ResetButton:OnClick()
    rematchRedux.dialog:ShowDialog("ResetOptions")
end

--[[ widget updates ]]

rematchRedux.optionsPanel.widgetUpdate = {}

function rematchRedux.optionsPanel.widgetUpdate:UseCustomScaleWidget()
    local xoff = settings.CustomScale and 0.25 or 0
    self.Check:SetTexCoord(0+xoff,0.25+xoff,0.5,0.75)
    self.ScaleButton:SetShown(settings.CustomScale)
    self.ScaleButton:SetText(format("%d%%",settings.CustomScaleValue or 0))
end

-- resets all non-table options to default, sets non-table options in import to given values, then reloads the UI
-- this is used for troubleshooting to mimic another user's options that was exported from the Export button in options
function rematchRedux.optionsPanel:ImportOptions(import)
    local defaults = settings:GetDefaults()
    -- wipe all number, boolean or string settings
    for var,value in pairs(defaults) do
        if type(value)=="number" or type(value)=="boolean" or type(value)=="string" then
            settings[var] = value
        end
    end
    for line in ((import or "").."\n"):gmatch("(.-)\n") do
        local var,value = line:match("([A-Za-z0-9_]+)=([A-Za-z0-9_%s]+)")
        if var and value then
            var=var:trim()
            value=value:trim()
            local default = settings[var]
            if default~=nil then
                if type(default)=="number" and tonumber(value) then
                    settings[var] = tonumber(value)
                elseif type(default)=="boolean" and (value=="true" or value=="false") then
                    settings[var] = value=="true"
                elseif type(default)=="string" and tostring(value) then
                    settings[var] = tostring(value)
                end
            end
        end
    end
    ReloadUI()
end
