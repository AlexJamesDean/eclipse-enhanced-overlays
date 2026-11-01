--- @param bool boolean
function ToggleUI(bool)
	SetNuiFocus(bool, bool)
	SendNUIMessage({
		action = "setVisible",
		data = bool
	})
end

-- ECLIPSE CITY (7 Aug 2026): mandatory on this box — any resource that takes NUI
-- focus must give it back when it stops, or an admin who is holding the menu open
-- during a restart is left with a locked cursor, no UI and no way out but a relog.
-- Upstream ships no teardown at all. See CLAUDE.md, "Gotchas on this box".
AddEventHandler('onClientResourceStop', function(resource)
	if resource ~= GetCurrentResourceName() then return end
	SetNuiFocus(false, false)
end)

function CheckDataFromKey(key)
	local actions = Config.Actions[key]
	if actions then
		local data = nil

		if actions.event then
			data = actions
		end

		if actions.dropdown then
			for _, v in pairs(actions.dropdown) do
				if v.event then
					local new = v
					new.perms = actions.perms
					data = new
					break
				end
			end
		end

		return data
	end

	local playerActions = Config.PlayerActions[key]
	if playerActions then
		return playerActions
	end

	local otherActions = Config.OtherActions[key]
	if otherActions then
		return otherActions
	end
end

--- @param title string
--- @param message string
function Log(title, message)
	TriggerServerEvent("qb-log:server:CreateLog", "ps-adminmenu", title, "red", message)
end
