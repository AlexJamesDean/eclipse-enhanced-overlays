local QBCore = exports['qb-core']:GetCoreObject({ 'Functions', 'Commands' })
local Bail = {}

-- Callbacks

QBCore.Functions.CreateCallback('qb-hotdogjob:server:HasMoney', function(source, cb)
    local Player = exports['qb-core']:GetPlayer(source)

    if Player.PlayerData.money.bank >= Config.StandDeposit then
        Player.RemoveMoney('bank', Config.StandDeposit, 'hot dog deposit')
        Bail[Player.PlayerData.citizenid] = true
        cb(true)
    else
        Bail[Player.PlayerData.citizenid] = false
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-hotdogjob:server:BringBack', function(source, cb)
    local Player = exports['qb-core']:GetPlayer(source)

    if Bail[Player.PlayerData.citizenid] then
        Player.AddMoney('bank', Config.StandDeposit, 'hot dog deposit')
        cb(true)
    else
        cb(false)
    end
end)

-- Events

RegisterNetEvent('qb-hotdogjob:server:Sell', function(coords, amount, price)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    -- SECURITY (ajd, 8 Aug 2026). This handler was arbitrary cash generation:
    --   * coords, amount AND price all came from the client;
    --   * the proximity test compared the player against coordinates they had
    --     sent themselves, so it always passed;
    --   * there was no job check and no item was removed;
    --   * the ExploitBan branch had no `return`, so a caught exploiter was
    --     banned AND paid on the same call.
    -- The coords test is retained but is still only a sanity check - the real
    -- protection is the job gate and the ceilings below, taken from config.lua
    -- (highest stock Max is 60; highest configured unit price max is 15).
    if Player.PlayerData.job.name ~= 'hotdog' then return end
    if type(coords) ~= 'vector3' then return end
    local pCoords = GetEntityCoords(GetPlayerPed(src))
    if #(pCoords - coords) > 4 then
        exports['qb-core']:ExploitBan(src, 'hotdog job')
        return
    end
    local qty  = math.floor(tonumber(amount) or 0)
    local unit = math.floor(tonumber(price) or 0)
    if qty < 1 or qty > 60 or unit < 1 or unit > 15 then return end
    Player.AddMoney('cash', qty * unit, 'sold hotdog')
end)

RegisterNetEvent('qb-hotdogjob:server:UpdateReputation', function(quality)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if quality == 'exotic' then
        if Player.GetRep('hotdog') + 3 > Config.MaxReputation then
            Player.AddRep('hotdog', Config.MaxReputation - Player.GetRep('hotdog'))
        else
            Player.AddRep('hotdog', 3)
        end
    elseif quality == 'rare' then
        if Player.GetRep('hotdog') + 2 > Config.MaxReputation then
            Player.AddRep('hotdog', Config.MaxReputation - Player.GetRep('hotdog'))
        else
            Player.AddRep('hotdog', 2)
        end
    elseif quality == 'common' then
        if Player.GetRep('hotdog') + 1 > Config.MaxReputation then
            Player.AddRep('hotdog', Config.MaxReputation - Player.GetRep('hotdog'))
        else
            Player.AddRep('hotdog', 1)
        end
    end

    TriggerClientEvent('qb-hotdogjob:client:UpdateReputation', src, Player.PlayerData.metadata['rep'])
end)

-- Commands

QBCore.Commands.Add('removestand', Lang:t('info.command'), {}, false, function(source, _)
    TriggerClientEvent('qb-hotdogjob:staff:DeletStand', source)
end, 'admin')
