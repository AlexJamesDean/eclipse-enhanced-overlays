Config = {}

Config.UseTarget = GetConvar('UseTarget', 'false') == 'true' -- Use qb-target interactions (don't change this, go to your server.cfg and add `setr UseTarget true` to use this and just that from true to false or the other way around)

Config.Locations = {
    [1] = {
        ['main'] = vector3(2397.42, 3089.44, 49.92),
        ['deliver'] = { coords = vector3(2351.5, 3132.96, 48.2), length = 6.0, width = 4.0, heading = 270.0 },
        ['list'] = { coords = vector3(2403.51, 3127.95, 48.15), length = 6.0, width = 4.0, heading = 270.0 },
    }
}

Config.Items = {
    'metalscrap',
    'plastic',
    'copper',
    'iron',
    'aluminum',
    'steel',
    'glass',
}

Config.VehicleCount = 40
Config.CurrentVehicles = {}

Config.Vehicles = {
    [1] = 'ninef',
    [2] = 'ninef2',
    [3] = 'banshee',
    [4] = 'alpha',
    [5] = 'baller',
    [6] = 'bison',
    [7] = 'huntley',
    [8] = 'f620',
    [9] = 'asea',
    [10] = 'pigalle',
    [11] = 'bullet',
    [12] = 'turismor',
    [13] = 'zentorno',
    [14] = 'dominator',
    [15] = 'blade',
    [16] = 'chino',
    [17] = 'sabregt',
    [18] = 'bati',
    [19] = 'carbonrs',
    [20] = 'akuma',
    [21] = 'thrust',
    [22] = 'exemplar',
    [23] = 'felon',
    [24] = 'sentinel',
    [25] = 'blista',
    [26] = 'fusilade',
    [27] = 'jackal',
    [28] = 'blista2',
    [29] = 'rocoto',
    [30] = 'seminole',
    [31] = 'landstalker',
    [32] = 'picador',
    [33] = 'prairie',
    [34] = 'bobcatxl',
    [35] = 'gauntlet',
    [36] = 'virgo',
    [37] = 'fq2',
    [38] = 'jester',
    [39] = 'rhapsody',
    [40] = 'feltzer2',
    [41] = 'buffalo',
    [42] = 'buffalo2',
    [43] = 'stretch',
    [44] = 'ratloader2',
    [45] = 'ruiner',
    [46] = 'rebel',
    -- Keys were sparse here (46 -> 48 -> 58..80): GenerateVehicleList draws with
    -- math.random(1, #Config.Vehicles) and # stops at the first gap, so every
    -- model below this line had NEVER been able to appear on the wanted list.
    -- Renumbered contiguous 3 Aug 2026 (duplicate 'stanier' dropped).
    [47] = 'slamvan',
    [48] = 'zion',
    [49] = 'zion2',
    [50] = 'tampa',
    [51] = 'sultan',
    [52] = 'asbo',
    [53] = 'panto',
    [54] = 'oracle',
    [55] = 'oracle2',
    [56] = 'sentinel2',
    [57] = 'baller2',
    [58] = 'schafter2',
    [59] = 'schwarzer',
    [60] = 'cavalcade',
    [61] = 'cavalcade2',
    [62] = 'comet2',
    [63] = 'serrano',
    [64] = 'tailgater',
    [65] = 'sandking',
    [66] = 'sandking2',
    [67] = 'cognoscenti',
    [68] = 'stanier',
    [69] = 'washington',
}
