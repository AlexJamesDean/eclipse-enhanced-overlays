local deadAnimDict = 'dead'
local deadAnim = 'dead_a'
local hold = 5
deathTime = 0

-- Read by the Aurora death UI without making the timer implementation global.
function GetDeathRespawnHold()
    return hold
end

-- Functions

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

function OnDeath()
    if not isDead then
        isDead = true
        TriggerServerEvent('hospital:server:SetDeathStatus', true)
        TriggerServerEvent('InteractSound_SV:PlayOnSource', 'demo', 0.1)
        local player = PlayerPedId()

        -- ajd 4 Aug 2026: bounded like SetLaststand's settle wait — a dead ped
        -- can report IsPedRagdoll indefinitely and this used to hang forever.
        local settleDeadline = GetGameTimer() + 4000
        while (GetEntitySpeed(player) > 0.5 or IsPedRagdoll(player)) and GetGameTimer() < settleDeadline do
            Wait(10)
        end

        if isDead then
            local pos = GetEntityCoords(player)
            local heading = GetEntityHeading(player)

            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped) then
                local veh = GetVehiclePedIsIn(ped)
                local vehseats = GetVehicleModelNumberOfSeats(GetHashKey(GetEntityModel(veh)))
                for i = -1, vehseats do
                    local occupant = GetPedInVehicleSeat(veh, i)
                    if occupant == ped then
                        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
                        SetPedIntoVehicle(ped, veh, i)
                    end
                end
            else
                NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z + 0.5, heading, true, false)
            end

            SetEntityInvincible(player, true)
            SetEntityHealth(player, GetEntityMaxHealth(player))
            if IsPedInAnyVehicle(player, false) then
                loadAnimDict('veh@low@front_ps@idle_duck')
                TaskPlayAnim(player, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 1.0, -1, 1, 0, 0, 0, 0)
            else
                loadAnimDict(deadAnimDict)
                TaskPlayAnim(player, deadAnimDict, deadAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
            end
            TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.civ_died'))
        end
    end
end

function DeathTimer()
    hold = 5
    while isDead do
        Wait(1000)
        deathTime = deathTime - 1
        if deathTime <= 0 then
            if IsControlPressed(0, 38) and hold <= 0 and not isInHospitalBed then
                TriggerEvent('hospital:client:RespawnAtHospital')
                hold = 5
            end
            if IsControlPressed(0, 38) then
                if hold - 1 >= 0 then
                    hold = hold - 1
                else
                    hold = 0
                end
            end
            if IsControlReleased(0, 38) then
                hold = 5
            end
        end
    end
end

-- Damage Handler

AddEventHandler('gameEventTriggered', function(event, data)
    if event == 'CEventNetworkEntityDamage' then
        local victim, attacker, victimDied, weapon = data[1], data[2], data[4], data[7]
        if not IsEntityAPed(victim) then return end
        if victimDied and NetworkGetPlayerIndexFromPed(victim) == PlayerId() and IsEntityDead(PlayerPedId()) then
            if not InLaststand then
                SetLaststand(true)
            elseif InLaststand and not isDead then
                SetLaststand(false)
                local playerid = NetworkGetPlayerIndexFromPed(victim)
                local playerName = GetPlayerName(playerid) .. ' ' .. '(' .. GetPlayerServerId(playerid) .. ')' or Lang:t('info.self_death')
                local killerId = NetworkGetPlayerIndexFromPed(attacker)
                local killerName = GetPlayerName(killerId) .. ' ' .. '(' .. GetPlayerServerId(killerId) .. ')' or Lang:t('info.self_death')
                local weaponLabel = (QBCore.Shared.Weapons and QBCore.Shared.Weapons[weapon] and QBCore.Shared.Weapons[weapon].label) or 'Unknown'
                local weaponName = (QBCore.Shared.Weapons and QBCore.Shared.Weapons[weapon] and QBCore.Shared.Weapons[weapon].name) or 'Unknown'
                TriggerServerEvent('qb-log:server:CreateLog', 'death', Lang:t('logs.death_log_title', { playername = playerName, playerid = GetPlayerServerId(playerid) }), 'red', Lang:t('logs.death_log_message', { killername = killerName, playername = playerName, weaponlabel = weaponLabel, weaponname = weaponName }))
                deathTime = Config.DeathTime
                OnDeath()
                DeathTimer()
            end
        end
    end
end)

-- Threads

-- ajd 4 Aug 2026: FALLBACK death watcher. The CEventNetworkEntityDamage
-- handler above was the ONLY way into laststand, and it has two holes:
-- its data[] layout is client-build-dependent (Enhanced auto-updates), and
-- deaths with no damage event at all (qb-core starvation SetEntityHealth,
-- any scripted kill) never fire it. Either hole = the player lies ragdolled
-- with no bleedout forever. This watcher catches any engine death the event
-- missed; SetLaststand's re-entry latch makes double-detection harmless.
CreateThread(function()
    while true do
        Wait(500)
        if LocalPlayer.state.isLoggedIn and not isDead and not InLaststand then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                SetLaststand(true)
            end
        end
    end
end)

emsNotified = false

CreateThread(function()
    while true do
        local sleep = 1000
        if isDead or InLaststand then
            sleep = 5
            local ped = PlayerPedId()
            if IsPauseMenuActive() then
                SetFrontendActive(false)
            end
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true)
            EnableControlAction(0, 38, true)
            EnableControlAction(0, 0, true)
            EnableControlAction(0, 322, true)
            EnableControlAction(0, 288, true)
            EnableControlAction(0, 213, true)
            EnableControlAction(0, 249, true)
            EnableControlAction(0, 46, true)
            EnableControlAction(0, 47, true)
            EnableControlAction(0, 74, true) -- H: ajd-aidoc default hotkey

            if isDead then
                if IsPedInAnyVehicle(ped, false) then
                    loadAnimDict('veh@low@front_ps@idle_duck')
                    if not IsEntityPlayingAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 3) then
                        TaskPlayAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                    end
                else
                    if isInHospitalBed then
                        if not IsEntityPlayingAnim(ped, inBedDict, inBedAnim, 3) then
                            loadAnimDict(inBedDict)
                            TaskPlayAnim(ped, inBedDict, inBedAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    -- ajd 31 Jul 2026 — added `and not isEscorted`. This branch
                    -- re-applies the dead pose every 5ms, so anyone being carried or
                    -- escorted had their carry animation stomped 200 times a second
                    -- and hung off the carrier in the lying-down pose. The laststand
                    -- branch below has always respected this flag (line ~201); the
                    -- dead branch never did. ajd-carry sets it through the same
                    -- hospital:client:isEscorted event qb-policejob uses.
                    elseif not isEscorted then
                        if not IsEntityPlayingAnim(ped, deadAnimDict, deadAnim, 3) then
                            loadAnimDict(deadAnimDict)
                            TaskPlayAnim(ped, deadAnimDict, deadAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    end
                end

                SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            elseif InLaststand then
                sleep = 5

                -- H belongs to medical care only while this last-stand screen is
                -- active. ajd-aidoc used to RegisterKeyMapping H globally, which
                -- intercepted unrelated healthy-state uses such as opening the
                -- controls for a boombox being carried.
                if IsControlJustPressed(0, 74) and GetResourceState('ajd-aidoc') == 'started' then
                    pcall(function()
                        exports['ajd-aidoc']:RequestFromBleedout()
                    end)
                end

                if LaststandTime <= Config.MinimumRevive then
                    if IsControlJustPressed(0, 47) and not emsNotified then
                        TriggerServerEvent('hospital:server:ambulanceAlert', Lang:t('info.civ_down'))
                        emsNotified = true
                    end
                end

                if not isEscorted then
                    if IsPedInAnyVehicle(ped, false) then
                        loadAnimDict('veh@low@front_ps@idle_duck')
                        if not IsEntityPlayingAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 3) then
                            TaskPlayAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    else
                        loadAnimDict(lastStandDict)
                        if not IsEntityPlayingAnim(ped, lastStandDict, lastStandAnim, 3) then
                            TaskPlayAnim(ped, lastStandDict, lastStandAnim, 1.0, 1.0, -1, 1, 0, 0, 0, 0)
                        end
                    end
                else
                    if IsPedInAnyVehicle(ped, false) then
                        loadAnimDict('veh@low@front_ps@idle_duck')
                        if IsEntityPlayingAnim(ped, 'veh@low@front_ps@idle_duck', 'sit', 3) then
                            StopAnimTask(ped, 'veh@low@front_ps@idle_duck', 'sit', 3)
                        end
                    else
                        loadAnimDict(lastStandDict)
                        if IsEntityPlayingAnim(ped, lastStandDict, lastStandAnim, 3) then
                            StopAnimTask(ped, lastStandDict, lastStandAnim, 3)
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
