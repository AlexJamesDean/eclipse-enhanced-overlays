local function noPerms(source)
    QBCore.Functions.Notify(source, "You are not Admin or God.", 'error')
end

--- ECLIPSE CITY (7 Aug 2026): mod-aware replacement for QBCore.Functions.IsOptin.
---
--- The stock helper hard-requires 'admin' (qb-core/server/functions.lua:641)
--- before it will even look at the optin flag, so a qbcore.mod principal passes
--- ps-adminmenu's `restricted = 'qbcore.mod'` gate on /admin and is then refused
--- with "You are not on admin duty" — the entire mod tier this resource ships is
--- unreachable out of the box on qb-core. The tier check is already done by the
--- caller (restricted, or CheckPerms); optin is only ever meant to be the
--- on/off-duty toggle, so that is all this reads. Defaults true (config.lua:33).
--- @param source number
--- @return boolean
function IsOnStaffDuty(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    return Player.PlayerData.optin ~= false
end

--- @param perms string
function CheckPerms(source, perms)
    local hasPerms = QBCore.Functions.HasPermission(source, perms)
    if not hasPerms then
        return noPerms(source)
    end

    return hasPerms
end

function CheckDataFromKey(key)
    local actions = Config.Actions[key]
    if actions then
        local data = nil

        if actions.event then
            data = actions
        end

        if actions.dropdown then
            for _, v in pairs(actions.dropdown) do
                if v.event then
                    local new = v
                    new.perms = actions.perms
                    data = new
                    break
                end
            end
        end

        return data
    end

    local playerActions = Config.PlayerActions[key]
    if playerActions then
        return playerActions
    end

    local otherActions = Config.OtherActions[key]
    if otherActions then
        return otherActions
    end
end

---@param plate string
---@return boolean
function CheckAlreadyPlate(plate)
    local vPlate = QBCore.Shared.Trim(plate)
    local result = MySQL.single.await("SELECT plate FROM player_vehicles WHERE plate = ?", { vPlate })
    if result and result.plate then return true end
    return false
end

lib.callback.register('ps-adminmenu:callback:CheckPerms', function(source, perms)
    return CheckPerms(source, perms)
end)

-- SILENT tier query (ajd, 8 Aug 2026). Deliberately NOT CheckPerms: that one calls
-- noPerms(source) on failure, so using it to ask "what am I?" would fire a rejection
-- notification at the user every time the menu opened.
-- Returns the CALLER's highest tier, or the explicit string `none`. nil is kept
-- available to mean the callback itself did not answer during a resource restart.
-- Used only to decide which buttons the
-- menu draws — every action is still enforced server-side by CheckPerms, so a lie
-- from a modified client buys nothing.
lib.callback.register('ps-adminmenu:callback:GetMyTier', function(source)
    if QBCore.Functions.HasPermission(source, 'god') then return 'god' end
    if QBCore.Functions.HasPermission(source, 'admin') then return 'admin' end
    if QBCore.Functions.HasPermission(source, 'mod') then return 'mod' end
    return 'none'
end)

lib.callback.register('ps-adminmenu:callback:CheckAlreadyPlate', function(_, vPlate)
    return CheckAlreadyPlate(vPlate)
end)

--- @param source number
--- @param target number
function CheckRoutingbucket(source, target)
    local sourceBucket = GetPlayerRoutingBucket(source)
    local targetBucket = GetPlayerRoutingBucket(target)

    if sourceBucket == targetBucket then return end

    SetPlayerRoutingBucket(source, targetBucket)
    QBCore.Functions.Notify(source, locale("bucket_set", targetBucket), 'error', 7500)
end
