Config = {}

-- priority list can be any identifier. (hex steamid, steamid32, ip) Integer = power over other people with priority
-- a lot of the steamid converting websites are broken rn and give you the wrong steamid. I use https://steamid.xyz/ with no problems.
-- you can also give priority through the API, read the examples/readme.
Config.Priority = {
    ["STEAM_0:1:0000####"] = 1,
    ["steam:110000######"] = 25,
    ["ip:127.0.0.0"] = 85
}

-- require people to run steam
Config.RequireSteam = false

-- "whitelist" only server
Config.PriorityOnly = false

-- disables hardcap, should keep this true
Config.DisableHardCap = true

-- will remove players from connecting if they don't load within: __ seconds; May need to increase this if you have a lot of downloads.
-- i have yet to find an easy way to determine whether they are still connecting and downloading content or are hanging in the loadscreen.
-- This may cause session provider errors if it is too low because the removed player may still be connecting, and will let the next person through...
-- even if the server is full. 10 minutes should be enough
Config.ConnectTimeOut = 1140

-- will remove players from queue if the server doesn't recieve a message from them within: __ seconds
Config.QueueTimeOut = 90

-- will give players temporary priority when they disconnect and when they start loading in
Config.EnableGrace = false

-- how much priority power grace time will give
Config.GracePower = 5

-- how long grace time lasts in seconds
Config.GraceTime = 480

Config.AntiSpam = false
Config.AntiSpamTimer = 30
Config.PleaseWait = "Please wait %f seconds. The connection will start automatically!"

-- Optional Discord prompt shown before the queue starts. This is deliberately not a
-- whitelist or acknowledgement gate: players can continue immediately and the card
-- advances on its own after the timeout.
Config.WelcomeCard = {
    Enabled = true,
    AutoContinueSeconds = 12,
    RepresentIntervalMs = 750,
    DiscordUrl = "https://discord.gg/77hYewHXgX",
    -- Caps vs sentence case is the ONLY way to rank these two buttons: an
    -- Adaptive Card action has no weight or colour, and Action.style needs 1.2.
    DiscordLabel = "JOIN DISCORD - CLAIM WELCOME PACK",
    ContinueLabel = ("Continue to " .. AJD_CITY.name),
    Title = ("WELCOME TO " .. AJD_CITY.name:upper()),
    Subtitle = "Open city. No whitelist.",
    Message = "Join our Discord, run /link there for a code, then type that code into /discord in game to claim your welcome pack:",
    Benefits = {
        { title = "WELCOME CASH", value = "£50,000" },
        { title = "LOST & FOUND", value = "5 boxes" },
        { title = "STARTER VEHICLE", value = "Included" },
        { title = "SUPPORT", value = "Almost 24/7 from an active developer" },
    },
}

-- on resource start, players can join the queue but will not let them join for __ milliseconds
-- this will let the queue settle and lets other resources finish initializing
Config.JoinDelay = 30000

-- will show how many people have temporary priority in the connection message
Config.ShowTemp = false

-- simple localization
Config.Language = {
    joining = "\xF0\x9F\x8E\x89Joining... [ENHANCED client only - Legacy FiveM will hang here! Get it at fivem.net]",
    connecting = "\xE2\x8F\xB3Connecting... [ENHANCED client only - Legacy FiveM will hang here! Get it at fivem.net]",
    idrr = "\xE2\x9D\x97[Queue] Error: Couldn't retrieve any of your id's, try restarting.",
    err = "\xE2\x9D\x97[Queue] There was an error",
    pos = "\xF0\x9F\x90\x8CYou are %d/%d in queue \xF0\x9F\x95\x9C%s",
    connectingerr = "\xE2\x9D\x97[Queue] Error: Error adding you to connecting list",
    timedout = "\xE2\x9D\x97[Queue] Error: Timed out?",
    wlonly = "\xE2\x9D\x97[Queue] You must be whitelisted to join this server",
    steam = "\xE2\x9D\x97 [Queue] Error: Steam must be running"
}
