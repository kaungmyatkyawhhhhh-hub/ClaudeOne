-- ShutdownService: soft shutdown. When Roblox closes a server ("Shut down all servers" / "Migrate to latest update"
-- after a publish), everyone in it is moved to a short-lived reserved "holding" server instead of being kicked, and from
-- there back into a fresh public server running the new version (owner, 13 Oct).
--  * Live server: BindToClose tells the players (small note), saves run as usual (PlayerData's own BindToClose; leaving
--    by teleport saves and releases the session too), and everyone is teleported together into one new reserved server.
--  * Holding server (a reserved server with no owner: the game reserves servers for nothing else): Main starts ONLY
--    this service, so no data is loaded or saved there (no session lock); Workspace attribute "SoftShutdown" makes the
--    loading screen say "Updating the gym". After a short wait the players go back to the game's public servers;
--    their data loads there (PlayerData waits for the old server's lock if a save is still finishing).
--  * Studio: nothing (a Studio test closing just stops).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShutdownService = {}

local HOLD_TIME = 6        -- seconds in the holding server before going back (old servers finish closing meanwhile)
local TELEPORT_TRIES = 4
local TRY_GAP = 2          -- seconds between teleport tries
local CLOSE_LIMIT = 25     -- BindToClose may take ~30 s in all; leave some for the saves

function ShutdownService.IsHoldingServer(): boolean
	return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0
end

-- Teleports `list` (still in the game) to the place, a few tries. options: TeleportOptions or nil.
local function teleport(list, options)
	for attempt = 1, TELEPORT_TRIES do
		local still = {}
		for _, player in ipairs(list) do
			if player.Parent == Players then table.insert(still, player) end
		end
		if #still == 0 then return true end
		local ok, err = pcall(function() TeleportService:TeleportAsync(game.PlaceId, still, options) end)
		if ok then return true end
		warn(string.format("[ShutdownService] teleport try %d failed: %s", attempt, tostring(err)))
		task.wait(TRY_GAP)
	end
	return false
end

-- A teleport that failed after it started (TeleportInitFailed): try that player again once more.
TeleportService.TeleportInitFailed:Connect(function(player, result, message, _placeId, options)
	if player.Parent ~= Players then return end
	warn("[ShutdownService] teleport failed for " .. player.Name .. ": " .. tostring(result) .. " " .. tostring(message))
	task.delay(TRY_GAP, function()
		if player.Parent == Players then pcall(function() TeleportService:TeleportAsync(game.PlaceId, { player }, options) end) end
	end)
end)

-- The holding server: sends everyone who arrives back to the game after HOLD_TIME (people arriving together go together).
function ShutdownService.StartHolding()
	workspace:SetAttribute("SoftShutdown", true)
	local waiting = {}
	local function sendSoon(player)
		table.insert(waiting, player)
		if #waiting > 1 then return end -- (a send is already planned)
		task.delay(HOLD_TIME, function()
			local list = waiting
			waiting = {}
			teleport(list, nil)
		end)
	end
	Players.PlayerAdded:Connect(sendSoon)
	for _, player in ipairs(Players:GetPlayers()) do sendSoon(player) end
end

-- The live server: on close, move everyone into one new holding server.
function ShutdownService.Start()
	if RunService:IsStudio() then return end
	game:BindToClose(function()
		local list = Players:GetPlayers()
		if #list == 0 then return end
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local event = remotes and remotes:FindFirstChild("PlayerEvent")
		if event then event:FireAllClients("SoftShutdown", {}) end
		task.wait(1) -- (the note shows before the teleport screen)
		local options = Instance.new("TeleportOptions")
		options.ShouldReserveServer = true
		options:SetTeleportData({ softShutdown = true })
		teleport(list, options)
		-- stay open until they're gone (closing kicks whoever is left)
		local deadline = os.clock() + CLOSE_LIMIT
		while #Players:GetPlayers() > 0 and os.clock() < deadline do task.wait(0.5) end
	end)
end

return ShutdownService
