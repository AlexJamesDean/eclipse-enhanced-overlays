--[[
    ox_inventory framework bridge for QBCore — client side.
    Mirrors modules/bridge/qbx/client.lua against QBCore's events.

    Differences from the qbx bridge:
      * qbx signals logout via an `isLoggedIn` statebag. QBCore fires the
        QBCore:Client:OnPlayerUnload event instead.
      * QBCore has no group-update events, so groups are re-derived from
        QBCore:Player:SetPlayerData whenever job or gang changes.

    Corrected 21 Aug 2026: this bridge is the path EVERY inventory operation on this
    box takes and has run in production since 25 Jul. The old `not yet run in-game`
    note outlived its truth by a month, and its onLogout half was found dead on
    1 Aug (bare AddEventHandler on a net event) precisely because it was live.
]]

local QBCore = exports['qb-core']:GetCoreObject()

---QBCore keeps job and gang separate; ox expects a single `groups` map.
---Kept identical to the server-side buildGroups so permission checks agree on both ends.
---@param playerData table
---@return table<string, number>
local function buildGroups(playerData)
    local groups = {}
    local job, gang = playerData.job, playerData.gang

    if job and job.name then
        groups[job.name] = job.grade and job.grade.level or 0
    end
    if gang and gang.name and gang.name ~= 'none' then
        groups[gang.name] = gang.grade and gang.grade.level or 0
    end

    return groups
end

-- RegisterNetEvent, NOT AddEventHandler: QBCore fires this with
-- TriggerClientEvent (qb-core server/player.lua:350), so a plain AddEventHandler
-- is rejected by the runtime ("event QBCore:Client:OnPlayerUnload was not safe
-- for net") and client.onLogout() never ran — inventory client state survived a
-- character switch. Written from the qbx bridge, where logout is a statebag and
-- this event does not exist.
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    client.onLogout()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    if not playerData then return end
    client.setPlayerData('groups', buildGroups(playerData))
end)

---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerStatus(values)
    -- QBCore's needs are managed by qb-smallresources / hud via statebags rather than a
    -- shared status API, so this keeps ox's own 0-100 player statuses in sync and lets
    -- QBCore's own hunger/thirst handling continue independently.
    for name, value in pairs(values) do
        -- compatibility for ESX style values
        if value > 100 or value < -100 then
            value = value * 0.0001
        end

        local currentValue = client.player:get(name) or 0
        client.player:setr(name, lib.math.clamp(currentValue + value, 0, 100))
    end
end
