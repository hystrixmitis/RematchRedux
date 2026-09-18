local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.notes = RematchReduxNotesCard

rematchRedux.events:Register(rematchRedux.notes,"PLAYER_LOGIN",function(self)

    -- register cardManager behavior
    rematchRedux.cardManager:Register("Notes",self,{
        update = self.Update,
        lockUpdate = self.UpdateLock,
        noAnchor = true,
        noHide = function() return settings.KeepNotesOnScreen end,
        noEscape = function() return settings.KeepNotesOnScreen and settings.NotesNoEsc end,
    })

    -- this scrollbar adjustment may happen in update or configure (makes room for resize grip which isn't shown when position-locked)
    self.Content.ScrollFrame.ScrollBar:SetPoint("TOPLEFT",self.Content.ScrollFrame,"TOPRIGHT",0,-13)
    self.Content.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT",self.Content.ScrollFrame,"BOTTOMRIGHT",0,28) -- 13 (align to bottom) + 15 (space for resize grip)
    self.Content.ScrollFrame.ScrollBar.trackBG:SetAlpha(0.25)
    self.Content.Bottom.DeleteButton:SetText(DELETE)
    self.Content.Bottom.UndoButton:SetText(L["Undo"])
    self.Content.Bottom.SaveButton:SetText(SAVE)
    rematchRedux.notes.LockButton:Configure()

    rematchRedux.dialog:Register("DeleteNotes",{
        title = L["Delete Notes"],
        accept = YES,
        cancel = NO,
        layout = {"Text","CheckButton"},
        refreshFunc = function(self,info,subject,firstRun)
            if rematchRedux.utils:GetIDType(subject)=="team" then
                self.Text:SetText(format(L["Do you want to delete notes for team %s\124r?"],rematchRedux.utils:GetFormattedTeamName(subject)))
            else
                local petInfo = rematchRedux.petInfo:Fetch(subject)
                if petInfo.isValid then
                    self.Text:SetText(format(L["Do you want to delete notes for pet %s%s\124r?"],petInfo.color.hex,petInfo.name))
                end
            end
            self.CheckButton:SetText(L["Don't Ask When Deleting Notes"])
            self.CheckButton:SetChecked(false)
        end,
        acceptFunc = function(self,info,subject)
            rematchRedux.notes:DeleteNotes(subject)
            if self.CheckButton:GetChecked() then
                settings.DontConfirmDeleteNotes = true
            end
        end
    })

    self:UpdateFont()

    self:SetScript("OnSizeChanged",self.OnSizeChanged)

end)

-- called on login and in options too
function rematchRedux.notes:UpdateFont()
    self.Content.ScrollFrame.EditBox:SetFontObject(settings.NotesFont or "GameFontHighlight")
end

-- for lock button in topleft corner, update icon and hide resize grip while locked
function rematchRedux.notes.LockButton:Configure()
    self:SetIcon(settings.LockNotesPosition and "lock" or "unlock")
    if settings.LockNotesPosition then
        rematchRedux.notes.Content.ScrollFrame.ResizeGrip:Hide()
        rematchRedux.notes.Content.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT",rematchRedux.notes.Content.ScrollFrame,"BOTTOMRIGHT",0,13)
    else
        rematchRedux.notes.Content.ScrollFrame.ResizeGrip:Show()
        rematchRedux.notes.Content.ScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT",rematchRedux.notes.Content.ScrollFrame,"BOTTOMRIGHT",0,28)
    end
end

function rematchRedux.notes:Update(subject)
    self.teamID = nil
    self.petID = nil
    if type(subject)=="string" and rematchRedux.savedTeams[subject] then -- this is a teamID
        local team = rematchRedux.savedTeams[subject]
        if team then
            self.teamID = subject
            self.Content.Top.Name:SetText(rematchRedux.utils:GetFormattedTeamName(subject))
            self.Content.Top.RightIcon:SetTexture(rematchRedux.savedGroups[team.groupID or "group:none"].icon)
            self.Content.ScrollFrame.EditBox:SetText(team.notes or "")
            self.Content.ScrollFrame.EditBox:SetCursorPosition(0)
            self.originalNotes = team.notes -- note this can be nil
        end
    elseif subject then -- this is likely a petID
        local petInfo = rematchRedux.petInfo:Fetch(subject)
        if petInfo.isValid then
            self.petID = subject
            local color = settings.ColorPetNames and petInfo.color
            self.Content.Top.Name:SetText(format("%s%s",color and color.hex or C.HEX_GOLD,petInfo.name))
            self.Content.Top.RightIcon:SetTexture(petInfo.icon)
            self.Content.ScrollFrame.EditBox:SetText(petInfo.notes or "")
            self.Content.ScrollFrame.EditBox:SetCursorPosition(0)
            self.originalNotes = petInfo.notes -- note this can be nil
        end
    end
    -- anchor notes if there is an anchor defined (otherwise use anchor in XML)
	if settings.NotesLeft then
		self:SetSize(settings.NotesWidth,settings.NotesHeight)
		self:ClearAllPoints()
		self:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",settings.NotesLeft,settings.NotesBottom)
	end
end

function rematchRedux.notes:UpdateLock()
    -- while card unlocked, hide scrollbar and resize grip by setting their alpha to 0
    local isLocked = rematchRedux.cardManager:IsCardLocked(self)
    self.Content.ScrollFrame.ScrollBar:SetAlpha(isLocked and 1 or 0)
    self.Content.ScrollFrame.ResizeGrip:SetAlpha(isLocked and 1 or 0)
end

-- sets focus to editbox
function rematchRedux.notes:SetFocus()
    self.Content.ScrollFrame.EditBox:SetFocus(true)
end

function rematchRedux.notes:ClearFocus()
    self.Content.ScrollFrame.EditBox.loseFocus = true
    self.Content.ScrollFrame.EditBox:ClearFocus()
end

--[[ editbox script handlers ]]

-- make sure editbox is a higher framelevel so it's not beneath focus grabber
function rematchRedux.notes.Content.ScrollFrame.EditBox:OnShow()
    self:SetFrameLevel(self:GetParent():GetFrameLevel()+4)
end

-- when focus gained, show controls at bottom
function rematchRedux.notes.Content.ScrollFrame.EditBox:OnEditFocusGained()
    rematchRedux.notes.Content.ScrollFrame:SetPoint("BOTTOMRIGHT",-26,8+C.NOTES_CONTROLS_HEIGHT)
    rematchRedux.notes.Content.Bottom:Show()
end

-- when focus lost, hide controls at bottom unless mouse is over bottom controls or resize button
function rematchRedux.notes.Content.ScrollFrame.EditBox:OnEditFocusLost()
    if (rematchRedux.notes.Content.Bottom:IsMouseOver() or rematchRedux.notes.Content.ScrollFrame.ResizeGrip:IsMouseOver()) and not self.loseFocus then
        self:SetFocus(true)
    else
        self.loseFocus = nil
        rematchRedux.notes.Content.ScrollFrame:SetPoint("BOTTOMRIGHT",-26,8)
        rematchRedux.notes.Content.Bottom:Hide()
    end
end

function rematchRedux.notes.Content.ScrollFrame.EditBox:OnEscapePressed()
    self.loseFocus = true -- if mouse is over bottom when hitting esc, don't grab focus back
    self:ClearFocus()
end

-- if focus grabber is clicked at all, it's because notes don't take up whole editBox; set cursor to end
function rematchRedux.notes.Content.ScrollFrame.FocusGrabber:OnClick()
    local editBox = self:GetParent().EditBox
    editBox:SetCursorPosition(editBox:GetText():len())
    editBox:SetFocus(true)
end

--[[ resizing script handlers ]]

-- when parent notes frame changes size, adjust editbox width and bottom button widths
function rematchRedux.notes:OnSizeChanged(width,height)
    rematchRedux.notes.Content.ScrollFrame.EditBox:SetWidth(width-45)
    local buttonWidth = (width-10)/3
    rematchRedux.notes.Content.Bottom.DeleteButton:SetWidth(buttonWidth)
    rematchRedux.notes.Content.Bottom.UndoButton:SetWidth(buttonWidth)
    rematchRedux.notes.Content.Bottom.SaveButton:SetWidth(buttonWidth)
end

-- resizing notes window from resize grip in lower right
function rematchRedux.notes.Content.ScrollFrame.ResizeGrip:OnMouseDown()
    if not settings.LockNotesPosition then
        rematchRedux.notes:StartSizing()
    end
end

function rematchRedux.notes.Content.ScrollFrame.ResizeGrip:OnMouseUp()
    if not settings.LockNotesPosition then
        rematchRedux.notes:StopMovingOrSizing()
        rematchRedux.notes:SavePosition()
        rematchRedux.notes:SetUserPlaced(false)
    end
end

--[[ window movement script handlers ]]

function rematchRedux.notes:OnMouseDown()
    if not settings.LockNotesPosition then
        self:StartMoving()
    end
end

function rematchRedux.notes:OnMouseUp()
    if not settings.LockNotesPosition then
        self:StopMovingOrSizing()
        self:SavePosition()
        self:SetUserPlaced(false)
    end
end

function rematchRedux.notes.LockButton:OnClick()
    settings.LockNotesPosition = not settings.LockNotesPosition
    self:Configure()
end

function rematchRedux.notes:SavePosition()
    settings.NotesLeft = self:GetLeft()
    settings.NotesBottom = self:GetBottom()
    settings.NotesWidth = self:GetWidth()
    settings.NotesHeight = self:GetHeight()
end

--[[ control buttons in bottom panel ]]

function rematchRedux.notes.Content.Bottom.SaveButton:OnClick()
    local text = rematchRedux.notes.Content.ScrollFrame.EditBox:GetText():trim()
    if rematchRedux.notes.teamID then
        local teamID = rematchRedux.notes.teamID
        if teamID and rematchRedux.savedTeams:IsUserTeam(teamID) then
            if text:len()>0 then
                rematchRedux.savedTeams[teamID].notes = text
            else
                rematchRedux.savedTeams[teamID].notes = nil
            end
            rematchRedux.frame:Update()
            rematchRedux.notes:ClearFocus()
            rematchRedux.events:Fire("REMATCHREDUX_NOTES_CHANGED",teamID)
        end
    elseif rematchRedux.notes.petID then
        local speciesID = rematchRedux.petInfo:Fetch(rematchRedux.notes.petID).speciesID
        if speciesID then
            if text:len()>0 then
                settings.PetNotes[speciesID] = text
            else
                settings.PetNotes[speciesID] = nil
            end
            rematchRedux.frame:Update()
            rematchRedux.notes:ClearFocus()
            rematchRedux.events:Fire("REMATCHREDUX_NOTES_CHANGED",speciesID)
        end
    end
end

function rematchRedux.notes.Content.Bottom.UndoButton:OnClick()
    rematchRedux.notes.Content.ScrollFrame.EditBox:SetText(rematchRedux.notes.originalNotes or "")
    rematchRedux.notes.Content.ScrollFrame.EditBox:SetCursorPosition(0)
end

function rematchRedux.notes.Content.Bottom.DeleteButton:OnClick()
    rematchRedux.notes:ClearFocus()
    rematchRedux.cardManager:HideCard(rematchRedux.notes)
    local subject = rematchRedux.notes.teamID or rematchRedux.notes.petID
    if not settings.DontConfirmDeleteNotes and rematchRedux.notes.originalNotes then
        if subject then
            rematchRedux.dialog:ShowDialog("DeleteNotes",subject)
        end
    else
        rematchRedux.notes:DeleteNotes(subject)
    end
end

function rematchRedux.notes:DeleteNotes(subject)
    if rematchRedux.utils:GetIDType(subject)=="team" then
        local team = rematchRedux.savedTeams[subject]
        if team then
            rematchRedux.savedTeams[subject].notes = nil
            rematchRedux.events:Fire("REMATCHREDUX_NOTES_CHANGED",subject)
        end
    elseif subject then
        local speciesID = rematchRedux.petInfo:Fetch(subject).speciesID
        if speciesID then
            settings.PetNotes[speciesID] = nil
            rematchRedux.events:Fire("REMATCHREDUX_NOTES_CHANGED",speciesID)
        end
    end
    rematchRedux.frame:Update()
end

-- primarily for the keybind, shows/hides notes for the currently loaded team, if one loaded (it's ok if team has no notes)
function rematchRedux.notes:Toggle()
    local teamID = rematchRedux.settings.currentTeamID
    if rematchRedux.savedTeams:IsUserTeam(teamID) then
        if rematchRedux.notes:IsVisible() then
            rematchRedux.cardManager:HideCard(rematchRedux.notes)
        else
            rematchRedux.cardManager:ShowCard(rematchRedux.notes,teamID)
        end
    end
end