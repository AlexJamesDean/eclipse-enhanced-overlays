-- Zones for Menus
Config = Config or {}

Config.UseTarget = GetConvar('UseTarget', 'false') == 'true' -- Use qb-target interactions (don't change this, go to your server.cfg and add `setr UseTarget true` to use this and just that from true to false or the other way around)

Config.BossMenus = {
    police = {
        vector3(447.16, -974.31, 30.47),
    },
    ambulance = {
        vector3(311.21, -599.36, 43.29),
    },
    cardealer = {
        vector3(-32.94, -1114.64, 26.42),
    },
    mechanic = {
        vector3(-347.59, -133.35, 39.01),
    },
}

-- Eclipse City (16 Aug 2026): the stock entries were five gangs all at
-- vector3(0, 0, 0) (unreachable, and triads was missing entirely). A gang gets
-- its menu coordinate here when AJ approves its base — usually inside the base.
-- Example:  ballas = { vector3(-123.4, 567.8, 21.0) },
Config.GangMenus = {}
