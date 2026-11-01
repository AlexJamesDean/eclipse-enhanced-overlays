local QBCore = exports['qb-core']:GetCoreObject({ 'Functions' })
local zones = {}
local atmModelHashes = {}

local isPlayerInsideBankZone = false

for i = 1, #Config.atmModels do
    atmModelHashes[joaat(Config.atmModels[i])] = true
end

-- Functions

local function OpenBank()
    QBCore.Functions.TriggerCallback('qb-banking:server:openBank', function(accounts, statements, playerData)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openBank',
            accounts = accounts,
            statements = statements,
            playerData = playerData
        })
    end)
end

local atmBusy = false
local atmRobberyBusy = false
local activeATMRobberyToken

local function ProgressBusy()
    if GetResourceState('progressbar') ~= 'started' then return false end
    local ok, busy = pcall(function()
        return exports.progressbar:isDoingSomething()
    end)
    return ok and busy == true
end

local function OpenATM()
    if atmBusy or atmRobberyBusy or ProgressBusy() then return end
    atmBusy = true
    QBCore.Functions.Progressbar('accessing_atm', Lang:t('progress.atm'), 1500, false, true, {
        disableMovement = false,
        disableCarMovement = false,
        disableMouse = false,
        disableCombat = false,
    }, {
        animDict = 'amb@prop_human_atm@male@enter',
        anim = 'enter',
    }, {
        model = 'prop_cs_credit_card',
        bone = 28422,
        coords = vector3(0.1, 0.03, -0.05),
        rotation = vector3(0.0, 0.0, 180.0),
    }, {}, function()
        atmBusy = false
        QBCore.Functions.TriggerCallback('qb-banking:server:openATM', function(accounts, playerData, acceptablePins)
            if not accounts then return end -- no bank card; server already notified
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'openATM',
                accounts = accounts,
                pinNumbers = acceptablePins,
                playerData = playerData
            })
        end)
    end, function()
        atmBusy = false
    end)
end

local function NearATM()
    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, v in pairs(Config.atmModels) do
        local hash = joaat(v)
        local atm = IsObjectNearPoint(hash, playerCoords.x, playerCoords.y, playerCoords.z, 1.5)
        if atm then
            return true
        end
    end
end

local function TargetATM(data)
    local entity = data and data.entity
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    if not atmModelHashes[GetEntityModel(entity)] then return nil end

    local coords = GetEntityCoords(entity)
    if #(GetEntityCoords(PlayerPedId()) - coords) > (Config.atmRobbery.maxDistance + 0.5) then return nil end
    return entity, coords
end

local function FinishATMRobbery(token, cancelled)
    ClearPedTasks(PlayerPedId())
    atmRobberyBusy = false
    if activeATMRobberyToken == token then activeATMRobberyToken = nil end
    TriggerServerEvent(cancelled and 'qb-banking:server:cancelATMRobbery' or 'qb-banking:server:completeATMRobbery', token)
end

local function RobATM(data)
    if atmRobberyBusy or ProgressBusy() or not Config.atmRobbery.enabled then return end

    local entity, coords = TargetATM(data)
    if not entity then return end

    atmRobberyBusy = true
    QBCore.Functions.TriggerCallback('qb-banking:server:startATMRobbery', function(response)
        if not response or not response.ok then
            atmRobberyBusy = false
            QBCore.Functions.Notify(response and response.message or 'The cashpoint cannot be robbed right now.', 'error', 5000)
            return
        end

        activeATMRobberyToken = response.token
        QBCore.Functions.Progressbar('rob_atm', 'Forcing open cashpoint', Config.atmRobbery.duration, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {
            animDict = 'veh@break_in@0h@p_m_one@',
            anim = 'low_force_entry_ds',
            flags = 16,
        }, {}, {}, function()
            FinishATMRobbery(response.token, false)
        end, function()
            FinishATMRobbery(response.token, true)
            QBCore.Functions.Notify('Cashpoint robbery cancelled.', 'error')
        end)
    end, {
        model = GetEntityModel(entity),
        coords = { x = coords.x, y = coords.y, z = coords.z },
    })
end

-- NUI Callback

RegisterNUICallback('closeApp', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:withdraw', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('deposit', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:deposit', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('internalTransfer', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:internalTransfer', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('externalTransfer', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:externalTransfer', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('orderCard', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:orderCard', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('openAccount', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:openAccount', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('renameAccount', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:renameAccount', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('deleteAccount', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:deleteAccount', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('addUser', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:addUser', function(status)
        cb(status)
    end, data)
end)

RegisterNUICallback('removeUser', function(data, cb)
    QBCore.Functions.TriggerCallback('qb-banking:server:removeUser', function(status)
        cb(status)
    end, data)
end)

-- Events

RegisterNetEvent('qb-banking:client:useCard', function()
    if NearATM() then OpenATM() end
end)

RegisterNetEvent('qb-banking:client:targetATM', function()
    OpenATM()
end)

RegisterNetEvent('qb-banking:client:robATM', function(data)
    RobATM(data)
end)

-- Threads

CreateThread(function()
    for i = 1, #Config.locations do
        local blip = AddBlipForCoord(Config.locations[i])
        SetBlipSprite(blip, Config.blipInfo.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, Config.blipInfo.scale)
        SetBlipColour(blip, Config.blipInfo.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(tostring(Config.blipInfo.name))
        EndTextCommandSetBlipName(blip)
    end
end)

if Config.useTarget then
    CreateThread(function()
        for i = 1, #Config.locations do
            exports['qb-target']:AddCircleZone('bank_' .. i, Config.locations[i], 1.0, {
                name = 'bank_' .. i,
                useZ = true,
                debugPoly = false,
            }, {
                options = {
                    {
                        icon = 'fas fa-university',
                        label = 'Open Bank',
                        action = function()
                            OpenBank()
                        end,
                    }
                },
                distance = 1.5
            })
        end
    end)

end

if Config.useAtmTarget then
    local function RegisterATMTargets()
        if GetResourceState('qb-target') ~= 'started' then return false end
        exports['qb-target']:AddTargetModel(Config.atmModels, {
            options = {
                {
                    type = 'client',
                    event = 'qb-banking:client:targetATM',
                    icon = 'fas fa-credit-card',
                    label = 'Use ATM',
                },
                {
                    type = 'client',
                    event = 'qb-banking:client:robATM',
                    icon = 'fas fa-hammer',
                    label = 'Rob ATM',
                },
            },
            distance = 1.5,
        })
        return true
    end

    CreateThread(function()
        while not RegisterATMTargets() do Wait(500) end
    end)

    AddEventHandler('onClientResourceStart', function(resourceName)
        if resourceName == 'qb-target' then RegisterATMTargets() end
    end)

    AddEventHandler('onClientResourceStop', function(resourceName)
        if resourceName == GetCurrentResourceName() and GetResourceState('qb-target') == 'started' then
            exports['qb-target']:RemoveTargetModel(Config.atmModels, { 'Use ATM', 'Rob ATM' })
        end
        if resourceName == GetCurrentResourceName() then
            SetNuiFocus(false, false)
            if activeATMRobberyToken then
                ClearPedTasks(PlayerPedId())
                TriggerServerEvent('qb-banking:server:cancelATMRobbery', activeATMRobberyToken)
            end
        end
    end)
else
    CreateThread(function()
        while true do
            Wait(750)
            if not isPlayerInsideBankZone and not IsNuiFocused() and NearATM() then
                exports['qb-core']:DrawText('[E] Use cashpoint')
                local nextCheck = GetGameTimer() + 500
                while true do
                    Wait(0)
                    if IsNuiFocused() then break end -- UI opened; prompt returns via outer loop
                    if IsControlJustPressed(0, 38) then
                        OpenATM()
                    end
                    if GetGameTimer() >= nextCheck then
                        nextCheck = GetGameTimer() + 500
                        if isPlayerInsideBankZone or not NearATM() then break end
                    end
                end
                exports['qb-core']:HideText()
            end
        end
    end)

end

if not Config.useTarget then
    CreateThread(function()
        for i = 1, #Config.locations do
            local zone = CircleZone:Create(Config.locations[i], 3.0, {
                name = 'bank_' .. i,
                debugPoly = false,
            })
            zones[#zones + 1] = zone
        end

        local combo = ComboZone:Create(zones, {
            name = 'bank_combo',
            debugPoly = false,
        })

        combo:onPlayerInOut(function(isPointInside)
            isPlayerInsideBankZone = isPointInside
            if isPlayerInsideBankZone then
                exports['qb-core']:DrawText('Open Bank')
                CreateThread(function()
                    while isPlayerInsideBankZone do
                        Wait(0)
                        if IsControlJustPressed(0, 38) then
                            OpenBank()
                        end
                    end
                end)
            else
                exports['qb-core']:HideText()
            end
        end)
    end)
end
