local Scoreboard = {
    players = {},
    counter = {}
}

-- sv_maxclients is a server convar, so publish it for the client-side NUI.
-- Reading it directly on the client returned the old hard-coded fallback (48).
GlobalState['scoreboard_slots'] = GetConvarInt('sv_maxclients', Config.Slots)

local function GetSteam(playerId)
    for i = 0, GetNumPlayerIdentifiers(playerId) - 1 do
        local prefix, identifier = string.strsplit(':', GetPlayerIdentifier(playerId, i))

        if prefix == 'steam' then
            return identifier
        end
    end

    print('^0[^1ERROR^0] ^0Unable to find your steam id')
    return false
end

local function GetAvatar(playerId)
    -- No usable Steam Web API key -> don't call Steam at all. The UI just uses the
    -- placeholder image. (Calling Steam with an invalid key returns a response that
    -- never resolved the promise, which hung AddPlayer and left the board empty.)
    local apiKey = GetConvar('steam_webApiKey', 'none')
    if apiKey == 'none' or apiKey == '' then
        return false
    end

    local steamHex = GetSteam(playerId)
    if not steamHex or steamHex == '' then
        return false
    end

    local steamId = tonumber(steamHex, 16)
    if not steamId then
        return false
    end

    local p = promise.new()
    PerformHttpRequest(('http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s'):format(apiKey, steamId), function(err, data, headers)
        local decoded = data and json.decode(data) or nil
        if decoded and decoded.response and decoded.response.players and decoded.response.players[1] then
            p:resolve(decoded.response.players[1].avatarfull)
        else
            p:resolve(false) -- always resolve so Citizen.Await never hangs
        end
    end)

    return Citizen.Await(p)
end

--[[
    HIDDEN PLAYERS (7 Aug 2026, for ajd-ghost).

    Removing someone from the board client-side is not enough on its own: the list and the
    counter are re-derived from `Scoreboard.players` here and republished through
    GlobalState, so anyone opening the board afterwards would see the hidden player return.
    The skip has to happen at the point the snapshot is built, which is here.

    Counted as well as listed — a header reading 5 players over a list of 4 is a worse tell
    than simply being on the board.
]]
Scoreboard.hidden = Scoreboard.hidden or {}

local function UpdateCounter()
    Wait(1000)
    Scoreboard.counter = { players = 0, police = 0, ambulance = 0, mechanic = 0 }

    local list = {}
    for playerId, data in pairs(Scoreboard.players) do
        if Scoreboard.hidden[playerId] then goto continue end

        Scoreboard.counter.players += 1
        list[#list + 1] = data

        local jobName = (data.jobName or ''):lower()  -- job NAME (not label), lowercased for comparison
        if jobName == 'police' then
            Scoreboard.counter.police += 1
        elseif jobName == 'ambulance' then
            Scoreboard.counter.ambulance += 1
        elseif jobName == 'mechanic' then
            Scoreboard.counter.mechanic += 1
        end

        ::continue::
    end

    -- Publish both through GlobalState so every client reads a consistent, race-free
    -- snapshot at open time (the counter already worked this way; the list now does too).
    GlobalState['scoreboard_players'] = list
    GlobalState['scoreboard_counter'] = Scoreboard.counter
end

function AddPlayer(player, restart)
    local playerId = GetSource(player)
    local playerData = GetPlayerData(player)

    Scoreboard.players[playerId] = {
        id = playerId,
        identifier = playerData.identifier,
        name = playerData.name,
        avatar = GetAvatar(playerId),
        job = playerData.job.label,  -- label for the UI list
        jobName = playerData.job.name  -- name for the header counters
    }

    if not restart then
        TriggerClientEvent('kossek-scoreboard:addPlayer', -1, Scoreboard.players[playerId])
        UpdateCounter()
    end
end

function PlayerLoaded(player)
    if player then
        AddPlayer(player)
        TriggerClientEvent('kossek-scoreboard:playerLoaded', GetSource(player), Scoreboard.players)
    end
end

function RemovePlayer(playerId)
    if playerId then
        TriggerClientEvent('kossek-scoreboard:removePlayer', -1, Scoreboard.players[playerId])
        Scoreboard.players[playerId] = nil

        UpdateCounter()
    end
end

function UpdatePlayerJob(playerId, job)
    if playerId then
        local player = GetPlayerFromId(playerId)
        if player then
            local playerData = GetPlayerData(player)
            Scoreboard.players[playerId].job = playerData.job.label  -- label for the UI list
            Scoreboard.players[playerId].jobName = playerData.job.name  -- name for the header counters
            TriggerClientEvent('kossek-scoreboard:updatePlayer', -1, Scoreboard.players[playerId])
            UpdateCounter()
        end
    end
end

AddEventHandler('playerDropped', function()
    local source = source
    RemovePlayer(source)
end)

AddEventHandler('onResourceStart', function(name)
    if name ~= GetCurrentResourceName() then return end

    -- GetQBPlayers() is keyed by player source, so `#players` is unreliable (often 0)
    -- and the original skipped everyone on a resource restart. Iterate with pairs.
    for _, qbPlayer in pairs(GetServerPlayers()) do
        local player = GetPlayerFromId(GetSource(qbPlayer))
        if player then
            AddPlayer(player, true)
        end
    end

    UpdateCounter() -- publishes players + counter into GlobalState
    TriggerClientEvent('kossek-scoreboard:playerLoaded', -1, Scoreboard.players)
end)

--[[
    ─── HIDE / SHOW, for ajd-ghost (7 Aug 2026) ─────────────────────────────────

    ajd-ghost drops AJ into his own routing bucket so players cannot reach him, but a
    bucket says nothing about this board — he tested it and was still listed. These
    exports are the missing half.

    Both do the same two things in the same order: flip the flag so the GlobalState
    snapshot in UpdateCounter stops including him, then push the incremental client event
    so boards already open update immediately instead of waiting for the next open.

    UpdateCounter() opens with a Wait, so it can only run inside a coroutine — hence the
    CreateThread. Calling it directly from an export invoked by another resource would
    error on the yield.

    `playerLoaded` also re-sends the full table to a joining client, so the flag has to be
    respected there too; that is handled by the snapshot rather than here.
]]
local function setHidden(playerId, hidden)
    playerId = tonumber(playerId)
    if not playerId then return false end

    local data = Scoreboard.players[playerId]
    if not data then return false end

    Scoreboard.hidden[playerId] = hidden or nil

    if hidden then
        TriggerClientEvent('kossek-scoreboard:removePlayer', -1, data)
    else
        TriggerClientEvent('kossek-scoreboard:addPlayer', -1, data)
    end

    CreateThread(UpdateCounter)
    return true
end

exports('HidePlayer', function(playerId) return setHidden(playerId, true) end)
exports('ShowPlayer', function(playerId) return setHidden(playerId, false) end)
exports('IsPlayerHidden', function(playerId) return Scoreboard.hidden[tonumber(playerId)] == true end)

-- A hidden player who disconnects must not leave the flag behind: server ids are reused,
-- so the next player to land on that id would be invisible on the board for no reason.
AddEventHandler('playerDropped', function()
    Scoreboard.hidden[source] = nil
end)
