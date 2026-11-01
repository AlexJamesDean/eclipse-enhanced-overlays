local inBankCardBZone = false
local inElectronickitZone = false
local bankCardBUsed = false
local currentLocker = 0
local copsCalled = false

-- Functions

--- This will load an animation dictionary so you can play an animation in that dictionary
--- @param dict string
--- @return nil
local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

-- Events

RegisterNetEvent('qb-bankrobbery:UseBankcardB', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    Config.OnEvidence(pos, 85)
    if not inBankCardBZone then return end
    QBCore.Functions.TriggerCallback('qb-bankrobbery:server:isRobberyActive', function(isBusy)
        if not isBusy then
            if CurrentCops >= Config.MinimumPacificPolice then
                if not Config.BigBanks['pacific']['isOpened'] then
                    Config.ShowRequiredItems({
                        [1] = { name = QBCore.Shared.Items['security_card_02']['name'], image = QBCore.Shared.Items['security_card_02']['image'] }
                    }, false)
                    loadAnimDict('anim@gangops@facility@servers@')
                    TaskPlayAnim(ped, 'anim@gangops@facility@servers@', 'hotwire', 3.0, 3.0, -1, 1, 0, false, false, false)
                    QBCore.Functions.Progressbar('security_pass', Lang:t('general.validating_bankcard'), math.random(5000, 10000), false, true, {
                        disableMovement = true,
                        disableCarMovement = true,
                        disableMouse = false,
                        disableCombat = true,
                    }, {}, {}, {}, function() -- Done
                        StopAnimTask(ped, 'anim@gangops@facility@servers@', 'hotwire', 1.0)
                        bankCardBUsed = true
                        exports['qb-core']:HideText()
                        Config.DoorlockAction(1, false)
                        TriggerServerEvent('qb-bankrobbery:server:removeBankCard', '02')
                        if copsCalled or not Config.BigBanks['pacific']['alarm'] then return end
                        TriggerServerEvent('qb-bankrobbery:server:callCops', 'pacific', 0, pos)
                        copsCalled = true
                    end, function() -- Cancel
                        StopAnimTask(ped, 'anim@gangops@facility@servers@', 'hotwire', 1.0)
                        QBCore.Functions.Notify(Lang:t('error.cancel_message'), 'error')
                    end)
                else
                    QBCore.Functions.Notify(Lang:t('error.bank_already_open'), 'error')
                end
            else
                QBCore.Functions.Notify(Lang:t('error.minimum_police_required', { police = Config.MinimumPacificPolice }), 'error')
            end
        else
            QBCore.Functions.Notify(Lang:t('error.security_lock_active'), 'error', 5500)
        end
    end)
end)

RegisterNetEvent('electronickit:UseElectronickit', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    if not inElectronickitZone then return end
    QBCore.Functions.TriggerCallback('qb-bankrobbery:server:isRobberyActive', function(isBusy)
        if not isBusy then
            if CurrentCops >= Config.MinimumPacificPolice then
                if not Config.BigBanks['pacific']['isOpened'] then
                    local hasItem = Config.HasItem({ 'trojan_usb', 'electronickit' })
                    if hasItem then
                        Config.ShowRequiredItems(nil, false)
                        loadAnimDict('anim@gangops@facility@servers@')
                        TaskPlayAnim(ped, 'anim@gangops@facility@servers@', 'hotwire', 3.0, 3.0, -1, 1, 0, false, false, false)
                        QBCore.Functions.Progressbar('hack_gate', Lang:t('general.connecting_hacking_device'), math.random(5000, 10000), false, true, {
                            disableMovement = true,
                            disableCarMovement = true,
                            disableMouse = false,
                            disableCombat = true,
                        }, {}, {}, {}, function() -- Done
                            TriggerServerEvent('qb-bankrobbery:server:removeElectronicKit')
                            StopAnimTask(ped, 'anim@gangops@facility@servers@', 'hotwire', 1.0)
                            local success = exports['qb-minigames']:Hacking(5, 30) -- code block size & seconds to solve
                            if success then
                                exports['qb-core']:HideText()
                                TriggerServerEvent('qb-bankrobbery:server:setBankState', 'pacific')
                            end
                            if copsCalled or not Config.BigBanks['pacific']['alarm'] then return end
                            TriggerServerEvent('qb-bankrobbery:server:callCops', 'pacific', 0, pos)
                            copsCalled = true
                        end, function() -- Cancel
                            StopAnimTask(ped, 'anim@gangops@facility@servers@', 'hotwire', 1.0)
                            QBCore.Functions.Notify(Lang:t('error.cancel_message'), 'error')
                        end)
                    else
                        QBCore.Functions.Notify(Lang:t('error.missing_item'), 'error')
                    end
                else
                    QBCore.Functions.Notify(Lang:t('error.bank_already_open'), 'error')
                end
            else
                QBCore.Functions.Notify(Lang:t('error.minimum_police_required', { police = Config.MinimumPacificPolice }), 'error')
            end
        else
            QBCore.Functions.Notify(Lang:t('error.security_lock_active'), 'error', 5500)
        end
    end)
end)

-- Threads

CreateThread(function()
    local bankCardBZone = BoxZone:Create(Config.BigBanks['pacific']['coords'][1], 1.5, 1.5, {
        name = 'pacific_coords_bankcardb',
        heading = Config.BigBanks['pacific']['heading'].closed,
        minZ = Config.BigBanks['pacific']['coords'][1].z - 1,
        maxZ = Config.BigBanks['pacific']['coords'][1].z + 1,
        debugPoly = false
    })
    bankCardBZone:onPlayerInOut(function(inside)
        inBankCardBZone = inside
        if inside and not bankCardBUsed and not Config.BigBanks['pacific']['isOpened'] then
            exports['qb-core']:DrawText('[E] Swipe security card  |  Requires Security Card B', 'right')
        else
            exports['qb-core']:HideText()
        end
    end)
    local electronickitZone = BoxZone:Create(Config.BigBanks['pacific']['coords'][2], 1.5, 1.5, {
        name = 'pacific_coords_electronickit',
        heading = Config.BigBanks['pacific']['heading'].closed,
        minZ = Config.BigBanks['pacific']['coords'][2].z - 1,
        maxZ = Config.BigBanks['pacific']['coords'][2].z + 1,
        debugPoly = false
    })
    electronickitZone:onPlayerInOut(function(inside)
        inElectronickitZone = inside
        if inside and not Config.BigBanks['pacific']['isOpened'] then
            exports['qb-core']:DrawText('[E] Connect electronic kit  |  Requires Electronic Kit + Trojan USB', 'right')
        else
            exports['qb-core']:HideText()
        end
    end)
    local thermite1Zone = BoxZone:Create(Config.BigBanks['pacific']['thermite'][1]['coords'], 1.5, 1.5, {
        name = 'pacific_coords_thermite_1',
        heading = Config.BigBanks['pacific']['heading'].closed,
        minZ = Config.BigBanks['pacific']['thermite'][1]['coords'].z - 1,
        maxZ = Config.BigBanks['pacific']['thermite'][1]['coords'].z + 1,
        debugPoly = false
    })
    thermite1Zone:onPlayerInOut(function(inside)
        if inside and not Config.BigBanks['pacific']['thermite'][1]['isOpened'] then
            currentThermiteGate = Config.BigBanks['pacific']['thermite'][1]['doorId']
            exports['qb-core']:DrawText('[E] Place thermite  |  Requires Thermite', 'right')
        else
            if currentThermiteGate == Config.BigBanks['pacific']['thermite'][1]['doorId'] then
                currentThermiteGate = 0
                exports['qb-core']:HideText()
            end
        end
    end)
    local thermite2Zone = BoxZone:Create(Config.BigBanks['pacific']['thermite'][2]['coords'], 1.5, 1.5, {
        name = 'pacific_coords_thermite_2',
        heading = Config.BigBanks['pacific']['heading'].closed,
        minZ = Config.BigBanks['pacific']['thermite'][2]['coords'].z - 1,
        maxZ = Config.BigBanks['pacific']['thermite'][2]['coords'].z + 1,
        debugPoly = false
    })
    thermite2Zone:onPlayerInOut(function(inside)
        if inside and not Config.BigBanks['pacific']['thermite'][2]['isOpened'] then
            currentThermiteGate = Config.BigBanks['pacific']['thermite'][2]['doorId']
            exports['qb-core']:DrawText('[E] Place thermite  |  Requires Thermite', 'right')
        else
            if currentThermiteGate == Config.BigBanks['pacific']['thermite'][2]['doorId'] then
                currentThermiteGate = 0
                exports['qb-core']:HideText()
            end
        end
    end)
    for k in pairs(Config.BigBanks['pacific']['lockers']) do
        if Config.UseTarget then
            exports['qb-target']:AddBoxZone('pacific_coords_locker_' .. k, Config.BigBanks['pacific']['lockers'][k]['coords'], 1.0, 1.0, {
                name = 'pacific_coords_locker_' .. k,
                heading = Config.BigBanks['pacific']['heading'].closed,
                minZ = Config.BigBanks['pacific']['lockers'][k]['coords'].z - 1,
                maxZ = Config.BigBanks['pacific']['lockers'][k]['coords'].z + 1,
                debugPoly = false
            }, {
                options = {
                    {
                        action = function()
                            openLocker('pacific', k)
                        end,
                        canInteract = function()
                            return not IsDrilling and Config.BigBanks['pacific']['isOpened'] and not Config.BigBanks['pacific']['lockers'][k]['isBusy'] and not Config.BigBanks['pacific']['lockers'][k]['isOpened']
                        end,
                        icon = 'fa-solid fa-vault',
                        label = Lang:t('general.break_safe_open_option_target'),
                    },
                },
                distance = 1.5
            })
        else
            local lockerZone = BoxZone:Create(Config.BigBanks['pacific']['lockers'][k]['coords'], 1.0, 1.0, {
                name = 'pacific_coords_locker_' .. k,
                heading = Config.BigBanks['pacific']['heading'].closed,
                minZ = Config.BigBanks['pacific']['lockers'][k]['coords'].z - 1,
                maxZ = Config.BigBanks['pacific']['lockers'][k]['coords'].z + 1,
                debugPoly = false
            })
            lockerZone:onPlayerInOut(function(inside)
                if inside and not IsDrilling and Config.BigBanks['pacific']['isOpened'] and not Config.BigBanks['pacific']['lockers'][k]['isBusy'] and not Config.BigBanks['pacific']['lockers'][k]['isOpened'] then
                    exports['qb-core']:DrawText(Lang:t('general.break_safe_open_option_drawtext'), 'right')
                    currentLocker = k
                else
                    if currentLocker == k then
                        currentLocker = 0
                        exports['qb-core']:HideText()
                    end
                end
            end)
        end
    end
    if not Config.UseTarget then
        while true do
            local sleep = 1000
            if isLoggedIn then
                if inBankCardBZone and not bankCardBUsed and not Config.BigBanks['pacific']['isOpened'] then
                    sleep = 0
                    if IsControlJustPressed(0, 38) then
                        exports['qb-core']:KeyPressed()
                        TriggerServerEvent('qb-bankrobbery:server:usePanelItem', 'security_card_02')
                        Wait(500)
                    end
                elseif inElectronickitZone and not Config.BigBanks['pacific']['isOpened'] then
                    sleep = 0
                    if IsControlJustPressed(0, 38) then
                        exports['qb-core']:KeyPressed()
                        TriggerServerEvent('qb-bankrobbery:server:usePanelItem', 'electronickit')
                        Wait(500)
                    end
                elseif currentThermiteGate ~= 0 then
                    sleep = 0
                    if IsControlJustPressed(0, 38) then
                        exports['qb-core']:KeyPressed()
                        TriggerServerEvent('qb-bankrobbery:server:usePanelItem', 'thermite')
                        Wait(500)
                    end
                elseif currentLocker ~= 0 and not IsDrilling and Config.BigBanks['pacific']['isOpened'] and not Config.BigBanks['pacific']['lockers'][currentLocker]['isBusy'] and not Config.BigBanks['pacific']['lockers'][currentLocker]['isOpened'] then
                    sleep = 0
                    if IsControlJustPressed(0, 38) then
                        exports['qb-core']:KeyPressed()
                        Wait(500)
                        exports['qb-core']:HideText()
                        if CurrentCops >= Config.MinimumPacificPolice then
                            openLocker('pacific', currentLocker)
                        else
                            QBCore.Functions.Notify(Lang:t('error.minimum_police_required', { police = Config.MinimumPacificPolice }), 'error')
                        end
                        sleep = 1000
                    end
                end
            end
            Wait(sleep)
        end
    end
end)
