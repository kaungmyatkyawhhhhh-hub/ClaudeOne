-- TrainerService (owner's feature run, task 7B): personal trainers (Config/Trainers).
--   * Trainer Desks: invisible TrainerPoint parts in front of each desk (tag "TrainerDesk", tools/builders/TrainerDesks)
--     with the "Trainers" prompt; it opens the Trainers window.
--   * Remote "Trainers": client -> server "Hire" (anywhere, owner's UI v2: tapping a tile buys it; coins taken once),
--     "Equip", "Unequip"; server -> client
--     "Open" | "Hired" | "Failed". Saved in data.trainers = { owned = { ids }, equipped = { ids } }.
--   * The equipped trainers' perks are BoostService sources ("Trainer_<id>": gains / regen / coins / pump), and the player
--     attribute "Trainers" lists them ("RookieCoach,PumpCoach") so every client can draw them following that player.
--   * The trainer models: one template per trainer, built here at start (NpcService: the Robloxian body painted in his
--     picture's colors, a hat from parts, a clipboard in the right hand, no name tag; nothing collides) into
--     ReplicatedStorage.TrainerModels; clients clone them.
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

local function hire(player, id)
	local trainer = type(id) == "string" and Trainers.ById[id]
	if not trainer or not PlayerData.Get(player) then return end
	local state = stateOf(player)
	if table.find(state.owned, trainer.id) then return end
	if not PlayerData.SpendCoins(player, trainer.price) then
		send(player, "Failed", { text = "Not enough coins", id = trainer.id })
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

-- The hat from his picture, from parts welded to the head (short hair under it): "cap" (crown + brim + button),
-- "headband" (a band round the forehead), "visor" (a band + brim, no crown), "headphones" (a band over the top + ear cups).
local function hat(model, look)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then return end
	local size = head.Size
	local d = math.max(size.X, size.Z) -- head width
	local top = size.Y / 2
	local function piece(name, shape, partSize, offset: CFrame, hex)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = partSize
		p.Color = Color3.fromHex(hex)
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
		p.CFrame = head.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = head, p
		weld.Parent = p
		p.Parent = model
		return p
	end
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up (its axis is X)
	local cylinder, block = Enum.PartType.Cylinder, Enum.PartType.Block
	local color = look.hatColor or "#1E1E22"
	-- short hair: a flat cap of hair on the top of the head (under the cap / visor it barely shows)
	piece("Hair", cylinder, Vector3.new(0.22, d * 1.03, d * 1.03), CFrame.new(0, top - 0.08, 0.02) * upright, look.hair or "#2B2B30")
	if look.hat == "cap" then
		piece("CapCrown", cylinder, Vector3.new(0.42, d * 1.07, d * 1.07), CFrame.new(0, top - 0.02, 0.02) * upright, color)
		piece("CapTop", Enum.PartType.Ball, Vector3.new(d * 0.98, d * 0.98, d * 0.98) * Vector3.new(1, 0.4, 1), CFrame.new(0, top + 0.2, 0.02), color)
		piece("CapBrim", block, Vector3.new(d * 0.78, 0.07, d * 0.42), CFrame.new(0, top - 0.18, -d * 0.62) * CFrame.Angles(math.rad(-8), 0, 0), color)
		piece("CapButton", Enum.PartType.Ball, Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, top + 0.3, 0.02), color)
	elseif look.hat == "headband" then
		piece("Headband", cylinder, Vector3.new(0.2, d * 1.06, d * 1.06), CFrame.new(0, top - 0.32, 0) * upright, color)
	elseif look.hat == "visor" then
		piece("VisorBand", cylinder, Vector3.new(0.2, d * 1.06, d * 1.06), CFrame.new(0, top - 0.24, 0) * upright, color)
		piece("VisorBrim", block, Vector3.new(d * 0.8, 0.07, d * 0.44), CFrame.new(0, top - 0.3, -d * 0.62) * CFrame.Angles(math.rad(-10), 0, 0), color)
	elseif look.hat == "headphones" then
		piece("PhonesBand", block, Vector3.new(d * 1.1, 0.12, 0.2), CFrame.new(0, top + 0.12, 0.04), color)
		for _, side in ipairs({ -1, 1 }) do
			piece("PhonesSide", block, Vector3.new(0.12, 0.42, 0.2), CFrame.new(side * d * 0.55, top - 0.12, 0.04), color)
			piece("PhonesCup", cylinder, Vector3.new(0.18, 0.42, 0.42), CFrame.new(side * d * 0.56, -size.Y * 0.05, 0.04), color)
		end
	end
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
		local spec = { name = trainer.id, skin = look.skin, shirt = look.shirt, pants = look.pants, animated = true, noLabel = true }
		local ok, model = pcall(NpcService.Build, spec, CFrame.new(0, -500, 0))
		if ok and model then
			model.Name = trainer.id
			clipboard(model)
			hat(model, look)
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
