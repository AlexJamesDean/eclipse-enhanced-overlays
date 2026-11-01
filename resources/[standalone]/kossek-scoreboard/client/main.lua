local displaying = false

local function OpenScoreboard()
    SendNUIMessage({
        action     = 'openScoreboard',
        myId       = GetPlayerServerId(PlayerId()),
        players    = GlobalState['scoreboard_players'] or {},
        counter    = GlobalState['scoreboard_counter'] or {},
        serverName = Config.ServerName,
        slots      = GlobalState['scoreboard_slots'] or Config.Slots
    })
end

local function CloseScoreboard()
    SendNUIMessage({ action = 'closeScoreboard' })
end

-- Arrow up/down scrolls the list while it's open.
CreateThread(function()
    while true do
        if displaying then
            if IsControlPressed(0, 188) then
                SendNUIMessage({ action = 'scrollUp' })
            elseif IsControlPressed(0, 173) then
                SendNUIMessage({ action = 'scrollDown' })
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- Single toggle: press to show, press again to hide. Data is read fresh from
-- GlobalState each open, so there is no client-side cache to race or miss.
-- Use a new command identifier so clients with the old HOME mapping cached in
-- their FiveM profile receive the new SLASH default instead of retaining HOME.
RegisterCommand('ec_scoreboard', function()
    if displaying then
        displaying = false
        CloseScoreboard()
    else
        displaying = true
        OpenScoreboard()
    end
end, false)

RegisterKeyMapping('ec_scoreboard', 'Toggle scoreboard', 'keyboard', Config.Key)
