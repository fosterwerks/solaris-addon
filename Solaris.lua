-- Create addon's namespace
Solaris = {}
Solaris.name = "Solaris"
Solaris.version = 1

-- INITIALIZATION ---------------------------------------------------------------------------------

function Solaris:Initialize()
    -- Associate our variable with the appropriate 'saved variables' file
    self.savedVariables = ZO_SavedVars:NewAccountWide("SolarisSavedVariables", Solaris.version, nil, {})

    -- Restore indicator's position based on saved data
    self:RestorePosition()
end

-- OTHER FUNCTIONS --------------------------------------------------------------------------------

function Solaris:RestorePosition()
    local left = self.savedVariables.left
    local top = self.savedVariables.top
    SolarisTimelineControl:ClearAnchors()
    SolarisTimelineControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
end

-- EVENT HANDLER FUNCTIONS ------------------------------------------------------------------------

function Solaris.OnAddOnLoaded(event, addonName)
    -- The event fires each time any addon loads; check to see that it is our addon that's loading
    if addonName == Solaris.name then return end

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

-- EVENT REGISTRATIONS ----------------------------------------------------------------------------

-- Register our event handler function to be called when the proper event occurs
EVENT_MANAGER:RegisterForEvent(Solaris.name, EVENT_ADD_ON_LOADED, Solaris.OnAddOnLoaded)
