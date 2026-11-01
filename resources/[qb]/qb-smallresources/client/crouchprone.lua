-- Crouch. Sole owner as of 2 Aug 2026: rpemotes was dropped (AJ's call), so the
-- LCONTROL collision that made crouch unusable is gone and this is the only
-- crouch system on the box again.
--
-- The history matters for anyone re-adding an emote pack: rpemotes bound
-- '+crouch' to LCONTROL too, both scripts fired on every press, each kept its
-- own independent boolean, and both drove the same 'move_ped_crouched' clipset.
-- After an odd number of presses the two were out of phase and one applied the
-- clipset while the other reset it -- the crouch you could not stand up from.
-- If any resource that binds crouch is ever installed again, disable one of them.

local isCrouching = false
local walkSet = 'default'

local function loadAnimSet(anim)
    if not HasAnimSetLoaded(anim) then
        RequestAnimSet(anim)
        while not HasAnimSetLoaded(anim) do
            Wait(10)
        end
    end
end

local function resetAnimSet()
    local ped = PlayerPedId()
    ResetPedMovementClipset(ped, 1.0)
    ResetPedWeaponMovementClipset(ped)
    ResetPedStrafeClipset(ped)

    if walkSet ~= 'default' then
        loadAnimSet(walkSet)
        SetPedMovementClipset(ped, walkSet, 1.0)
        RemoveAnimSet(walkSet)
    end
end

-- LCONTROL is ALSO the game's native INPUT_DUCK (control 36), so without this
-- one press does two things: our clipset crouch, and GTA's own stealth/sneak
-- mode. That combination is what read as a "half crouch" before the real crouch
-- (AJ, 2 Aug 2026) -- it was never a separate crouch stage, it was stealth mode
-- underneath the clipset.
--
-- Holding 36 disabled for as long as we are crouched keeps stealth out of it.
-- A RegisterKeyMapping command still fires from a disabled control, which is
-- what lets the same key uncrouch (rpemotes relied on this too).
local function blockStealthWhileCrouched()
    CreateThread(function()
        while isCrouching do
            DisableControlAction(0, 36, true)

            local ped = PlayerPedId()
            if GetPedStealthMovement(ped) ~= 0 then
                SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
            end

            Wait(0)
        end
    end)
end

RegisterNetEvent('crouchprone:client:SetWalkSet', function(clipset)
    walkSet = clipset
end)

RegisterCommand('togglecrouch', function()
    local ped = PlayerPedId()
    if IsPedSittingInAnyVehicle(ped) or IsPedFalling(ped) or IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) or IsPauseMenuActive() then
        return
    end

    -- Typing in a NUI field must not crouch the character underneath it. The
    -- panels on this box keep game input alive (SetNuiFocusKeepInput), so the
    -- keypress reaches here even while a menu is open.
    if IsNuiFocused() then return end

    ClearPedTasks(ped)
    if isCrouching then
        isCrouching = false
        resetAnimSet()
        SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
    else
        isCrouching = true
        loadAnimSet('move_ped_crouched')
        SetPedMovementClipset(ped, 'move_ped_crouched', 1.0)
        SetPedStrafeClipset(ped, 'move_ped_crouched_strafing')
        SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
        blockStealthWhileCrouched()
    end
end, false)

-- Never leave someone stuck in the crouch clipset because the resource stopped.
AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not isCrouching then return end
    isCrouching = false
    resetAnimSet()
    SetPedStealthMovement(PlayerPedId(), false, 'DEFAULT_ACTION')
end)

RegisterKeyMapping('togglecrouch', 'Toggle Crouch', 'keyboard', 'LCONTROL')
