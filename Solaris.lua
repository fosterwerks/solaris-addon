Solaris = {}
Solaris.name = "Solaris"
Solaris.version = 1

local defaults = {
    numberOfDays = 3
}

-- CONSTANTS --------------------------------------------------------------------------------------

local PERCENT_NIGHT = 7200 / 20955
local PERCENT_DAY = 1 - PERCENT_NIGHT
local PERCENT_TT = 20955 / (24 * 60 * 60)

local SECONDS_PER_DAY = 86400

local WINDOW_LENGTH = 480

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

function Solaris.GetPercentTT()
	local day,night=20955,7200
	local tSinceMidnight=GetTimeStamp() - 1398044126 + night/2 + (day-night)/2
	local daysPast=day*math.floor(tSinceMidnight/day)
	local s=tSinceMidnight-daysPast
    local t=s/day
    return t
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

    local p = Solaris.GetPercentRT() * w / 2
    local rti = window:GetNamedChild("RT_Indicator")
    rti:ClearAnchors()
    rti:SetAnchor(BOTTOM, window, TOPLEFT, p, 0)

    local tDay_1 = CreateControlFromVirtual("Daytime", window, "DaytimeLine", "1")
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
