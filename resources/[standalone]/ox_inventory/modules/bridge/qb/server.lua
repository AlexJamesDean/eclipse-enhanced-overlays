--[[
    ox_inventory framework bridge for QBCore (not qbx_core).

    WHY THIS FILE EXISTS
    overextended dropped QBCore support — official ox_inventory ships bridges for
    ox / esx / qbx / nd only. AJ is staying on QBCore, so this implements the same
    bridge interface against QBCore's API instead of pulling in an unmaintained fork.
    Selected with `set inventory:framework "qb"` in server.cfg
    (init.lua:17 -> shared.framework -> modules.bridge.<framework>.server).

    Written against the qbx bridge as the reference, since qbx_core is a QBCore fork
    and its bridge is the closest sibling. Differences that mattered:
      * QBCore has no `groups` table. It has job + gang, so groups are synthesised as
        { [job.name] = job.grade.level, [gang.name] = gang.grade.level }.
      * qbx exposes exports (QBX:GetPlayer / :GetGroups / :IsGradeBoss). QBCore uses
        QBCore.Functions.* and QBCore.Shared.* instead.
      * qbx fires qbx_core:server:playerLoggedOut / onGroupUpdate. QBCore fires
        QBCore:Server:PlayerLoaded / QBCore:Server:OnPlayerUnload and has no group
        update event, so job/gang changes are picked up via SetPlayerData.
      * qbx_vehicles provides GetVehicleIdByPlate. QBCore has no equivalent, so owned
        vehicles are resolved with a direct player_vehicles lookup.

    Corrected 21 Aug 2026: exercised continuously against this live server since
    25 Jul — it is the path every inventory operation takes. Two real defects have
    been found and fixed in it since (the both-ends vs trailing-only plate trim at
    getOwnedVehicleId, and the dead onLogout handler), which is what a live bridge
    looks like, not an unverified one.
]]

local Inventory = require 'modules.inventory.server'
local QBCore = exports['qb-core']:GetCoreObject()

---QBCore stores job and gang separately rather than as a group map. ox uses `groups`
---for shop/stash/vehicle permission checks, so flatten both into one table.
---@param playerData table
---@return table<string, number>
local function buildGroups(playerData)
    local groups = {}
    local job, gang = playerData.job, playerData.gang

    if job and job.name then
        groups[job.name] = job.grade and job.grade.level or 0
    end
    -- Gangs share the namespace deliberately: ox group checks are name-based, and a
    -- server should not have a job and a gang with the same name.
    if gang and gang.name and gang.name ~= 'none' then
        groups[gang.name] = gang.grade and gang.grade.level or 0
    end

    return groups
end

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    -- `player` here is QBCore PlayerData
    local charinfo = player.charinfo or {}
    return {
        source = player.source,
        name = ('%s %s'):format(charinfo.firstname or '?', charinfo.lastname or '?'),
        groups = buildGroups(player),
        sex = charinfo.gender,
        dateofbirth = charinfo.birthdate,
    }
end

local function setupPlayer(playerData)
    if not playerData then return end

    playerData.identifier = playerData.citizenid
    playerData.name = ('%s %s'):format(
        playerData.charinfo and playerData.charinfo.firstname or '?',
        playerData.charinfo and playerData.charinfo.lastname or '?')

    server.setPlayerInventory(playerData)

    -- Seed ox's `money` item FROM QBCore's balance, one-way, so ox-native UI can show a
    -- figure. QBCore stays authoritative — syncInventory never writes money back.
    --
    -- Seeded unconditionally rather than iterating GetAccountItemCounts: that only returns
    -- accounts that ALREADY exist as items, so on a freshly-migrated server it returns
    -- nothing, the seed never runs, and ox is left believing the player has zero.
    local cash = playerData.money and playerData.money.cash
    if cash then
        local ok, err = pcall(Inventory.SetItem, playerData.source, 'money', cash)
        if not ok then
            print(('[qb-bridge] could not seed money item for %s: %s')
                :format(tostring(playerData.source), tostring(err)))
        end
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    setupPlayer(Player.PlayerData)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    server.playerDropped(source)
end)

-- Pick up players already online when the resource restarts, so a live `ensure` does
-- not leave everyone without an inventory.
SetTimeout(500, function()
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        setupPlayer(player.PlayerData)
    end
end)

-- QBCore has no group-update event. Job and gang changes both land in SetPlayerData,
-- so re-derive groups from there instead.
AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    local inventory = Inventory(source)
    if not inventory or not inventory.player then return end
    local player = QBCore.Functions.GetPlayer(source)
    if player then inventory.player.groups = buildGroups(player.PlayerData) end
end)

AddEventHandler('QBCore:Server:OnGangUpdate', function(source, gang)
    local inventory = Inventory(source)
    if not inventory or not inventory.player then return end
    local player = QBCore.Functions.GetPlayer(source)
    if player then inventory.player.groups = buildGroups(player.PlayerData) end
end)

---Called by ox for every non-weapon item use (server.lua:495-502), wrapped in pcall — so
---anything that throws in here fails SILENTLY and the item simply does nothing.
---
---Two qb-vs-qbx differences bit here, both invisible because of that pcall:
---  1. qbx_core's CanUseItem returns the callback FUNCTION. This qb-core returns a TABLE:
---         QBCore.UsableItems[item] = { func = rawFunc, resource = GetInvokingResource() }
---     The qbx bridge this was copied from does `cb(source, data)`, which here attempts to
---     call a table. That is why the phone stopped working after the ox switch.
---  2. qb's CreateUseableItem callbacks receive (source, item) where `item` is a qb-shaped
---     item table — several read `item.info` or `item.slot`. ox passes its own
---     {name, count, slot, metadata} shape, so it is translated below.
function server.UseItem(source, itemName, data)
    -- ox invokes this inside a pcall, so ANYTHING that throws here fails completely
    -- silently. If item use ever breaks again, print itemName and the CanUseItem result
    -- at the top of this function — that is the only way to see the chain.
    local usable = QBCore.Functions.CanUseItem and QBCore.Functions.CanUseItem(itemName)
    if not usable then return end

    -- tolerate both shapes: this qb-core's { func = ... } and a bare function
    local fn = type(usable) == 'table' and usable.func or usable

    -- fn is usually NOT a plain Lua function. CreateUseableItem is called from another
    -- resource, so the callback crosses a resource boundary and FiveM marshals it as a
    -- CALLABLE TABLE carrying __cfx_functionReference. qb-core's own isCallable
    -- (server/player.lua:16) accounts for this; an earlier version of this bridge checked
    -- `type(fn) ~= 'function'` and silently rejected every single usable item.
    local function isCallable(v)
        if type(v) == 'function' then return true end
        if type(v) == 'table' then
            if type(rawget(v, '__cfx_functionReference')) == 'string' then return true end
            local mt = getmetatable(v)
            if mt and type(mt.__call) == 'function' then return true end
        end
        return false
    end

    if not isCallable(fn) then
        print(('[qb-bridge]   handler is not callable (%s) — cannot invoke'):format(type(fn)))
        return
    end

    local item = data and {
        name = data.name,
        amount = data.count,        -- qb callbacks read .amount
        count = data.count,         -- ox naming kept too
        slot = data.slot,
        info = data.metadata or {}, -- qb callbacks read .info
        metadata = data.metadata or {},
        type = 'item',
    } or nil

    return fn(source, item)
end

-- Kept deliberately: if this line is absent from the boot log then shared.framework is not
-- 'qb', a different bridge is running, and nothing else in here will behave.
print('[qb-bridge] QBCore bridge loaded')

---@diagnostic disable-next-line: duplicate-set-field
---Translate ox's slot table into something QBCore consumers understand.
---ox uses `count` / `metadata`; qb uses `amount` / `info`. Both are emitted so existing
---code works untouched either way. This bridge previously assigned ox's table straight
---across, which broke every client-side reader —
---  ajd-fishing/client/fishbuyer.lua:113  "attempt to perform arithmetic on a nil value
---  (field 'amount')"
---plus ajd-scavenge and ajd-crafting. A fresh table is built rather than mutating ox's
---own, which it relies on internally.
local function toQbItems(items)
    local out = {}
    for slot, item in pairs(items or {}) do
        if type(item) == 'table' and item.name then
            local sharedItem = QBCore.Shared.Items[item.name]
            out[slot] = {
                name = item.name,
                amount = item.count,               -- qb
                count = item.count,                -- ox
                slot = item.slot or slot,
                info = item.metadata or {},        -- qb
                metadata = item.metadata or {},    -- ox
                label = item.label,
                -- ox stores the TOTAL weight of the whole slot here. QBCore's item
                -- shape requires the PER-ITEM weight; QBCore consumers multiply it
                -- by `amount` themselves. Passing ox's slot weight caused stacked
                -- items to be counted twice (count²), making ordinary inventories
                -- appear hundreds of kilograms overweight.
                weight = sharedItem and sharedItem.weight
                    or ((item.count or 0) > 0 and item.weight / item.count or item.weight),
                type = sharedItem and sharedItem.type or item.type or 'item',
                unique = item.stack == false,
                useable = true,
            }
        end
    end
    return out
end

function server.syncInventory(inv)
    local player = QBCore.Functions.GetPlayer(inv.id)
    if not player then return end

    -- Keep PlayerData.items populated. ox is the source of truth, but plenty of
    -- QBCore resources read PlayerData.items directly and would otherwise see nothing.
    player.Functions.SetPlayerData('items', toQbItems(inv.items))

    --[[
        CASH IS AN ITEM. ox is authoritative for it; players.money.cash mirrors it.

        This is deliberate design (AJ, 25 Jul 2026): physical cash can be robbed or dropped,
        which makes banking a real decision. Bank and crypto stay in QBCore — they are not
        items, so they are not robbable, and that is the point.

        DANGER, learned the hard way: this loop writes ox's money item count into
        players.money.cash. If a player has NO money item it reports 0 and this zeroes their
        cash. That is exactly what happened earlier today — replacing data/items.lua dropped
        ox's own `money` item definition, so nobody could hold one, and 26 players were
        wiped. Two things keep it safe now:
          * `money` and `black_money` are defined in data/items.lua (and emitted by
            ajd-itemconvert, so a re-run cannot drop them again)
          * every player was seeded a money item by the 25 Jul wipe/seed migration
        If either stops being true, this will silently destroy balances again.
    ]]
    local accounts = Inventory.GetAccountItemCounts(inv)
    if not accounts then return end

    --[[
        ONLY `money` -> `cash` is mirrored.

        QBCore.Config.Money.MoneyTypes on this server is { cash, bank, crypto } — there is
        no black_money account, so mirroring ox's black_money item would call SetMoney with
        a type qb-core does not know. bank and crypto are excluded on purpose: they are not
        items, which is the whole point of the design (bank your cash or risk losing it).

        The reason string is load-bearing. ajd-inventory-compat overrides SetMoney to route
        cash into the ox item, and matches on exactly this string to let this one call
        through to the real QBCore function. Change it in one place and the HUD silently
        stops updating — change it in both, or not at all.
    ]]
    local amount = accounts.money
    if amount and player.Functions.GetMoney('cash') ~= amount then
        player.Functions.SetMoney('cash', amount, 'ox_inventory sync')
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, license)
    local player = QBCore.Functions.GetPlayer(inv.id)
    -- QBCore spells it 'licences' (British) in metadata.
    local licences = player and player.PlayerData.metadata and player.PlayerData.metadata.licences
    return licences and licences[license]
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    local player = QBCore.Functions.GetPlayer(inv.id)
    if not player then return end

    local licences = player.PlayerData.metadata.licences or {}

    if licences[license.name] then
        return false, 'already_have'
    elseif Inventory.GetItem(inv, 'money', false, true) < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)
    licences[license.name] = true
    player.Functions.SetMetaData('licences', licences)

    return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group, grade)
    -- QBCore has no IsGradeBoss export; isboss lives in the shared job/gang tables and
    -- the grade keys are strings.
    local shared = QBCore.Shared.Jobs[group] or QBCore.Shared.Gangs[group]
    if not shared or not shared.grades then return false end
    local gradeInfo = shared.grades[tostring(grade)] or shared.grades[grade]
    return gradeInfo and gradeInfo.isboss or false
end

---@param entityId number
---@return number | string
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    local stateId = Entity(entityId).state.vehicleid
    if stateId then return stateId end

    local plate = GetVehicleNumberPlateText(entityId)
    if not plate then return end

    -- NOTE the extra parentheses around the gsub. string.gsub returns TWO values (the
    -- result AND the substitution count), and as the last element of a table constructor
    -- it expands — so `{ plate:gsub(...) }` built { 'ABC123', 0 }, i.e. two parameters for
    -- one `?`. oxmysql then threw, this function failed, ox's openInventory callback
    -- returned nil, and the client reported "You can not open this inventory" for BOTH
    -- trunk and glovebox while the player inventory worked fine.
    -- Trim BOTH ends, not just the tail. GTA pads a plate shorter than 8 characters out
    -- to 8 on the entity, and the padding can land in front of the text — so a
    -- trailing-only trim left ' ACIDOG' and the lookup below compared that against a
    -- TRIM()ed column and matched nothing. getOwnedVehicleId then returned nil, which
    -- fails SILENTLY: Inventory.Load short-circuits on `id and ...` and hands back an
    -- empty table (trunk opens, no error, no contents), and every save runs
    -- `UPDATE ... WHERE id = NULL` for zero rows — visible only as ox's own
    -- "Saved 0/1 trunks" log line. Affected every plate under 8 characters.
    -- This also has to agree with ox_inventory/server.lua:180, which builds the
    -- inventory id ('trunk<plate>') with ox_lib's string.strtrim — a both-end trim.
    -- The two must strip identically or the id and the row id describe different cars.
    local trimmed = (plate:gsub('^%s*(.-)%s*$', '%1'))

    -- QBCore has no qbx_vehicles equivalent, so read player_vehicles directly. Plates are
    -- stored padded or trimmed inconsistently by different scripts, so compare trimmed on
    -- both sides rather than trusting the stored form.
    return MySQL.scalar.await(
        'SELECT id FROM player_vehicles WHERE TRIM(plate) = ? LIMIT 1',
        { trimmed }
    )
end
