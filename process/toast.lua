local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.toast = {}

function rematchRedux.toast:Setup(petID)
    local petInfo = rematchRedux.petInfo:Fetch(petID)
    if petID then
        self.Title:SetText(L["Now leveling:"])
        self.Name:SetText(petInfo.name)
        self.Icon.Texture:SetTexture(petInfo.icon)
    else
        self.Title:SetText(L["RematchRedux's leveling queue is empty"])
        self.Name:SetText(L["All done leveling pets!"])
        self.Icon.Texture:SetTexture("Interface\\Icons\\INV_Pet_Achievement_WinAPetBattle")
    end
end

function rematchRedux.toast:ToastLevelingPet(petID)
    if settings.HidePetToast then
        return -- aww :(
    end
    if not self.LevelingToastSystem then
        self.LevelingToastSystem = AlertFrame:AddQueuedAlertFrameSubSystem("RematchReduxLevelingToastTemplate",self.Setup,2,0)
    end
    self.LevelingToastSystem:AddAlert(petID)
end
