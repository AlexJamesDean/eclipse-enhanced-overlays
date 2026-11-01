local coreResource = Config.Core == "qbx_core" and "qb-core" or Config.Core
QBCore = exports[coreResource]:GetCoreObject()
PlayerData = {}
local firstOpenSynced = false

-- Functions
local function setupMenu()
	PlayerData = QBCore.Functions.GetPlayerData()
	local resources = lib.callback.await('ps-adminmenu:callback:GetResources', false)
	local commands = lib.callback.await('ps-adminmenu:callback:GetCommands', false)

	-- ECLIPSE CITY (ajd, 8 Aug 2026): filter the action list by the caller's tier
	-- before it reaches the NUI. Upstream sent Config.Actions in full to everyone,
	-- so any action tiered above the viewer rendered as a button that silently did
	-- nothing when clicked — which is exactly why the 7 Aug partial-tiering attempt
	-- was reverted. Tier the action AND hide it, or don't tier it at all.
	-- This is COSMETIC ONLY. Every action is still enforced server-side by
	-- CheckPerms, so a modified client that unhides a button gains nothing.
	local myTier
	for attempt = 1, 5 do
		local ok, result = pcall(lib.callback.await, 'ps-adminmenu:callback:GetMyTier', false)
		if ok and result ~= nil then
			myTier = result
			break
		end
		Wait(attempt * 150)
	end

	-- nil means the callback was unavailable/failed, not "no permissions" (the
	-- server returns the explicit string `none` for that). Never replace a valid
	-- menu with an empty action table because of a transient restart race.
	if myTier == nil then
		print('[ps-adminmenu] setup aborted: GetMyTier did not answer')
		return false
	end

	local TIER_RANK = { mod = 1, admin = 2, god = 3 }
	local myRank = TIER_RANK[myTier] or 0
	local visibleActions = {}
	for key, action in pairs(Config.Actions) do
		if myRank >= (TIER_RANK[action.perms] or 1) then
			visibleActions[key] = action
		end
	end

	GetData()
	SendNUIMessage({
		action = "setupUI",
		data = {
			actions = visibleActions,
			resources = resources,
			playerData = PlayerData,
			commands = commands
		}
	})
	return true
end

-- Event Handlers
-- ECLIPSE CITY FIX (7 Aug 2026): upstream used a bare AddEventHandler here, but
-- QBCore:Client:OnPlayerLoaded arrives over the wire from qb-core's server
-- (server/events.lua). Net-safety is registered PER RESOURCE, so qb-core's own
-- RegisterNetEvent does nothing for us — without this line the client threw
-- "event QBCore:Client:OnPlayerLoaded was not safe for net" and setupMenu()
-- never ran on login, leaving the menu with no actions, resources or commands
-- until the resource itself restarted.
RegisterNetEvent("QBCore:Client:OnPlayerLoaded")
AddEventHandler("QBCore:Client:OnPlayerLoaded", function()
	firstOpenSynced = false
	setupMenu()
end)

AddEventHandler("onResourceStart", function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		-- The page has no upstream ready handshake. This best-effort warm-up may
		-- arrive before CEF is listening, so the first actual open resends below.
		Wait(500)
		setupMenu()
	end
end)

-- NUICallbacks
RegisterNUICallback("hideUI", function()
	ToggleUI(false)
end)

RegisterNUICallback("clickButton", function(data)
	local selectedData = data.selectedData
	local key = data.data
	local data = CheckDataFromKey(key)
	if not data then return end

	if data.type == "client" then
		TriggerServerEvent('ps-adminmenu:server:ValidateClientAction', key, selectedData, data.event, data.perms)
	elseif data.type == "server" then
		TriggerServerEvent(data.event, key, selectedData)
	elseif data.type == "command" then
		ExecuteCommand(data.event)
	end

	-- In-world tools need camera/keyboard input as soon as they start. Keeping the
	-- full-focus NUI open makes laser, noclip, spectate, etc. appear broken even
	-- though their event fired successfully. Only actions explicitly marked in
	-- config close; ordinary admin actions keep the menu open for batch work.
	if data.closeOnUse == true then
		ToggleUI(false)
	end

	Log("Action Used: " .. key,
            PlayerData.name ..
            " (" ..
            PlayerData.citizenid ..
            ") - Used: " .. key .. (selectedData and (" with args: " .. json.encode(selectedData)) or ""))
end)

-- Open UI Event
RegisterNetEvent('ps-adminmenu:client:OpenUI', function()
	-- A fixed startup delay is not proof the NUI bundle is ready. Sending setup on
	-- the first real open guarantees a listening page and repairs empty menus after
	-- a hot restart without polling or rebuilding the minified Svelte bundle.
	if not firstOpenSynced then
		if not setupMenu() then
			QBCore.Functions.Notify('Admin menu is still loading; try again', 'error', 3000)
			return
		end
		firstOpenSynced = true
	end
	ToggleUI(true)
end)

-- Close UI Event
RegisterNetEvent('ps-adminmenu:client:CloseUI', function()
	ToggleUI(false)
end)

-- Change resource state
RegisterNUICallback("setResourceState", function(data, cb)
	local resources = lib.callback.await('ps-adminmenu:callback:ChangeResourceState', false, data)
	cb(resources)
end)

-- Get players
RegisterNUICallback("getPlayers", function(data, cb)
	local players = lib.callback.await('ps-adminmenu:callback:GetPlayers', false)
	cb(players)
end)
