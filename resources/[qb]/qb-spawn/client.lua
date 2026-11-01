local QBCore = exports['qb-core']:GetCoreObject({ 'Functions' })
local camZPlus1 = 1500
local camZPlus2 = 50
local pointCamCoords = 75
local pointCamCoords2 = 0
local cam1Time = 500
local cam2Time = 1000
local choosingSpawn = false
local Houses = {}
local cam = nil
local cam2 = nil

-- Functions

local function SetDisplay(bool)
    local translations = {}
    for k in pairs(Lang.fallback and Lang.fallback.phrases or Lang.phrases) do
        if k:sub(0, #'ui.') then
            translations[k:sub(#'ui.' + 1)] = Lang:t(k)
        end
    end
    choosingSpawn = bool
    SetNuiFocus(bool, bool)
    SendNUIMessage({
        action = 'showUi',
        status = bool,
        translations = translations
    })
end

-- Events

RegisterNetEvent('qb-spawn:client:openUI', function(value)
    SetEntityVisible(PlayerPedId(), false)
    DoScreenFadeOut(250)
    Wait(1000)
    DoScreenFadeIn(250)
    QBCore.Functions.GetPlayerData(function(PlayerData)
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', PlayerData.position.x, PlayerData.position.y, PlayerData.position.z + camZPlus1, -85.00, 0.00, 0.00, 100.00, false, 0)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 1, true, true)
    end)
    Wait(500)
    SetDisplay(value)
end)

RegisterNetEvent('qb-houses:client:setHouseConfig', function(houseConfig)
    Houses = houseConfig
end)

RegisterNetEvent('qb-spawn:client:setupSpawns', function(cData, new, apps)
    if not new then
        QBCore.Functions.TriggerCallback('qb-spawn:server:getOwnedHouses', function(houses)
            local myHouses = {}
            if houses ~= nil then
                for i = 1, (#houses), 1 do
                    myHouses[#myHouses + 1] = {
                        house = houses[i].house,
                        label = Houses[houses[i].house].adress,
                    }
                end
            end

            Wait(500)
            SendNUIMessage({
                action = 'setupLocations',
                locations = QB.Spawns,
                houses = myHouses,
                isNew = new
            })
        end, cData.citizenid)
    elseif new then
        SendNUIMessage({
            action = 'setupAppartements',
            locations = apps,
            isNew = new
        })
    end
end)

-- NUI Callbacks

RegisterNUICallback('exit', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'showUi',
        status = false
    })
    choosingSpawn = false
    cb('ok')
end)

local function SetCam(campos)
    cam2 = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', campos.x, campos.y, campos.z + camZPlus1, 300.00, 0.00, 0.00, 110.00, false, 0)
    PointCamAtCoord(cam2, campos.x, campos.y, campos.z + pointCamCoords)
    SetCamActiveWithInterp(cam2, cam, cam1Time, true, true)
    if DoesCamExist(cam) then
        DestroyCam(cam, true)
    end
    Wait(cam1Time)

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', campos.x, campos.y, campos.z + camZPlus2, 300.00, 0.00, 0.00, 110.00, false, 0)
    PointCamAtCoord(cam, campos.x, campos.y, campos.z + pointCamCoords2)
    SetCamActiveWithInterp(cam, cam2, cam2Time, true, true)
    SetEntityCoords(PlayerPedId(), campos.x, campos.y, campos.z)
end

RegisterNUICallback('setCam', function(data, cb)
    local location = tostring(data.posname)
    local type = tostring(data.type)
    DoScreenFadeOut(200)
    Wait(500)
    DoScreenFadeIn(200)
    if DoesCamExist(cam) then DestroyCam(cam, true) end
    if DoesCamExist(cam2) then DestroyCam(cam2, true) end
    if type == 'current' then
        QBCore.Functions.GetPlayerData(function(PlayerData)
            SetCam(PlayerData.position)
        end)
    elseif type == 'house' then
        SetCam(Houses[location].coords.enter)
    elseif type == 'normal' then
        SetCam(QB.Spawns[location].coords)
    elseif type == 'appartment' then
        SetCam(Apartments.Locations[location].coords.enter)
    end
    cb('ok')
end)

RegisterNUICallback('chooseAppa', function(data, cb)
    local ped = PlayerPedId()
    local appaYeet = data.appType
    SetDisplay(false)
    DoScreenFadeOut(500)
    Wait(5000)
    TriggerServerEvent('apartments:server:CreateApartment', appaYeet, Apartments.Locations[appaYeet].label, true)
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    FreezeEntityPosition(ped, false)
    RenderScriptCams(false, true, 500, true, true)
    SetCamActive(cam, false)
    DestroyCam(cam, true)
    SetCamActive(cam2, false)
    DestroyCam(cam2, true)
    SetEntityVisible(ped, true)
    cb('ok')
end)

local function PreSpawnPlayer()
    SetDisplay(false)
    DoScreenFadeOut(500)
    Wait(2000)
end

local function PostSpawnPlayer(ped)
    FreezeEntityPosition(ped, false)
    RenderScriptCams(false, true, 500, true, true)
    SetCamActive(cam, false)
    DestroyCam(cam, true)
    SetCamActive(cam2, false)
    DestroyCam(cam2, true)
    SetEntityVisible(PlayerPedId(), true)
    Wait(500)
    DoScreenFadeIn(250)
end

RegisterNUICallback('spawnplayer', function(data, cb)
    local location = tostring(data.spawnloc)
    local type = tostring(data.typeLoc)
    local ped = PlayerPedId()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local insideMeta = PlayerData.metadata['inside']
    if type == 'current' then
        PreSpawnPlayer()
        -- Fixed 25 Jul 2026: this used to re-fetch player data via the ASYNC form
        --     QBCore.Functions.GetPlayerData(function(pd) ... end)
        -- and set the coords inside that callback, even though PlayerData was already
        -- fetched synchronously on line 170. The callback resolved *after*
        -- PostSpawnPlayer() had faded the screen back in, so the teleport raced the fade
        -- and anything else positioning the ped in that window won — which is how
        -- "spawn at last location" ended up putting people somewhere else entirely.
        -- Uses the data we already have, applied synchronously, and re-asserts once after
        -- a frame because the ped can be recreated during the collision load.
        local pos = PlayerData.position
        if pos then
            ped = PlayerPedId()
            SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
            SetEntityHeading(ped, pos.a or 0.0)
            FreezeEntityPosition(ped, false)

            CreateThread(function()
                Wait(250)
                local p = PlayerPedId()
                if #(GetEntityCoords(p) - vector3(pos.x, pos.y, pos.z)) > 5.0 then
                    SetEntityCoords(p, pos.x, pos.y, pos.z, false, false, false, false)
                    SetEntityHeading(p, pos.a or 0.0)
                end
            end)
        end

        if insideMeta.house ~= nil then
            local houseId = insideMeta.house
            TriggerEvent('qb-houses:client:LastLocationHouse', houseId)
        elseif insideMeta.apartment.apartmentType ~= nil or insideMeta.apartment.apartmentId ~= nil then
            local apartmentType = insideMeta.apartment.apartmentType
            local apartmentId = insideMeta.apartment.apartmentId
            TriggerEvent('qb-apartments:client:LastLocationHouse', apartmentType, apartmentId)
        end
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        PostSpawnPlayer()
    elseif type == 'house' then
        PreSpawnPlayer()
        TriggerEvent('qb-houses:client:enterOwnedHouse', location)
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
        PostSpawnPlayer()
    elseif type == 'normal' then
        local pos = QB.Spawns[location] and QB.Spawns[location].coords
        if not pos then
            print(('[spawn-dbg] NO COORDS for location %s — QB.Spawns keys: %s')
                :format(tostring(location), json.encode(QB.Spawns and (function()
                    local k = {} for key in pairs(QB.Spawns) do k[#k+1] = key end return k
                end)() or {})))
            return cb('ok')
        end

        -- TEMPORARY INSTRUMENTATION (25 Jul 2026): selecting Legion was landing the player
        -- at their last saved position instead. These prints show whether the teleport is
        -- applied and then overridden by something else, or never applied at all.
        print(('[spawn-dbg] selected=%s target=%.2f, %.2f, %.2f'):format(location, pos.x, pos.y, pos.z))

        PreSpawnPlayer()
        SetEntityCoords(ped, pos.x, pos.y, pos.z)
        print(('[spawn-dbg] after 1st SetEntityCoords: %s'):format(GetEntityCoords(PlayerPedId())))

        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
        TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
        Wait(500)
        print(('[spawn-dbg] after OnPlayerLoaded + 500ms: %s'):format(GetEntityCoords(PlayerPedId())))

        -- re-fetch the ped: it can be recreated during the load, leaving the captured
        -- handle stale so every SetEntityCoords above silently targeted a dead entity
        ped = PlayerPedId()
        SetEntityCoords(ped, pos.x, pos.y, pos.z)
        SetEntityHeading(ped, pos.w)
        print(('[spawn-dbg] after 2nd SetEntityCoords: %s'):format(GetEntityCoords(ped)))

        PostSpawnPlayer()

        CreateThread(function()
            Wait(2000)
            print(('[spawn-dbg] 2s after PostSpawnPlayer: %s'):format(GetEntityCoords(PlayerPedId())))
        end)
    end
    cb('ok')
end)

-- Threads

CreateThread(function()
    while true do
        Wait(0)
        if choosingSpawn then
            DisableAllControlActions(0)
        else
            Wait(1000)
        end
    end
end)
