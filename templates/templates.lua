local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants

--[[ RematchReduxTooltipScripts ]]

RematchReduxTooltipScriptsMixin = {}

-- the OnEnter/OnLeave are "append" script handlers so safe to inherit to frames that already have an OnEnter/OnLeave,
-- but the RematchReduxTooltipScripts should be inherited last: <Frame inherits="MyTemplate,RematchReduxTooltipScripts"/>
-- note to self: don't refactor and use OnEnter/OnLeave because whatever inherits this may have them already
function RematchReduxTooltipScriptsMixin:TooltipOnEnter()
    rematchRedux.tooltip:ShowSimpleTooltip(self)
end

function RematchReduxTooltipScriptsMixin:TooltipOnLeave()
    rematchRedux.tooltip:Hide()
end

--[[ RematchReduxPanelButtonTemplate ]]

RematchReduxPanelButtonMixin = {}

function RematchReduxPanelButtonMixin:SetText(text)
    self.Text:SetText(text)
end

function RematchReduxPanelButtonMixin:OnEnter()
    if self:IsEnabled() then
        for i=1,3 do
            self.Highlight[i]:Show()
        end
        self.Text:SetTextColor(1,1,1)
    end
end

function RematchReduxPanelButtonMixin:OnLeave()
    if self:IsEnabled() then
        for i=1,3 do
            self.Highlight[i]:Hide()
        end
        self.Text:SetTextColor(1,0.82,0)
    end
end

function RematchReduxPanelButtonMixin:OnMouseDown()
    if self:IsEnabled() then
        for i=1,3 do
            self.Back[i]:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
        end
        self.Text:SetPoint("CENTER",-1,-2)
    end
end

function RematchReduxPanelButtonMixin:OnMouseUp()
    if self:IsEnabled() then
        for i=1,3 do self.Back[i]:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up") end
        self.Text:SetPoint("CENTER")
    end
end

function RematchReduxPanelButtonMixin:DeferredOnClick(button)
    if self:IsEnabled() and self.OnClick then
        self.OnClick(self,button)
    end
end

function RematchReduxPanelButtonMixin:OnDisable()
    for i=1,3 do
        self.Back[i]:SetTexture("Interface\\Buttons\\UI-Panel-Button-Disabled")
    end
    self.Text:SetPoint("CENTER")
    self.Text:SetTextColor(0.5,0.5,0.5)
end

function RematchReduxPanelButtonMixin:OnEnable()
    for i=1,3 do
        self.Back[i]:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    end
    self.Text:SetTextColor(1,0.82,0)
end

--[[ RematchReduxCheckButtonTemplate ]]

RematchReduxCheckButtonMixin = {}

function RematchReduxCheckButtonMixin:SetText(text)
    self.Text:SetText(text)
    self:SetHitRectInsets(0,-2-(self.Text:GetStringWidth()),0,0)
end

function RematchReduxCheckButtonMixin:OnEnter()
    if self:IsEnabled() then
        self.Text:SetTextColor(1,1,1)
    end
    rematchRedux.tooltip:ShowSimpleTooltip(self)
end

function RematchReduxCheckButtonMixin:OnLeave()
    if self:IsEnabled() then
        self.Text:SetTextColor(1,0.82,0)
    end
    rematchRedux.tooltip:Hide()
end

function RematchReduxCheckButtonMixin:OnDisable()
    self.Text:SetTextColor(0.5,0.5,0.5)
end

function RematchReduxCheckButtonMixin:OnEnable()
    self.Text:SetTextColor(1,0.82,0)
end

function RematchReduxCheckButtonMixin:DeferredOnClick()
    if self.OnClick then
        self.OnClick(self)
    end
    PlaySound(C.SOUND_CHECKBUTTON)
end

--[[ RematchReduxTitlebarButtonTemplate ]]

RematchReduxTitlebarButtonMixin = {}

-- texcoords into Interface\AddOns\RematchRedux\textures\titlebarButtons.blp
local texCoords = {
    close = {0.00390625,0.14453125,0.01171875,0.15234375},
    minimize = {0.15234375,0.29296875,0.01171875,0.15234375},
    maximize = {0.30078125,0.44140625,0.01171875,0.15234375},
    pin = {0.44921875,0.58984375,0.01171875,0.15234375},
    lock = {0.00390625,0.14453125,0.4921875,0.6328125},
    unlock = {0.15234375,0.29296875,0.4921875,0.6328125},
    left = {0.30078125,0.44140625,0.4921875,0.6328125},
    right = {0.44921875,0.58984375,0.4921875,0.6328125},
    flip = {0.59765625,0.73828125,0.4921875,0.6328125}
}

function RematchReduxTitlebarButtonMixin:OnLoad()
    self:SetIcon(self.icon)
end

function RematchReduxTitlebarButtonMixin:DeferredOnClick()
    if self.OnClick then
        self:OnClick()
    end
end

-- sets the button's texture to one of the texcoords at the top
function RematchReduxTitlebarButtonMixin:SetIcon(icon)
    if icon and texCoords[icon] then
        self.icon = icon
    end
    self:Update()
end

function RematchReduxTitlebarButtonMixin:Update()
    local coords = texCoords[self.icon]
    if coords then
        local disableOff = 41/256
        local pushedOff = (41/256)*2
		self:GetNormalTexture():SetTexCoord(coords[1],coords[2],coords[3],coords[4])
		self:GetDisabledTexture():SetTexCoord(coords[1],coords[2],coords[3]+disableOff,coords[4]+disableOff)
		self:GetPushedTexture():SetTexCoord(coords[1],coords[2],coords[3]+pushedOff,coords[4]+pushedOff)
    end
end

--[[ RematchReduxAllButtonTemplate mixin ]]

RematchReduxAllButtonMixin = {}

-- the OnClick for this is undefined since it's overwritten in autoScrollBox.lua

-- texcoords for allButton depending on plus/minus or up/down state
local allButtonTexCoords = {
    plus = { -- isExpanded = false
        up = {0,1,0,0.1875},
        down = {0,1,0.1875,0.375}
    },
    minus = { -- isExpanded = true
        up = {0,1,0.375,0.5625},
        down = {0,1,0.5625,0.75}
    },
    disabled = {0,1,0.75,0.9375}
}

function RematchReduxAllButtonMixin:SetExpanded(isExpanded)
    self.isExpanded = isExpanded
    self:Update()
end

function RematchReduxAllButtonMixin:Update()
    if self:IsEnabled() then
        local coords = allButtonTexCoords[self.isExpanded and "minus" or "plus"][self.isDown and "down" or "up"]
        self.Back:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
        self.Highlight:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
        self.Text:SetPoint("CENTER",7-(self.isDown and 1 or 0),0-(self.isDown and 2 or 0))
    else
        local coords = allButtonTexCoords.disabled
        self.Back:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
        self.Highlight:SetTexCoord(coords[1],coords[2],coords[3],coords[4])
    end
end

function RematchReduxAllButtonMixin:OnEnter()
    self.Highlight:Show()
end

function RematchReduxAllButtonMixin:OnLeave()
    self.Highlight:Hide()
end

function RematchReduxAllButtonMixin:OnMouseDown()
    if self:IsEnabled() then
        self.isDown = true
        self:Update()
    end
end

function RematchReduxAllButtonMixin:OnMouseUp()
    self.isDown = false
    self:Update()
end

function RematchReduxAllButtonMixin:OnDisable()
    self.Back:SetDesaturated(true)
    self.Text:SetTextColor(0.5,0.5,0.5)
    self.isDown = false
    self:Update()
end

function RematchReduxAllButtonMixin:OnEnable()
    self.Back:SetDesaturated(false)
    self.Text:SetTextColor(1,1,1)
    self:Update()
end

--[[ RematchReduxClearButtonTemplate ]]

RematchReduxClearButtonMixin = {}

function RematchReduxClearButtonMixin:OnEnter()
    self.Texture:SetAlpha(1.0)
end

function RematchReduxClearButtonMixin:OnLeave()
    self.Texture:SetAlpha(0.5)
end

function RematchReduxClearButtonMixin:OnMouseDown()
    self.Texture:SetPoint("TOPLEFT",-1,-2)
end

function RematchReduxClearButtonMixin:OnMouseUp()
    self.Texture:SetPoint("TOPLEFT",0,0)
end

--[[ RematchReduxEditBoxTemplate mixin ]]

RematchReduxEditBoxMixin = {}

function RematchReduxEditBoxMixin:OnLoad()
    self.Clear:SetScript("OnClick",function(self)
        self:GetParent():SetText("")
        self:GetParent():ClearFocus()
        self:Hide()
        if self:GetParent().Instructions then
            self:GetParent().Instructions:Show()
        end
    end)
end

function RematchReduxEditBoxMixin:OnEscapePressed()
    self:ClearFocus()
end

function RematchReduxEditBoxMixin:OnEditFocusLost()
    self.Clear:SetShown(self:GetText():len()>0)
    if self.SearchIcon then
        self.SearchIcon:SetVertexColor(0.6,0.6,0.6)
    end
    if self.Instructions then
        self.Instructions:SetShown(self:GetText():len()==0)
    end
end

function RematchReduxEditBoxMixin:OnEditFocusGained()
    self.Clear:Show()
    if self.SearchIcon then
        self.SearchIcon:SetVertexColor(1.0,1.0,1.0)
    end
    if self.Instructions then
        self.Instructions:Hide()
    end
end

--[[ RematchReduxSmallGreyButtonTemplate ]]

RematchReduxSmallGreyButtonMixin = {}

function RematchReduxSmallGreyButtonMixin:OnLoad()
    if self.icon then
        if self.coords then
            local left,right,top,bottom = self.coords:match("^(.+),(.+),(.+),(.+)$")
            if tonumber(left) then
                self:SetIcon(self.icon,tonumber(left),tonumber(right),tonumber(top),tonumber(bottom))
            end
        else -- no texcoords, set just the icon
            self:SetIcon(self.icon)
        end
    end
end

-- sets the icon texture to the given icon and optional texcoords
function RematchReduxSmallGreyButtonMixin:SetIcon(icon,left,right,top,bottom)
    if icon then
        self.Icon:SetTexture(icon)
    end
    if left then
        self.Icon:SetTexCoord(left,right,top,bottom)
    else
        self.Icon:SetTexCoord(0,1,0,1)
    end
end

-- set button's icon to an arrow pointing "up", "down", "left" or "right"
function RematchReduxSmallGreyButtonMixin:SetDirection(direction)
    self.direction = direction
    if direction=="up" then
        self:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\texticons",0.5,0.625,0.25,0.375)
    elseif direction=="down" then
        self:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\texticons",0.625,0.75,0.25,0.375)
    elseif direction=="left" then
        self:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\texticons",0.25,0.375,0.325,0.375)
    elseif direction=="right" then
        self:SetIcon("Interface\\AddOns\\RematchRedux\\textures\\texticons",0.375,0.5,0.325,0.375)
    end
end

function RematchReduxSmallGreyButtonMixin:OnEnter()
    if self:IsEnabled() then
        rematchRedux.textureHighlight:Show(self.Back,self.Icon)
    end
end

function RematchReduxSmallGreyButtonMixin:OnLeave()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxSmallGreyButtonMixin:OnMouseDown()
    if self:IsEnabled() then
        self.Icon:SetPoint("CENTER",-1,-2)
        self.Back:SetTexCoord(0.375,0.46875,0.359375,0.453125)
        self.Icon:SetVertexColor(0.7,0.7,0.7)
        rematchRedux.textureHighlight:Hide()
    end
end

-- called 0 frames after OnMouseUp
local function delayedSmallGreyButtonHighlight(self)
    if self:IsEnabled() then
        rematchRedux.textureHighlight:Show(self.Back,self.Icon)
    end
end

function RematchReduxSmallGreyButtonMixin:OnMouseUp()
    if self:IsEnabled() then
        self.Icon:SetPoint("CENTER")
        self.Back:SetTexCoord(0.375,0.46875,0.25,0.34375)
        self.Icon:SetVertexColor(1,1,1)
        if self:IsMouseMotionFocus() then
            -- delay because if click is changing the icon we want highlight to change too
            rematchRedux.timer:Start(0,delayedSmallGreyButtonHighlight,self)
        end
    end
end

function RematchReduxSmallGreyButtonMixin:OnDisable()
    self.Icon:SetPoint("CENTER")
    self.Back:SetTexCoord(0.375,0.46875,0.25,0.34375)
    self.Icon:SetDesaturated(true)
    self.Icon:SetVertexColor(0.5,0.5,0.5)
end

function RematchReduxSmallGreyButtonMixin:OnEnable()
    self.Icon:SetDesaturated(false)
    self.Icon:SetVertexColor(1,1,1)
end

--[[ RematchReduxGreyPanelButtonTemplate and RematchReduxWideGreyPanelButtonTemplate mixin ]]

RematchReduxGreyPanelButtonMixin = {}

function RematchReduxGreyPanelButtonMixin:SetText(text)
    self.Text:SetText(text)
end

function RematchReduxGreyPanelButtonMixin:OnEnter()
    if self:IsEnabled() then
        self.Highlight:Show()
    end
end

function RematchReduxGreyPanelButtonMixin:OnLeave()
    self.Highlight:Hide()
end

-- for dimensions other than 80x24, grey buttons should have a coord keyvalue from C.GREY_BUTTON_COORDS
function RematchReduxGreyPanelButtonMixin:OnMouseDown()
    if self:IsEnabled() then
        local coord = self.coord and C.GREY_BUTTON_COORDS[self.coord] or C.GREY_BUTTON_COORDS["80x24"]
        self.Back:SetTexCoord(coord.Down[1],coord.Down[2],coord.Down[3],coord.Down[4])
        self.Highlight:SetTexCoord(coord.Down[1],coord.Down[2],coord.Down[3],coord.Down[4])
        self.Text:SetPoint("CENTER",-1,-2)
        if self.Arrow then
            self.Arrow:SetPoint("RIGHT",-6,-2)
        end
    end
end

-- for dimensions other than 80x24, grey buttons should have a coord keyvalue from C.GREY_BUTTON_COORDS
function RematchReduxGreyPanelButtonMixin:OnMouseUp()
    local coord = self.coord and C.GREY_BUTTON_COORDS[self.coord] or C.GREY_BUTTON_COORDS["80x24"]
    self.Back:SetTexCoord(coord.Up[1],coord.Up[2],coord.Up[3],coord.Up[4])
    self.Highlight:SetTexCoord(coord.Up[1],coord.Up[2],coord.Up[3],coord.Up[4])
    self.Text:SetPoint("CENTER")
    if self.Arrow then
        self.Arrow:SetPoint("RIGHT",-5,0)
        self.Arrow:SetShown(not self.noArrow)
    end
end

function RematchReduxGreyPanelButtonMixin:OnDisable()
    self.Text:SetVertexColor(0.5,0.5,0.5)
end

function RematchReduxGreyPanelButtonMixin:OnEnable()
    self.Text:SetTextColor(1,1,1)
end

--[[ RematchReduxTextureMouseMixin is used by various textures-as-buttons for a highlight effect ]]

RematchReduxTextureMouseMixin = {}

function RematchReduxTextureMouseMixin:OnEnter()
    rematchRedux.textureHighlight:Show(self)
    if self.tooltipTitle or self.tooltipBody then
        rematchRedux.tooltip:ShowSimpleTooltip(self,self.tooltipTitle,self.tooltipBody)
    end
end

function RematchReduxTextureMouseMixin:OnLeave()
    rematchRedux.textureHighlight:Hide()
    if self.tooltipTitle or self.tooltipBody then
        rematchRedux.tooltip:Hide()
    end
end

function RematchReduxTextureMouseMixin:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxTextureMouseMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematchRedux.textureHighlight:Show(self)
        if self.OnClick then
            self.OnClick(self,GetMouseButtonClicked())
        end
    end
end

--[[ RematchReduxColorSwatchTemplate mixin ]]

RematchReduxColorSwatchMixin = {}

function RematchReduxColorSwatchMixin:OnLoad()
    self:SetColor(self.color)
end

function RematchReduxColorSwatchMixin:OnEnter()
    rematchRedux.textureHighlight:Show(self.Border)
end

function RematchReduxColorSwatchMixin:OnLeave()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxColorSwatchMixin:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxColorSwatchMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        rematchRedux.textureHighlight:Show(self.Border)
    end
end

function RematchReduxColorSwatchMixin:SetColor(color)
    self.color = color
    if color then
        local r,g,b = rematchRedux.utils:HexToRGB(color)
        if r and g and b then
            self.Color:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            self.Color:SetVertexColor(r,g,b)
            self.Selected:SetVertexColor(r,g,b)
        end
    else
        self.Color:SetTexture("Interface\\AddOns\\RematchRedux\\textures\\defaultcolor")
        self.Color:SetVertexColor(1,1,1)
        self.Selected:SetVertexColor(1,0.82,0)
    end
end

--[[ RematchReduxRoundButtonTemplate mixin ]]

RematchReduxRoundButtonMixin = {}

function RematchReduxRoundButtonMixin:OnLoad()
    self.SetTexture = function(self,texture)
        self.Texture:SetTexture(texture)
        if self.Highlight then
            self.Highlight:SetTexture(texture)
        end
    end
    if self.icon then
        self:SetTexture(self.icon)
    end
end

--[[ RematchReduxNotesButtonTemplate mixin ]]

RematchReduxNotesButtonMixin = {}

function RematchReduxNotesButtonMixin:OnEnter()
    local parent = self:GetParent()
    rematchRedux.textureHighlight:Show(self,parent.Back)
    rematchRedux.cardManager:OnEnter(rematchRedux.notes,parent,parent.petID or parent.teamID)
end

function RematchReduxNotesButtonMixin:OnLeave()
    local parent = self:GetParent()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.cardManager:OnLeave( rematchRedux.notes )
end

function RematchReduxNotesButtonMixin:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxNotesButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        local parent = self:GetParent()
        rematchRedux.textureHighlight:Show(self,parent.Back)
        rematchRedux.cardManager:OnClick(rematchRedux.notes,self,parent.petID or parent.teamID)
    end
end

function RematchReduxNotesButtonMixin:OnClick()
    -- card manager onclick for notes
end

--[[ RematchReduxHeaderListButtonTemplate mixin ]]

RematchReduxHeaderListButtonMixin = {}

-- sets the background depending on whether in single-panel mode (wide header) and all other modes
function RematchReduxHeaderListButtonMixin:SetBack()
    if rematchRedux.layout:GetMode(C.CURRENT)==1 then -- if in single-panel mode, use wide header
        self.Back:SetTexCoord(0,0.611328125,0.5,0.90625)
    else -- otherwise use normal-width header
        self.Back:SetTexCoord(0,0.494140625,0,0.40625)
    end
end

-- if isSearching is true, update ExpandIcon to an empty square and desaturate it
-- if isExpanded is true, update ExpandIcon to a "-"
-- if isExpanded is false, update ExpandIcon to a "+"
function RematchReduxHeaderListButtonMixin:SetExpanded(isExpanded,isSearching)
    -- update the +/- to show if header collapsed
    local desaturate, left, right, top, bottom = false, nil, nil, nil, nil
    if isSearching then
        left,right,top,bottom = 0.8515625,0.902343750,0,0.40625 -- neither plus or minus while searching
        desaturate = true
    elseif isExpanded then
        left,right,top,bottom = 0.80078125,0.8515625,0,0.40625 -- minus
    else
        left,right,top,bottom = 0.75,0.80078125,0,0.40625 -- plus
    end
    self.ExpandIcon:SetTexCoord(left,right,top,bottom)
    self.ExpandIcon:SetDesaturated(desaturate)
end

--[[ RematchReduxStretchTabTemplate mixin ]]

RematchReduxStretchTabMixin = {}

function RematchReduxStretchTabMixin:SetSelected(isSelected)
    self.isSelected = isSelected
    if isSelected then
        self.Left:SetTexCoord(0.375,0.40625,0.75,0.84375)
        self.Mid:SetTexCoord(0.40625,0.48828125,0.75,0.84375)
        self.Right:SetTexCoord(0.48828125,0.51953125,0.75,0.84375)
        self.Text:SetTextColor(1,1,1)
        for i=1,3 do
            self.Highlights[i]:Hide()
        end
    else
        self.Left:SetTexCoord(0.1875,0.21875,0.75,0.84375)
        self.Mid:SetTexCoord(0.21875,0.30078125,0.75,0.84375)
        self.Right:SetTexCoord(0.30078125,0.33203125,0.75,0.84375)
        self.Text:SetTextColor(1,0.82,0)
    end
end

function RematchReduxStretchTabMixin:IsSelected()
    return self.isSelected
end

function RematchReduxStretchTabMixin:SetText(text)
    self.Text:SetText(text)
    self:SetWidth(max(40,self.Text:GetStringWidth()+16))
end

function RematchReduxStretchTabMixin:OnEnter()
    if not self.isSelected then
        self.Text:SetTextColor(1,1,1)
        for i=1,3 do
            self.Highlights[i]:Show()
        end
    end
end

function RematchReduxStretchTabMixin:OnLeave()
    if not self.isSelected then
        self.Text:SetTextColor(1,0.82,0)
        for i=1,3 do
            self.Highlights[i]:Hide()
        end
    end
end

function RematchReduxStretchTabMixin:OnMouseDown()
    if not self.isSelected then
        self.Text:SetPoint("CENTER",-1,-2)
    end
end

function RematchReduxStretchTabMixin:OnMouseUp()
    self.Text:SetPoint("CENTER")
end

--[[ RematchReduxPetTextureMixin has no XML template, this is a mixin to make pet cards viewable from ]]

RematchReduxPetTextureMixin = {}

function RematchReduxPetTextureMixin:OnEnter()
    rematchRedux.textureHighlight:Show(self)
    rematchRedux.cardManager:OnEnter(rematchRedux.petCard,self,self.petID) -- anchor to parent
end

function RematchReduxPetTextureMixin:OnLeave()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.cardManager:OnLeave( rematchRedux.petCard )
end

function RematchReduxPetTextureMixin:OnMouseDown()
    rematchRedux.textureHighlight:Hide()
end

function RematchReduxPetTextureMixin:OnMouseUp(button)
    if self:IsMouseMotionFocus() then
        rematchRedux.textureHighlight:Show(self)
        if button~="RightButton" then -- textures don't have an OnClick
            local petInfo = rematchRedux.petInfo:Fetch(self.petID)
            if petInfo.isValid then
                rematchRedux.cardManager:OnClick(rematchRedux.petCard,self,self.petID)
            end
        end
    end
end

