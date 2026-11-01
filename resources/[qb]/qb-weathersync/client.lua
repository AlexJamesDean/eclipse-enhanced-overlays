local CurrentWeather = Config.StartWeather
local lastWeather = CurrentWeather
local baseTime = Config.BaseTime
local timeOffset = Config.TimeOffset
local freezeTime = Config.FreezeTime
local blackout = Config.Blackout
local blackoutVehicle = Config.BlackoutVehicle
local disable = Config.Disabled

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
end)

RegisterNetEvent('qb-weathersync:client:EnableSync', function()
    disable = false
    TriggerServerEvent('qb-weathersync:server:RequestStateSync')
end)

RegisterNetEvent('qb-weathersync:client:DisableSync', function()
    disable = true
    SetRainLevel(0.0)
    SetWeatherTypePersist('CLEAR')
    SetWeatherTypeNow('CLEAR')
    SetWeatherTypeNowPersist('CLEAR')
    NetworkOverrideClockTime(18, 0, 0)
end)

RegisterNetEvent('qb-weathersync:client:SyncWeather', function(NewWeather, newblackout)
    CurrentWeather = NewWeather
    blackout = newblackout
end)

RegisterNetEvent('qb-weathersync:client:SyncTime', function(base, offset, freeze)
    freezeTime = freeze
    timeOffset = offset
    baseTime = base
end)

CreateThread(function()
    while true do
        if not disable then
            if lastWeather ~= CurrentWeather then
                lastWeather = CurrentWeather
                SetWeatherTypeOverTime(CurrentWeather, 15.0)
                Wait(15000)
            end
            Wait(100) -- Wait 0 seconds to prevent crashing.
            SetArtificialLightsState(blackout)
            SetArtificialLightsStateAffectsVehicles(blackoutVehicle)
            ClearOverrideWeather()
            ClearWeatherTypePersist()
            SetWeatherTypePersist(lastWeather)
            SetWeatherTypeNow(lastWeather)
            SetWeatherTypeNowPersist(lastWeather)
            if lastWeather == 'XMAS' then
                SetForceVehicleTrails(true)
                SetForcePedFootstepsTracks(true)
            else
                SetForceVehicleTrails(false)
                SetForcePedFootstepsTracks(false)
            end
            if lastWeather == 'RAIN' then
                SetRainLevel(0.3)
            elseif lastWeather == 'THUNDER' then
                SetRainLevel(0.5)
            else
                SetRainLevel(0.0)
            end
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    local hour
    local minute = 0
    local second = 0 --Add seconds for shadow smoothness
    local timeIncrement = Config.RealTimeSync and 0.25 or 1
    local tick = GetGameTimer()

    while true do
        if not disable and (GetResourceState('ajd-alwaysnight') == 'started' or GlobalState.eclipseActive or GlobalState.clockOwner) then
            -- ajd-alwaysnight owns the clock (30 Jul 2026): both resources were
            -- calling NetworkOverrideClockTime - this loop every frame - so the
            -- night lock lost the race and the server ran full daylight cycles.
            -- Weather stays this resource's job; time is alwaysnight's while
            -- that resource is running. Same deal for ajd-eclipse (11 Aug 2026)
            -- while GlobalState.eclipseActive: this resource's own freeze can't
            -- hold a steady sun (the 60s baseTime re-derive ignores the freeze
            -- flag and the 2s sync stomps the client compensation), and the
            -- eclipse needs the sun nailed in place. GlobalState.clockOwner is
            -- the general form: any resource that sets it drives the clock.
            Wait(5000)
        elseif not disable then
            Wait(0)
            local _, _, _, hours, minutes, _ = GetLocalTime()
            local newBaseTime = baseTime
            if GetGameTimer() - tick > (Config.RealTimeSync and 500 or 22) then
                second = second + timeIncrement
                tick = GetGameTimer()
            end
            if freezeTime then
                timeOffset = timeOffset + baseTime - newBaseTime
                second = 0
            end
            baseTime = newBaseTime
            if Config.RealTimeSync then
                hour = hours
                minute = minutes
            else
                hour = math.floor(((baseTime + timeOffset) / 60) % 24)
                if minute ~= math.floor((baseTime + timeOffset) % 60) then --Reset seconds to 0 when new minute
                    minute = math.floor((baseTime + timeOffset) % 60)
                    second = 0
                end
            end
            NetworkOverrideClockTime(hour, minute, second) --Send hour included seconds to network clock time
        else
            Wait(1000)
        end
    end
end)
