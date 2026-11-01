local QBCore = exports['qb-core']:GetCoreObject({ 'Functions', 'Commands', 'Shared' })
local Accounts = {}
local Statements = {}
local ActiveATMRobberies = {}
local ActiveATMs = {}
local ATMCooldowns = {}
local ATMModelHashes = {}

for i = 1, #Config.atmModels do
    ATMModelHashes[joaat(Config.atmModels[i])] = true
end

-- Functions

local function getPlayerAndCitizenId(playerId)
    local Player = exports['qb-core']:GetPlayer(playerId)
    if not Player then return nil, nil end
    return Player, Player.PlayerData.citizenid
end

local function GetNumberOfAccounts(citizenid)
    local numberOfAccounts = 0
    for _, account in pairs(Accounts) do
        if account.citizenid == citizenid then
            numberOfAccounts = numberOfAccounts + 1
        end
    end
    return numberOfAccounts
end

local function getOnDutyPoliceCount()
    local count = 0
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = player.PlayerData.job
        if job and job.onduty and (job.type == 'leo' or job.name == 'police' or job.name == 'lspd') then
            count = count + 1
        end
    end
    return count
end

local function getUsableATMCrowbar(src)
    if GetResourceState('ox_inventory') ~= 'started' then return nil end

    local ok, slot = pcall(function()
        return exports.ox_inventory:GetSlotWithItem(src, Config.atmRobbery.requiredItem)
    end)
    if not ok or type(slot) ~= 'table' then return nil end

    local durability = tonumber(slot.metadata and slot.metadata.durability) or 100
    if durability <= 0 then return nil end

    return {
        slot = slot.slot,
        durability = durability,
    }
end

local function damageATMCrowbar(src, crowbar)
    local durability = math.max(0, crowbar.durability - Config.atmRobbery.durabilityLoss)
    return pcall(function()
        exports.ox_inventory:SetDurability(src, crowbar.slot, durability)
    end)
end

local function stillHasATMCrowbar(src, slotId)
    local ok, slot = pcall(function()
        return exports.ox_inventory:GetSlot(src, slotId)
    end)
    return ok and type(slot) == 'table' and slot.name == string.upper(Config.atmRobbery.requiredItem)
end

local function validATMRequest(src, data)
    if type(data) ~= 'table' or not ATMModelHashes[tonumber(data.model)] then return nil end
    if type(data.coords) ~= 'table' then return nil end

    local x, y, z = tonumber(data.coords.x), tonumber(data.coords.y), tonumber(data.coords.z)
    if not x or not y or not z or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 2000 then return nil end

    local coords = vector3(x, y, z)
    local ped = GetPlayerPed(src)
    if ped == 0 or #(GetEntityCoords(ped) - coords) > (Config.atmRobbery.maxDistance + 0.75) then return nil end

    local function halfMetre(value)
        return math.floor((value * 2) + 0.5) / 2
    end

    local key = ('%d:%.1f:%.1f:%.1f'):format(data.model, halfMetre(x), halfMetre(y), halfMetre(z))
    return key, coords
end

local function dispatchATMRobbery(coords)
    local message = 'Cashpoint robbery in progress'
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = player.PlayerData.job
        if job and job.onduty and (job.type == 'leo' or job.name == 'police' or job.name == 'lspd') then
            local officer = player.PlayerData.source
            local alertCoords = { x = coords.x, y = coords.y, z = coords.z }
            TriggerClientEvent('qb-phone:client:addPoliceAlert', officer, {
                title = 'New Call',
                coords = alertCoords,
                description = message,
            })
            TriggerClientEvent('police:client:policeAlert', officer, alertCoords, message)
        end
    end
end

local function clearATMRobbery(src, token)
    local robbery = ActiveATMRobberies[src]
    if not robbery or robbery.token ~= token then return nil end
    ActiveATMRobberies[src] = nil
    if ActiveATMs[robbery.key] == src then ActiveATMs[robbery.key] = nil end
    return robbery
end

-- Exported Functions

local function CreatePlayerAccount(playerId, accountName, accountBalance, accountUsers)
    local Player, citizenid = getPlayerAndCitizenId(playerId)
    if not Player or not citizenid then return false end

    if Accounts[accountName] then
        return false
    end

    Accounts[accountName] = {
        citizenid = citizenid,
        account_name = accountName,
        account_balance = accountBalance,
        account_type = 'shared',
        users = accountUsers
    }

    local insertSuccess = MySQL.insert.await('INSERT INTO bank_accounts (citizenid, account_name, account_balance, account_type, users) VALUES (?, ?, ?, ?, ?)', { citizenid, accountName, accountBalance, 'shared', accountUsers })
    return insertSuccess
end
exports('CreatePlayerAccount', CreatePlayerAccount)

local function CreateJobAccount(accountName, accountBalance)
    Accounts[accountName] = {
        account_name = accountName,
        account_balance = accountBalance,
        account_type = 'job'
    }
    local insertSuccess = MySQL.insert.await('INSERT INTO bank_accounts (account_name, account_balance, account_type) VALUES (?, ?, ?)', { accountName, accountBalance, 'job' })
    return insertSuccess
end
exports('CreateJobAccount', CreateJobAccount)

local function CreateGangAccount(accountName, accountBalance)
    Accounts[accountName] = {
        account_name = accountName,
        account_balance = accountBalance,
        account_type = 'gang'
    }
    local insertSuccess = MySQL.insert.await('INSERT INTO bank_accounts (account_name, account_balance, account_type) VALUES (?, ?, ?)', { accountName, accountBalance, 'gang' })
    return insertSuccess
end
exports('CreateGangAccount', CreateGangAccount)

local function CreateBankStatement(playerId, account, amount, reason, statementType, accountType)
    local Player, citizenid = getPlayerAndCitizenId(playerId)
    if not Player or not citizenid then return false end

    local newStatement = {
        citizenid = citizenid,
        amount = amount,
        reason = reason,
        date = os.time() * 1000,
        statement_type = statementType
    }
    if accountType == 'player' or accountType == 'shared' then
        if accountType == 'player' then account = 'checking' end
        if not Statements[citizenid] then Statements[citizenid] = {} end
        if not Statements[citizenid][account] then Statements[citizenid][account] = {} end
        Statements[citizenid][account][#Statements[citizenid][account] + 1] = newStatement
    else
        if not Statements[account] then Statements[account] = {} end
        Statements[account][#Statements[account] + 1] = newStatement
    end

    local insertSuccess = MySQL.insert.await('INSERT INTO bank_statements (citizenid, account_name, amount, reason, statement_type) VALUES (?, ?, ?, ?, ?)', { citizenid, account, amount, reason, statementType })
    if not insertSuccess then return false end
    return true
end
exports('CreateBankStatement', CreateBankStatement)

-- `contributorCitizenId` is optional so existing callers keep the old API. Resources
-- that are moving a known player's money into a society account should pass it: the
-- society ledger can then be joined back to `players` instead of recording an
-- anonymous deposit.
local function AddMoney(accountName, amount, reason, contributorCitizenId)
    if not reason then reason = 'External Deposit' end
    local newStatement = {
        citizenid = contributorCitizenId,
        amount = amount,
        reason = reason,
        date = os.time() * 1000,
        statement_type = 'deposit'
    }
    if Accounts[accountName] then
        local accountToUpdate = Accounts[accountName]
        accountToUpdate.account_balance = accountToUpdate.account_balance + amount
        if not Statements[accountName] then Statements[accountName] = {} end
        Statements[accountName][#Statements[accountName] + 1] = newStatement
        if contributorCitizenId then
            MySQL.insert.await('INSERT INTO bank_statements (citizenid, account_name, amount, reason, statement_type) VALUES (?, ?, ?, ?, ?)',
                { contributorCitizenId, accountName, amount, reason, 'deposit' })
        else
            MySQL.insert.await('INSERT INTO bank_statements (account_name, amount, reason, statement_type) VALUES (?, ?, ?, ?)',
                { accountName, amount, reason, 'deposit' })
        end
        local updateSuccess = MySQL.update.await('UPDATE bank_accounts SET account_balance = account_balance + ? WHERE account_name = ?', { amount, accountName })
        return updateSuccess
    end
    return false
end
exports('AddMoney', AddMoney)
exports('AddGangMoney', AddMoney)

local function RemoveMoney(accountName, amount, reason)
    if not reason then reason = 'External Withdrawal' end
    local newStatement = {
        amount = amount,
        reason = reason,
        date = os.time() * 1000,
        statement_type = 'withdraw'
    }
    if Accounts[accountName] then
        local accountToUpdate = Accounts[accountName]
        accountToUpdate.account_balance = accountToUpdate.account_balance - amount
        if not Statements[accountName] then Statements[accountName] = {} end
        Statements[accountName][#Statements[accountName] + 1] = newStatement
        MySQL.insert.await('INSERT INTO bank_statements (account_name, amount, reason, statement_type) VALUES (?, ?, ?, ?)', { accountName, amount, reason, 'withdraw' })
        local updateSuccess = MySQL.update.await('UPDATE bank_accounts SET account_balance = account_balance - ? WHERE account_name = ?', { amount, accountName })
        return updateSuccess
    end
    return false
end
exports('RemoveMoney', RemoveMoney)
exports('RemoveGangMoney', RemoveMoney)

local function GetAccount(accountName)
    if Accounts[accountName] then
        return Accounts[accountName]
    end
    return nil
end
exports('GetAccount', GetAccount)
exports('GetGangAccount', GetAccount)

local function GetAccountBalance(accountName)
    local account = GetAccount(accountName)
    return account and account.account_balance or 0
end
exports('GetAccountBalance', GetAccountBalance)

-- Callbacks

QBCore.Functions.CreateCallback('qb-banking:server:openBank', function(source, cb)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return end
    local job = Player.PlayerData.job
    local gang = Player.PlayerData.gang
    local accounts = {}
    local statements = {}
    if job.name ~= 'unemployed' and not Accounts[job.name] then CreateJobAccount(job.name, 0) end
    if gang.name ~= 'none' and not Accounts[gang.name] then CreateGangAccount(gang.name, 0) end
    accounts[#accounts + 1] = { account_name = 'checking', account_type = 'checking', account_balance = Player.PlayerData.money.bank }
    statements['checking'] = Statements[citizenid] and Statements[citizenid]['checking'] or {}
    for accountName, accountInfo in pairs(Accounts) do
        if accountInfo.citizenid == citizenid then
            accounts[#accounts + 1] = accountInfo
            if Statements[accountName] then statements[accountName] = Statements[accountName] end
        end
        if accountInfo.users and string.find(accountInfo.users, citizenid) then
            accounts[#accounts + 1] = accountInfo
            if Statements[accountName] then statements[accountName] = Statements[accountName] end
        end
        if (accountName == job.name and job.isboss) or (accountName == gang.name and gang.isboss) then
            accounts[#accounts + 1] = accountInfo
            if Statements[accountName] then statements[accountName] = Statements[accountName] end
        end
    end
    cb(accounts, statements, Player.PlayerData)
end)

QBCore.Functions.CreateCallback('qb-banking:server:openATM', function(source, cb)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return end
    local bankCards = exports['qb-inventory']:GetItemsByName(src, 'bank_card') -- inventory method, not on Player API
    -- the ox shim returns {} (never nil) when the player has no card; an empty pin list
    -- would put the NUI on an unpassable PIN screen, so refuse here with feedback
    if not bankCards or #bankCards == 0 then
        TriggerClientEvent('QBCore:Notify', src, Lang:t('error.card'), 'error')
        return cb(false)
    end
    local acceptablePins = {}
    for _, bankCard in ipairs(bankCards) do acceptablePins[#acceptablePins + 1] = bankCard.info.cardPin end
    local job = Player.PlayerData.job
    local gang = Player.PlayerData.gang
    local accounts = {}
    accounts[#accounts + 1] = { account_name = 'checking', account_type = 'checking', account_balance = Player.PlayerData.money.bank }
    for accountName, accountInfo in pairs(Accounts) do
        if accountInfo.citizenid == citizenid then
            accounts[#accounts + 1] = accountInfo
        end
        if accountInfo.users and string.find(accountInfo.users, citizenid) then
            accounts[#accounts + 1] = accountInfo
        end
        if (accountName == job.name and job.isboss) or (accountName == gang.name and gang.isboss) then
            accounts[#accounts + 1] = accountInfo
        end
    end
    cb(accounts, Player.PlayerData, acceptablePins)
end)

QBCore.Functions.CreateCallback('qb-banking:server:withdraw', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local accountName = data.accountName
    local withdrawAmount = tonumber(data.amount)
    -- SECURITY (ajd, 8 Aug 2026): a negative amount inverted both money
    -- movements and the `balance < amount` test passed trivially for it.
    if not withdrawAmount or withdrawAmount <= 0 then return cb({ success = false, message = Lang:t('error.error') }) end
    local reason = (data.reason ~= '' and data.reason) or 'Bank Withdrawal'
    if accountName == 'checking' then
        local accountBalance = Player.PlayerData.money.bank
        if accountBalance < withdrawAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        Player.RemoveMoney('bank', withdrawAmount, 'bank withdrawal')
        Player.AddMoney('cash', withdrawAmount, 'bank withdrawal')
        if not CreateBankStatement(src, 'checking', withdrawAmount, reason, 'withdraw', 'player') then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.withdraw') })
    end
    if Accounts[accountName] then
        local job = Player.PlayerData.job
        local gang = Player.PlayerData.gang
        if Accounts[accountName].account_type == 'job' and (job.name ~= accountName or not job.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        if Accounts[accountName].account_type == 'gang' and (gang.name ~= accountName or not gang.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        local accountBalance = GetAccountBalance(accountName)
        if accountBalance < withdrawAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        if not RemoveMoney(accountName, withdrawAmount) then return cb({ success = false, message = Lang:t('error.error') }) end
        Player.AddMoney('cash', withdrawAmount, 'bank account: ' .. accountName .. ' withdrawal')
        if not CreateBankStatement(src, accountName, withdrawAmount, reason, 'withdraw', Accounts[accountName].account_type) then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.withdraw') })
    end
end)

QBCore.Functions.CreateCallback('qb-banking:server:deposit', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local accountName = data.accountName
    local depositAmount = tonumber(data.amount)
    -- SECURITY (ajd, 8 Aug 2026): a negative amount inverted both money
    -- movements and the `balance < amount` test passed trivially for it.
    if not depositAmount or depositAmount <= 0 then return cb({ success = false, message = Lang:t('error.error') }) end
    local reason = (data.reason ~= '' and data.reason) or 'Bank Deposit'
    if accountName == 'checking' then
        local accountBalance = Player.PlayerData.money.cash
        if accountBalance < depositAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        Player.RemoveMoney('cash', depositAmount, 'bank deposit')
        Player.AddMoney('bank', depositAmount, 'bank deposit')
        if not CreateBankStatement(src, 'checking', depositAmount, reason, 'deposit', 'player') then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.deposit') })
    end
    if Accounts[accountName] then
        local job = Player.PlayerData.job
        local gang = Player.PlayerData.gang
        if Accounts[accountName].account_type == 'job' and (job.name ~= accountName or not job.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        if Accounts[accountName].account_type == 'gang' and (gang.name ~= accountName or not gang.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        if Player.PlayerData.money.cash < depositAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        Player.RemoveMoney('cash', depositAmount, 'bank account: ' .. accountName .. ' deposit')
        if not AddMoney(accountName, depositAmount) then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.deposit') })
    end
end)

QBCore.Functions.CreateCallback('qb-banking:server:internalTransfer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local job = Player.PlayerData.job
    local gang = Player.PlayerData.gang
    local fromAccountName = data.fromAccountName
    local toAccountName = data.toAccountName
    local transferAmount = tonumber(data.amount)
    local reason = (data.reason ~= '' and data.reason) or 'Internal transfer'
    if fromAccountName == 'checking' then
        if Player.PlayerData.money.bank < transferAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        Player.RemoveMoney('bank', transferAmount, reason)
        if toAccountName == 'checking' then
            Player.AddMoney('bank', transferAmount, reason)
        else
            if not AddMoney(toAccountName, transferAmount) then return cb({ success = false, message = Lang:t('error.error') }) end
        end
        if not CreateBankStatement(src, 'checking', transferAmount, reason, 'withdraw', 'player') then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.transfer') })
    elseif toAccountName == 'checking' then
        if Accounts[fromAccountName].account_type == 'job' and (job.name ~= fromAccountName or not job.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        if Accounts[fromAccountName].account_type == 'gang' and (gang.name ~= fromAccountName or not gang.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        local fromAccountBalance = GetAccountBalance(fromAccountName)
        if fromAccountBalance < transferAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        if not RemoveMoney(fromAccountName, transferAmount) then return cb({ success = false, message = Lang:t('error.error') }) end
        Player.AddMoney('bank', transferAmount, reason)
        if not CreateBankStatement(src, 'checking', transferAmount, reason, 'deposit', 'player') then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.transfer') })
    else
        if Accounts[fromAccountName].account_type == 'job' and (job.name ~= fromAccountName or not job.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        if Accounts[fromAccountName].account_type == 'gang' and (gang.name ~= fromAccountName or not gang.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        local fromAccountBalance = GetAccountBalance(fromAccountName)
        if fromAccountBalance < transferAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        if not RemoveMoney(fromAccountName, transferAmount) then return cb({ success = false, message = Lang:t('error.error') }) end
        if not AddMoney(toAccountName, transferAmount) then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.transfer') })
    end
end)

QBCore.Functions.CreateCallback('qb-banking:server:externalTransfer', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local job = Player.PlayerData.job
    local gang = Player.PlayerData.gang
    local toAccountName = data.toAccountNumber
    local toPlayer = exports['qb-core']:GetPlayerByCitizenId(toAccountName)
    if not toPlayer then return cb({ success = false, message = Lang:t('error.error') }) end
    local fromAccountName = data.fromAccountName
    local transferAmount = tonumber(data.amount)
    local reason = (data.reason ~= '' and data.reason) or 'External transfer'
    if fromAccountName == 'checking' then
        if Player.PlayerData.money.bank < transferAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        Player.RemoveMoney('bank', transferAmount, reason)
        toPlayer.AddMoney('bank', transferAmount, reason)
        if not CreateBankStatement(src, 'checking', transferAmount, reason, 'withdraw', 'player') then return cb({ success = false, message = Lang:t('error.error') }) end
        if not CreateBankStatement(toPlayer.PlayerData.source, 'checking', transferAmount, reason, 'deposit', 'player') then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.transfer') })
    else
        if Accounts[fromAccountName].account_type == 'job' and (job.name ~= fromAccountName or not job.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        if Accounts[fromAccountName].account_type == 'gang' and (gang.name ~= fromAccountName or not gang.isboss) then return cb({ success = false, message = Lang:t('error.access') }) end
        local fromAccountBalance = GetAccountBalance(fromAccountName)
        if fromAccountBalance < transferAmount then return cb({ success = false, message = Lang:t('error.money') }) end
        if not RemoveMoney(fromAccountName, transferAmount) then return cb({ success = false, message = Lang:t('error.error') }) end
        toPlayer.AddMoney('bank', transferAmount, reason)
        if not CreateBankStatement(toPlayer.PlayerData.source, 'checking', transferAmount, reason, 'deposit', 'player') then return cb({ success = false, message = Lang:t('error.error') }) end
        cb({ success = true, message = Lang:t('success.transfer') })
    end
end)

QBCore.Functions.CreateCallback('qb-banking:server:orderCard', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local cardNumber = math.random(1000000000000000, 9999999999999999)
    local pinNumber = tonumber(data.pin)
    if not pinNumber then return cb({ success = false, message = Lang:t('error.pin') }) end
    local info = {
        citizenid = citizenid,
        name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        cardNumber = cardNumber,
        cardPin = pinNumber,
    }
    exports['qb-inventory']:AddItem(src, 'bank_card', 1, false, info, 'qb-banking:server:orderCard')
    cb({ success = true, message = Lang:t('success.card') })
end)

QBCore.Functions.CreateCallback('qb-banking:server:openAccount', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local accountName = data.accountName
    local initialAmount = tonumber(data.amount)
    if GetNumberOfAccounts(citizenid) >= Config.maxAccounts then return cb({ success = false, message = Lang:t('error.accounts') }) end
    if Player.PlayerData.money.bank < initialAmount then return cb({ success = false, message = Lang:t('error.money') }) end
    Player.RemoveMoney('bank', initialAmount, 'Opened account ' .. accountName)
    if not CreatePlayerAccount(src, accountName, initialAmount, json.encode({})) then return cb({ success = false, message = Lang:t('error.error') }) end
    if not CreateBankStatement(src, accountName, initialAmount, 'Initial deposit', 'deposit', 'shared') then return cb({ success = false, message = Lang:t('error.error') }) end
    if not CreateBankStatement(src, 'checking', initialAmount, 'Initial deposit for ' .. accountName, 'withdraw', 'player') then return cb({ success = false, message = Lang:t('error.error') }) end
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Account Opened', 'green', string.format('**%s** opened account **%s** with an initial deposit of **£%s**', GetPlayerName(src), accountName, initialAmount))
    cb({ success = true, message = Lang:t('success.account') })
end)

QBCore.Functions.CreateCallback('qb-banking:server:renameAccount', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local oldName = data.oldName
    local newName = data.newName
    if not Accounts[oldName] then return cb({ success = false, message = Lang:t('error.error') }) end
    if Accounts[oldName].citizenid ~= citizenid then return cb({ success = false, message = Lang:t('error.access') }) end
    Accounts[newName] = Accounts[oldName]
    Accounts[newName].account_name = newName
    Accounts[oldName] = nil
    local result = MySQL.update.await('UPDATE bank_accounts SET account_name = ? WHERE account_name = ? AND citizenid = ?', { newName, oldName, citizenid })
    if not result then return cb({ success = false, message = Lang:t('error.error') }) end
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Account Renamed', 'red', string.format('**%s** renamed **%s** to **%s**', GetPlayerName(src), oldName, newName))
    cb({ success = true, message = Lang:t('success.rename') })
end)

QBCore.Functions.CreateCallback('qb-banking:server:deleteAccount', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local accountName = data.accountName
    if not Accounts[accountName] then return cb({ success = false, message = Lang:t('error.error') }) end
    if Accounts[accountName].citizenid ~= citizenid then return cb({ success = false, message = Lang:t('error.access') }) end
    Accounts[accountName] = nil
    local result = MySQL.rawExecute.await('DELETE FROM bank_accounts WHERE account_name = ? AND citizenid = ?', { accountName, citizenid })
    if not result then return cb({ success = false, message = Lang:t('error.error') }) end
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Account Deleted', 'red', string.format('**%s** deleted account **%s**', GetPlayerName(src), accountName))
    cb({ success = true, message = Lang:t('success.delete') })
end)

QBCore.Functions.CreateCallback('qb-banking:server:addUser', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local userToAdd = data.userName
    local accountName = data.accountName
    if not Accounts[accountName] then return cb({ success = false, message = Lang:t('error.account') }) end
    if Accounts[accountName].citizenid ~= citizenid then return cb({ success = false, message = Lang:t('error.access') }) end
    local account = Accounts[accountName]
    local users = json.decode(account.users)
    for _, cid in ipairs(users) do
        if cid == userToAdd then return cb({ success = false, message = Lang:t('error.user') }) end
    end
    users[#users + 1] = userToAdd
    local usersData = json.encode(users)
    Accounts[accountName].users = usersData
    local result = MySQL.update.await('UPDATE bank_accounts SET users = ? WHERE account_name = ? AND citizenid = ?', { usersData, accountName, citizenid })
    if not result then cb({ success = false, message = Lang:t('error.error') }) end
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'User Added', 'green', string.format('**%s** added **%s** to **%s**', GetPlayerName(src), userToAdd, accountName))
    cb({ success = true, message = Lang:t('success.userAdd') })
end)

QBCore.Functions.CreateCallback('qb-banking:server:removeUser', function(source, cb, data)
    local src = source
    local Player, citizenid = getPlayerAndCitizenId(src)
    if not Player or not citizenid then return cb({ success = false, message = Lang:t('error.error') }) end
    local userToRemove = data.userName
    local accountName = data.accountName
    if not Accounts[accountName] then return cb({ success = false, message = Lang:t('error.account') }) end
    if Accounts[accountName].citizenid ~= citizenid then return cb({ success = false, message = Lang:t('error.access') }) end
    local account = Accounts[accountName]
    local users = json.decode(account.users)
    local userFound = false
    for i = #users, 1, -1 do
        if users[i] == userToRemove then
            table.remove(users, i)
            userFound = true
            break
        end
    end
    if not userFound then return cb({ success = false, message = Lang:t('error.noUser') }) end
    local usersData = json.encode(users)
    Accounts[accountName].users = usersData
    local result = MySQL.update.await('UPDATE bank_accounts SET users = ? WHERE account_name = ? AND citizenid = ?', { usersData, accountName, citizenid })
    if not result then cb({ success = false, message = Lang:t('error.error') }) end
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'User Removed', 'red', string.format('**%s** removed **%s** from **%s**', GetPlayerName(src), userToRemove, accountName))
    cb({ success = true, message = Lang:t('success.userRemove') })
end)

QBCore.Functions.CreateCallback('qb-banking:server:startATMRobbery', function(source, cb, data)
    local src = source
    if not Config.atmRobbery.enabled then return cb({ ok = false, message = 'Cashpoint robberies are disabled.' }) end
    if ActiveATMRobberies[src] then return cb({ ok = false, message = 'You are already robbing a cashpoint.' }) end

    local key, coords = validATMRequest(src, data)
    if not key then return cb({ ok = false, message = 'Move closer to the cashpoint.' }) end
    if ActiveATMs[key] then return cb({ ok = false, message = 'Someone is already forcing this cashpoint.' }) end

    local remaining = (ATMCooldowns[key] or 0) - os.time()
    if remaining > 0 then
        return cb({ ok = false, message = ('This cashpoint has already been emptied. Try again in %d minutes.'):format(math.ceil(remaining / 60)) })
    end

    local crowbar = getUsableATMCrowbar(src)
    if not crowbar then return cb({ ok = false, message = 'You need a usable crowbar to rob this cashpoint.' }) end

    local police = getOnDutyPoliceCount()
    if police < Config.atmRobbery.minimumPolice then
        return cb({ ok = false, message = 'At least one on-duty police officer is required.' })
    end

    local token = ('%d:%d:%d'):format(src, os.time(), math.random(100000, 999999))
    local robbery = {
        token = token,
        key = key,
        coords = coords,
        crowbarSlot = crowbar.slot,
        startedAt = GetGameTimer(),
    }

    if not damageATMCrowbar(src, crowbar) then
        return cb({ ok = false, message = 'The crowbar could not be used.' })
    end

    ActiveATMRobberies[src] = robbery
    ActiveATMs[key] = src
    ATMCooldowns[key] = os.time() + Config.atmRobbery.cooldown

    -- The alarm is server-owned and fires before the 30-second progress begins.
    dispatchATMRobbery(coords)
    cb({ ok = true, token = token })

    SetTimeout(Config.atmRobbery.duration + 15000, function()
        clearATMRobbery(src, token)
    end)
end)

RegisterNetEvent('qb-banking:server:cancelATMRobbery', function(token)
    clearATMRobbery(source, tostring(token or ''))
end)

RegisterNetEvent('qb-banking:server:completeATMRobbery', function(token)
    local src = source
    local robbery = ActiveATMRobberies[src]
    if not robbery or robbery.token ~= tostring(token or '') then return end

    local elapsed = GetGameTimer() - robbery.startedAt
    local ped = GetPlayerPed(src)
    local closeEnough = ped ~= 0 and #(GetEntityCoords(ped) - robbery.coords) <= (Config.atmRobbery.maxDistance + 0.75)
    local hasItem = stillHasATMCrowbar(src, robbery.crowbarSlot)
    clearATMRobbery(src, robbery.token)

    if elapsed < (Config.atmRobbery.duration - 1000) or not closeEnough or not hasItem then
        TriggerClientEvent('QBCore:Notify', src, 'The cashpoint robbery failed.', 'error', 5000)
        return
    end

    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end

    local reward = math.random(Config.atmRobbery.reward.min, Config.atmRobbery.reward.max)
    Player.Functions.AddMoney('cash', reward, 'atm-robbery')
    TriggerClientEvent('QBCore:Notify', src, ('You took £%d from the cashpoint.'):format(reward), 'success', 5000)
    TriggerEvent('qb-log:server:CreateLog', 'robbery', 'Cashpoint Robbery', 'red',
        ('**%s** robbed a cashpoint for **£%d**'):format(GetPlayerName(src), reward))
end)

AddEventHandler('playerDropped', function()
    local src = source
    local robbery = ActiveATMRobberies[src]
    if robbery then clearATMRobbery(src, robbery.token) end
end)

-- Items

QBCore.Functions.CreateUseableItem('bank_card', function(source, item)
    local Player = exports['qb-core']:GetPlayer(source)
    if not Player then return end
    if exports['qb-inventory']:GetItemByName(source, item.name) then -- inventory method, not on Player API
        TriggerClientEvent('qb-banking:client:useCard', source)
    end
end)

-- Threads

CreateThread(function()
    local accounts = MySQL.query.await('SELECT * FROM bank_accounts')

    for _, account in ipairs(accounts) do
        Accounts[account.account_name] = account
    end

    for job in pairs(QBCore.Shared.Jobs) do
        if Accounts[job] == nil then
            CreateJobAccount(job, 0)
        end
    end
end)

CreateThread(function()
    local statements = MySQL.query.await('SELECT * FROM bank_statements')
    for _, statement in ipairs(statements) do
        if statement.account_name == 'checking' then
            if not Statements[statement.citizenid] then Statements[statement.citizenid] = {} end
            if not Statements[statement.citizenid][statement.account_name] then Statements[statement.citizenid][statement.account_name] = {} end
            Statements[statement.citizenid][statement.account_name][#Statements[statement.citizenid][statement.account_name] + 1] = statement
        else
            if not Statements[statement.account_name] then Statements[statement.account_name] = {} end
            Statements[statement.account_name][#Statements[statement.account_name] + 1] = statement
        end
    end
end)

-- Commands

QBCore.Commands.Add('givecash', 'Give Cash', { { name = 'id', help = 'Player ID' }, { name = 'amount', help = 'Amount' } }, true, function(source, args)
    local src = source
    local Player = exports['qb-core']:GetPlayer(src)
    if not Player then return end
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local target = exports['qb-core']:GetPlayer(tonumber(args[1]))
    if not target then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.noUser'), 'error') end
    local targetPed = GetPlayerPed(tonumber(args[1]))
    local targetCoords = GetEntityCoords(targetPed)
    local amount = tonumber(args[2])
    if not amount then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.amount'), 'error') end
    if amount <= 0 then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.amount'), 'error') end
    if #(playerCoords - targetCoords) > 5 then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.toofar'), 'error') end
    if Player.PlayerData.money.cash < amount then return TriggerClientEvent('QBCore:Notify', src, Lang:t('error.money'), 'error') end
    Player.RemoveMoney('cash', amount, 'cash transfer')
    target.AddMoney('cash', amount, 'cash transfer')
    TriggerClientEvent('QBCore:Notify', src, string.format(Lang:t('success.give'), amount), 'success')
    TriggerClientEvent('QBCore:Notify', target.PlayerData.source, string.format(Lang:t('success.receive'), amount), 'success')
end)
