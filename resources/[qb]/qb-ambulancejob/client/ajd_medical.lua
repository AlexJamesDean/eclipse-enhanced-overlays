-- ajd addition (30 Jul 2026): generic treatment surface for ajd-shops'
-- medical catalogue (tourniquet / splint / multi-use kits). Bleeding and
-- limb state are resource-globals of this resource (isBleeding, BodyParts,
-- injured, and the bleed timers in client/main.lua + client/wounding.lua)
-- with only item-specific handlers, so the generic events and the read
-- exports have to live here rather than in ajd-shops.

local QBCore = exports['qb-core']:GetCoreObject()

local function syncInjuries()
    TriggerServerEvent('hospital:server:SyncInjuries', {
        limbs = BodyParts,
        isBleeding = tonumber(isBleeding)
    })
end

local function anyLimpDamage()
    for _, part in pairs(BodyParts) do
        if part.causeLimp and part.isDamaged then
            return true
        end
    end
    return false
end

exports('AjdGetBleedLevel', function()
    return tonumber(isBleeding) or 0
end)

exports('AjdIsLimping', anyLimpDamage)

RegisterNetEvent('ajd-medical:client:adjustBleed', function(delta)
    delta = tonumber(delta)
    if not delta then return end

    local level = math.max(0, math.min(4, (tonumber(isBleeding) or 0) + delta))
    isBleeding = level

    if level == 0 then
        bleedTickTimer = 0
        advanceBleedTimer = 0
        fadeOutTimer = 0
        blackoutTimer = 0
        QBCore.Functions.Notify('The bleeding has stopped', 'success')
    else
        QBCore.Functions.Notify(Lang:t('info.bleed_alert', { bleedstate = Config.BleedingStates[level].label }), 'error', 5000)
    end

    syncInjuries()
end)

RegisterNetEvent('ajd-medical:client:healLegs', function()
    for _, part in pairs(BodyParts) do
        if part.causeLimp and part.isDamaged then
            part.isDamaged = false
            part.severity = 0
        end
    end

    for i = #injured, 1, -1 do
        local entry = injured[i]
        if BodyParts[entry.part] and BodyParts[entry.part].causeLimp then
            table.remove(injured, i)
        end
    end

    if not anyLimpDamage() then
        ResetPedMovementClipset(PlayerPedId(), 0.0)
        SetPlayerSprint(PlayerId(), true)
        QBCore.Functions.Notify('Your leg is braced - you can walk properly again', 'success')
    end

    syncInjuries()
end)
