local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings

RematchReduxPetCardTopButtonMixin = {}

function RematchReduxPetCardTopButtonMixin:OnEnter()
    self.Highlight:Show()
    if not settings.PetCardNoMouseoverFlip then
        rematchRedux.petCard.softFlip = true
        rematchRedux.petCard:FlipCard()
    end
end

function RematchReduxPetCardTopButtonMixin:OnLeave()
    self.Highlight:Hide()
    if not settings.PetCardNoMouseoverFlip then
        rematchRedux.petCard.softFlip = false
        rematchRedux.petCard:FlipCard()
    end
end

function RematchReduxPetCardTopButtonMixin:OnMouseDown()
    self.Highlight:Hide()
end

function RematchReduxPetCardTopButtonMixin:OnMouseUp()
    if self:IsMouseMotionFocus() then
        self.Highlight:Show()
    end
end

-- click of a top button will flip the card (unless it's a special type like leveling, random, ignored)
function RematchReduxPetCardTopButtonMixin:OnClick()
    local petInfo = rematchRedux.petInfo:Fetch(rematchRedux.petCard.petID)
    if not petInfo.isSpecialType then
        rematchRedux.petCard.hardFlip = not rematchRedux.petCard.hardFlip
        rematchRedux.petCard:FlipCard()
    end
end

RematchReduxPetCardAbilityMixin = {}

function RematchReduxPetCardAbilityMixin:OnEnter()
    self.Highlight:Show()
    rematchRedux.textureHighlight:Show(self.Icon)
    rematchRedux.menus:Hide()
    rematchRedux.abilityTooltip:ShowTooltip(self,rematchRedux.petCard.petID,self.abilityID,rematchRedux.petCard)
end

function RematchReduxPetCardAbilityMixin:OnLeave()
    self.Highlight:Hide()
    rematchRedux.textureHighlight:Hide()
    rematchRedux.abilityTooltip:Hide()
end

function RematchReduxPetCardAbilityMixin:OnClick(button)
    if rematchRedux.utils:HandleSpecialAbilityClicks(self.abilityID,rematchRedux.petCard.petID) then
        return
    elseif button=="RightButton" then
        rematchRedux.menus:Show("AbilityMenu",self,self.abilityID,"cursor")
    end
end

RematchReduxPetCardStatusBarMixin = {}

function RematchReduxPetCardStatusBarMixin:OnEnter()
    self.Text:Show()
end

function RematchReduxPetCardStatusBarMixin:OnLeave()
    if not settings.PetCardAlwaysShowHPXPText then
        self.Text:Hide()
    end
end

RematchReduxPetCardStatMixin = {}

-- stat buttons are created on demand, and need to be added to clickable elements for card manager
function RematchReduxPetCardStatMixin:OnLoad()
    rematchRedux.cardManager:AddClickableElementToCard(rematchRedux.petCard,self)
    self:EnableMouse(false) -- start off transparent to mouse clicks
end

function RematchReduxPetCardStatMixin:OnEnter()
    local info = rematchRedux.petCardStats[self:GetID()]
    if info then
        self.Highlight:Show()
        if self.Icon then
            rematchRedux.textureHighlight:Show(self.Icon)
        end
        local petInfo = rematchRedux.petInfo:Fetch(rematchRedux.petCard.petID)

        if info.enter then
            info.enter(self,petInfo)
        elseif info.altTooltip=="Breed" and (settings.PetCardMinimized or settings.PetCardHidePossibleBreeds) then -- special case for Breed stat, show BreedTable if possible breeds hidden
            rematchRedux.petCard:ShowBreedTable(self)
        else
            local tooltipTitle = rematchRedux.utils:Evaluate(rematchRedux.utils:Evaluate(info.tooltipTitle,rematchRedux.petCard,petInfo))
            local tooltipBody = rematchRedux.utils:Evaluate(rematchRedux.utils:Evaluate(info.tooltipBody,rematchRedux.petCard,petInfo))
            if tooltipTitle then
                rematchRedux.tooltip:ShowSimpleTooltip(self,tooltipTitle,tooltipBody)
            end
        end
    end
end

function RematchReduxPetCardStatMixin:OnLeave()
    local info = rematchRedux.petCardStats[self:GetID()]
    if info then
        self.Highlight:Hide()
        if self.Icon then
            rematchRedux.textureHighlight:Hide()
        end
        rematchRedux.petCard:HideBreedTable()
        if info.leave then
            info.leave(self,rematchRedux.petInfo:Fetch(rematchRedux.petCard.petID))
        end
    end
    rematchRedux.tooltip:Hide()
end

function RematchReduxPetCardStatMixin:OnMouseDown()
    local info = rematchRedux.petCardStats[self:GetID()]
    if info then
        self.Highlight:Hide()
        if self.Icon then
            rematchRedux.textureHighlight:Hide()
        end
    end
end

function RematchReduxPetCardStatMixin:OnMouseUp()
    local info = rematchRedux.petCardStats[self:GetID()]
    if info then
        self.Highlight:Show()
        if self.Icon then
            rematchRedux.textureHighlight:Hide(self.Icon)
        end
    end
end

function RematchReduxPetCardStatMixin:OnClick()
    local info = rematchRedux.petCardStats[self:GetID()]
    if info and info.click then
        info.click(self,rematchRedux.petInfo:Fetch(rematchRedux.petCard.petID))
    end
end
