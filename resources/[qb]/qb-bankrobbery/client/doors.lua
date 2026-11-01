local function ResetBigBank(bankId)
    if bankId ~= 'paleto' and bankId ~= 'pacific' then return end

    if bankId == 'paleto' then
        Config.DoorlockAction(4, true)
        local object = GetClosestObjectOfType(Config.BigBanks['paleto']['coords']['x'], Config.BigBanks['paleto']['coords']['y'], Config.BigBanks['paleto']['coords']['z'], 5.0, Config.BigBanks['paleto']['object'], false, false, false)
        if object ~= 0 then
            SetEntityHeading(object, Config.BigBanks['paleto']['heading'].closed)
        end
    else
        local object = GetClosestObjectOfType(Config.BigBanks['pacific']['coords'][2]['x'], Config.BigBanks['pacific']['coords'][2]['y'], Config.BigBanks['pacific']['coords'][2]['z'], 20.0, Config.BigBanks['pacific']['object'], false, false, false)
        if object ~= 0 then
            SetEntityHeading(object, Config.BigBanks['pacific']['heading'].closed)
        end
    end

    for k in pairs(Config.BigBanks[bankId]['lockers']) do
        Config.BigBanks[bankId]['lockers'][k]['isBusy'] = false
        Config.BigBanks[bankId]['lockers'][k]['isOpened'] = false
    end
    for k, gate in pairs(Config.BigBanks[bankId]['thermite'] or {}) do
        gate.isOpened = false
        Config.DoorlockAction(gate.doorId, true)
    end
    Config.BigBanks[bankId]['isOpened'] = false
end

RegisterNetEvent('qb-bankrobbery:client:ResetBigBank', ResetBigBank)

-- Kept for compatibility with any older reset caller.
RegisterNetEvent('qb-bankrobbery:client:ClearTimeoutDoors', function()
    ResetBigBank('paleto')
    ResetBigBank('pacific')
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local PaletoDist = #(pos - Config.BigBanks['paleto']['coords'])
        local PacificDist = #(pos - Config.BigBanks['pacific']['coords'][2])
        if PaletoDist < 15 then
            if Config.BigBanks['paleto']['isOpened'] then
                Config.DoorlockAction(4, false)
                local object = GetClosestObjectOfType(Config.BigBanks['paleto']['coords']['x'], Config.BigBanks['paleto']['coords']['y'], Config.BigBanks['paleto']['coords']['z'], 5.0, Config.BigBanks['paleto']['object'], false, false, false)
                if object ~= 0 then
                    SetEntityHeading(object, Config.BigBanks['paleto']['heading'].open)
                end
            else
                Config.DoorlockAction(4, true)
                local object = GetClosestObjectOfType(Config.BigBanks['paleto']['coords']['x'], Config.BigBanks['paleto']['coords']['y'], Config.BigBanks['paleto']['coords']['z'], 5.0, Config.BigBanks['paleto']['object'], false, false, false)
                if object ~= 0 then
                    SetEntityHeading(object, Config.BigBanks['paleto']['heading'].closed)
                end
            end
        end

        -- Pacific Check
        if PacificDist < 50 then
            if Config.BigBanks['pacific']['isOpened'] then
                local object = GetClosestObjectOfType(Config.BigBanks['pacific']['coords'][2]['x'], Config.BigBanks['pacific']['coords'][2]['y'], Config.BigBanks['pacific']['coords'][2]['z'], 20.0, Config.BigBanks['pacific']['object'], false, false, false)
                if object ~= 0 then
                    SetEntityHeading(object, Config.BigBanks['pacific']['heading'].open)
                end
            else
                local object = GetClosestObjectOfType(Config.BigBanks['pacific']['coords'][2]['x'], Config.BigBanks['pacific']['coords'][2]['y'], Config.BigBanks['pacific']['coords'][2]['z'], 20.0, Config.BigBanks['pacific']['object'], false, false, false)
                if object ~= 0 then
                    SetEntityHeading(object, Config.BigBanks['pacific']['heading'].closed)
                end
            end
        end
        Wait(1000)
    end
end)
