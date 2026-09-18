local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
rematchRedux.textureDrag = {}

--[[
    This handles the dragging of petIDs from textures (which don't have OnDragStart).
    For dragging teams, see process\dragFrame.xml
]]

local isDragging -- true while the texture is being dragged (mouse went down on dragging texture and hasn't gone up)
local dragSource -- texture where the mouse went down

rematchRedux.events:Register(rematchRedux.textureDrag,"PLAYER_LOGIN",function(self)
    self.eventFrame = CreateFrame("Frame",nil,rematchRedux.frame)
    self.eventFrame:SetScript("OnShow",function() self:Start() end)
    self.eventFrame:SetScript("OnHide",function() self:Stop() end)
end)

-- when RematchRedux shown, start watching for mouse down/up events
function rematchRedux.textureDrag:Start()
    rematchRedux.events:Register(self,"GLOBAL_MOUSE_DOWN",self.GLOBAL_MOUSE_DOWN)
    rematchRedux.events:Register(self,"GLOBAL_MOUSE_UP",self.GLOBAL_MOUSE_UP)
end

-- when RematchRedux hides, stop watching for mouse down/up events
function rematchRedux.textureDrag:Stop()
    rematchRedux.events:Unregister(self,"GLOBAL_MOUSE_DOWN")
    rematchRedux.events:Unregister(self,"GLOBAL_MOUSE_UP")
    isDragging = nil
    dragSource = nil
end

-- when mouse goes down when there's nothing on the cursor, see if focus is a texture with a .draggable flag
function rematchRedux.textureDrag:GLOBAL_MOUSE_DOWN(button)
    if button=="LeftButton" and not GetCursorInfo() then
        local focus = GetMouseFoci()[1]
        if focus and not focus:IsForbidden() and focus:GetObjectType()=="Texture" and focus.draggable then
            isDragging = true
            dragSource = focus
        end
    end
end

-- when mouse goes up, see if focus has a .dragReceive value and call its OnReceiveDrag (or its parent's if it doesn't have one)
function rematchRedux.textureDrag:GLOBAL_MOUSE_UP()
    if self:IsDragging() and GetCursorInfo() then -- if there's a pet on the mouse
        local focus = GetMouseFoci()[1]
        if focus then
            if focus:GetObjectType()=="Texture" then
                focus = focus:GetParent() -- if dropping onto a texture, then shift to parent frame
            end
            -- if the focus has an OnReceiveDrag, then call it
            local onReceive = focus:GetScript("OnReceiveDrag")
            if onReceive then
                onReceive(focus)
            end
        end
    end
    isDragging = nil
    dragSource = nil
end

-- only dragging if the mouse has left the source where the texture was picked up
function rematchRedux.textureDrag:IsDragging()
    return isDragging and dragSource~=GetMouseFoci()[1]
end
