Config = {
    useTarget = GetConvar('UseTarget', 'false') == 'true',
    -- Cashpoints use the eye independently of the city-wide UseTarget policy.
    -- Bank counters keep their existing E interaction while UseTarget is false.
    useAtmTarget = true,
    atmModels = { 'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm' },
    atmRobbery = {
        enabled = true,
        requiredItem = 'WEAPON_CROWBAR',
        durabilityLoss = 20,
        minimumPolice = 1,
        duration = 30000,
        cooldown = 30 * 60,
        maxDistance = 2.0,
        reward = {
            min = 1500,
            max = 3000,
        },
    },
    useDailyLimit = true,
    dailyLimit = 5000,
    maxAccounts = 2,
    blipInfo = {
        name = 'Bank',
        sprite = 108,
        color = 2,
        scale = 0.55
    },
    locations = {
        vector3(149.05, -1041.3, 29.37),
        vector3(313.32, -280.03, 54.17),
        vector3(-351.94, -50.72, 49.04),
        vector3(-1212.68, -331.83, 37.78),
        vector3(-2961.67, 482.31, 15.7),
        vector3(1175.64, 2707.71, 38.09),
        vector3(247.65, 223.87, 106.29),
        vector3(-111.98, 6470.56, 31.63)
    }
}
