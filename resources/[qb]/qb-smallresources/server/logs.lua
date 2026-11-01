local Webhooks = {
    -- SET 26 Jul 2026. Only 'default' is filled deliberately: line 65 falls back to it for
    -- any log name whose own webhook is '', so this single entry catches all 38 types in
    -- one channel. Fill individual names below to split them out later.
    ['default'] = '',
    -- ─── Eclipse City job channels (AJ's webhooks, 12 Aug 2026) ──────────────
    -- A name MUST exist here or CreateLog refuses it outright ("Tried to call a
    -- log that isn't configured...") — `nil` is what the guard catches, unlike
    -- `''`, which is truthy and falls through to default. These have real URLs so
    -- each job posts to its own channel rather than the shared one.
    ['mining']      = '',
    ['removals']    = '',
    ['garbagejob']  = '',
    ['taxijob']     = '',
    ['trucker']     = '',
    ['fishing']     = '',
    ['vehicleshop'] = '',
    ['garage']      = '',
    ['testwebhook'] = '',
    ['playermoney'] = '',
    ['playerinventory'] = '',
    ['robbing'] = '',
    ['cuffing'] = '',
    ['drop'] = '',
    ['trunk'] = '',
    ['stash'] = '',
    ['glovebox'] = '',
    ['banking'] = '',
    -- (stock `['vehicleshop'] = ''` removed 12 Aug 2026 — it is set with a real URL
    -- in the Eclipse City block above. A DUPLICATE KEY IS NOT AN ERROR IN LUA: the
    -- later one silently wins, so leaving both here would have quietly sent the
    -- vehicle shop's logs to the default channel and looked like the webhook was
    -- wrong.)
    ['vehicleupgrades'] = '',
    ['shops'] = '',
    ['dealers'] = '',
    ['storerobbery'] = '',
    ['bankrobbery'] = '',
    ['powerplants'] = '',
    ['death'] = '',
    ['joinleave'] = '',
    ['ooc'] = '',
    ['report'] = '',
    ['me'] = '',
    ['pmelding'] = '',
    ['112'] = '',
    ['bans'] = '',
    ['anticheat'] = '',
    ['weather'] = '',
    ['moneysafes'] = '',
    ['bennys'] = '',
    ['bossmenu'] = '',
    ['robbery'] = '',
    ['casino'] = '',
    ['traphouse'] = '',
    ['911'] = '',
    ['palert'] = '',
    ['house'] = '',
    ['qbjobs'] = '',
}

local colors = { -- https://www.spycolor.com/
    ['default'] = 14423100,
    ['blue'] = 255,
    ['red'] = 16711680,
    ['green'] = 65280,
    ['white'] = 16777215,
    ['black'] = 0,
    ['orange'] = 16744192,
    ['yellow'] = 16776960,
    ['pink'] = 16761035,
    ['lightgreen'] = 65309,
}

local logQueue = {}
local queuedAt = {}   -- name -> os.time() the oldest unsent entry was queued

--- Post whatever is queued for `name` and clear it. Split out of the handler so
--- both the size trigger and the age trigger use one path.
local function flushQueue(name, tagEveryone)
    local q = logQueue[name]
    if not q or #q == 0 then return end

    local postData = { username = 'QB Logs', embeds = {} }
    if tagEveryone then postData.content = '@everyone' end
    for i = 1, #q do postData.embeds[#postData.embeds + 1] = q[i].data[1] end

    PerformHttpRequest(q[1].webhook, function() end, 'POST', json.encode(postData),
        { ['Content-Type'] = 'application/json' })
    logQueue[name] = {}
    queuedAt[name] = nil
end

--- ⚠ THE QUEUE HAD NO TIMER (found 12 Aug 2026, wiring ajd-mining into this).
--- `CreateLog` only posted once a name had **10** entries, so any low-volume
--- category — admin actions, level-ups, anything rare — sat in memory and NEVER
--- POSTED, and was lost outright at the next restart. That silently applied to
--- every one of the 38 log names on this box, not just the new ones: a channel
--- that logs one event an hour was effectively switched off.
---
--- Anything waiting longer than this goes out on its own.
local FLUSH_SECONDS = 30

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for name, at in pairs(queuedAt) do
            if now - at >= FLUSH_SECONDS then flushQueue(name, false) end
        end
    end
end)

--- Send anything still queued before the process goes away, so a restart does not
--- eat the last few events of a session.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for name in pairs(logQueue) do flushQueue(name, false) end
end)

RegisterNetEvent('qb-log:server:CreateLog', function(name, title, color, message, tagEveryone, imageUrl)
    local tag = tagEveryone or false

    if Config.Logging == 'discord' then
        if not Webhooks[name] then
            print('Tried to call a log that isn\'t configured with the name of ' .. name)
            return
        end
        local webHook = Webhooks[name] ~= '' and Webhooks[name] or Webhooks['default']
        local embedData = {
            {
                ['title'] = title,
                ['color'] = colors[color] or colors['default'],
                ['footer'] = {
                    ['text'] = os.date('%c'),
                },
                ['description'] = message,
                ['author'] = {
                    ['name'] = 'QBCore Logs',
                    ['icon_url'] = 'https://raw.githubusercontent.com/GhzGarage/qb-media-kit/main/Display%20Pictures/Logo%20-%20Display%20Picture%20-%20Stylized%20-%20Red.png',
                },
                ['image'] = imageUrl and imageUrl ~= '' and { ['url'] = imageUrl } or nil,
            }
        }

        if not logQueue[name] then logQueue[name] = {} end
        logQueue[name][#logQueue[name] + 1] = { webhook = webHook, data = embedData }
        if not queuedAt[name] then queuedAt[name] = os.time() end

        -- Full: send now. Otherwise the age sweep above will take it within
        -- FLUSH_SECONDS. Both paths go through flushQueue so the queue and its
        -- timestamp can never get out of step — the size branch used to clear
        -- `logQueue` inline, which is how a stale `queuedAt` would have leaked.
        if #logQueue[name] >= 10 then
            flushQueue(name, tag)
        end
    elseif Config.Logging == 'fivemanage' then
        local FiveManageAPIKey = GetConvar('FIVEMANAGE_LOGS_API_KEY', 'false')
        if FiveManageAPIKey == 'false' then
            print('You need to set the FiveManage API key in your server.cfg')
            return
        end
        local extraData = {
            level = tagEveryone and 'warn' or 'info', -- info, warn, error or debug
            message = title,                          -- any string
            metadata = {                              -- a table or object with any properties you want
                description = message,
                playerId = source,
                playerLicense = GetPlayerIdentifierByType(source, 'license'),
                playerDiscord = GetPlayerIdentifierByType(source, 'discord')
            },
            resource = GetInvokingResource(),
        }
        PerformHttpRequest('https://api.fivemanage.com/api/logs', function(statusCode, response, headers)
            -- Uncomment the following line to enable debugging
            -- print(statusCode, response, json.encode(headers))
        end, 'POST', json.encode(extraData), {
            ['Authorization'] = FiveManageAPIKey,
            ['Content-Type'] = 'application/json',
        })
    end
end)

Citizen.CreateThread(function()
    local timer = 0
    while true do
        Wait(1000)
        timer = timer + 1
        if timer >= 60 then -- If 60 seconds have passed, post the logs
            timer = 0
            for name, queue in pairs(logQueue) do
                if #queue > 0 then
                    local postData = { username = 'QB Logs', embeds = {} }
                    for i = 1, #queue do
                        postData.embeds[#postData.embeds + 1] = queue[i].data[1]
                    end
                    PerformHttpRequest(queue[1].webhook, function() end, 'POST', json.encode(postData), { ['Content-Type'] = 'application/json' })
                    logQueue[name] = {}
                end
            end
        end
    end
end)

QBCore.Commands.Add('testwebhook', 'Test Your Discord Webhook For Logs (God Only)', {}, false, function()
    TriggerEvent('qb-log:server:CreateLog', 'testwebhook', 'Test Webhook', 'default', 'Webhook setup successfully')
end, 'god')
