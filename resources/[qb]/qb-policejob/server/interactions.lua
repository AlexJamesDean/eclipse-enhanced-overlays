local sharedItems = exports['qb-core']:GetShared('Items')

-- ---------------------------------------------------------------------------
-- ajd 31 Jul 2026 — the ten range checks in this file each used to end in
-- `DropPlayer(src, 'Attempted exploit abuse')`.
--
-- They kick on a POSITION heuristic, and the server's copy of a player's position
-- is not reliable enough to punish anybody on. The case that proved it: a player
-- being escorted is ATTACHED to their dragger on their own client, and while dead
-- their ped effectively stops feeding the server fresh coordinates — so carrying a
-- downed friend to the hospital and pressing /escort again to put them down
-- measured as "3+ metres apart" and kicked the person doing the helping, with no
-- ban row and no explanation (AJ, 31 Jul 2026).
--
-- The protection is unchanged in effect — the action is still refused, so nobody
-- can cuff, rob or bill a player from across the map — but a mis-measure now costs
-- a notification instead of a disconnect, and a genuine attempt leaves a console
-- line to look at. Releasing someone you are already escorting skips the check
-- entirely: they are attached to you, so the distance is not meaningful.
-- ---------------------------------------------------------------------------
local escorting = {}   -- dragger src -> target src, for the release exemption above

-- 3 Aug 2026 — every police interaction started refusing (AJ: "policejob is
-- completely broken"). The client only fires these events when IT measures the
-- target within 1.5m (client/interactions.lua:245), so a server refusal at >2.5m
-- means the server's own measurement is wrong. This line did not record WHICH
-- way it was wrong, so it could not tell apart the two candidates:
--   * targetPed resolved to 0 -> coords (0,0,0) -> distance = |playerCoords|,
--     i.e. thousands. Fits "completely broken" (fails every time).
--   * the target's synced position is stale by a few metres. Fits intermittent
--     failure, and is the class already documented at the top of this file.
-- One refusal in the log now discriminates them outright.
local function refuseOutOfRange(src, what, targetId, playerCoords, targetCoords)
    local detail = ''
    if playerCoords and targetCoords then
        local targetPed = targetId and GetPlayerPed(targetId) or nil
        detail = (' | target %s ped %s dist %.2f | src %.1f %.1f %.1f | tgt %.1f %.1f %.1f%s'):format(
            tostring(targetId), tostring(targetPed), #(playerCoords - targetCoords),
            playerCoords.x, playerCoords.y, playerCoords.z,
            targetCoords.x, targetCoords.y, targetCoords.z,
            (targetCoords.x == 0.0 and targetCoords.y == 0.0 and targetCoords.z == 0.0)
                and '  <-- TARGET PED DID NOT RESOLVE' or '')
    end
    print(('[qb-policejob] %s from %s refused — target measured out of range%s'):format(what, tostring(src), detail))
    TriggerClientEvent('QBCore:Notify', src, 'They are not close enough', 'error')
end

AddEventHandler('playerDropped', function()
    local src = source
    escorting[src] = nil
    for dragger, target in pairs(escorting) do
        if target == src then escorting[dragger] = nil end
    end
end)

local function searchClosestPlayer(src)
    if not src or src <= 0 then return end
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    local PlayerData = Player.PlayerData
    if PlayerData.job.type ~= 'leo' or not PlayerData.job.onduty then
        TriggerClientEvent('QBCore:Notify', src, 'You must be an on-duty police officer', 'error')
        return
    end
    local player, distance = QBCore.Functions.GetClosestPlayer(src)
    if player ~= -1 and distance < 1.8 then
        local SearchedPlayer = exports['qb-core']:GetPlayer(tonumber(player))
        if not SearchedPlayer then return end
        -- Use ox's native player-open route. It repeats the proximity and police
        -- group checks client/server-side before presenting the two inventories.
        TriggerClientEvent('ox_inventory:openInventory', src, 'player', tonumber(player))
        TriggerClientEvent('QBCore:Notify', player, Lang:t('info.being_searched'))
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.none_nearby'), 'error')
    end
end

RegisterNetEvent('police:server:SearchPlayer', function()
    searchClosestPlayer(source)
end)

QBCore.Commands.Add('search', 'Search the nearest person', {}, false, function(source)
    searchClosestPlayer(source)
end)

RegisterNetEvent('police:server:CuffPlayer', function(playerId, isSoftcuff)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'CuffPlayer', playerId, playerCoords, targetCoords) end

    local Player = exports['qb-core']:GetPlayer(src)
    local CuffedPlayer = exports['qb-core']:GetPlayer(playerId)
    if not Player or not CuffedPlayer or (not Player.GetItemByName('handcuffs') and Player.PlayerData.job.type ~= 'leo') then return end

    TriggerClientEvent('police:client:GetCuffed', CuffedPlayer.PlayerData.source, Player.PlayerData.source, isSoftcuff)
end)

RegisterNetEvent('police:server:EscortPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)

    -- /escort is a TOGGLE: the second call puts the player back down. On that call
    -- the target is attached to this player, so their synced position is stale by
    -- however far the pair has walked — which is exactly the measurement this check
    -- used to kick for. A release is never range-checked.
    local releasing = escorting[src] == playerId
    if not releasing and #(playerCoords - targetCoords) > 2.5 then
        return refuseOutOfRange(src, 'EscortPlayer', playerId, playerCoords, targetCoords)
    end

    local Player = exports['qb-core']:GetPlayer(source)
    local EscortPlayer = exports['qb-core']:GetPlayer(playerId)
    if not Player or not EscortPlayer then return end

    if (Player.PlayerData.job.type == 'leo' or Player.PlayerData.job.name == 'ambulance') or (EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead'] or EscortPlayer.PlayerData.metadata['inlaststand']) then
        TriggerClientEvent('police:client:GetEscorted', EscortPlayer.PlayerData.source, Player.PlayerData.source)
        escorting[src] = (not releasing) and playerId or nil
    else
        -- Refused because the target is back on their feet (or was never cuffed).
        -- If we were carrying them, the pairing is over either way — clear it so a
        -- later /escort on somebody else is not treated as a release.
        escorting[src] = nil
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:KidnapPlayer', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'KidnapPlayer', playerId, playerCoords, targetCoords) end

    local Player = exports['qb-core']:GetPlayer(source)
    local EscortPlayer = exports['qb-core']:GetPlayer(playerId)
    if not Player or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead'] or EscortPlayer.PlayerData.metadata['inlaststand'] then
        TriggerClientEvent('police:client:GetKidnappedTarget', EscortPlayer.PlayerData.source, Player.PlayerData.source)
        TriggerClientEvent('police:client:GetKidnappedDragger', Player.PlayerData.source, EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:SetPlayerOutVehicle', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'SetPlayerOutVehicle', playerId, playerCoords, targetCoords) end

    local EscortPlayer = exports['qb-core']:GetPlayer(playerId)
    if not exports['qb-core']:GetPlayer(src) or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead'] then
        TriggerClientEvent('police:client:SetOutVehicle', EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:PutPlayerInVehicle', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'PutPlayerInVehicle', playerId, playerCoords, targetCoords) end

    local EscortPlayer = exports['qb-core']:GetPlayer(playerId)
    if not exports['qb-core']:GetPlayer(src) or not EscortPlayer then return end

    if EscortPlayer.PlayerData.metadata['ishandcuffed'] or EscortPlayer.PlayerData.metadata['isdead'] then
        TriggerClientEvent('police:client:PutInVehicle', EscortPlayer.PlayerData.source)
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_cuffed_dead'), 'error')
    end
end)

RegisterNetEvent('police:server:BillPlayer', function(playerId, price)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'BillPlayer', playerId, playerCoords, targetCoords) end

    local Player = exports['qb-core']:GetPlayer(src)
    local OtherPlayer = exports['qb-core']:GetPlayer(playerId)
    if not Player or not OtherPlayer or Player.PlayerData.job.type ~= 'leo' then return end

    OtherPlayer.Functions.RemoveMoney('bank', price, 'paid-bills')
    exports['qb-banking']:AddMoney('police', price, 'Fine paid')
    TriggerClientEvent('QBCore:Notify', OtherPlayer.PlayerData.source, Lang:t('info.fine_received', { fine = price }))
end)

RegisterNetEvent('police:server:JailPlayer', function(playerId, time)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'JailPlayer', playerId, playerCoords, targetCoords) end

    local Player = exports['qb-core']:GetPlayer(src)
    local OtherPlayer = exports['qb-core']:GetPlayer(playerId)
    if not Player or not OtherPlayer or Player.PlayerData.job.type ~= 'leo' then return end

    local currentDate = os.date('*t')
    if currentDate.day == 31 then
        currentDate.day = 30
    end

    OtherPlayer.Functions.SetMetaData('injail', time)
    OtherPlayer.Functions.SetMetaData('criminalrecord', {
        ['hasRecord'] = true,
        ['date'] = currentDate
    })
    TriggerClientEvent('police:client:SendToJail', OtherPlayer.PlayerData.source, time)
    TriggerClientEvent('QBCore:Notify', src, Lang:t('info.sent_jail_for', { time = time }))
end)

RegisterNetEvent('police:server:SeizeCash', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'SeizeCash', playerId, playerCoords, targetCoords) end
    local Player = exports['qb-core']:GetPlayer(src)
    local SearchedPlayer = exports['qb-core']:GetPlayer(playerId)
    if not Player or not SearchedPlayer then return end
    if Player.PlayerData.job.type ~= 'leo' then return end
    local moneyAmount = SearchedPlayer.PlayerData.money['cash']
    local info = { cash = moneyAmount }
    SearchedPlayer.Functions.RemoveMoney('cash', moneyAmount, 'police-cash-seized')
    exports['qb-inventory']:AddItem(src, 'moneybag', 1, false, info, 'police:server:SeizeCash')
    TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['moneybag'], 'add')
    TriggerClientEvent('QBCore:Notify', SearchedPlayer.PlayerData.source, Lang:t('info.cash_confiscated'))
end)

RegisterNetEvent('police:server:SeizeDriverLicense', function(playerId)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'SeizeDriverLicense', playerId, playerCoords, targetCoords) end

    local SearchedPlayer = exports['qb-core']:GetPlayer(playerId)
    if not exports['qb-core']:GetPlayer(src) or not SearchedPlayer then return end

    local driverLicense = SearchedPlayer.PlayerData.metadata['licences']['driver']
    if driverLicense then
        local licenses = { ['driver'] = false, ['business'] = SearchedPlayer.PlayerData.metadata['licences']['business'] }
        SearchedPlayer.Functions.SetMetaData('licences', licenses)
        TriggerClientEvent('QBCore:Notify', SearchedPlayer.PlayerData.source, Lang:t('info.driving_license_confiscated'))
    else
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.no_driver_license'), 'error')
    end
end)

RegisterNetEvent('police:server:RobPlayer', function(playerId)
    local src = source
    if not exports['ajd-crime']:CanStartCrime(src, 'robbing another player') then return end
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(playerId)
    local playerCoords = GetEntityCoords(playerPed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(playerCoords - targetCoords) > 2.5 then return refuseOutOfRange(src, 'RobPlayer', playerId, playerCoords, targetCoords) end

    local Player = exports['qb-core']:GetPlayer(src)
    local SearchedPlayer = exports['qb-core']:GetPlayer(playerId)
    if not Player or not SearchedPlayer then return end

    local money = SearchedPlayer.PlayerData.money['cash']
    Player.AddMoney('cash', money, 'police-player-robbed')
    SearchedPlayer.Functions.RemoveMoney('cash', money, 'police-player-robbed')
    exports['qb-inventory']:OpenInventoryById(src, playerId)
    TriggerClientEvent('QBCore:Notify', SearchedPlayer.PlayerData.source, Lang:t('info.cash_robbed', { money = money }))
    TriggerClientEvent('QBCore:Notify', Player.PlayerData.source, Lang:t('info.stolen_money', { stolen = money }))
end)
