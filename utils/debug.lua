local _, rematchRedux = ...
local L = rematchRedux.localization
rematchRedux.debug = {}

local debugTypes = {
    error = true,
    layout = false,
    savedvar = false,
    journal = false,
    roster = false,
    event = true,
    updates = true,
    teams = false,
}

rematchRedux.debug.times = {} -- used to log times
local profileStop

-- returns where the calling function was called from
function rematchRedux.debug:CallerID()
    local where = (debugstack():match(".-\n.-\n.-\n.-\\AddOns\\.-\\(.-:%d+.-)\n") or ""):gsub("\"]","")
    if where:len()==0 then
        where = (debugstack():match(".-\n.-\n.-\\AddOns\\.-\\(.-:%d+.-)\n") or ""):gsub("\"]","")
    end
    return where:len()>0 and where or debugstack()
end


function rematchRedux.debug:Write(debugType,...)
    if debugTypes[debugType] then
        print(...)
    end
end

-- returns the parentKey under rematchRedux of the given frame
function rematchRedux.debug:GetModuleName(module)
    for k,v in pairs(rematchRedux) do
        if module==v then
            return k
        end
    end
    return module
end

-- call this to wrap all update functions to print "Updating <parentKey>"
local updateHooks
function rematchRedux.debug:MonitorUpdates()
    for k,v in pairs(rematchRedux) do
        if type(v)=="table" and type(v.Update)=="function" then
            local o = v.Update
            rematchRedux[k].Update = function(self,...)
                rematchRedux.debug:Write("updates","Updating",k)
                return o(self,...)
            end
        end
    end
end

function rematchRedux.debug:StartProfile()
    profileStop = debugprofilestop()
end

function rematchRedux.debug:Profile(name)
    rematchRedux.debug.times[name] = (rematchRedux.debug.times[name] or 0) + (debugprofilestop()-profileStop)
    profileStop = debugprofilestop()
end