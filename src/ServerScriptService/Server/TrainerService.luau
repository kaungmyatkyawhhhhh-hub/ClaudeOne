-- TrainerService (owner's feature run, task 7B): personal trainers (Config/Trainers).
--   * Trainer Desks: invisible TrainerPoint parts in front of each desk (tag "TrainerDesk", tools/builders/TrainerDesks)
--     with the "Trainers" prompt; it opens the Trainers panel in hire mode.
--   * Remote "Trainers": client -> server "Hire" (near a desk, coins taken once), "Equip", "Unequip"; server -> client
--     "Open" | "Hired" | "Failed". Saved in data.trainers = { owned = { ids }, equipped = { ids } }.
--   * The equipped trainers' perks are BoostService sources ("Trainer_<id>": gains / regen / coins / pump), and the player
--     attribute "Trainers" lists them ("RookieCoach,PumpCoach") so every client can draw them following that player.
--   * The trainer models: one template per trainer, built here at start (NpcService: the Robloxian body, catalog clothes,
--     a clipboard in the right hand; nothing collides) into ReplicatedStorage.TrainerModels; clients clone them.
-- Slots: Config.Trainers.Slots, +1 with the Extra Trainer pass (player attribute Pass_ExtraTrainer, MonetizationService).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trainers = require(ReplicatedStorage.Shared.Config.Trainers)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local NpcService = require(script.Parent.NpcService)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local TrainerService = {}

local remote: RemoteEvent
local desks = {} -- TrainerPoint parts

local function send(player, kind, info)
	remote:FireClient(player, kind, info or {})
end

local function slotsOf(player): number
	return Trainers.SlotsFor(player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) == true)
end

local function stateOf(player)
	local data = PlayerData.Get(player)
	local t = data and type(data.trainers) == "table" and data.trainers or {}
	return { owned = type(t.owned) == "table" and table.clone(t.owned) or {}, equipped = type(t.equipped) == "table" and table.clone(t.equipped) or {} }
end

-- write the state, the perks and the attribute everyone reads
local function apply(player, state)
	state.equipped = Trainers.CleanEquipped(state.equipped, state.owned, slotsOf(player))
	if PlayerData.Get(player) then PlayerData.SetTable(player, "trainers", state) end
	local on = {}
	for _, id in ipairs(state.equipped) do on[id] = true end
	for _, trainer in ipairs(Trainers.List) do
		BoostService.SetPlayer(player, "Trainer_" .. trainer.id, on[trainer.id] and trainer.perk or nil)
	end
	player:SetAttribute("Trainers", table.concat(state.equipped, ","))
end

local function nearDesk(player): boolean
	for _, desk in ipairs(desks) do
		if desk.Parent and Guard.Near(player, desk, Trainers.DeskDistance + Guard.DistanceSlack) then return true end
	end
	return false
end

local function hire(player, id)
	local trainer = type(id) == "string" and Trainers.ById[id]
	if not trainer or not PlayerData.Get(player) then return end
	if not nearDesk(player) then
		send(player, "Failed", { text = "Hire trainers at a Trainer Desk at the front of any gym." })
		return
	end
	local state = stateOf(player)
	if table.find(state.owned, trainer.id) then return end
	if not PlayerData.SpendCoins(player, trainer.price) then
		send(player, "Failed", { text = trainer.name .. " costs " .. trainer.price .. " coins." })
		return
	end
	table.insert(state.owned, trainer.id)
	-- a free slot: he starts following right away
	if #state.equipped < slotsOf(player) then table.insert(state.equipped, trainer.id) end
	apply(player, state)
	send(player, "Hired", { id = trainer.id })
end

local function equip(player, id)
	local trainer = type(id) == "string" and Trainers.ById[id]
	if not trainer then return end
	local state = stateOf(player)
	if not table.find(state.owned, trainer.id) or table.find(state.equipped, trainer.id) then return end
	-- all slots full: he takes the last slot's place
	if #state.equipped >= slotsOf(player) then table.remove(state.equipped) end
	table.insert(state.equipped, trainer.id)
	apply(player, state)
end

local function unequip(player, id)
	local state = stateOf(player)
	local index = type(id) == "string" and table.find(state.equipped, id)
	if not index then return end
	table.remove(state.equipped, index)
	apply(player, state)
end

------------------------------------------------------------------------
-- Templates
------------------------------------------------------------------------
local function clipboard(model)
	local hand = model:FindFirstChild("RightHand")
	if not hand or not hand:IsA("BasePart") then return end
	local function piece(name, size, offset, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
		-- held flat against the forearm side, in front of the hand
		p.CFrame = hand.CFrame * CFrame.new(0, -0.35, -0.35) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = hand, p
		weld.Parent = p
		p.Parent = model
	end
	piece("Clipboard", Vector3.new(0.75, 1, 0.06), Vector3.zero, Color3.fromHex("#7A5230"), Enum.Material.Wood)
	piece("Paper", Vector3.new(0.62, 0.78, 0.02), Vector3.new(0, -0.06, -0.04), Color3.fromHex("#F4F1EA"), Enum.Material.SmoothPlastic)
	piece("Clip", Vector3.new(0.34, 0.12, 0.08), Vector3.new(0, 0.46, -0.03), Color3.fromHex("#C9CCD2"), Enum.Material.Metal)
end

-- Hair and hats: welded to the body part their attachment sits on (the clones on the clients carry the weld; without it
-- an accessory falls off as soon as the clone moves)
local function attachAccessories(model)
	for _, accessory in ipairs(model:GetChildren()) do
		local handle = accessory:IsA("Accessory") and accessory:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			for _, joint in ipairs(handle:GetChildren()) do
				if joint:IsA("JointInstance") or joint:IsA("WeldConstraint") then joint:Destroy() end
			end
			local own = handle:FindFirstChildOfClass("Attachment")
			local target = nil
			for _, d in ipairs(model:GetDescendants()) do
				if own and d:IsA("Attachment") and d.Name == own.Name and d.Parent ~= handle and d.Parent and d.Parent.Parent == model then target = d end
			end
			if own and target then
				handle.CFrame = target.WorldCFrame * own.CFrame:Inverse()
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = handle, target.Parent
				weld.Parent = handle
				handle.Anchored = false
				handle.Massless = true
			end
		end
	end
end

local function buildTemplates()
	local folder = ReplicatedStorage:FindFirstChild("TrainerModels")
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "TrainerModels"
	for _, trainer in ipairs(Trainers.List) do
		local look = trainer.look
		local spec = { name = trainer.coachName, skin = look.skin, shirtId = look.shirt, pantsId = look.pants, hairIds = { look.hair }, animated = true }
		local ok, model = pcall(NpcService.Build, spec, CFrame.new(0, -500, 0))
		if ok and model then
			model.Name = trainer.id
			model:SetAttribute("CoachName", trainer.coachName)
			clipboard(model)
			attachAccessories(model)
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					-- never blocks a player, a machine or a click
					part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
					if part.Name ~= "HumanoidRootPart" then part.CastShadow = part.Name == "UpperTorso" or part.Name == "LowerTorso" end
				elseif part:IsA("ProximityPrompt") then
					part:Destroy()
				end
			end
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
			model.Parent = folder
		else
			warn("[TrainerService] couldn't build " .. trainer.id .. ": " .. tostring(model))
		end
	end
	folder.Parent = ReplicatedStorage
end

------------------------------------------------------------------------
-- Desks
------------------------------------------------------------------------
local function addDesk(part)
	if not part:IsA("BasePart") or table.find(desks, part) then return end
	table.insert(desks, part)
	local prompt = part:FindFirstChild("TrainerPrompt")
	if not prompt then
		local created = Instance.new("ProximityPrompt")
		created.Name = "TrainerPrompt"
		created.ActionText = "Trainers"
		created.ObjectText = "Trainer Desk"
		created.MaxActivationDistance = Trainers.DeskDistance
		created.RequiresLineOfSight = false
		created.Parent = part
		prompt = created
	end
	Guard.OnTriggered(prompt, function(player)
		if PlayerData.Get(player) then send(player, "Open", { desk = true }) end
	end)
end

function TrainerService.Start()
	local existing = Remotes:FindFirstChild("Trainers")
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = "Trainers"
		created.Parent = Remotes
		remote = created
	end
	Guard.Remote(remote, "Trainers", 3, 4, function(player, action, id)
		if action == "Hire" then
			hire(player, id)
		elseif action == "Equip" then
			equip(player, id)
		elseif action == "Unequip" then
			unequip(player, id)
		end
	end)

	task.spawn(buildTemplates)

	if #CollectionService:GetTagged("TrainerDesk") == 0 then
		warn("[TrainerService] no Trainer Desks (tag TrainerDesk): build them with tools/builders/TrainerDesks.luau")
	end
	for _, part in ipairs(CollectionService:GetTagged("TrainerDesk")) do addDesk(part) end
	CollectionService:GetInstanceAddedSignal("TrainerDesk"):Connect(addDesk)

	local function ready(player)
		apply(player, stateOf(player))
		-- the pass (bought later, or found at join) adds a slot
		player:GetAttributeChangedSignal("Pass_" .. Trainers.ExtraSlotPass):Connect(function() apply(player, stateOf(player)) end)
	end
	PlayerData.Loaded:Connect(ready)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Get(player) then ready(player) end
	end

	-- Studio: Workspace attribute TestTrainers = "RookieCoach,PumpCoach" gives every player those trainers and equips them
	-- (TestTrainerSlots = 2 acts out the Extra Trainer pass)
	if game:GetService("RunService"):IsStudio() then
		local function test()
			local list = Workspace:GetAttribute("TestTrainers")
			if type(list) ~= "string" then return end
			for _, player in ipairs(Players:GetPlayers()) do
				if Workspace:GetAttribute("TestTrainerSlots") == 2 then player:SetAttribute("Pass_" .. Trainers.ExtraSlotPass, true) end
				local state = stateOf(player)
				state.equipped = {}
				for id in string.gmatch(list, "[^,]+") do
					if Trainers.ById[id] then
						if not table.find(state.owned, id) then table.insert(state.owned, id) end
						table.insert(state.equipped, id)
					end
				end
				apply(player, state)
			end
		end
		Workspace:GetAttributeChangedSignal("TestTrainers"):Connect(test)
		Workspace:GetAttributeChangedSignal("TestTrainerSlots"):Connect(test)
	end
end

return TrainerService
