local QBCore = exports['qb-core']:GetCoreObject({ 'Functions' })
local sharedItems = exports['qb-core']:GetShared('Items')
local bigBankTimeouts = {}
local smallBankTimeouts = {}

-- Functions

---Return the authoritative number of on-duty law-enforcement players.
---The client event remains a fast path, but this prevents a bank-resource restart from
---leaving every client at CurrentCops = 0 until qb-policejob's ten-minute broadcast.
---@return number
local function GetOnDutyPoliceCount()
    local amount = 0
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = player.PlayerData.job
        if job and job.type == 'leo' and job.onduty then
            amount += 1
        end
    end
    return amount
end

--- This will convert a table's keys into an array
--- @param tbl table
--- @return array
local function TableKeysToArray(tbl)
    local array = {}
    for k in pairs(tbl) do
        array[#array + 1] = k
    end
    return array
end

--- This will loop over the given table to check if the power stations in the table have been hit
--- @param toLoop table
--- @return boolean
local function TableLoopStations(toLoop)
    local hits = 0
    for _, station in pairs(toLoop) do
        if type(station) == 'table' then
            local hits2 = 0
            for _, station2 in pairs(station) do
                if Config.PowerStations[station2].hit then hits2 += 1 end
                if hits2 == #station then return true end
            end
        else
            if Config.PowerStations[station].hit then hits += 1 end
            if hits == #toLoop then return true end
        end
    end
    return false
end

--- This will check what stations have been hit and update them accordingly
--- @return nil
local function CheckStationHits()
    local policeHits = {}
    local bankHits = {}

    for k, v in pairs(Config.CameraHits) do
        local allStationsHitPolice = false
        local allStationsHitBank = false
        if type(v.type) == 'table' then
            for _, cameraType in pairs(v.type) do
                if cameraType == 'police' then
                    if type(v.stationsToHitPolice) == 'table' then
                        allStationsHitPolice = TableLoopStations(v.stationsToHitPolice)
                    else
                        allStationsHitPolice = Config.PowerStations[v.stationsToHitPolice].hit
                    end
                elseif cameraType == 'bank' then
                    if type(v.stationsToHitBank) == 'table' then
                        allStationsHitBank = TableLoopStations(v.stationsToHitBank)
                    else
                        allStationsHitBank = Config.PowerStations[v.stationsToHitBank].hit
                    end
                end
            end
        else
            if v.type == 'police' then
                if type(v.stationsToHitPolice) == 'table' then
                    allStationsHitPolice = TableLoopStations(v.stationsToHitPolice)
                else
                    allStationsHitPolice = Config.PowerStations[v.stationsToHitPolice].hit
                end
            elseif v.type == 'bank' then
                if type(v.stationsToHitBank) == 'table' then
                    allStationsHitBank = TableLoopStations(v.stationsToHitBank)
                else
                    allStationsHitBank = Config.PowerStations[v.stationsToHitBank].hit
                end
            end
        end

        if allStationsHitPolice then
            policeHits[k] = true
        end

        if allStationsHitBank then
            bankHits[k] = true
        end
    end

    policeHits = TableKeysToArray(policeHits)
    bankHits = TableKeysToArray(bankHits)

    -- table.type checks if it's empty as well, if it's empty it will return the type 'empty' instead of 'array'
    if table.type(policeHits) == 'array' then Config.OnPoliceCameraHit(policeHits) end
    if table.type(bankHits) == 'array' then TriggerClientEvent('qb-bankrobbery:client:BankSecurity', -1, bankHits, false) end
end

--- This will do a quick check to see if all stations have been hit
--- @return boolean
local function AllStationsHit()
    local hit = 0
    for k in pairs(Config.PowerStations) do
        if Config.PowerStations[k].hit then
            hit += 1
        end
    end
    return hit >= Config.HitsNeeded
end

--- This will check if the given coords are in the area of the given distance of a powerstation
--- @param coords vector3
--- @param dist number
--- @return boolean
local function IsNearPowerStation(coords, dist)
    for _, v in pairs(Config.PowerStations) do
        if #(coords - v.coords) < dist then
            return true
        end
    end
    return false
end

-- Events

RegisterNetEvent('qb-bankrobbery:server:setBankState', function(bankId)
    if bankId == 'paleto' then
        if Config.BigBanks['paleto']['isOpened'] or #(GetEntityCoords(GetPlayerPed(source)) - Config.BigBanks['paleto']['coords']) > 2.5 then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:setBankState', extraInfo = ' (paleto) ', source = source }))
        end
        Config.BigBanks['paleto']['isOpened'] = true
        TriggerEvent('qb-bankrobbery:server:setTimeout', 'paleto')
    elseif bankId == 'pacific' then
        if Config.BigBanks['pacific']['isOpened'] or #(GetEntityCoords(GetPlayerPed(source)) - Config.BigBanks['pacific']['coords'][2]) > 2.5 then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:setBankState', extraInfo = ' (pacific) ', source = source }))
        end
        Config.BigBanks['pacific']['isOpened'] = true
        TriggerEvent('qb-bankrobbery:server:setTimeout', 'pacific')
    else
        if Config.SmallBanks[bankId]['isOpened'] or #(GetEntityCoords(GetPlayerPed(source)) - Config.SmallBanks[bankId]['coords']) > 2.5 then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:setBankState', extraInfo = ' (smallbank ' .. bankId .. ') ', source = source }))
        end
        Config.SmallBanks[bankId]['isOpened'] = true
        TriggerEvent('qb-bankrobbery:server:SetSmallBankTimeout', bankId)
    end
    TriggerClientEvent('qb-bankrobbery:client:setBankState', -1, bankId)
    Config.OnRobberyStart(bankId)
end)

RegisterNetEvent('qb-bankrobbery:server:setLockerState', function(bankId, lockerId, state, bool)
    local bankType = Config.BigBanks[bankId] and 'BigBanks' or 'SmallBanks'
    local bank = Config[bankType][bankId]
    local locker = bank and bank['lockers'][lockerId]
    if not locker then return end
    local extraInfo = (' (%s' .. bankId .. ') '):format(bankType == 'SmallBanks' and 'smallbank' or '')
    if #(GetEntityCoords(GetPlayerPed(source)) - locker['coords']) > 2.5 then
        return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:setLockerState', extraInfo = extraInfo, source = source }))
    end
    locker[state] = bool
    TriggerClientEvent('qb-bankrobbery:client:setLockerState', -1, bankId, lockerId, state, bool)
end)

RegisterNetEvent('qb-bankrobbery:server:recieveItem', function(type, bankId, lockerId)
    local src = source
    local ply = exports['qb-core']:GetPlayer(src)
    if not ply then return end
    if type == 'small' then
        if not Config.SmallBanks[bankId] or not Config.SmallBanks[bankId]['lockers'][lockerId] then return end
        if #(GetEntityCoords(GetPlayerPed(src)) - Config.SmallBanks[bankId]['lockers'][lockerId]['coords']) > 2.5 then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:receiveItem', extraInfo = ' (smallbank ' .. bankId .. ') ', source = source }))
        end
        local itemType = math.random(#Config.RewardTypes)
        local WeaponChance = math.random(1, 50)
        local odd1 = math.random(1, 50)
        local tierChance = math.random(1, 100)
        local tier
        if tierChance < 50 then tier = 1 elseif tierChance >= 50 and tierChance < 80 then tier = 2 elseif tierChance >= 80 and tierChance < 95 then tier = 3 else tier = 4 end
        if WeaponChance ~= odd1 then
            if tier ~= 4 then
                if Config.RewardTypes[itemType].type == 'item' then
                    local item = Config.LockerRewards['tier' .. tier][math.random(#Config.LockerRewards['tier' .. tier])]
                    local itemAmount = math.random(item.minAmount, item.maxAmount)
                    exports['qb-inventory']:AddItem(src, item.item, itemAmount, false, false, 'qb-bankrobbery:server:recieveItem')
                    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems[item.item], 'add')
                elseif Config.RewardTypes[itemType].type == 'money' then
                    local info = {
                        worth = math.random(2800, 3800)
                    }
                    exports['qb-inventory']:AddItem(src, 'markedbills', math.random(2, 4), false, info, 'qb-bankrobbery:server:recieveItem')
                    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['markedbills'], 'add')
                end
            else
                exports['qb-inventory']:AddItem(src, 'security_card_01', 1, false, false, 'qb-bankrobbery:server:recieveItem')
                TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['security_card_01'], 'add')
            end
        else
            exports['qb-inventory']:AddItem(src, 'weapon_stungun', 1, false, false, 'qb-bankrobbery:server:recieveItem')
            TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['weapon_stungun'], 'add')
        end
    elseif type == 'paleto' then
        if #(GetEntityCoords(GetPlayerPed(source)) - Config.BigBanks['paleto']['lockers'][lockerId]['coords']) > 2.5 then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:receiveItem', extraInfo = ' (paleto) ', source = source }))
        end
        local itemType = math.random(#Config.RewardTypes)
        local tierChance = math.random(1, 100)
        local WeaponChance = math.random(1, 10)
        local odd1 = math.random(1, 10)
        local tier
        if tierChance < 25 then tier = 1 elseif tierChance >= 25 and tierChance < 70 then tier = 2 elseif tierChance >= 70 and tierChance < 95 then tier = 3 else tier = 4 end
        if WeaponChance ~= odd1 then
            if tier ~= 4 then
                if Config.RewardTypes[itemType].type == 'item' then
                    local item = Config.LockerRewardsPaleto['tier' .. tier][math.random(#Config.LockerRewardsPaleto['tier' .. tier])]
                    local itemAmount = math.random(item.minAmount, item.maxAmount)
                    exports['qb-inventory']:AddItem(src, item.item, itemAmount, false, false, 'qb-bankrobbery:server:recieveItem')
                    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems[item.item], 'add')
                elseif Config.RewardTypes[itemType].type == 'money' then
                    local info = {
                        worth = math.random(5000, 7000)
                    }
                    exports['qb-inventory']:AddItem(src, 'markedbills', math.random(2, 4), false, info, 'qb-bankrobbery:server:recieveItem')
                    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['markedbills'], 'add')
                end
            else
                exports['qb-inventory']:AddItem(src, 'security_card_02', 1, false, false, 'qb-bankrobbery:server:recieveItem')
                TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['security_card_02'], 'add')
            end
        else
            exports['qb-inventory']:AddItem(src, 'weapon_vintagepistol', 1, false, false, 'qb-bankrobbery:server:recieveItem')
            TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['weapon_vintagepistol'], 'add')
        end
    elseif type == 'pacific' then
        if #(GetEntityCoords(GetPlayerPed(source)) - Config.BigBanks['pacific']['lockers'][lockerId]['coords']) > 2.5 then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:receiveItem', extraInfo = ' (pacific) ', source = source }))
        end
        local itemType = math.random(#Config.RewardTypes)
        local WeaponChance = math.random(1, 100)
        local odd1 = math.random(1, 100)
        local odd2 = math.random(1, 100)
        local tierChance = math.random(1, 100)
        local tier
        if tierChance < 25 then tier = 1 elseif tierChance < 50 then tier = 2 elseif tierChance < 95 then tier = 3 else tier = 4 end
        if WeaponChance ~= odd1 or WeaponChance ~= odd2 then
            if tier ~= 4 then
                if Config.RewardTypes[itemType].type == 'item' then
                    local item = Config.LockerRewardsPacific['tier' .. tier][math.random(#Config.LockerRewardsPacific['tier' .. tier])]
                    local itemAmount = math.random(item.minAmount, item.maxAmount)
                    exports['qb-inventory']:AddItem(src, item.item, itemAmount, false, false, 'qb-bankrobbery:server:recieveItem')
                    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems[item.item], 'add')
                elseif Config.RewardTypes[itemType].type == 'money' then
                    local info = {
                        worth = math.random(22000, 26000)
                    }
                    exports['qb-inventory']:AddItem(src, 'markedbills', math.random(1, 4), false, info, 'qb-bankrobbery:server:recieveItem')
                    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['markedbills'], 'add')
                end
            else
                local info = {
                    worth = math.random(22000, 26000)
                }
                exports['qb-inventory']:AddItem(src, 'markedbills', math.random(1, 4), false, info, 'qb-bankrobbery:server:recieveItem')
                TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['markedbills'], 'add')
                info = {
                    crypto = math.random(1, 3)
                }
                exports['qb-inventory']:AddItem(src, 'cryptostick', 1, false, info, 'qb-bankrobbery:server:recieveItem')
                TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['cryptostick'], 'add')
            end
        else
            local chance = math.random(1, 2)
            local odd = math.random(1, 2)
            if chance == odd then
                exports['qb-inventory']:AddItem(src, 'weapon_microsmg', 1, false, false, 'qb-bankrobbery:server:recieveItem')
                TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['weapon_microsmg'], 'add')
            else
                exports['qb-inventory']:AddItem(src, 'weapon_minismg', 1, false, false, 'qb-bankrobbery:server:recieveItem')
                TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['weapon_minismg'], 'add')
            end
        end
    end
end)

AddEventHandler('qb-bankrobbery:server:setTimeout', function(bankId)
    if bankId ~= 'paleto' and bankId ~= 'pacific' then return end
    if bigBankTimeouts[bankId] then return end
    bigBankTimeouts[bankId] = true
    CreateThread(function()
        SetTimeout(60000 * 90, function()
            for k in pairs(Config.BigBanks[bankId]['lockers']) do
                Config.BigBanks[bankId]['lockers'][k]['isBusy'] = false
                Config.BigBanks[bankId]['lockers'][k]['isOpened'] = false
            end
            for k in pairs(Config.BigBanks[bankId]['thermite'] or {}) do
                Config.BigBanks[bankId]['thermite'][k]['isOpened'] = false
            end
            TriggerClientEvent('qb-bankrobbery:client:ResetBigBank', -1, bankId)
            Config.BigBanks[bankId]['isOpened'] = false
            bigBankTimeouts[bankId] = nil
            Config.OnRobberyTimeoutEnd(bankId)
        end)
    end)
end)

AddEventHandler('qb-bankrobbery:server:SetSmallBankTimeout', function(bankId)
    if not Config.SmallBanks[bankId] or smallBankTimeouts[bankId] then return end
    smallBankTimeouts[bankId] = true
    CreateThread(function()
        SetTimeout(60000 * 30, function()
            for k in pairs(Config.SmallBanks[bankId]['lockers']) do
                Config.SmallBanks[bankId]['lockers'][k]['isOpened'] = false
                Config.SmallBanks[bankId]['lockers'][k]['isBusy'] = false
            end
            TriggerClientEvent('qb-bankrobbery:client:ResetFleecaLockers', -1, bankId)
            smallBankTimeouts[bankId] = nil
            Config.OnRobberyTimeoutEnd(bankId)
        end)
    end)
end)

RegisterNetEvent('qb-bankrobbery:server:callCops', function(type, bank, coords)
    if type == 'small' then
        if not Config.SmallBanks[bank]['alarm'] then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:callCops', extraInfo = ' (smallbank ' .. bank .. ') ', source = source }))
        end
    elseif type == 'paleto' then
        if not Config.BigBanks['paleto']['alarm'] then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:callCops', extraInfo = ' (paleto) ', source = source }))
        end
    elseif type == 'pacific' then
        if not Config.BigBanks['pacific']['alarm'] then
            return error(Lang:t('error.event_trigger_wrong', { event = 'qb-bankrobbery:server:callCops', extraInfo = ' (pacific) ', source = source }))
        end
    end
    TriggerClientEvent('qb-bankrobbery:client:robberyCall', -1, type, coords)
end)

RegisterNetEvent('qb-bankrobbery:server:SetStationStatus', function(key, isHit)
    Config.PowerStations[key].hit = isHit
    TriggerClientEvent('qb-bankrobbery:client:SetStationStatus', -1, key, isHit)
    if AllStationsHit() then
        exports['qb-weathersync']:setBlackout(true)
        TriggerClientEvent('qb-bankrobbery:client:disableAllBankSecurity', -1)
        Config.OnBlackout(true)
        CreateThread(function()
            SetTimeout(60000 * Config.BlackoutTimer, function()
                exports['qb-weathersync']:setBlackout(false)
                TriggerClientEvent('qb-bankrobbery:client:enableAllBankSecurity', -1)
                Config.OnBlackout(false)
            end)
        end)
    else
        CheckStationHits()
    end
end)

RegisterNetEvent('qb-bankrobbery:server:setThermiteState', function(doorId, isOpened)
    local src = source
    local playerCoords = GetEntityCoords(GetPlayerPed(src))

    for bankId, bank in pairs(Config.BigBanks) do
        for gateId, gate in pairs(bank.thermite or {}) do
            if gate.doorId == doorId then
                if #(playerCoords - gate.coords) > 2.5 then return end
                gate.isOpened = isOpened == true
                TriggerClientEvent('qb-bankrobbery:client:setThermiteState', -1, bankId, gateId, gate.isOpened)
                return
            end
        end
    end
end)

RegisterNetEvent('qb-bankrobbery:server:removeElectronicKit', function()
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(src, 'electronickit', 1, false, 'qb-bankrobbery:server:removeElectronicKit')
    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['electronickit'], 'remove')
    exports['qb-inventory']:RemoveItem(src, 'trojan_usb', 1, false, 'qb-bankrobbery:server:removeElectronicKit')
    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['trojan_usb'], 'remove')
end)

RegisterNetEvent('qb-bankrobbery:server:removeBankCard', function(number)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(src, 'security_card_' .. number, 1, false, 'qb-bankrobbery:server:removeBankCard')
    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['security_card_' .. number], 'remove')
end)

RegisterNetEvent('thermite:StartServerFire', function(coords, maxChildren, isGasFire)
    local src = source
    local ped = GetPlayerPed(src)
    local coords2 = GetEntityCoords(ped)
    local thermiteCoords = Config.BigBanks['pacific'].thermite[1].coords
    local thermite2Coords = Config.BigBanks['pacific'].thermite[2].coords
    local thermite3Coords = Config.BigBanks['paleto'].thermite[1].coords
    if #(coords2 - thermiteCoords) < 10 or #(coords2 - thermite2Coords) < 10 or #(coords2 - thermite3Coords) < 10 or IsNearPowerStation(coords2, 10) then
        TriggerClientEvent('thermite:StartFire', -1, coords, maxChildren, isGasFire)
    end
end)

RegisterNetEvent('thermite:StopFires', function()
    TriggerClientEvent('thermite:StopFires', -1)
end)

-- Callbacks

QBCore.Functions.CreateCallback('qb-bankrobbery:server:isRobberyActive', function(_, cb)
    -- Eclipse City allows independent bank robberies; one active bank must not
    -- place every other initiation panel into a citywide security lockdown.
    cb(false)
end)

QBCore.Functions.CreateCallback('qb-bankrobbery:server:GetCopCount', function(_, cb)
    cb(GetOnDutyPoliceCount())
end)

QBCore.Functions.CreateCallback('qb-bankrobbery:server:GetConfig', function(_, cb)
    cb(Config.PowerStations, Config.BigBanks, Config.SmallBanks)
end)

QBCore.Functions.CreateCallback('thermite:server:check', function(source, cb)
    local Player = exports['qb-core']:GetPlayer(source)
    if not Player then return cb(false) end
    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(source, 'thermite', 1)
    end)
    if ok and removed then
        TriggerClientEvent('qb-inventory:client:ItemBox', source, sharedItems['thermite'], 'remove')
        cb(true)
    else
        print(('[qb-bankrobbery] thermite consumption failed src=%s error=%s')
            :format(source, tostring(removed)))
        cb(false)
    end
end)

-- Items

local function inventoryItemCount(source, itemName)
    local oxCount = 0
    if GetResourceState('ox_inventory') == 'started' then
        local ok, count = pcall(function()
            return exports.ox_inventory:GetItemCount(source, itemName)
        end)
        if ok then oxCount = tonumber(count) or 0 end
    end

    -- ox's QBCore bridge also mirrors the inventory into PlayerData.items. Use
    -- that as an independent fallback and log disagreements so a compatibility
    -- regression cannot silently reject an item the player visibly owns.
    local qbCount = 0
    local Player = exports['qb-core']:GetPlayer(source)
    if Player and Player.PlayerData and Player.PlayerData.items then
        for _, item in pairs(Player.PlayerData.items) do
            if item and item.name == itemName then
                qbCount = qbCount + (tonumber(item.amount or item.count) or 0)
            end
        end
    end

    if oxCount ~= qbCount then
        print(('[qb-bankrobbery] inventory count mismatch src=%s item=%s ox=%d qb=%d')
            :format(source, itemName, oxCount, qbCount))
    end

    return math.max(oxCount, qbCount)
end

local function hasInventoryItem(source, itemName)
    return inventoryItemCount(source, itemName) > 0
end

local function usePanelItem(source, itemName)
    local Player = exports['qb-core']:GetPlayer(source)
    if not Player then return end

    if itemName == 'thermite' then
        if not hasInventoryItem(source, 'thermite') then
            return TriggerClientEvent('QBCore:Notify', source, Lang:t('error.missing_item'), 'error')
        end
        TriggerClientEvent('thermite:UseThermite', source)
        return
    end

    if itemName == 'electronickit' then
        if not hasInventoryItem(source, 'electronickit') or not hasInventoryItem(source, 'trojan_usb') then
            return TriggerClientEvent('QBCore:Notify', source, Lang:t('error.missing_item'), 'error')
        end
        TriggerClientEvent('electronickit:UseElectronickit', source)
        return
    end

    if itemName == 'security_card_01' or itemName == 'security_card_02' then
        if not hasInventoryItem(source, itemName) then
            return TriggerClientEvent('QBCore:Notify', source, Lang:t('error.missing_item'), 'error')
        end
        TriggerClientEvent(itemName == 'security_card_01' and 'qb-bankrobbery:UseBankcardA' or 'qb-bankrobbery:UseBankcardB', source)
    end
end

-- The E prompts use the same authoritative item path as using an item from the
-- inventory. Only the four known panel tools are accepted.
RegisterNetEvent('qb-bankrobbery:server:usePanelItem', function(itemName)
    if itemName ~= 'thermite' and itemName ~= 'electronickit'
        and itemName ~= 'security_card_01' and itemName ~= 'security_card_02' then return end
    usePanelItem(source, itemName)
end)

QBCore.Functions.CreateUseableItem('thermite', function(source)
    usePanelItem(source, 'thermite')
end)

QBCore.Functions.CreateUseableItem('security_card_01', function(source)
    usePanelItem(source, 'security_card_01')
end)

QBCore.Functions.CreateUseableItem('security_card_02', function(source)
    usePanelItem(source, 'security_card_02')
end)

QBCore.Functions.CreateUseableItem('electronickit', function(source)
    usePanelItem(source, 'electronickit')
end)
