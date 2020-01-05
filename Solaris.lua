Solaris = {}
Solaris.name = "Solaris"
Solaris.version = 1

local defaults = {
    numberOfDays = 3
}

-- CONSTANTS --------------------------------------------------------------------------------------

local SECONDS_PER_DAY_RT = 86400
local SECONDS_PER_DAY_TT = 20955
local PERCENT_TT_TO_RT = SECONDS_PER_DAY_TT / SECONDS_PER_DAY_RT

local PERCENT_DAYTIME_TO_DAY_TT = 19 / 24

-- TIME FUNCTIONS ---------------------------------------------------------------------------------

function Solaris.GetSecondsRT()
    local t = GetFormattedTime()
    local s = t % 100           t = math.floor(t/100)
    s = s + (t % 100) * 60      t = math.floor(t/100)
    s = s + (t * 3600)
    return s
end

function Solaris.GetPercentRT()
    local t = GetFormattedTime()
    local s = t % 100
    t = (t - s) / 100
    local m = t % 100
    local h = (t - m) / 100
    m = m + (s / 60)
    h = h + (m / 60)
    return h / 24
end

function Solaris.GetHMS(percentOfDay)
    local t = percentOfDay * 24
    local h = math.floor(t) t=(t-h)*60
    local m = math.floor(t) t=(t-m)*60
    local s = math.floor(t)
    return h, m, s
end

-- param: rtSeconds (optional)
-- rtSeconds is the number of seconds past midnight (real-time) at the beginning of the current day
function Solaris.GetPercentTT(rtSeconds)
    local day = SECONDS_PER_DAY_TT
    
    local t = GetTimeStamp()
    local rtS = Solaris.GetSecondsRT()

    local secondsSinceSomeMidnightInGame = t - (1398044126 - day/2)            -- 139... = calibaration at sun noon in-game?
    
    if rtSeconds then
        secondsSinceSomeMidnightInGame = secondsSinceSomeMidnightInGame - rtS + rtSeconds
    end
    
    local s = secondsSinceSomeMidnightInGame % day
    local p = s / day
    return p
end

-- INITIALIZATION ---------------------------------------------------------------------------------

function Solaris:Initialize()
    -- Associate our variable with the appropriate 'saved variables' file
    self.savedVariables = ZO_SavedVars:NewAccountWide("SolarisSavedVariables", Solaris.version, nil, defaults)

    self:RestorePosition()
    self:BuildControls()
    self:RegisterSlashCommands()
end

function Solaris:RegisterSlashCommands()

end



-- GUI FUNCTIONS ----------------------------------------------------------------------------------

function Solaris:RestorePosition()
    local left = self.savedVariables.left
    local top = self.savedVariables.top
    SolarisTimelineControl:ClearAnchors()
    SolarisTimelineControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

function Solaris:BuildControls()
    local window = SolarisTimelineControl
    local w, _ = window:GetDimensions()
    
    -- Width of a real day on timeline control, control spans two days
    local rDayWidth = w / 2
    -- Width of a tamriel day on timeline control
    local tDayWidth = rDayWidth * PERCENT_TT_TO_RT
    local tDaytimeWidth = tDayWidth * PERCENT_DAYTIME_TO_DAY_TT
    
    -- Update the Real-time Indicator position
    local sRt = Solaris.GetSecondsRT()
    local pos = (sRt / SECONDS_PER_DAY_RT) * rDayWidth
    local rti = window:GetNamedChild("RT_Indicator")
    rti:ClearAnchors()
    rti:SetAnchor(BOTTOM, window, TOPLEFT, pos, 0)

    local p = Solaris.GetPercentTT()
    local shift = -(p * tDayWidth) + (3/24 * tDayWidth) + pos

    -- Create day line for the current tamriel day
    local tDayNow = CreateControlFromVirtual("TamrielDayNow", window, "DaytimeLine")
    tDayNow:SetWidth(tDaytimeWidth)
    tDayNow:ClearAnchors()
    tDayNow:SetAnchor(TOPLEFT, window, TOPLEFT, shift, 2)
    
    -- Hide or trim current tamriel day line depending on position
    if -shift >= tDaytimeWidth then
        tDayNow:SetHidden(true)
    elseif shift < 0 then
        tDayNow:SetWidth(tDaytimeWidth - (-shift))
        tDayNow:ClearAnchors()
        tDayNow:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 2)
    end

    -- Now create tamriel days, back to midnight this morning
    local index = 0
    local tDayPast
    repeat
        index = index + 1
        shift = shift - tDayWidth
        tDayPast = CreateControlFromVirtual("TamrielDayPast", window, "DaytimeLine", index)
        tDayPast:SetWidth(tDaytimeWidth)
        tDayPast:ClearAnchors()
        tDayPast:SetAnchor(TOPLEFT, window, TOPLEFT, shift, 2)
    until shift <= 0

    -- correct last created TamrielDayPast
    if -shift >= tDaytimeWidth then
        tDayPast:SetHidden(true)            -- if a full bar is off the line
    else
        tDayPast:SetWidth(tDaytimeWidth - (-shift))
        tDayPast:ClearAnchors()
        tDayPast:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 2)
    end

    -- Now add future tamriel days
    index = 0
    shift = pos  + ((1 - p) * tDayWidth) - (2/24 * tDayWidth)       -- init shift to right side of tDayNow
    local tDayFuture
    repeat
        index = index + 1
        shift = shift + tDayWidth
        tDayFuture = CreateControlFromVirtual("TamrielDayFuture", window, "DaytimeLine", index)
        tDayFuture:SetWidth(tDaytimeWidth)
        tDayFuture:ClearAnchors()
        tDayFuture:SetAnchor(TOPRIGHT, window, TOPLEFT, shift, 2)
    until shift >= w

    -- correct last created TamrielDayPast
    if shift >= w + tDaytimeWidth then
        tDayFuture:SetHidden(true)            -- if a full bar is off the line
    else
        tDayFuture:SetWidth(tDaytimeWidth - (shift - w))
    end
end


-- EVENT HANDLER FUNCTIONS ------------------------------------------------------------------------

function Solaris.OnAddOnLoaded(event, addonName)
    -- The event fires each time any addon loads; check to see that it is our addon that's loading
    if addonName ~= Solaris.name then return end

    -- Unregister loaded callback
    EVENT_MANAGER:UnregisterForEvent(Solaris.name, EVENT_ADD_ON_LOADED)

    -- Begin initialization
    Solaris:Initialize()
end

function Solaris.OnTimelineMoveStop()
    -- Save position after moving control
    Solaris.savedVariables.left = SolarisTimelineControl:GetLeft()
    Solaris.savedVariables.top = SolarisTimelineControl:GetTop()
end

function Solaris.UpdateRTIPosition()
end

-- EVENT REGISTRATIONS ----------------------------------------------------------------------------

-- Register our event handler function to be called when the proper event occurs
EVENT_MANAGER:RegisterForEvent(Solaris.name, EVENT_ADD_ON_LOADED, Solaris.OnAddOnLoaded)
