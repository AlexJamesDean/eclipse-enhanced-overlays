-- Clear Inventory
RegisterNetEvent('ps-adminmenu:server:ClearInventory', function(data, selectedData)
    local data = CheckDataFromKey(data)
    -- ECLIPSE CITY FIX (7 Aug 2026): upstream calls CheckPerms(data.perms) with the
    -- source argument missing, so perms lands in the `source` slot and the real
    -- perms arg is nil. HasPermission returns false for a nil permission, so this
    -- handler failed CLOSED for everyone including gods — Clear Inventory silently
    -- did nothing. It fails safe, but it never worked. Every sibling handler in
    -- this file passes source correctly; this was the only one missing it.
    if not data or not CheckPerms(source, data.perms) then return end

    local src = source
    local player = selectedData["Player"].value
    local Player = QBCore.Functions.GetPlayer(player)

    if not Player then
        return QBCore.Functions.Notify(source, locale("not_online"), 'error', 7500)
    end

    if Config.Inventory == 'ox_inventory' then
        exports.ox_inventory:ClearInventory(player)
    else
        exports[Config.Inventory]:ClearInventory(player, nil)
    end

    QBCore.Functions.Notify(src,
        locale("invcleared", Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname),
        'success', 7500)
end)

-- Clear Inventory Offline
RegisterNetEvent('ps-adminmenu:server:ClearInventoryOffline', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end

    local src = source
    local citizenId = selectedData["Citizen ID"].value
    local Player = QBCore.Functions.GetPlayerByCitizenId(citizenId)

    if Player then
        if Config.Inventory == 'ox_inventory' then
            exports.ox_inventory:ClearInventory(Player.PlayerData.source)
        else
            exports[Config.Inventory]:ClearInventory(Player.PlayerData.source, nil)
        end
        QBCore.Functions.Notify(src,
            locale("invcleared", Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname),
            'success', 7500)
    else
        MySQL.Async.fetchAll("SELECT * FROM players WHERE citizenid = @citizenid", { ['@citizenid'] = citizenId },
            function(result)
                if result and result[1] then
                    MySQL.Async.execute("UPDATE players SET inventory = '{}' WHERE citizenid = @citizenid",
                        { ['@citizenid'] = citizenId })
                    QBCore.Functions.Notify(src, "Player's inventory cleared", 'success', 7500)
                else
                    QBCore.Functions.Notify(src, locale("player_not_found"), 'error', 7500)
                end
            end)
    end
end)

-- Open Inv / Stash / Trunk [ox side]
--
-- SECURITY (ajd, 8 Aug 2026): these three shipped with NO server-side permission
-- check. The admin gate lived only in the client-side menu that decides whether to
-- DRAW the button — but RegisterNetEvent registers a network endpoint, so any client
-- could TriggerServerEvent these directly, never open a menu, and force-open any
-- player's inventory, any stash, or any vehicle boot. Four of the seven handlers in
-- this file already called CheckPerms; these three were the omission.
-- 'mod' is the correct tier: server.cfg gives qbcore.admin the qbcore.mod principal,
-- so mod, admin and god all pass, and nobody else does.
RegisterNetEvent('ps-adminmenu:server:OpenInv', function(data)
    local src = source
    if not CheckPerms(src, 'mod') then return end
    exports.ox_inventory:forceOpenInventory(src, 'player', data)
end)

RegisterNetEvent('ps-adminmenu:server:OpenStash', function(data)
    local src = source
    if not CheckPerms(src, 'mod') then return end
    exports.ox_inventory:forceOpenInventory(src, 'stash', data)
end)

RegisterNetEvent('ps-adminmenu:server:OpenTrunk', function(data)
    local src = source
    if not CheckPerms(src, 'mod') then return end
    exports.ox_inventory:forceOpenInventory(src, 'trunk', data)
end)

-- Give Item
RegisterNetEvent('ps-adminmenu:server:GiveItem', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end

    local target = selectedData["Player"].value
    local item = selectedData["Item"].value
    local amount = tonumber(selectedData["Amount"].value)
    local Player = QBCore.Functions.GetPlayer(target)

    if not item or not amount or amount <= 0 then return end
    if not Player then
        return QBCore.Functions.Notify(source, locale("not_online"), 'error', 7500)
    end

    if Config.Inventory == "ox_inventory" then
        exports.ox_inventory:AddItem(target, item, amount)
    elseif Config.Inventory == "qb-inventory" then
        Player.Functions.AddItem(item, amount)
    end

    QBCore.Functions.Notify(source,
        locale("give_item", amount .. " " .. item,
            Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname), "success", 7500)
end)

-- Give Item to All
RegisterNetEvent('ps-adminmenu:server:GiveItemAll', function(data, selectedData)
    local data = CheckDataFromKey(data)
    if not data or not CheckPerms(source, data.perms) then return end

    local item = selectedData["Item"].value
    local amount = tonumber(selectedData["Amount"].value)
    local players = QBCore.Functions.GetPlayers()

    if not item or not amount or amount <= 0 then return end

    for _, id in pairs(players) do
        if Config.Inventory == "ox_inventory" then
            exports.ox_inventory:AddItem(id, item, amount)
        elseif Config.Inventory == "qb-inventory" then
            local Player = QBCore.Functions.GetPlayer(id)
            if Player then
                Player.Functions.AddItem(item, amount)
            end
        end
    end

    QBCore.Functions.Notify(source, locale("give_item_all", amount .. " " .. item), "success", 7500)
end)