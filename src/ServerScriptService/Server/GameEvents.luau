-- GameEvents: one place where services announce what a player just did, so other services (daily quests, leaderboards)
-- can count it without each service knowing about the others.
--   GameEvents.Fire(name, player, amount, info)   e.g. Fire("Rep", player, 1, { machineId = "FlatBench", groups = {...} })
--   GameEvents.On(name, handler)                  handler(player, amount, info); returns the connection
-- Names in use: "Rep", "CardioMeters", "Spot", "PosingEntered", "PosingWon", "ArmWrestleWon", "RivalBeaten".
-- Handlers run in their own thread, so a failing or slow handler never breaks the service that fired the event.
local GameEvents = {}

local handlers = {} -- [name] = { handler, ... }

function GameEvents.On(name, handler)
	handlers[name] = handlers[name] or {}
	table.insert(handlers[name], handler)
	return {
		Disconnect = function()
			local list = handlers[name]
			local index = list and table.find(list, handler)
			if index then table.remove(list, index) end
		end,
	}
end

function GameEvents.Fire(name, player, amount, info)
	for _, handler in ipairs(handlers[name] or {}) do
		task.spawn(function()
			local ok, err = pcall(handler, player, amount or 1, info)
			if not ok then warn("[GameEvents] " .. name .. " handler failed: " .. tostring(err)) end
		end)
	end
end

return GameEvents
