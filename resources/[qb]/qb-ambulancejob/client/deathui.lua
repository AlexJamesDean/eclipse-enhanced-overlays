-- Eclipse City Aurora presentation for QBCore's last-stand and full-death flow.
-- Input remains in Lua; NUI is deliberately display-only so it never steals focus.

local aidocStage = 'idle'
local lastPayload = nil
local visualPhase = 'clear'
local deadTimecycle = nil
local deadPostfx = nil
local defibAttempted = false

local function findAvailableTimecycle(candidates)
    local ok, count = pcall(GetTimecycleModifierCount)
    if not ok or type(count) ~= 'number' or count <= 0 then return nil end

    local available = {}
    for i = 0, count - 1 do
        local nameOk, name = pcall(GetTimecycleModifierNameByIndex, i)
        if nameOk and type(name) == 'string' then
            available[name:lower()] = name
        end
    end

    for _, candidate in ipairs(candidates or {}) do
        local match = available[tostring(candidate):lower()]
        if match then return match end
    end
end

local function clearDeadGrade()
    if deadTimecycle then
        pcall(ClearTimecycleModifier)
        deadTimecycle = nil
    end
    if deadPostfx then
        pcall(AnimpostfxStop, deadPostfx)
        deadPostfx = nil
    end
end

local function setVisualPhase(phase)
    if visualPhase == phase then return end
    visualPhase = phase

    if phase == 'clear' then
        clearDeadGrade()
        TriggerEvent('ajd-drugs:client:setMedicalVisualSuspended', false)
        return
    end

    -- Medical grading owns the view while down. ajd-drugs restores any active
    -- drug grade once this resource releases it on revive/respawn.
    TriggerEvent('ajd-drugs:client:setMedicalVisualSuspended', true)

    if phase == 'laststand' then
        clearDeadGrade()
        return
    end

    clearDeadGrade()
    local visuals = Config.DeathVisuals or {}
    deadTimecycle = findAvailableTimecycle(visuals.deadTimecycles)
    if deadTimecycle then
        pcall(SetTransitionTimecycleModifier, deadTimecycle, visuals.transitionSeconds or 1.0)
        pcall(SetTimecycleModifierStrength, visuals.deadStrength or 0.88)
    else
        deadPostfx = visuals.deadPostfxFallback or 'DeathFailOut'
        pcall(AnimpostfxPlay, deadPostfx, 0, true)
    end
end

local function getAidocUiState()
    if GetResourceState('ajd-aidoc') ~= 'started' then
        return { available = false, stage = 'offline', key = 'H', price = 0 }
    end

    local ok, state = pcall(function()
        return exports['ajd-aidoc']:GetUiState()
    end)

    if ok and type(state) == 'table' then
        aidocStage = state.stage or aidocStage
        return {
            available = true,
            stage = aidocStage,
            key = state.key or 'H',
            price = tonumber(state.price) or 0
        }
    end

    return { available = true, stage = aidocStage, key = 'H', price = 0 }
end

RegisterNetEvent('qb-ambulancejob:client:aidocState', function(stage)
    if type(stage) == 'string' then aidocStage = stage end
end)

RegisterNetEvent('hospital:client:SetDefibAttempted', function(attempted)
    defibAttempted = attempted and true or false
end)

exports('IsAidocWindowOpen', function()
    return InLaststand and not isDead
end)

local function sendIfChanged(payload, signature)
    if signature == lastPayload then return end
    lastPayload = signature
    SendNUIMessage(payload)
end

CreateThread(function()
    while true do
        local down = isDead or InLaststand
        if not down or isInHospitalBed then
            setVisualPhase('clear')
            sendIfChanged({ action = 'death:hide' }, 'hidden')
            Wait(500)
        else
            local phase = InLaststand and 'laststand' or 'dead'
            local previousPhase = visualPhase
            setVisualPhase(phase)
            if phase == 'dead' and previousPhase ~= 'dead' then
                local playerData = QBCore.Functions.GetPlayerData()
                local metadata = playerData and playerData.metadata or {}
                defibAttempted = metadata['defibattempted'] == true
            end
            local seconds = math.max(0, math.ceil(phase == 'laststand' and LaststandTime or deathTime))
            local respawnHold = GetDeathRespawnHold and GetDeathRespawnHold() or 5
            local aidoc = phase == 'laststand' and getAidocUiState()
                or { available = false, stage = 'closed', key = 'H', price = 0 }

            local payload = {
                action = 'death:update',
                phase = phase,
                seconds = seconds,
                respawnReady = phase == 'dead' and seconds <= 0,
                respawnHold = respawnHold,
                respawnCost = Config.BillCost,
                canAlertEms = phase == 'laststand' and LaststandTime <= Config.MinimumRevive,
                emsNotified = emsNotified,
                aidoc = aidoc,
                overlay = phase == 'laststand' and (Config.DeathVisuals or {}).bleedout or nil,
                defibAttempted = phase == 'dead' and defibAttempted or false
            }

            local signature = table.concat({
                phase, seconds, respawnHold, tostring(payload.canAlertEms),
                tostring(emsNotified), tostring(aidoc.available), aidoc.stage,
                aidoc.key, aidoc.price, tostring(payload.defibAttempted)
            }, ':')

            sendIfChanged(payload, signature)
            Wait(100)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    setVisualPhase('clear')
    SendNUIMessage({ action = 'death:hide' })
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    setVisualPhase('clear')
    SendNUIMessage({ action = 'death:hide' })
end)
