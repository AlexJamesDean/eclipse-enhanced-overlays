-- Internal gang IDs are retained for compatibility with player data and resources.
-- The labels below are the names shown to players.
QBCore.Shared.GangAliases = {
    cartel = 'northside',
}

QBCore.Shared.Gangs = {
    -- System fallback
    none = {
        label = 'No Gang',
        grades = {
            ['0'] = { name = 'Unaffiliated' },
        },
    },

    -- London street organisations
    lostmc = {
        label = 'Borough Mandem',
        grades = {
            ['0'] = { name = 'Younger' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Older' },
            ['3'] = { name = 'Bossman', isboss = true },
        },
    },
    ballas = {
        label = 'Eastwick Crew',
        grades = {
            ['0'] = { name = 'Younger' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Older' },
            ['3'] = { name = 'Bossman', isboss = true },
        },
    },
    vagos = {
        label = 'Dockside Crew',
        grades = {
            ['0'] = { name = 'Younger' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Older' },
            ['3'] = { name = 'Bossman', isboss = true },
        },
    },
    families = {
        label = 'Tanner\'s End',
        grades = {
            ['0'] = { name = 'Younger' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Older' },
            ['3'] = { name = 'Bossman', isboss = true },
        },
    },
    triads = {
        label = 'Strip Mandem',
        grades = {
            ['0'] = { name = 'Younger' },
            ['1'] = { name = 'Soldier' },
            ['2'] = { name = 'Older' },
            ['3'] = { name = 'Bossman', isboss = true },
        },
    },

    -- Organised crime
    northside = {
        label = 'Northside Firm',
        grades = {
            ['0'] = { name = 'Associate' },
            ['1'] = { name = 'Enforcer' },
            ['2'] = { name = 'Underboss' },
            ['3'] = { name = 'Boss', isboss = true },
        },
    },

    southside = {
        label = 'Southside Syndicate',
        grades = {
            ['0'] = { name = 'Newcomer' },
            ['1'] = { name = 'Enforcer' },
            ['2'] = { name = 'Underboss', isboss = true },
            ['3'] = { name = 'Leader', isboss = true },
        },
    },
}
