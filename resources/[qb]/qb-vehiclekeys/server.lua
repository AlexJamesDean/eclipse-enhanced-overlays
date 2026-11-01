-----------------------
----   Variables   ----
-----------------------
local QBCore = exports['qb-core']:GetCoreObject({ 'Functions', 'Commands' })
local sharedItems = exports['qb-core']:GetShared('Items')

local function Trim(value)
    return value and value:match('^%s*(.-)%s*$') or value
end

-- Every plate that enters this resource is canonicalised through here before it is
-- used as a key. GiveKeys/HasKeys/RemoveKeys and the persisted `vehicleKeys`
-- metadata MUST agree on the format or a grant silently fails to satisfy the check
-- that follows it - which reads in game as "the keys did nothing". Callers are not
-- consistent: some pass QBCore.Functions.GetPlate (trimmed), some pass raw
-- GetVehicleNumberPlateText (GTA pads to 8), and the ownership lookup added
-- 8 Aug 2026 passes the player_vehicles value. Trimmed + uppercase is the form the
-- DB already stores (verified: 126 rows, none padded, none lowercase).
local function NormalisePlate(plate)
    if type(plate) ~= 'string' then return nil end
    plate = Trim(plate):upper()
    if plate == '' then return nil end
    return plate
end

local VehicleList = {}

-----------------------
----   Threads     ----
-----------------------

-----------------------
---- Server Events ----
-----------------------

-- Event to give keys. receiver can either be a single id, or a table of ids.
-- Must already have keys to the vehicle, trigger the event from the server, or pass forcegive paramter as true.
RegisterNetEvent('qb-vehiclekeys:server:GiveVehicleKeys', function(receiver, plate)
    local giver = source

    if HasKeys(giver, plate) then
        TriggerClientEvent('QBCore:Notify', giver, Lang:t('notify.vgkeys'), 'success')
        if type(receiver) == 'table' then
            for _, r in ipairs(receiver) do
                GiveKeys(receiver[r], plate)
            end
        else
            GiveKeys(receiver, plate)
        end
    else
        TriggerClientEvent('QBCore:Notify', giver, Lang:t('notify.ydhk'), 'error')
    end
end)

-- SECURITY (ajd, 8 Aug 2026): this granted keys to ANY plate on request, with no
-- check of any kind - a client could hand itself the keys to every vehicle on the
-- server. GTA pads plates to 8 characters, hence the trim before comparing.
local function platesMatch(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' then return false end
    return (a:gsub('%s+$', '')):upper() == (b:gsub('%s+$', '')):upper()
end

-- FIX (ajd, 8 Aug 2026): the first version of that check required the player to be
-- SEATED in the matching vehicle, which broke every "spawn a car and hand the owner
-- its keys" path on the box - garages, vehicle shops, rentals, the phone garage app
-- and all seven job vehicle spawners grant keys while the player is still standing
-- next to the car. They all route through the `vehiclekeys:client:SetOwner` compat
-- event (client.lua:296), so they all failed silently.
--
-- A grant now needs any ONE of three grounds:
--   1. the player is sitting in a vehicle carrying that plate (the original check);
--   2. a vehicle carrying that plate is within Config.KeyGrantRadius of them, which
--      covers job vehicles, rentals, hotwiring and carjacking;
--   3. the plate is registered to their citizenid in `player_vehicles` - the
--      "called my own car out" case, and the only ground immune to the sync race.
--
-- The sync race: spawners call SetVehicleNumberPlateText client-side and fire the
-- key grant in the SAME frame, so the server can still be holding the old plate for
-- a tick or two. Ground 3 does not care; ground 2 does, hence the bounded retry.
--
-- ORDER MATTERS FOR COST, and the cheap-looking order is the wrong one. NPC cars are
-- unlocked on this box (Config.LockNPCDrivingCars = false), so client.lua:60 fires
-- this on EVERY NPC car a player gets into - checking ownership first would put a
-- guaranteed-miss DB query on that path. Ground 2 answers it on the first sweep
-- instead, because an NPC car's plate is long since synced. So: seated, then ONE
-- proximity sweep, then the DB, then the remaining sweeps. Worst case for an NPC
-- entry is one sweep and no query; for an owner spawning a car, one sweep and one
-- query. The retry budget is only ever spent on a non-owned, freshly-plated car.
local KEY_GRANT_TRIES = 4
local KEY_GRANT_WAIT = 250

local function ownsPlate(src, plate)
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return false end

    local owner = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { NormalisePlate(plate) })
    return owner ~= nil and owner == Player.PlayerData.citizenid
end

local function vehicleWithPlateNear(src, plate)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    if not GetAllVehicles then return false end

    local ok, all = pcall(GetAllVehicles)
    if not ok or type(all) ~= 'table' then return false end

    local origin = GetEntityCoords(ped)
    local radius = Config.KeyGrantRadius or 10.0

    for i = 1, #all do
        local veh = all[i]
        if DoesEntityExist(veh)
            and platesMatch(GetVehicleNumberPlateText(veh), plate)
            and #(GetEntityCoords(veh) - origin) <= radius then
            return true
        end
    end

    return false
end

-- One in-flight request per player. Without this a client could spam plates that
-- will never match and stack a retry coroutine (and a vehicle sweep) for each one.
local acquiring = {}

AddEventHandler('playerDropped', function()
    acquiring[source] = nil
end)

RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    if type(plate) ~= 'string' or plate == '' then return end
    if acquiring[src] then return end
    if HasKeys(src, plate) then return end

    local seated = GetVehiclePedIsIn(GetPlayerPed(src), false)
    if seated and seated ~= 0 and platesMatch(GetVehicleNumberPlateText(seated), plate) then
        return GiveKeys(src, plate)
    end

    acquiring[src] = true

    local granted = false
    for attempt = 1, KEY_GRANT_TRIES do
        if vehicleWithPlateNear(src, plate) then
            granted = true
            break
        end

        -- Ownership is checked once, after the first sweep has failed.
        if attempt == 1 and ownsPlate(src, plate) then
            granted = true
            break
        end

        if attempt < KEY_GRANT_TRIES then Wait(KEY_GRANT_WAIT) end
    end

    acquiring[src] = nil
    if granted then GiveKeys(src, plate) end
end)

RegisterNetEvent('qb-vehiclekeys:server:RemoveVehicleKeys', function(plate)
    local src = source
    local hasKey = HasKeys(src, plate)
    if not hasKey then return end

    RemoveKeys(src, plate)
end)

RegisterNetEvent('qb-vehiclekeys:server:breakLockpick', function(itemName)
    local Player = exports['qb-core']:GetPlayer(source)
    if not Player then return end
    if not (itemName == 'lockpick' or itemName == 'advancedlockpick') then return end
    if exports['qb-inventory']:RemoveItem(source, itemName, 1, false, 'qb-vehiclekeys:server:breakLockpick') then
        TriggerClientEvent('qb-inventory:client:ItemBox', source, sharedItems[itemName], 'remove')
    end
end)

RegisterNetEvent('qb-vehiclekeys:server:setVehLockState', function(vehNetId, state)
    SetVehicleDoorsLocked(NetworkGetEntityFromNetworkId(vehNetId), state)
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:GetVehicleKeys', function(source, cb)
    local Player = exports['qb-core']:GetPlayer(source)
    if not Player then return cb({}) end
    local citizenid = Player.PlayerData.citizenid
    local keysList = {}
    for plate, citizenids in pairs(VehicleList) do
        if citizenids[citizenid] then
            keysList[plate] = true
        end
    end
    if Player.PlayerData.metadata['vehicleKeys'] and Config.PersistentKeys then
        for plate in pairs(Player.PlayerData.metadata['vehicleKeys']) do
            keysList[plate] = true
        end
    end
    cb(keysList)
end)

QBCore.Functions.CreateCallback('qb-vehiclekeys:server:checkPlayerOwned', function(_, cb, plate)
    local playerOwned = false
    if VehicleList[plate] then
        playerOwned = true
    end
    cb(playerOwned)
end)

-----------------------
----   Functions   ----
-----------------------

function GiveKeys(id, plate)
    local Player = exports['qb-core']:GetPlayer(id)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    if not plate then
        if GetVehiclePedIsIn(GetPlayerPed(id), false) ~= 0 then
            plate = GetVehicleNumberPlateText(GetVehiclePedIsIn(GetPlayerPed(id), false))
        else
            return
        end
    end

    plate = NormalisePlate(plate)
    if not plate then return end

    if not VehicleList[plate] then VehicleList[plate] = {} end
    VehicleList[plate][citizenid] = true

    local oldKeys = Player.PlayerData.metadata['vehicleKeys'] or {}
    oldKeys[plate] = true
    Player.SetMetaData('vehicleKeys', oldKeys)

    TriggerClientEvent('QBCore:Notify', id, Lang:t('notify.vgetkeys'))
    TriggerClientEvent('qb-vehiclekeys:client:AddKeys', id, plate)
end

exports('GiveKeys', GiveKeys)

function RemoveKeys(id, plate)
    local Player = exports['qb-core']:GetPlayer(id)
    if not Player then return end
    local citizenid = Player.PlayerData.citizenid

    plate = NormalisePlate(plate)
    if not plate then return end

    if VehicleList[plate] and VehicleList[plate][citizenid] then
        VehicleList[plate][citizenid] = nil
    end

    local oldKeys = Player.PlayerData.metadata['vehicleKeys'] or {}
    oldKeys[plate] = nil
    Player.SetMetaData('vehicleKeys', oldKeys)

    TriggerClientEvent('qb-vehiclekeys:client:RemoveKeys', id, plate)
end

exports('RemoveKeys', RemoveKeys)

function HasKeys(id, plate)
    local Player = exports['qb-core']:GetPlayer(id)
    if not Player then return false end
    local citizenid = Player.PlayerData.citizenid

    plate = NormalisePlate(plate)
    if not plate then return false end

    if VehicleList[plate] and VehicleList[plate][citizenid] then
        return true
    end

    if Player.PlayerData.metadata['vehicleKeys'] and Config.PersistentKeys and Player.PlayerData.metadata['vehicleKeys'][plate] then
        return true
    end

    return false
end

exports('HasKeys', HasKeys)

QBCore.Commands.Add('givekeys', Lang:t('addcom.givekeys'), { { name = Lang:t('addcom.givekeys_id'), help = Lang:t('addcom.givekeys_id_help') } }, false, function(source, args)
    local src = source
    TriggerClientEvent('qb-vehiclekeys:client:GiveKeys', src, tonumber(args[1]))
end)

QBCore.Commands.Add('addkeys', Lang:t('addcom.addkeys'), { { name = Lang:t('addcom.addkeys_id'), help = Lang:t('addcom.addkeys_id_help') }, { name = Lang:t('addcom.addkeys_plate'), help = Lang:t('addcom.addkeys_plate_help') } }, true, function(source, args)
    local src = source
    if not args[1] or not args[2] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.fpid'))
        return
    end
    GiveKeys(tonumber(args[1]), args[2])
end, 'admin')

QBCore.Commands.Add('removekeys', Lang:t('addcom.rkeys'), { { name = Lang:t('addcom.rkeys_id'), help = Lang:t('addcom.rkeys_id_help') }, { name = Lang:t('addcom.rkeys_plate'), help = Lang:t('addcom.rkeys_plate_help') } }, true, function(source, args)
    local src = source
    if not args[1] or not args[2] then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('notify.fpid'))
        return
    end
    RemoveKeys(tonumber(args[1]), args[2])
end, 'admin')
