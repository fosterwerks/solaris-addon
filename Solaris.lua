Solaris = {}
Solaris.name = "Solaris"
Solaris.version = 2

local defaults = {
}

-- CONSTANTS --------------------------------------------------------------------------------------

local SECONDS_PER_DAY_RT = 86400
local SECONDS_PER_DAY_TT = 20955
local RT_TO_TT = SECONDS_PER_DAY_TT / SECONDS_PER_DAY_RT
local TT_TO_RT = SECONDS_PER_DAY_RT / SECONDS_PER_DAY_TT

local PERCENT_DAYTIME_TO_DAY_TT = 19 / 24
local PERCENT_NIGHTTIME_TO_DAY_TT = 5 / 24

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

-- SLASH COMMANDS ---------------------------------------------------------------------------------

function Solaris.GetSunriseSunset()
    local SUNRISE_P = 3/24
    local SUNSET_P = 22/24

    rts = Solaris.GetSecondsRT()
    ttp = Solaris.GetPercentTT()

    local sunrise, sunset               -- defined as seconds past midnight (real-time)

    if ttp < SUNRISE_P then
        sunrise = (rts + (ttp - SUNRISE_P) * SECONDS_PER_DAY_TT) % SECONDS_PER_DAY_RT
        sunset = (sunrise + SECONDS_PER_DAY_TT * PERCENT_DAYTIME_TO_DAY_TT) % SECONDS_PER_DAY_RT
        df("Next sunrise: %s:%s:%s", Solaris.GetHMS(sunrise))
        df("Next sunset: %s:%s:%s", Solaris.GetHMS(sunset))
    elseif ttp < SUNSET_P then
        sunset = ((rts + (SUNSET_P - ttp) * SECONDS_PER_DAY_TT) % SECONDS_PER_DAY_RT) / SECONDS_PER_DAY_RT
        sunrise = ((sunset + SECONDS_PER_DAY_TT * PERCENT_NIGHTTIME_TO_DAY_TT) % SECONDS_PER_DAY_RT) / SECONDS_PER_DAY_RT
        df("Next sunset: %s:%s:%s", Solaris.GetHMS(sunset))
        df("Next sunrise: %s:%s:%s", Solaris.GetHMS(sunrise))
    else
        sunrise = (rts + (1 - ttp + SUNRISE_P) * SECONDS_PER_DAY_TT) % SECONDS_PER_DAY_RT
        sunset = (sunrise + SECONDS_PER_DAY_TT * PERCENT_DAYTIME_TO_DAY_TT) % SECONDS_PER_DAY_RT
        df("Next sunrise: %s:%s:%s", Solaris.GetHMS(sunrise))
        df("Next sunset: %s:%s:%s", Solaris.GetHMS(sunset))
    end

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
    SLASH_COMMANDS["/sol"] = Solaris.GetSunriseSunset
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
    local tDayWidth = rDayWidth * RT_TO_TT
    local tDaytimeWidth = tDayWidth * PERCENT_DAYTIME_TO_DAY_TT
    
    -- Update the Real-time Indicator position
    local pos = Solaris.UpdateRTI()
    
    -- Create first line to correspond with midnight (real-time) this morning
    local p = Solaris.GetPercentTT(0)
    local shift = -(p * tDayWidth) + (3/24 * tDayWidth)
    local tDayLine = window:GetNamedChild("TamrielDayLine") or
        CreateControlFromVirtual("$(parent)TamrielDayLine", window, "DaytimeLine")
    tDayLine:SetWidth(tDaytimeWidth)
    tDayLine:ClearAnchors()
    tDayLine:SetAnchor(TOPLEFT, window, TOPLEFT, shift, 2)
    tDayLine:SetHidden(false)
    
    -- Hide or trim line depending on position
    if -shift >= tDaytimeWidth then
        tDayLine:SetHidden(true)         -- if line is fully off the bar
    elseif shift < 0 then
        tDayLine:SetWidth(tDaytimeWidth - (-shift))
        tDayLine:ClearAnchors()
        tDayLine:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 2)
    end

    -- Now add tamriel days until the end of the bar
    shift = shift + tDaytimeWidth   -- anchoring now off the top-right corner of first day line
    index = 0
    repeat
        index = index + 1
        shift = shift + tDayWidth
        tDayLine = window:GetNamedChild("TamrielDayLine"..index) or
            CreateControlFromVirtual("$(parent)TamrielDayLine", window, "DaytimeLine", index)
        tDayLine:SetWidth(tDaytimeWidth)
        tDayLine:ClearAnchors()
        tDayLine:SetAnchor(TOPRIGHT, window, TOPLEFT, shift, 2)
        tDayLine:SetHidden(false)
    until shift >= w

    -- correct last created TamrielDayFuture
    if shift >= w + tDaytimeWidth then
        tDayLine:SetHidden(true)            -- if a full bar is off the line
    elseif shift > w then
        tDayLine:SetWidth(tDaytimeWidth - (shift - w))
        tDayLine:ClearAnchors()
        tDayLine:SetAnchor(TOPRIGHT, window, TOPRIGHT, 0, 2)
    end

    -- cleanup any bars from a rebuild
    index = index + 1
    while window:GetNamedChild("TamrielDayLine"..index) do
        window:GetNamedChild("TamrielDayLine"..index):SetHidden(true)
        index = index + 1
    end
end

function Solaris.UpdateRTI()
    local window = SolarisTimelineControl
    local w, _ = window:GetDimensions()
    
    -- Width of a real day on timeline control, control spans two days
    local rDayWidth = w / 2
    -- Width of a tamriel day on timeline control
    local tDayWidth = rDayWidth * RT_TO_TT
    local tDaytimeWidth = tDayWidth * PERCENT_DAYTIME_TO_DAY_TT
    
    -- Update the Real-time Indicator position
    local sRt = Solaris.GetSecondsRT()
    local pos = (sRt / SECONDS_PER_DAY_RT) * rDayWidth
    local rti = window:GetNamedChild("RT_Indicator")
    rti:ClearAnchors()
    rti:SetAnchor(BOTTOM, window, TOPLEFT, pos, 0)

    return pos
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

local lastPos
local lastUpdate = GetTimeStamp()
function Solaris.OnUpdate()
    local now = GetTimeStamp()
    if now - lastUpdate < 60 then return end
    lastUpdate = now

    -- update real-time indicator position and returns new position
    local pos = Solaris.UpdateRTI()

    if lastPos and (lastPos > pos) then
        Solaris.BuildControls()
    end
    lastPos = pos
end

-- EVENT REGISTRATIONS ----------------------------------------------------------------------------

-- Register our event handler function to be called when the proper event occurs
EVENT_MANAGER:RegisterForEvent(Solaris.name, EVENT_ADD_ON_LOADED, Solaris.OnAddOnLoaded)
