if GetResourceState('qb-core') ~= 'started' then return end

QBCore = exports['qb-core']:GetCoreObject()

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
	PlayerLoaded(player)
end)

AddEventHandler('QBCore:Server:OnJobUpdate', function(playerId, job)
	UpdatePlayerJob(playerId, job)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(playerId)
    RemovePlayer(playerId)
end)

function GetSource(player)
    return player.PlayerData.source
end

function GetPlayerJob(player)
    return player.PlayerData.job
end

function GetPlayerFromId(source)
    return QBCore.Functions.GetPlayer(source)
end

function GetServerPlayers()
    return QBCore.Functions.GetQBPlayers()
end

function GetPlayerData(player)
    local citizenid = player.PlayerData.citizenid
    local firstName = player.PlayerData.charinfo.firstname
    local lastName = player.PlayerData.charinfo.lastname
    local jobName = player.PlayerData.job.name
    local jobLabel = player.PlayerData.job.label

    return {
        identifier = citizenid,
        name = firstName .. ' ' .. lastName,
        job = {
            name = jobName,
            label = jobLabel
        }
    }
end