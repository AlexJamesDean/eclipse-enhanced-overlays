local PlayerInjuries = {}
local PlayerWeaponWounds = {}
local QBCore = exports['qb-core']:GetCoreObject({ 'Functions', 'Commands' })
local sharedItems = exports['qb-core']:GetShared('Items')
local doctorCount = 0
local doctorCalled = false
local Doctors = {}
local pendingDefibrillations = {}

local function notify(src, message, kind)
	TriggerClientEvent('QBCore:Notify', src, message, kind or 'primary')
end

local function playersWithinDistance(sourceId, targetId, maximum)
	local sourcePed = GetPlayerPed(sourceId)
	local targetPed = GetPlayerPed(targetId)
	if sourcePed <= 0 or targetPed <= 0 then return false end
	return #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) <= maximum
end

local function patientHasActiveDefibrillation(targetId)
	local now = GetGameTimer()
	for helper, pending in pairs(pendingDefibrillations) do
		if now > pending.expiresAt then
			pendingDefibrillations[helper] = nil
		elseif pending.target == targetId then
			return true
		end
	end
	return false
end

-- Events

-- Compatibility with txAdmin Menu's heal options.
-- This is an admin only server side event that will pass the target player id or -1.
AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
	if GetInvokingResource() ~= 'monitor' or type(eventData) ~= 'table' or type(eventData.id) ~= 'number' then
		return
	end

	TriggerClientEvent('hospital:client:Revive', eventData.id)
	TriggerClientEvent('hospital:client:HealInjuries', eventData.id, 'full')
end)

RegisterNetEvent('hospital:server:SendToBed', function(bedId, isRevive, hospitalIndex)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	TriggerClientEvent('hospital:client:SendToBed', src, bedId, Config.Locations['hospital'][hospitalIndex]['beds'][bedId], isRevive)
	TriggerClientEvent('hospital:client:SetBed', -1, bedId, true, hospitalIndex)
	Player.RemoveMoney('bank', Config.BillCost, 'respawned-at-hospital')
	exports['qb-banking']:AddMoney('ambulance', Config.BillCost, 'Player treatment')
	TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost, Config.Locations['hospital'][hospitalIndex]['name'])
end)

RegisterNetEvent('hospital:server:RespawnAtHospital', function(hospitalIndex)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if not Player then return end

	local metadata = Player.PlayerData.metadata or {}
	if metadata['isdead'] ~= true or metadata['inlaststand'] == true then return end
	local windowEnd = tonumber(metadata['defibwindowend']) or 0
	if windowEnd > os.time() then
		notify(src, ('Hospital transfer is available in %d seconds.'):format(windowEnd - os.time()), 'error')
		return
	end
	if patientHasActiveDefibrillation(src) then
		notify(src, 'Defibrillation is in progress. Wait for the result.', 'primary')
		return
	end

	-- ajd 31 Jul 2026 — this server has no hospital interior, so every bed in
	-- Config.Locations (353.1/-584.6/43.11 and friends) sits inside solid building
	-- geometry: bleeding out teleported players into the shell. ajd-hospital owns
	-- the replacement (stood up on the Pillbox forecourt, then charged once the
	-- client acknowledges a successful transfer). Its
	-- reception zone is). Jail respawns are left on the stock path — Bolingbroke's
	-- beds are in a real interior. If ajd-hospital is stopped or its config is
	-- broken it returns false and the stock bed code below runs unchanged.
	if (Player.PlayerData.metadata['injail'] or 0) <= 0 and GetResourceState('ajd-hospital') == 'started' then
		local ok, handled = pcall(function() return exports['ajd-hospital']:RespawnOutside(src) end)
		if ok and handled then return end
	end

	if Player.PlayerData.metadata['injail'] > 0 then
		for i = 1, #Config.Locations['jailbeds'] do
			local v = Config.Locations['jailbeds'][i]
			if not v.taken then
				TriggerClientEvent('hospital:client:SendToBed', src, i, v, true)
				TriggerClientEvent('hospital:client:SetBed2', -1, i, true)
				if Config.WipeInventoryOnRespawn then
					Player.ClearInventory()
					MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
					TriggerClientEvent('QBCore:Notify', src, Lang:t('error.possessions_taken'), 'error')
				end
				Player.RemoveMoney('bank', Config.BillCost, 'respawned-at-hospital')
				exports['qb-banking']:AddMoney('ambulance', Config.BillCost, 'Player treatment')
				TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost)
				return
			end
		end

		TriggerClientEvent('hospital:client:SendToBed', src, 1, Config.Locations['jailbeds'][1], true)
		TriggerClientEvent('hospital:client:SetBed', -1, 1, true)
		if Config.WipeInventoryOnRespawn then
			Player.ClearInventory()
			MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.possessions_taken'), 'error')
		end
		Player.RemoveMoney('bank', Config.BillCost, 'respawned-at-hospital')
		exports['qb-banking']:AddMoney('ambulance', Config.BillCost, 'Player treatment')
		TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost)
	else
		for i = 1, #Config.Locations['hospital'][hospitalIndex]['beds'] do
			local v = Config.Locations['hospital'][hospitalIndex]['beds'][i]
			if not v.taken then
				TriggerClientEvent('hospital:client:SendToBed', src, i, v, true)
				TriggerClientEvent('hospital:client:SetBed', -1, i, true, hospitalIndex)
				if Config.WipeInventoryOnRespawn then
					Player.ClearInventory()
					MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
					TriggerClientEvent('QBCore:Notify', src, Lang:t('error.possessions_taken'), 'error')
				end
				Player.RemoveMoney('bank', Config.BillCost, 'respawned-at-hospital')
				exports['qb-banking']:AddMoney('ambulance', Config.BillCost, 'Player treatment')
				TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost, Config.Locations['hospital'][hospitalIndex]['name'])
				return
			end
		end
		-- All beds were full, placing in first bed as fallback
		TriggerClientEvent('hospital:client:SendToBed', src, 1, Config.Locations['hospital'][hospitalIndex]['beds'][1], true)
		TriggerClientEvent('hospital:client:SetBed', -1, 1, true, hospitalIndex)
		if Config.WipeInventoryOnRespawn then
			Player.ClearInventory()
			MySQL.update('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.possessions_taken'), 'error')
		end
		Player.RemoveMoney('bank', Config.BillCost, 'respawned-at-hospital')
		exports['qb-banking']:AddMoney('ambulance', Config.BillCost, 'Player treatment')
		TriggerClientEvent('hospital:client:SendBillEmail', src, Config.BillCost, Config.Locations['hospital'][hospitalIndex]['name'])
	end
end)

RegisterNetEvent('hospital:server:ambulanceAlert', function(text)
	local src = source
	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	local players = QBCore.Functions.GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
			TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, text)
		end
	end
end)

RegisterNetEvent('hospital:server:LeaveBed', function(id, hospitalIndex)
	TriggerClientEvent('hospital:client:SetBed', -1, id, false, hospitalIndex)
end)

RegisterNetEvent('hospital:server:SyncInjuries', function(data)
	local src = source
	PlayerInjuries[src] = data
end)

RegisterNetEvent('hospital:server:SetWeaponDamage', function(data)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player then
		PlayerWeaponWounds[Player.PlayerData.source] = data
	end
end)

RegisterNetEvent('hospital:server:RestoreWeaponDamage', function()
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	PlayerWeaponWounds[Player.PlayerData.source] = nil
end)

RegisterNetEvent('hospital:server:SetDeathStatus', function(isDead)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player then
		local metadata = Player.PlayerData.metadata or {}
		local wasDead = metadata['isdead'] == true
		if isDead and not wasDead then
			Player.SetMetaData('defibattempted', false)
			Player.SetMetaData('defibwindowend', os.time() + (Config.DeathTime or 90))
			TriggerClientEvent('hospital:client:SetDefibAttempted', src, false)
		elseif isDead then
			-- Rehydrate a full-death episode after reconnect/resource restart without
			-- granting another attempt. Older active episodes may not yet have a window.
			local windowEnd = tonumber(metadata['defibwindowend']) or 0
			if windowEnd <= 0 then
				windowEnd = os.time() + (Config.DeathTime or 90)
				Player.SetMetaData('defibwindowend', windowEnd)
			end
			TriggerClientEvent('hospital:client:SetDefibAttempted', src, metadata['defibattempted'] == true)
		elseif not isDead then
			Player.SetMetaData('defibattempted', false)
			Player.SetMetaData('defibwindowend', 0)
			TriggerClientEvent('hospital:client:SetDefibAttempted', src, false)
		end
		Player.SetMetaData('isdead', isDead)
	end
end)

RegisterNetEvent('hospital:server:BeginDefibrillation', function(targetId)
	local src = source
	targetId = tonumber(targetId)
	local config = Config.Defibrillator or {}
	local Player = exports['qb-core']:GetPlayer(src)
	local Patient = targetId and exports['qb-core']:GetPlayer(targetId)

	if not Player or not Patient or targetId == src then
		notify(src, 'No valid patient was found.', 'error')
		return
	end
	if pendingDefibrillations[src] then
		notify(src, 'You already have a defibrillation in progress.', 'error')
		return
	end
	if not QBCore.Functions.HasItem(src, config.item or 'defibrillator', 1) then
		notify(src, 'You need a defibrillator.', 'error')
		return
	end
	if not playersWithinDistance(src, targetId, config.maxDistance or 3.0) then
		notify(src, 'Move closer to the patient.', 'error')
		return
	end

	local metadata = Patient.PlayerData.metadata or {}
	if metadata['isdead'] ~= true or metadata['inlaststand'] == true then
		notify(src, 'A defibrillator can only be used during full death.', 'error')
		return
	end

	local windowEnd = tonumber(metadata['defibwindowend']) or 0
	if windowEnd <= os.time() then
		notify(src, 'The defibrillation window has closed.', 'error')
		return
	end
	if metadata['defibattempted'] == true then
		notify(src, 'Defibrillation has already been attempted on this patient.', 'error')
		return
	end

	-- Commit the patient-wide one-shot before revealing or performing the roll.
	-- This survives cancellation, another helper, and reconnects via metadata.
	Patient.SetMetaData('defibattempted', true)
	TriggerClientEvent('hospital:client:SetDefibAttempted', targetId, true)

	local now = GetGameTimer()
	local duration = config.duration or 10000
	pendingDefibrillations[src] = {
		target = targetId,
		windowEnd = windowEnd,
		startedAt = now,
		readyAt = now + math.floor(duration * (config.progressTolerance or 0.80)),
		expiresAt = now + duration + 15000,
		success = math.random(100) <= (config.successChance or 50),
	}

	notify(targetId, 'Someone is attempting defibrillation. Do not hospital-transfer yet.', 'primary')
	TriggerClientEvent('hospital:client:BeginDefibrillation', src, targetId)
end)

RegisterNetEvent('hospital:server:FinishDefibrillation', function(targetId)
	local src = source
	local pending = pendingDefibrillations[src]
	pendingDefibrillations[src] = nil
	targetId = tonumber(targetId)

	if not pending or pending.target ~= targetId then return end
	local now = GetGameTimer()
	if now < pending.readyAt or now > pending.expiresAt then
		notify(src, 'The defibrillation sequence was invalid. The attempt is spent.', 'error')
		return
	end

	local Patient = exports['qb-core']:GetPlayer(targetId)
	if not Patient then return end
	local metadata = Patient.PlayerData.metadata or {}
	if metadata['isdead'] ~= true or metadata['inlaststand'] == true
		or tonumber(metadata['defibwindowend']) ~= pending.windowEnd then
		return
	end
	if not playersWithinDistance(src, targetId, (Config.Defibrillator or {}).maxDistance or 3.0) then
		notify(src, 'You moved too far from the patient. The attempt failed.', 'error')
		return
	end

	if pending.success then
		TriggerClientEvent('hospital:client:Revive', targetId)
		TriggerClientEvent('hospital:client:DefibrillationResult', src, true)
	else
		TriggerClientEvent('hospital:client:DefibrillationResult', src, false)
		notify(targetId, 'The shock failed. Hospital transfer is your remaining option.', 'error')
	end
end)

RegisterNetEvent('hospital:server:CancelDefibrillation', function(targetId)
	local src = source
	local pending = pendingDefibrillations[src]
	if pending and pending.target == tonumber(targetId) then
		pendingDefibrillations[src] = nil
	end
end)

RegisterNetEvent('hospital:server:SetLaststandStatus', function(bool)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player then
		Player.SetMetaData('inlaststand', bool)
		if bool then
			Player.SetMetaData('laststandsince', os.time())
			Player.SetMetaData('isdead', false)
			Player.SetMetaData('defibattempted', false)
			Player.SetMetaData('defibwindowend', 0)
			TriggerClientEvent('hospital:client:SetDefibAttempted', src, false)
		end
	end
end)

-- A last stand only resumes at login within Config.LaststandResumeSeconds of when it
-- began; anything older (including pre-stamp legacy flags) is cleared here BEFORE the
-- client resync reads the metadata, so a stale flag can never collapse a healthy
-- character at spawn again.
RegisterNetEvent('QBCore:Server:PlayerLoaded', function(Player)
	local src = source
	Player = Player or exports['qb-core']:GetPlayer(src)
	if not Player then return end

	local metadata = Player.PlayerData.metadata or {}
	if metadata['inlaststand'] ~= true then return end

	local since = tonumber(metadata['laststandsince']) or 0
	local window = Config.LaststandResumeSeconds or 1800
	if since <= 0 or (os.time() - since) > window then
		-- PlayerLoaded is emitted by qb-core, so the Player metatable does not
		-- survive the cross-resource event. Functions contains bound methods.
		Player.Functions.SetMetaData('inlaststand', false)
		Player.Functions.SetMetaData('laststandsince', 0)
	end
end)

RegisterNetEvent('hospital:server:SetArmor', function(amount)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player then
		Player.SetMetaData('armor', amount)
	end
end)

RegisterNetEvent('hospital:server:TreatWounds', function(playerId)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	local Patient = exports['qb-core']:GetPlayer(playerId)
	if Patient then
		if Player.PlayerData.job.name == 'ambulance' then
			exports['qb-inventory']:RemoveItem(src, 'bandage', 1, false, 'hospital:server:TreatWounds')
			TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['bandage'], 'remove')
			TriggerClientEvent('hospital:client:HealInjuries', Patient.PlayerData.source, 'full')
		end
	end
end)

RegisterNetEvent('hospital:server:AddDoctor', function(job)
	if job == 'ambulance' then
		local src = source
		doctorCount = doctorCount + 1
		TriggerClientEvent('hospital:client:SetDoctorCount', -1, doctorCount)
		Doctors[src] = true
	end
end)

RegisterNetEvent('hospital:server:RemoveDoctor', function(job)
	if job == 'ambulance' then
		local src = source
		doctorCount = doctorCount - 1
		TriggerClientEvent('hospital:client:SetDoctorCount', -1, doctorCount)
		Doctors[src] = nil
	end
end)

AddEventHandler('playerDropped', function()
	local src = source
	pendingDefibrillations[src] = nil
	for helper, pending in pairs(pendingDefibrillations) do
		if pending.target == src then pendingDefibrillations[helper] = nil end
	end
	if Doctors[src] then
		doctorCount = doctorCount - 1
		TriggerClientEvent('hospital:client:SetDoctorCount', -1, doctorCount)
		Doctors[src] = nil
	end
end)

RegisterNetEvent('hospital:server:RevivePlayer', function(playerId, isOldMan)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	local Patient = exports['qb-core']:GetPlayer(playerId)
	local oldMan = isOldMan or false
	if Patient then
		if Player.PlayerData.job.name == 'ambulance' or QBCore.Functions.HasItem(src, 'firstaid', 1) then
			if oldMan then
				-- Cash first, then the bank. £5,000 in notes on you is rare here;
				-- the fee was effectively unpayable. Flattened player object —
				-- this file uses exports['qb-core']:GetPlayer, so the money
				-- methods are top-level rather than under .Functions.
				local money = Player.PlayerData.money or {}
				local paid = false
				if (money.cash or 0) >= 5000 then
					paid = Player.RemoveMoney('cash', 5000, 'revived-player') and true or false
				end
				if not paid and (money.bank or 0) >= 5000 then
					paid = Player.RemoveMoney('bank', 5000, 'revived-player') and true or false
				end
				if paid then
					exports['qb-inventory']:RemoveItem(src, 'firstaid', 1, false, 'hospital:server:RevivePlayer')
					TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['firstaid'], 'remove')
					TriggerClientEvent('hospital:client:Revive', Patient.PlayerData.source)
				else
					TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_enough_money'), 'error')
				end
			else
				exports['qb-inventory']:RemoveItem(src, 'firstaid', 1, false, 'hospital:server:RevivePlayer')
				TriggerClientEvent('qb-inventory:client:ItemBox', src, sharedItems['firstaid'], 'remove')
				TriggerClientEvent('hospital:client:Revive', Patient.PlayerData.source)
			end
		else
			-- Eclipse City (16 Aug 2026): this used to PERMABAN + drop. The client
			-- pre-checks the firstaid item, but a 5-60s progress bar sits between that
			-- check and this validation, so an item consumed or desynced in the window
			-- banned an innocent player. Reject and log instead.
			notify(src, 'You need a first aid kit to do that.', 'error')
			TriggerEvent('qb-log:server:CreateLog', 'ambulancejob', 'Revive rejected', 'orange', string.format('%s (%s) tried RevivePlayer without EMS job or a firstaid item', GetPlayerName(src) or '?', QBCore.Functions.GetIdentifier(src, 'license') or '?'), false)
		end
	end
end)

RegisterNetEvent('hospital:server:SendDoctorAlert', function(hospitalName)
	local src = source
	if not doctorCalled then
		doctorCalled = true
		local players = QBCore.Functions.GetQBPlayers()
		for _, v in pairs(players) do
			if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
				TriggerClientEvent('QBCore:Notify', v.PlayerData.source, Lang:t('info.dr_needed', { hospital = hospitalName }), 'ambulance')
			end
		end
		SetTimeout(Config.DocCooldown * 60000, function()
			doctorCalled = false
		end)
	else
		TriggerClientEvent('QBCore:Notify', src, 'Doctor has already been notified', 'error')
	end
end)

RegisterNetEvent('hospital:server:UseFirstAid', function(targetId)
	local src = source
	local Target = exports['qb-core']:GetPlayer(targetId)
	if Target then
		TriggerClientEvent('hospital:client:CanHelp', targetId, src)
	end
end)

RegisterNetEvent('hospital:server:CanHelp', function(helperId, canHelp)
	local src = source
	if canHelp then
		TriggerClientEvent('hospital:client:HelpPerson', helperId, src)
	else
		TriggerClientEvent('QBCore:Notify', helperId, Lang:t('error.cant_help'), 'error')
	end
end)

RegisterNetEvent('hospital:server:removeBandage', function()
	local Player = exports['qb-core']:GetPlayer(source)
	if not Player then return end
	exports['qb-inventory']:RemoveItem(source, 'bandage', 1, false, 'hospital:server:removeBandage')
end)

RegisterNetEvent('hospital:server:removeIfaks', function()
	local Player = exports['qb-core']:GetPlayer(source)
	if not Player then return end
	exports['qb-inventory']:RemoveItem(source, 'ifaks', 1, false, 'hospital:server:removeIfaks')
end)

RegisterNetEvent('hospital:server:removePainkillers', function()
	local Player = exports['qb-core']:GetPlayer(source)
	if not Player then return end
	exports['qb-inventory']:RemoveItem(source, 'painkillers', 1, false, 'hospital:server:removePainkillers')
end)

RegisterNetEvent('hospital:server:resetHungerThirst', function()
	local Player = exports['qb-core']:GetPlayer(source)

	if not Player then return end

	Player.SetMetaData('hunger', 100)
	Player.SetMetaData('thirst', 100)

	TriggerClientEvent('hud:client:UpdateNeeds', source, 100, 100)
end)

RegisterNetEvent('qb-ambulancejob:server:stash', function()
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if not Player then return end
	local citizenId = Player.PlayerData.citizenid
	local stashName = 'ambulancestash_' .. citizenId
	exports['qb-inventory']:OpenInventory(src, stashName)
end)

-- Callbacks

QBCore.Functions.CreateCallback('hospital:GetDoctors', function(_, cb)
	local amount = 0
	local players = QBCore.Functions.GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
			amount = amount + 1
		end
	end
	cb(amount)
end)

QBCore.Functions.CreateCallback('hospital:GetPlayerStatus', function(_, cb, playerId)
	local Player = exports['qb-core']:GetPlayer(playerId)
	local injuries = {}
	injuries['WEAPONWOUNDS'] = {}
	if Player then
		if PlayerInjuries[Player.PlayerData.source] then
			if (PlayerInjuries[Player.PlayerData.source].isBleeding > 0) then
				injuries['BLEED'] = PlayerInjuries[Player.PlayerData.source].isBleeding
			end
			for k, _ in pairs(PlayerInjuries[Player.PlayerData.source].limbs) do
				if PlayerInjuries[Player.PlayerData.source].limbs[k].isDamaged then
					injuries[k] = PlayerInjuries[Player.PlayerData.source].limbs[k]
				end
			end
		end
		if PlayerWeaponWounds[Player.PlayerData.source] then
			for k, v in pairs(PlayerWeaponWounds[Player.PlayerData.source]) do
				injuries['WEAPONWOUNDS'][k] = v
			end
		end
	end
	cb(injuries)
end)

QBCore.Functions.CreateCallback('hospital:GetPlayerBleeding', function(source, cb)
	local src = source
	if PlayerInjuries[src] and PlayerInjuries[src].isBleeding then
		cb(PlayerInjuries[src].isBleeding)
	else
		cb(nil)
	end
end)

-- Commands

QBCore.Commands.Add('911e', Lang:t('info.ems_report'), { { name = 'message', help = Lang:t('info.message_sent') } }, false, function(source, args)
	local src = source
	local message
	if args[1] then message = table.concat(args, ' ') else message = Lang:t('info.civ_call') end
	local ped = GetPlayerPed(src)
	local coords = GetEntityCoords(ped)
	local players = QBCore.Functions.GetQBPlayers()
	for _, v in pairs(players) do
		if v.PlayerData.job.name == 'ambulance' and v.PlayerData.job.onduty then
			TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, message)
		end
	end
end)

QBCore.Commands.Add('status', Lang:t('info.check_health'), {}, false, function(source, _)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player.PlayerData.job.name == 'ambulance' then
		TriggerClientEvent('hospital:client:CheckStatus', src)
	else
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_ems'), 'error')
	end
end)

QBCore.Commands.Add('heal', Lang:t('info.heal_player'), {}, false, function(source, _)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player.PlayerData.job.name == 'ambulance' then
		TriggerClientEvent('hospital:client:TreatWounds', src)
	else
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_ems'), 'error')
	end
end)

QBCore.Commands.Add('revivep', Lang:t('info.revive_player'), {}, false, function(source, _)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player.PlayerData.job.name == 'ambulance' then
		TriggerClientEvent('hospital:client:RevivePlayer', src)
	else
		TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_ems'), 'error')
	end
end)

QBCore.Commands.Add('revive', Lang:t('info.revive_player_a'), { { name = 'id', help = Lang:t('info.player_id') } }, false, function(source, args)
	local src = source
	if args[1] then
		local Player = exports['qb-core']:GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:Revive', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
		end
	else
		TriggerClientEvent('hospital:client:Revive', src)
	end
end, 'admin')

QBCore.Commands.Add('setpain', Lang:t('info.pain_level'), { { name = 'id', help = Lang:t('info.player_id') } }, false, function(source, args)
	local src = source
	if args[1] then
		local Player = exports['qb-core']:GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:SetPain', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
		end
	else
		TriggerClientEvent('hospital:client:SetPain', src)
	end
end, 'admin')

QBCore.Commands.Add('kill', Lang:t('info.kill'), { { name = 'id', help = Lang:t('info.player_id') } }, false, function(source, args)
	local src = source
	if args[1] then
		local Player = exports['qb-core']:GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:KillPlayer', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
		end
	else
		TriggerClientEvent('hospital:client:KillPlayer', src)
	end
end, 'admin')

QBCore.Commands.Add('aheal', Lang:t('info.heal_player_a'), { { name = 'id', help = Lang:t('info.player_id') } }, false, function(source, args)
	local src = source
	if args[1] then
		local Player = exports['qb-core']:GetPlayer(tonumber(args[1]))
		if Player then
			TriggerClientEvent('hospital:client:adminHeal', Player.PlayerData.source)
		else
			TriggerClientEvent('QBCore:Notify', src, Lang:t('error.not_online'), 'error')
		end
	else
		TriggerClientEvent('hospital:client:adminHeal', src)
	end
end, 'admin')

-- Items

QBCore.Functions.CreateUseableItem('ifaks', function(source, item)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player.GetItemByName(item.name) ~= nil then
		TriggerClientEvent('hospital:client:UseIfaks', src)
	end
end)

QBCore.Functions.CreateUseableItem('bandage', function(source, item)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player.GetItemByName(item.name) ~= nil then
		TriggerClientEvent('hospital:client:UseBandage', src)
	end
end)

QBCore.Functions.CreateUseableItem('painkillers', function(source, item)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player.GetItemByName(item.name) ~= nil then
		TriggerClientEvent('hospital:client:UsePainkillers', src)
	end
end)

QBCore.Functions.CreateUseableItem('firstaid', function(source, item)
	local src = source
	local Player = exports['qb-core']:GetPlayer(src)
	if Player.GetItemByName(item.name) ~= nil then
		TriggerClientEvent('hospital:client:UseFirstAid', src)
	end
end)

QBCore.Functions.CreateUseableItem((Config.Defibrillator or {}).item or 'defibrillator', function(source)
	local src = source
	if QBCore.Functions.HasItem(src, (Config.Defibrillator or {}).item or 'defibrillator', 1) then
		TriggerClientEvent('hospital:client:UseDefibrillator', src)
	end
end)

exports('GetDoctorCount', function() return doctorCount end)
