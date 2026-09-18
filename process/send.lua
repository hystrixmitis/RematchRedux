local _, rematchRedux = ...
local L = rematchRedux.localization
local C = rematchRedux.constants
local settings = rematchRedux.settings
rematchRedux.send = {}

local incomingTeam -- teamString received from another user is built on this
local outgoingTeam -- teamString being sent split into an ordered table
local outgoingRecipient -- name or bnet account of player team is being sent to
local outgoingChannel -- "whisper" or "bnet" channel used to send the team

rematchRedux.events:Register(rematchRedux.send,"PLAYER_LOGIN",function(self)

	C_ChatInfo.RegisterAddonMessagePrefix("RematchRedux")
    rematchRedux.events:Register(rematchRedux.send,"CHAT_MSG_ADDON",rematchRedux.send.CHAT_MSG_ADDON)
    rematchRedux.events:Register(rematchRedux.send,"BN_CHAT_MSG_ADDON",rematchRedux.send.CHAT_MSG_ADDON)

    rematchRedux.dialog:Register("SendTeam",{
        title = L["Send Team"],
        accept = L["Send"],
        cancel = CANCEL,
        layout = {"Text","Spacer","TeamWithAbilities","IncludeCheckButtons","Help","EditBox","Feedback"},
        stayOnAccept = true,
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                self.Text:SetText(rematchRedux.utils:GetFormattedTeamName(subject.teamID))
                self.TeamWithAbilities:FillFromTeamID(subject.teamID)
                self.IncludeCheckButtons:Update(subject.teamID)
                self.Help:SetText(L["Enter the name of an online RematchRedux user:"])
                self.EditBox:SetLabel(L["Send To:"])
                self.EditBox:SetText("")
                self.EditBox:SetEnabled(true)
                self.Feedback:Hide()
                rematchRedux.dialog.AcceptButton:Disable()
            end
        end,
        cancelFunc = function(self,info,subject)
            rematchRedux.send:StopSend()
        end,
        changeFunc = function(self,info,subject)
            local name = self.EditBox:GetText():trim()
            rematchRedux.dialog.AcceptButton:SetEnabled(name:len()>0)
            settings.ExportIncludePreferences = self.IncludeCheckButtons.IncludePreferences:GetChecked()
            settings.ExportIncludeNotes = self.IncludeCheckButtons.IncludeNotes:GetChecked()
        end,
        acceptFunc = function(self,info,subject)
            outgoingChannel = nil
            outgoingRecipient = nil
            self.Feedback:Show()
            self.Feedback:Set("mail",L["Sending, please wait..."])
            local name = self.EditBox:GetText():trim()
            local bnetID = BNet_GetBNetIDAccount(name)
            if bnetID then
                local bnetInfo = C_BattleNet.GetAccountInfoByID(bnetID)
                if bnetInfo then
                    local bnetAccount = bnetInfo.gameAccountInfo.gameAccountID
                    local client = bnetInfo.gameAccountInfo.clientProgram
                    if bnetAccount and client=="WoW" then
                        outgoingChannel = "bnet"
                        outgoingRecipient = bnetAccount
                    end
                end
            end
            -- if a bnet outgoingRecipient wasn't online, look for a user with that name
            if not outgoingRecipient then
                outgoingChannel = "whisper"
                outgoingRecipient = name
            end
            outgoingTeam = rematchRedux.teamStrings:SplitTeamStrings(subject.teamID)
            -- ready to send the team
            rematchRedux.send:SendTeam()
         end
    })

    rematchRedux.dialog:Register("ReceiveTeam",{
        title = L["Incoming RematchRedux Team"],
        accept = SAVE,
        cancel = CANCEL,
        other = L["Load"],
        layouts = {
            Default = {"Text","Spacer","Text2","TeamWithAbilities","CheckButton","GroupSelect"},
            SingleTeamConflict = {"Text","Spacer","Text2","TeamWithAbilities","CheckButton","GroupSelect","Feedback","ConflictRadios"},
            GroupPick = {"GroupPicker"}
        },
        conditions = {
            CheckButton = function(self,info,subject) -- only show breed checkbutton if there's a breed source
                return rematchRedux.breedInfo:GetBreedSource() and true or false
            end,
        },        
        refreshFunc = function(self,info,subject,firstRun)
            if firstRun then
                -- for whisper, sender is the name of the sender; for bnet, sender is bnet id
                local senderName = subject.sender
                if type(senderName)=="number" then
                    local bnetInfo = C_BattleNet.GetGameAccountInfoByID(subject.sender)
                    senderName = bnetInfo and bnetInfo.characterName or L["Someone"]
                end
                self.Text:SetText(format(L["%s%s has sent you a team!"],C.HEX_BLUE,senderName))
                rematchRedux.teamStrings:SidelineTeamString(subject.import,settings.LastSelectedGroup)
                self.Text2:SetText(C.HEX_WHITE..(rematchRedux.savedTeams.sideline.name or ""))
                self.CheckButton:SetText(L["Prioritize Breed For Imports"])
                self.CheckButton.Check.tooltipBody = L["When importing teams, prefer pets that match the breed even if higher levels of other breeds are available."]                
                self.CheckButton:SetChecked(settings.PrioritizeBreedOnImport)
                rematchRedux.dialog.OtherButton.tooltipTitle = L["Only Load This Team"]
                rematchRedux.dialog.OtherButton.tooltipBody = L["This will only load the team and not save it.\n\nThis is for importing teams you intend to use just once. You can still save the team afterwards if you want to keep it."]
                self.TeamWithAbilities:FillFromTeamID("sideline")

                if not settings.ImportRememberOverride then
                    settings.ImportConflictOverwrite = false
                end
                self.ConflictRadios:Update()

                local numGroups,numTeams,numConflicts,numBad = rematchRedux.teamStrings:AnalyzeImport(subject.import)                
                if numConflicts > 0 then
                    self.GroupPicker:SetReturn("SingleTeamConflict")
                    self.Feedback:Set("warning",L["This team has the same name as an existing team"])
                    rematchRedux.dialog:ChangeLayout("SingleTeamConflict")                    
                else
                    self.GroupPicker:SetReturn("Default")
                end
            end
            self.GroupSelect:Fill(rematchRedux.savedTeams.sideline.groupID)
        end,
        changeFunc = function(self,info,subject)
            settings.PrioritizeBreedOnImport = self.CheckButton:GetChecked()
            rematchRedux.teamStrings:SidelineTeamString(subject.import,settings.LastSelectedGroup)
            self.TeamWithAbilities:FillFromTeamID("sideline")
        end,
        acceptFunc = function(self,info,subject)
            rematchRedux.teamStrings:Import(subject.import)
        end,
        otherFunc = function(self,info,subject)
            rematchRedux.teamStrings:LoadOnly(subject.import)
        end
    })

end)

-- sends message to recipient (name or bnet account) over the channel ("whisper" or "bnet")
function rematchRedux.send:SendMessage(recipient,message)
    if type(recipient)=="number" then -- this is a bnet account
        BNSendGameData(recipient,"RematchRedux",message)
    elseif type(recipient)=="string" then -- this is a regular name
        C_ChatInfo.SendAddonMessage("RematchRedux",message,"WHISPER",recipient)
    end
end

-- from the subject built in the SendTeam dialog
-- subject = {
--     channel = "whipser" or "bnet"
--     recipient = name or battlenet ID sending to
--     teamID = teamID being sent
--     data = ordered table of teamString potentially split into multiple lines
-- }
function rematchRedux.send:SendTeam()
    if outgoingRecipient and outgoingChannel and type(outgoingTeam)=="table" and #outgoingTeam>0 then
        rematchRedux.timer:Start(C.SEND_TIMEOUT,rematchRedux.send.Timeout)
        if rematchRedux.dialog:GetOpenDialog()~="SendTeam" then
            return -- dialog was closed before team fully sent, we're done
        end
        rematchRedux.send:SendMessage(outgoingRecipient,outgoingTeam[1])
        tremove(outgoingTeam,1)
    end
end

-- after C.SEND_TIMEOUT seconds when a send begins, this is called
function rematchRedux.send:Timeout()
    if rematchRedux.dialog:GetOpenDialog()=="SendTeam" then
        rematchRedux.dialog.Canvas.Feedback:Set("failure",L["No response. This player is not online or doesn't have RematchRedux enabled."])
    end
end

-- stops the timeout and clears outgoing team
function rematchRedux.send:StopSend()
    rematchRedux.timer:Stop(rematchRedux.send.Timeout)
    outgoingTeam = nil
    outgoingRecipient = nil
    outgoingChannel = nil
end

-- both BN_CHAT_MSG_ADDON and CHAT_MSG_ADDON use this, when a message is received
function rematchRedux.send:CHAT_MSG_ADDON(prefix,message,_,sender)
    if prefix~="RematchRedux" then
        return
    end
    local isSending = rematchRedux.dialog:GetOpenDialog()=="SendTeam"

    if isSending and message~="ack" then
        rematchRedux.send:StopSend() -- message received from recipient that should stop sending
    end

    if isSending and message=="ack" then -- one line of incomplete team received (expecting more)
        rematchRedux.send:SendTeam()
    elseif isSending and message=="ok" then -- team was received completely from receipient
        rematchRedux.dialog.Canvas.Feedback:Set("success",L["Team successfully sent!"])
    elseif isSending and message=="busy" then -- recipient has a dialog open
        rematchRedux.dialog.Canvas.Feedback:Set("failure",L["They're busy. Try again later."])
    elseif isSending and message=="combat" then -- recipient in combat
        rematchRedux.dialog.Canvas.Feedback:Set("failure",L["They're in combat. Try again later."])
    elseif isSending and message=="block" then -- recipient has Disable Share checked in options
        rematchRedux.dialog.Canvas.Feedback:Set("failure",L["They have team sharing disabled."])
    elseif isSending and message=="error" then -- recipient had an error when receing team, try again
        rematchRedux.dialog.Canvas.Feedback:Set("failure",L["There was an error. Try again later."])
    
    -- any other messages are unsolicited, likely an incoming team
    
    elseif not isSending and settings.DisableShare then
        rematchRedux.send:SendMessage(sender,"block")
    elseif not isSending and InCombatLockdown() then
        rematchRedux.send:SendMessage(sender,"combat")
    elseif rematchRedux.dialog:GetOpenDialog() then
        rematchRedux.send:SendMessage(sender,"busy")
    elseif not isSending then

        -- if receiving beginning of what could be a team, start incomingTeam concatenated string
        if not message:match("^\002") then
            incomingTeam = message:gsub("\003","")
        elseif not incomingTeam then -- it began with \002 but we haven't started an incomingTeam
            rematchRedux.send:SendMessage(sender,"error") 
            return
        else -- it began with \002 and an incomingTeam began, add to it
            incomingTeam = incomingTeam..message:gsub("\002",""):gsub("\003","")
        end

        if message:match("\003$") then -- line ends with \003 so more is coming, send ack to get next line
            rematchRedux.send:SendMessage(sender,"ack")
            return
        else -- if this was the last (possibly only) line, test if it's a team
            local numGroups,numTeams,numConflicts,numBad = rematchRedux.teamStrings:AnalyzeImport(incomingTeam)
            if numTeams==0 or numBad~=0 then -- not a valid team :(
                rematchRedux.send:SendMessage(sender,"error")
                return
            else -- it's a valid team!
                rematchRedux.send:SendMessage(sender,"ok")
                rematchRedux.teamStrings:SidelineTeamString(incomingTeam,settings.LastSelectedGroup)
                rematchRedux.dialog:ShowDialog("ReceiveTeam",{sender=sender,import=incomingTeam})
            end
        end
        -- incomingTeam needs to be nil'ed at some point
    end
end
