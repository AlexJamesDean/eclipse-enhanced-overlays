local QBCore = exports['qb-core']:GetCoreObject({ 'Functions', 'Commands' })

-- Eclipse City (16 Aug 2026): gang menu locations are placed in game with
-- /setgangmenu and persisted in resource KVP — the config table shipped five
-- unreachable vector3(0,0,0) placeholders and editing it needed a restart per gang.
local GangMenuOverrides = (function()
	local raw = GetResourceKvpString('gangmenus')
	if not raw or raw == '' then return {} end
	local ok, decoded = pcall(json.decode, raw)
	return (ok and type(decoded) == 'table') and decoded or {}
end)()

local function saveGangMenuOverrides()
	SetResourceKvp('gangmenus', json.encode(GangMenuOverrides))
end

function GangMenuCoords(gangName)
	local out = {}
	for _, c in ipairs((Config.GangMenus or {})[gangName] or {}) do
		out[#out + 1] = c
	end
	local o = GangMenuOverrides[gangName]
	if o then out[#out + 1] = vector3(o.x, o.y, o.z) end
	return out
end

local function gangMenuWirePayload()
	local out = {}
	for gang, list in pairs(Config.GangMenus or {}) do
		out[gang] = {}
		for i, c in ipairs(list) do out[gang][i] = { x = c.x, y = c.y, z = c.z } end
	end
	for gang, o in pairs(GangMenuOverrides) do
		out[gang] = out[gang] or {}
		out[gang][#out[gang] + 1] = { x = o.x, y = o.y, z = o.z }
	end
	return out
end

RegisterNetEvent('qb-management:server:requestGangMenus', function()
	TriggerClientEvent('qb-management:client:setGangMenus', source, gangMenuWirePayload())
end)

QBCore.Commands.Add('setgangmenu', 'Place or clear a gang boss menu at your position (Admin Only)', {
	{ name = 'gang', help = 'gang name from shared gangs' },
	{ name = 'clear', help = 'optional: "clear" removes it' },
}, true, function(source, args)
	local gangName = args[1] and args[1]:lower()
	local gangs = exports['qb-core']:GetShared('Gangs')
	if not gangName or not gangs[gangName] or gangName == 'none' then
		TriggerClientEvent('QBCore:Notify', source, 'Unknown gang. Use a name from shared gangs.', 'error')
		return
	end

	if args[2] and args[2]:lower() == 'clear' then
		GangMenuOverrides[gangName] = nil
		saveGangMenuOverrides()
		TriggerClientEvent('qb-management:client:setGangMenus', -1, gangMenuWirePayload())
		TriggerClientEvent('QBCore:Notify', source, ('Gang menu for %s cleared.'):format(gangs[gangName].label), 'success')
		return
	end

	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then return end
	local c = GetEntityCoords(ped)
	GangMenuOverrides[gangName] = { x = c.x, y = c.y, z = c.z }
	saveGangMenuOverrides()
	TriggerClientEvent('qb-management:client:setGangMenus', -1, gangMenuWirePayload())
	TriggerClientEvent('QBCore:Notify', source, ('Gang menu for %s placed here.'):format(gangs[gangName].label), 'success')
end, 'admin')

-- Get Employees
QBCore.Functions.CreateCallback('qb-gangmenu:server:GetEmployees', function(source, cb, gangname)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)

	if not Player.PlayerData.gang.isboss then
		ExploitBan(src, 'GetEmployees Exploiting')
		return
	end

	local employees = {}
	-- The gang name comes from the boss's own server-side record, never the wire;
	-- the old version concatenated the client argument straight into a LIKE.
	local gangName = Player.PlayerData.gang.name
	local players = MySQL.query.await("SELECT * FROM `players` WHERE JSON_UNQUOTE(JSON_EXTRACT(`gang`, '$.name')) = ?", { gangName })
	if players[1] ~= nil then
		for _, value in pairs(players) do
			local Target = QBCore.Functions.GetPlayerByCitizenId(value.citizenid) or QBCore.Functions.GetOfflinePlayerByCitizenId(value.citizenid)

			if Target then
				local isOnline = Target.PlayerData.source
				employees[#employees + 1] = {
					empSource = Target.PlayerData.citizenid,
					grade = Target.PlayerData.gang.grade,
					isboss = Target.PlayerData.gang.isboss,
					name = (isOnline and '🟢 ' or '❌ ') .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname
				}
			end
		end
	end
	cb(employees)
end)

RegisterNetEvent('qb-gangmenu:server:stash', function()
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if not Player then return end
	local playerGang = Player.PlayerData.gang
	if not playerGang.isboss then return end
	local playerPed = GetPlayerPed(src)
	local playerCoords = GetEntityCoords(playerPed)
	local bossCoords = GangMenuCoords(playerGang.name)
	if #bossCoords == 0 then return end
	for i = 1, #bossCoords do
		local coords = bossCoords[i]
		if #(playerCoords - coords) < 2.5 then
			local stashName = 'boss_' .. playerGang.name
			exports['qb-inventory']:OpenInventory(src, stashName, {
				maxweight = 4000000,
				slots = 25,
			})
			return
		end
	end
end)

-- Grade Change
RegisterNetEvent('qb-gangmenu:server:GradeUpdate', function(data)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	local Employee = QBCore.Functions.GetPlayerByCitizenId(data.cid) or QBCore.Functions.GetOfflinePlayerByCitizenId(data.cid)

	if not Player.PlayerData.gang.isboss then
		ExploitBan(src, 'GradeUpdate Exploiting')
		return
	end
	if data.grade > Player.PlayerData.gang.grade.level then
		TriggerClientEvent('QBCore:Notify', src, 'You cannot promote to this rank!', 'error')
		return
	end

	if Employee then
		if Employee.Functions.SetGang(Player.PlayerData.gang.name, data.grade) then
			TriggerClientEvent('QBCore:Notify', src, 'Successfully promoted!', 'success')
			Employee.Functions.Save()

			if Employee.PlayerData.source then
				TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, 'You have been promoted to ' .. data.gradename .. '.', 'success')
			end
		else
			TriggerClientEvent('QBCore:Notify', src, 'Grade does not exist.', 'error')
		end
	end
	TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
end)

-- Fire Member
RegisterNetEvent('qb-gangmenu:server:FireMember', function(target)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	local Employee = QBCore.Functions.GetPlayerByCitizenId(target) or QBCore.Functions.GetOfflinePlayerByCitizenId(target)

	if not Player.PlayerData.gang.isboss then
		ExploitBan(src, 'FireEmployee Exploiting')
		return
	end

	if Employee then
		if target == Player.PlayerData.citizenid then
			TriggerClientEvent('QBCore:Notify', src, 'You can\'t kick yourself out of the gang!', 'error')
			return
		elseif Employee.PlayerData.gang.grade.level > Player.PlayerData.gang.grade.level then
			TriggerClientEvent('QBCore:Notify', src, 'You cannot fire this citizen!', 'error')
			return
		end
		if Employee.Functions.SetGang('none', '0') then
			Employee.Functions.Save()
			TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Gang Fire', 'orange', Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. ' ' .. Employee.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.gang.name .. ')', false)
			TriggerClientEvent('QBCore:Notify', src, 'Gang Member fired!', 'success')

			if Employee.PlayerData.source then -- Player is online
				TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, 'You have been expelled from the gang!', 'error')
			end
		else
			TriggerClientEvent('QBCore:Notify', src, 'Error.', 'error')
		end
	end
	TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
end)

-- Recruit Player
RegisterNetEvent('qb-gangmenu:server:HireMember', function(recruit)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	local Target = exports['qb-core']:GetPlayer(recruit)

	if not Player.PlayerData.gang.isboss then
		ExploitBan(src, 'HireEmployee Exploiting')
		return
	end

	if Target and Target.Functions.SetGang(Player.PlayerData.gang.name, 0) then
		TriggerClientEvent('QBCore:Notify', src, 'You hired ' .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' come ' .. Player.PlayerData.gang.label .. '', 'success')
		TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, 'You have been hired as ' .. Player.PlayerData.gang.label .. '', 'success')
		TriggerEvent('qb-log:server:CreateLog', 'gangmenu', 'Recruit', 'yellow', (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) .. ' successfully recruited ' .. Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname .. ' (' .. Player.PlayerData.gang.name .. ')', false)
	end
	TriggerClientEvent('qb-gangmenu:client:OpenMenu', src)
end)

-- Get closest player sv
QBCore.Functions.CreateCallback('qb-gangmenu:getplayers', function(source, cb)
	local src = source
	local players = {}
	local PlayerPed = GetPlayerPed(src)
	local pCoords = GetEntityCoords(PlayerPed)
	for _, v in pairs(QBCore.Functions.GetPlayers()) do
		local targetped = GetPlayerPed(v)
		local tCoords = GetEntityCoords(targetped)
		local dist = #(pCoords - tCoords)
		if PlayerPed ~= targetped and dist < 10 then
			local ped = exports['qb-core']:GetPlayer(v)
			players[#players + 1] = {
				id = v,
				coords = GetEntityCoords(targetped),
				name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
				citizenid = ped.PlayerData.citizenid,
				sources = GetPlayerPed(ped.PlayerData.source),
				sourceplayer = ped.PlayerData.source
			}
		end
	end
	table.sort(players, function(a, b)
		return a.name < b.name
	end)
	cb(players)
end)
