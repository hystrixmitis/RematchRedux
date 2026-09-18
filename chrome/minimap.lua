local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.minimap = RematchReduxMinimapButton

rematchRedux.events:Register(rematchRedux.minimap,"PLAYER_LOGIN",function(self)
    self:Configure()
    rematchRedux.menus:Register("MinimapFavorites",{})
end)

function rematchRedux.minimap:OnEnter()
    if not self.isDragging then
        rematchRedux.tooltip:ShowSimpleTooltip(self,L["RematchRedux"],format(L["%s Toggle Window\n%s Load Favorite Team"],C.LMB_TEXT_ICON,C.RMB_TEXT_ICON),"BOTTOMRIGHT",self,"TOPLEFT",8,-8)
    end
end

function rematchRedux.minimap:OnLeave()
    rematchRedux.tooltip:Hide()
end

function rematchRedux.minimap:OnMouseDown()
    self.Icon:SetPoint("CENTER",1,-1)
    self.Icon:SetVertexColor(0.65,0.65,0.65)
end

function rematchRedux.minimap:OnMouseUp()
    self.Icon:SetPoint("CENTER")
    self.Icon:SetVertexColor(1,1,1)
end

-- menu function to load teamID
local function loadTeam(self)
    rematchRedux.loadTeam:LoadTeamID(self.teamID)
end

function rematchRedux.minimap:OnClick(button)
    if button=="RightButton" then
        rematchRedux.tooltip:Hide()
        -- rebuild menu for current favorites
        local menu = rematchRedux.menus:GetDefinition("MinimapFavorites")
        wipe(menu) -- clear menu and rebuild
        tinsert(menu,{title=L["Favorite Teams"]})
        local teams = rematchRedux.savedGroups["group:favorites"].teams
        if not teams or #teams==0 then -- if no teams :(
            tinsert(menu,{text=format(L["%sNo favorite teams :("],C.HEX_GREY)})
        else -- at least one team favorited, add them to menu
            for _,teamID in ipairs(teams) do
                tinsert(menu,{text=rematchRedux.utils:GetFormattedTeamName(teamID),teamID=teamID,func=loadTeam})
            end
        end

        rematchRedux.menus:Register("MinimapFavorites",menu)

        rematchRedux.menus:Toggle("MinimapFavorites",self,nil,"TOPRIGHT",self,"BOTTOMLEFT",8,8)
    else
        rematchRedux.frame:Toggle()
    end
end

function rematchRedux.minimap:OnDragStart()
    rematchRedux.menus:Hide()
    rematchRedux.tooltip:Hide()
    self.isDragging = true
    self:SetScript("OnUpdate",self.OnDragUpdate)
end

function rematchRedux.minimap:OnDragStop()
    self.Icon:SetPoint("CENTER")
    self.Icon:SetVertexColor(1,1,1)
    self:SetScript("OnUpdate",nil)
    self.isDragging = false
end

function rematchRedux.minimap:Configure()
    self:SetShown(settings.UseMinimapButton)
    self:Update()
end

-- updates position of button based on MinimapButtonPosition setting
function rematchRedux.minimap:Update()
    local angle = settings.MinimapButtonPosition or -162
    self:SetPoint("CENTER",Minimap,"CENTER",(105*cos(angle)),(105*sin(angle)))
end

-- OnUpdate while button being dragged, calculates new position(angle) for button and moves it
function rematchRedux.minimap:OnDragUpdate(elapsed)
    local x,y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local minX,minY = Minimap:GetCenter()
    settings.MinimapButtonPosition = math.deg(math.atan2(y/scale-minY,x/scale-minX))
    rematchRedux.minimap:Update()
end