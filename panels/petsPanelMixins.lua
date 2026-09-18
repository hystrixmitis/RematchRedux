local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings

RematchReduxTypeBarTabMixin = {}

function RematchReduxTypeBarTabMixin:OnEnter()
    if not self.isSelected then
        self.Text:SetTextColor(1,1,1)
        self.Highlight:Show()
    end
end

function RematchReduxTypeBarTabMixin:OnLeave()
    if self.isSelected then
        self.Text:SetTextColor(1,1,1)
    else
        self.Text:SetTextColor(1,0.82,0)
    end
    self.Highlight:Hide()
end

function RematchReduxTypeBarTabMixin:OnMouseDown()
    if not self.isSelected then -- only do a push effect on unselected tabs
        self.Text:SetPoint("CENTER",-1,-2)
    end
end

function RematchReduxTypeBarTabMixin:OnMouseUp()
    self.Text:SetPoint("CENTER",0,-1)
end

function RematchReduxTypeBarTabMixin:OnClick()
    settings.TypeBarTab = self.id
    self:GetParent():Update()
end
