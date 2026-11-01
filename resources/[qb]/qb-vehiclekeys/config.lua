Config = {}

-- Key System Settings
Config.PersistentKeys = true -- Whether keys received should be saved after server restart, or not

-- How close a player must be to a vehicle for the server to accept a key grant for
-- its plate, when they neither own it nor are sitting in it (server.lua's ground 3 —
-- job vehicles, rentals, hotwiring, carjacking). This is a SECURITY bound, not a
-- gameplay one: it is what stops a client asking for the keys to every plate on the
-- server. Keep it generous enough to cover spawning next to a car, but finite.
Config.KeyGrantRadius = 10.0

-- Vehicle lock settings
Config.LockToggleAnimation = {
    AnimDict = 'anim@mp_player_intmenu@key_fob@',
    Anim = 'fob_click',
    Prop = 'prop_cuff_keys_01',
    PropBone = 57005,
    WaitTime = 500,
}
Config.LockAnimSound = 'keys'
Config.LockToggleSound = 'lock'
Config.LockToggleDist = 8.0

-- NPC Vehicle Lock States
-- ALL NPC CARS UNLOCKED (AJ's call, 25 Jul 2026) — players kept trying to steal cars and
-- bouncing off locked doors, which is friction with no gameplay in it.
Config.LockNPCDrivingCars = false      -- Occupied NPC cars: unlocked AND keys granted, passengers flee
                                       -- (client.lua:56-63 fires AcquireVehicleKeys). Effectively instant
                                       -- acquisition — no hotwire. Carjacking becomes optional flavour, not the gate.
Config.LockNPCParkedCars = false       -- Parked NPC cars: unlocked, but NO keys granted (client.lua:74-78 sets the
                                       -- lock state only) — so these still route through the hotwire settings below.
Config.UseKeyfob = false               -- you can set this true if you dont need ui
-- Lockpick Settings
Config.RemoveLockpickNormal = 0.5      -- Chance to remove lockpick on fail
Config.RemoveLockpickAdvanced = 0.2    -- Chance to remove advanced lockpick on fail
-- Carjack Settings
Config.CarJackEnable = true            -- True allows for the ability to car jack peds.
Config.CarjackingTime = 7500           -- How long it takes to carjack
Config.DelayBetweenCarjackings = 10000 -- Time before you can carjack again
Config.CarjackChance = {
    ['2685387236'] = 0.0,              -- melee
    ['416676503'] = 0.5,               -- handguns
    ['-957766203'] = 0.75,             -- SMG
    ['860033945'] = 0.90,              -- shotgun
    ['970310034'] = 0.90,              -- assault
    ['1159398588'] = 0.99,             -- LMG
    ['3082541095'] = 0.99,             -- sniper
    ['2725924767'] = 0.99,             -- heavy
    ['1548507267'] = 0.0,              -- throwable
    ['4257178988'] = 0.0,              -- misc
}

-- Hotwire Settings
Config.HotwireChance = 0.5        -- Chance for successful hotwire or not
Config.TimeBetweenHotwires = 5000 -- Time in ms between hotwire attempts
Config.minHotwireTime = 20000     -- Minimum hotwire time in ms
Config.maxHotwireTime = 40000     --  Maximum hotwire time in ms

-- Police Alert Settings
Config.AlertCooldown = 10000         -- 10 seconds
Config.PoliceAlertChance = 0.75      -- Chance of alerting police during the day
Config.PoliceNightAlertChance = 0.50 -- Chance of alerting police at night (times:01-06)

-- Job Settings
Config.SharedKeys = { -- Share keys amongst employees. Employees can lock/unlock any job-listed vehicle
    ['police'] = {    -- Job name
        requireOnduty = false,
        vehicles = {
            'police', -- Vehicle model
            'police2', -- Vehicle model
        }
    },

    ['mechanic'] = {
        requireOnduty = false,
        vehicles = {
            'towtruck',
        }
    }
}

-- These vehicles cannot be jacked
Config.ImmuneVehicles = {
    'stockade'
}

-- These vehicles will never lock
Config.NoLockVehicles = {}

-- These weapons cannot be used for carjacking
Config.NoCarjackWeapons = {
    'WEAPON_UNARMED',
    'WEAPON_Knife',
    'WEAPON_Nightstick',
    'WEAPON_HAMMER',
    'WEAPON_Bat',
    'WEAPON_Crowbar',
    'WEAPON_Golfclub',
    'WEAPON_Bottle',
    'WEAPON_Dagger',
    'WEAPON_Hatchet',
    'WEAPON_KnuckleDuster',
    'WEAPON_Machete',
    'WEAPON_Flashlight',
    'WEAPON_SwitchBlade',
    'WEAPON_Poolcue',
    'WEAPON_Wrench',
    'WEAPON_Battleaxe',
    'WEAPON_Grenade',
    'WEAPON_StickyBomb',
    'WEAPON_ProximityMine',
    'WEAPON_BZGas',
    'WEAPON_Molotov',
    'WEAPON_FireExtinguisher',
    'WEAPON_PetrolCan',
    'WEAPON_Flare',
    'WEAPON_Ball',
    'WEAPON_Snowball',
    'WEAPON_SmokeGrenade',
}
