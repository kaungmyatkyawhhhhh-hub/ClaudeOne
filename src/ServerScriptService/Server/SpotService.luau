-- SpotService: spotting (owner's redo, 8 Oct night; numbers in Config.Spotting). Server-authoritative:
--  * A player asks to spot a lifter ("Request", the lifter's UserId): they must be near, not lifting or spotting, the
--    machine must be spottable (Config.Machines spotType), the lifter must take requests (settings.spotRequests) and
--    have a free place (Config.Spotting.MaxSpotters, else "Full"). The lifter gets a request card for RequestTimeout s.
--  * The lifter answers ("Respond", the asker's UserId, accept). Accepted: the spotter is placed (root anchored) at a
--    spot on the machine (SpotPoints attachments from tools/builders/SpotPoints, by count: Config.Spotting.HandsSlots /
--    HypeSlots); everyone is re-placed when the count changes. Character attributes SpotLifter (UserId), SpotType and
--    SpotSlot tell every client how to pose them (SpotClient).
--  * "Push" taps: counted at most MaxTapsPerSecond a second, perfectly even taps ignored; ClickRate a second or more =
--    clicking (until ClickHold after the last counted tap).
--  * The lifter's gains: BoostService source "Spotted" = Spotting.BoostFor(count, clicking). The lifter gets "Spotted"
--    (boost, names); each spotter "State" (clicking, boost).
--  * Every RewardEvery lifter reps each spotter gets coins (more while clicking); spotted reps count for the Spotter title.
--  * Spotting ends on "Exit", moving / jumping (the client sends Exit; the server also ends it if the spotter gets away
--    from their spot), the lifter leaving the machine, death or leaving the game.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spotting = require(ReplicatedStorage.Shared.Config.Spotting)
local Machines = require(ReplicatedStorage.Shared.Config.Machines)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)
local BoostService = require(script.Parent.BoostService)
local TitleService = require(script.Parent.TitleService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local SpotService = {}

local remote: RemoteEvent
local spots = {}       -- [model] = { lifter, machine, spotters = { [player] = record }, order = { player } }
local spotting = {}    -- [spotter] = model
local requests = {}    -- [lifter] = { [asker] = expiresAt }
local lastAsk = {}     -- [asker] = os.clock()

local function send(player, kind, info)
	if player and player.Parent then remote:FireClient(player, kind, info or {}) end
end

local function rootOf(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid and humanoid.Health > 0) then return nil end
	return root, humanoid, character
end

-- the machine a player is lifting on, or nil
local function machineOf(player)
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == player.UserId then return model end
	end
	return nil
end

------------------------------------------------------------------------
-- Spots
------------------------------------------------------------------------
-- The world CFrame (on the floor, facing the lifter) of a named spot; machines without SpotPoints get a computed one.
local function spotCFrame(model, name: string, index: number): CFrame
	local holder = model:FindFirstChild("SpotPoints")
	local attachment = holder and holder:FindFirstChild(name)
	if attachment and attachment:IsA("Attachment") then return attachment.WorldCFrame end
	local pivot = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2 + 2.2
	local angle = math.rad(({ 0, -36, 36, -72, 72 })[index] or 0)
	local at = pivot * Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
	local floor = Vector3.new(at.X, pivot.Y, at.Z)
	return CFrame.lookAt(floor, Vector3.new(pivot.X, pivot.Y, pivot.Z))
end

local function place(record, player, model, slot: string, index: number, kind: string)
	local root, humanoid, character = rootOf(player)
	if not root then return end
	local cf = spotCFrame(model, slot, index)
	record.slot, record.at = slot, cf.Position
	root.Anchored = true
	character:PivotTo(cf * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	character:SetAttribute("SpotLifter", spots[model].lifter.UserId)
	character:SetAttribute("SpotType", kind)
	character:SetAttribute("SpotSlot", slot)
end

-- puts every spotter of a machine on the spot for the current count (join order)
local function layout(model)
	local spot = spots[model]
	if not spot then return end
	local count = #spot.order
	local kind = spot.machine.spotType
	local slots = if kind == "hands" then Spotting.HandsSlots[count] else Spotting.HypeSlots
	for index, player in ipairs(spot.order) do
		local slot = slots and slots[index] or Spotting.HypeSlots[index]
		place(spot.spotters[player], player, model, slot, index, kind)
	end
end

local function clickingCount(spot, now: number): number
	local n = 0
	for _, record in pairs(spot.spotters) do
		if now < record.clickingUntil then n += 1 end
	end
	return n
end

local function names(spot): { string }
	local list = {}
	for _, player in ipairs(spot.order) do table.insert(list, player.DisplayName) end
	return list
end

-- the lifter's boost and everyone's display, when anything changed
local function refresh(model)
	local spot = spots[model]
	if not spot then return end
	local now = os.clock()
	local count, clicking = #spot.order, clickingCount(spot, now)
	local boost = Spotting.BoostFor(count, clicking)
	local key = count .. ":" .. clicking
	if spot.key == key then return end
	spot.key = key
	BoostService.SetPlayer(spot.lifter, "Spotted", if count > 0 then { gains = boost } else nil)
	send(spot.lifter, "Spotted", { count = count, clicking = clicking, boost = boost, names = names(spot) })
	for player, record in pairs(spot.spotters) do
		send(player, "State", { clicking = now < record.clickingUntil, boost = boost, count = count, lifter = spot.lifter.DisplayName })
	end
end

local function release(player)
	local _, _, character = rootOf(player)
	character = character or player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then root.Anchored = false end
		character:SetAttribute("SpotLifter", nil)
		character:SetAttribute("SpotType", nil)
		character:SetAttribute("SpotSlot", nil)
	end
end

local function stopSpotting(player, reason: string)
	local model = spotting[player]
	if not model then return end
	spotting[player] = nil
	local spot = spots[model]
	release(player)
	-- (with the session's totals, for the spotter's "you spotted N reps, +C coins" wrap-up)
	local record = spot and spot.spotters[player]
	send(player, "Ended", { reason = reason, reps = record and record.totalReps or 0, coins = record and record.totalCoins or 0 })
	if not spot then return end
	spot.spotters[player] = nil
	local index = table.find(spot.order, player)
	if index then table.remove(spot.order, index) end
	if #spot.order == 0 then
		BoostService.SetPlayer(spot.lifter, "Spotted", nil)
		send(spot.lifter, "Spotted", { count = 0, clicking = 0, boost = 1, names = {} })
		spots[model] = nil
	else
		spot.key = nil
		layout(model)
		refresh(model)
	end
end

local function endAll(model, reason: string)
	local spot = spots[model]
	if not spot then return end
	for _, player in ipairs(table.clone(spot.order)) do stopSpotting(player, reason) end
	if spot.lifter.Parent then
		BoostService.SetPlayer(spot.lifter, "Spotted", nil)
		send(spot.lifter, "Spotted", { count = 0, clicking = 0, boost = 1, names = {} })
	end
	spots[model] = nil
end

------------------------------------------------------------------------
-- Requests
------------------------------------------------------------------------
-- why `asker` can't spot `lifter` on `model` now (nil = they can)
local function blocked(asker, lifter, model): string?
	if not lifter or lifter == asker or not lifter.Parent then return "Unavailable" end
	if not model or model:GetAttribute("UserId") ~= lifter.UserId then return "Unavailable" end
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	if not machine or not machine.spotType then return "NotSpottable" end
	if not PlayerData.Get(asker) or machineOf(asker) or spotting[asker] or machineOf(lifter) ~= model then return "Busy" end
	local root = rootOf(asker)
	if not root or (root.Position - model:GetPivot().Position).Magnitude > Spotting.Range then return "TooFar" end
	local spot = spots[model]
	if spot and #spot.order >= Spotting.MaxSpotters then return "Full" end
	return nil
end

local function ask(asker, lifterUserId)
	if type(lifterUserId) ~= "number" then return end
	local now = os.clock()
	if now - (lastAsk[asker] or -math.huge) < Spotting.RequestCooldown then return end
	local lifter = Players:GetPlayerByUserId(lifterUserId)
	local model = lifter and machineOf(lifter)
	local why = blocked(asker, lifter, model)
	if why then
		send(asker, "Refused", { reason = why, name = lifter and lifter.DisplayName or "" })
		return
	end
	local data = PlayerData.Get(lifter)
	if not data or data.settings.spotRequests == "Off" then
		send(asker, "Refused", { reason = "RequestsOff", name = lifter.DisplayName })
		return
	end
	lastAsk[asker] = now
	requests[lifter] = requests[lifter] or {}
	requests[lifter][asker] = now + Spotting.RequestTimeout
	send(lifter, "Request", { userId = asker.UserId, name = asker.DisplayName, timeout = Spotting.RequestTimeout })
	send(asker, "Asked", { name = lifter.DisplayName })
end

local function respond(lifter, askerUserId, accept)
	if type(askerUserId) ~= "number" or type(accept) ~= "boolean" then return end
	local asker = Players:GetPlayerByUserId(askerUserId)
	local pending = requests[lifter]
	local expires = asker and pending and pending[asker]
	if not expires then return end
	pending[asker] = nil
	if os.clock() > expires then return end
	if not accept then
		send(asker, "Refused", { reason = "Declined", name = lifter.DisplayName })
		return
	end
	local model = machineOf(lifter)
	local why = blocked(asker, lifter, model)
	if why then
		send(asker, "Refused", { reason = why, name = lifter.DisplayName })
		return
	end
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	local spot = spots[model]
	if not spot then
		spot = { lifter = lifter, machine = machine, spotters = {}, order = {} }
		spots[model] = spot
	end
	spot.spotters[asker] = { taps = {}, recent = {}, clickingUntil = 0, reps = 0, slot = nil, at = nil }
	table.insert(spot.order, asker)
	spotting[asker] = model
	spot.key = nil
	layout(model)
	send(asker, "Started", { lifter = lifter.DisplayName, kind = machine.spotType, machine = machine.name })
	refresh(model)
end

------------------------------------------------------------------------
-- PUSH taps (the anti auto-clicker)
------------------------------------------------------------------------
local function push(player)
	local model = spotting[player]
	local spot = model and spots[model]
	local record = spot and spot.spotters[player]
	if not record then return end
	Spotting.Tap(record, os.clock())
	refresh(model)
end

------------------------------------------------------------------------
-- Reps (MachineService -> SocialService.OnRep -> here)
------------------------------------------------------------------------
function SpotService.OnRep(lifter)
	local model = machineOf(lifter)
	local spot = model and spots[model]
	if not spot or spot.lifter ~= lifter then return end
	local now = os.clock()
	for player, record in pairs(spot.spotters) do
		local data = PlayerData.Get(player)
		if data then
			record.reps += 1
			record.totalReps = (record.totalReps or 0) + 1
			PlayerData.SetStat(player, "spotReps", (data.stats.spotReps or 0) + 1)
			local clicking = now < record.clickingUntil
			local paid = nil
			if record.reps >= Spotting.RewardEvery then
				record.reps = 0
				paid = Spotting.RewardCoins + (if clicking then Spotting.RewardClickingCoins else 0)
				PlayerData.AddCoins(player, paid)
				record.totalCoins = (record.totalCoins or 0) + paid
			end
			-- every lifter rep reaches the spotter (their payout bar, the "assist" when they were pushing, the coins)
			send(player, "Rep", { progress = record.reps, every = Spotting.RewardEvery, assist = clicking, paid = paid })
			TitleService.Check(player)
		end
	end
end

------------------------------------------------------------------------
local function tick()
	local now = os.clock()
	for model, spot in pairs(spots) do
		-- the lifter left the machine
		if not spot.lifter.Parent or model:GetAttribute("UserId") ~= spot.lifter.UserId or not model.Parent then
			endAll(model, "LifterLeft")
			continue
		end
		for player, record in pairs(spot.spotters) do
			local root = rootOf(player)
			if not player.Parent or not root then
				stopSpotting(player, "Gone")
			elseif record.at and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(record.at.X, 0, record.at.Z)).Magnitude > Spotting.LeaveDistance then
				stopSpotting(player, "Moved")
			end
		end
		if spots[model] then refresh(model) end
	end
	-- requests that ran out
	for lifter, pending in pairs(requests) do
		for asker, expires in pairs(pending) do
			if now > expires then
				pending[asker] = nil
				send(lifter, "RequestClosed", { userId = asker.UserId })
				send(asker, "Refused", { reason = "NoAnswer", name = lifter.DisplayName })
			end
		end
	end
end

function SpotService.IsSpotting(player): boolean
	return spotting[player] ~= nil
end

function SpotService.Start()
	remote = Remotes:FindFirstChild("Spot") :: RemoteEvent
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "Spot"
		remote.Parent = Remotes
	end
	Guard.Remote(remote, "Spot", 20, 24, function(player, action, a, b)
		if action == "Request" then
			ask(player, a)
		elseif action == "Respond" then
			respond(player, a, b)
		elseif action == "Push" then
			push(player)
		elseif action == "Exit" then
			stopSpotting(player, "Exit")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		stopSpotting(player, "Gone")
		requests[player] = nil
		lastAsk[player] = nil
		for model, spot in pairs(spots) do
			if spot.lifter == player then endAll(model, "LifterLeft") end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function() stopSpotting(player, "Gone") end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterRemoving:Connect(function() stopSpotting(player, "Gone") end)
	end
	task.spawn(function()
		while true do
			task.wait(0.2)
			tick()
		end
	end)
end

return SpotService
