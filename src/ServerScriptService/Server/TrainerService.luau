-- TrainerService (owner's feature run, task 7B): personal trainers (Config/Trainers).
--   * Trainer Desks: invisible TrainerPoint parts in front of each desk (tag "TrainerDesk", tools/builders/TrainerDesks)
--     with the "Trainers" prompt; it opens the Trainers window.
--   * Remote "Trainers": client -> server "Hire" (anywhere, owner's UI v2: tapping a tile buys it; coins taken once),
--     "Equip", "Unequip"; server -> client
--     "Open" | "Hired" | "Failed". Saved in data.trainers = { owned = { ids }, equipped = { ids } }.
--   * The equipped trainers' perks are BoostService sources ("Trainer_<id>": gains / regen / coins / pump), and the player
--     attribute "Trainers" lists them ("RookieCoach,PumpCoach") so every client can draw them following that player.
--   * The trainer models (owner, 14 Oct: real gym coaches): one template per trainer, built here at start from a
--     HumanoidDescription (NpcService: the Robloxian R15 body, Roblox's own free catalog hair and face), our own clothing
--     templates (Shirt / Pants images), small part-built props (look.extras) and the static muscle stages ("MuscleG",
--     MuscleClient; the Pump coach the biggest); no name tag, nothing collides. Into ReplicatedStorage.TrainerModels;
--     clients clone them.
-- Slots: Config.Trainers.Slots, +1 with the Extra Trainer pass (player attribute Pass_ExtraTrainer, MonetizationService).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trainers = require(ReplicatedStorage.Shared.Config.Trainers)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local NpcService = require(script.Parent.NpcService)
local BodyService = require(script.Parent.BodyService)
local BodyShape = require(ReplicatedStorage.Shared.BodyShape)
local Genetics = require(ReplicatedStorage.Shared.Config.Genetics)
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
	-- (owner's bug, 19 Oct: "when I rejoin my trainer disappears". At join the Extra Trainer pass isn't known yet: the list was
	-- cut to 1 slot and SAVED that way, so the second trainer was gone for good. The save keeps up to the most slots anyone
	-- can have; only the trainers that follow you now are capped to your slots.)
	state.equipped = Trainers.CleanEquipped(state.equipped, state.owned, Trainers.SlotsFor(true))
	if PlayerData.Get(player) then PlayerData.SetTable(player, "trainers", state) end
	local active = Trainers.CleanEquipped(state.equipped, state.owned, slotsOf(player))
	local on = {}
	for _, id in ipairs(active) do on[id] = true end
	for _, trainer in ipairs(Trainers.List) do
		BoostService.SetPlayer(player, "Trainer_" .. trainer.id, on[trainer.id] and trainer.perk or nil)
	end
	player:SetAttribute("Trainers", table.concat(active, ","))
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
	if not table.find(state.owned, trainer.id) then return end
	-- (only the trainers that follow now count: a saved one past your slots is dropped when you pick another)
	state.equipped = Trainers.CleanEquipped(state.equipped, state.owned, slotsOf(player))
	if table.find(state.equipped, trainer.id) then return end
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
-- The small props each trainer carries (Config/Trainers look.extras), built from parts welded to his body. Kept small
-- and close to the body so nothing floats or clips: a whistle on a cord, a headband, a water bottle in the left hand,
-- a cap, a clipboard in the right hand, a lifting belt round the waist, wrist wraps.
local function prop(model, partName, name, shape, size, offset: CFrame, hex, material)
	local base = model:FindFirstChild(partName)
	if not base or not base:IsA("BasePart") then return nil end
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = Color3.fromHex(hex)
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
	p.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = base, p
	weld.Parent = p
	p.Parent = model
	return p
end

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up (its axis is X)
local function extras(model, look)
	local color = look.extraColor or "#1E1E22"
	local cyl, ball = Enum.PartType.Cylinder, Enum.PartType.Ball
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	local waist = model:FindFirstChild("LowerTorso")
	local hs = head and head.Size or Vector3.new(1.2, 1.2, 1.2)
	local ts = torso and torso.Size or Vector3.new(2, 1.6, 1)
	local ws = waist and waist.Size or Vector3.new(2, 0.4, 1)
	local d = math.max(hs.X, hs.Z)
	for _, kind in ipairs(look.extras or {}) do
		if kind == "whistle" then
			-- a thin cord from the neck down the chest to a small silver whistle
			for _, side in ipairs({ -1, 1 }) do
				prop(model, "UpperTorso", "WhistleCord", nil, Vector3.new(0.05, ts.Y * 0.45, 0.05),
					CFrame.new(side * ts.X * 0.12, ts.Y * 0.22, -ts.Z * 0.62) * CFrame.Angles(0, 0, side * math.rad(-14)), color)
			end
			prop(model, "UpperTorso", "Whistle", cyl, Vector3.new(0.34, 0.2, 0.2), CFrame.new(0, -ts.Y * 0.02, -ts.Z * 0.66), "#D9DCE0", Enum.Material.Metal)
			prop(model, "UpperTorso", "WhistleRing", cyl, Vector3.new(0.06, 0.14, 0.14), CFrame.new(-0.16, -ts.Y * 0.02 + 0.04, -ts.Z * 0.66), "#9EA3AA", Enum.Material.Metal)
		elseif kind == "headband" then
			prop(model, "Head", "Headband", cyl, Vector3.new(0.2, d * 1.06, d * 1.06), CFrame.new(0, hs.Y * 0.18, 0) * UPRIGHT, color, Enum.Material.Fabric)
		elseif kind == "bottle" then
			local hand = "LeftHand"
			prop(model, hand, "Bottle", cyl, Vector3.new(0.7, 0.32, 0.32), CFrame.new(0, -0.18, -0.12) * UPRIGHT, "#2FAE55")
			prop(model, hand, "BottleCap", cyl, Vector3.new(0.14, 0.26, 0.26), CFrame.new(0, 0.24, -0.12) * UPRIGHT, color)
		elseif kind == "cap" then
			prop(model, "Head", "CapCrown", cyl, Vector3.new(0.42, d * 1.07, d * 1.07), CFrame.new(0, hs.Y / 2 - 0.02, 0.02) * UPRIGHT, color)
			prop(model, "Head", "CapTop", ball, Vector3.new(d * 0.98, d * 0.4, d * 0.98), CFrame.new(0, hs.Y / 2 + 0.2, 0.02), color)
			prop(model, "Head", "CapBrim", nil, Vector3.new(d * 0.78, 0.07, d * 0.42), CFrame.new(0, hs.Y / 2 - 0.18, -d * 0.62) * CFrame.Angles(math.rad(-8), 0, 0), color)
			prop(model, "Head", "CapLogo", nil, Vector3.new(d * 0.3, 0.16, 0.04), CFrame.new(0, hs.Y / 2 + 0.06, -d * 0.53), "#E0B23A") -- (a plain gold patch, no brand)
		elseif kind == "clipboard" then
			local o = CFrame.new(0, -0.35, -0.35) * CFrame.Angles(math.rad(-20), 0, 0)
			prop(model, "RightHand", "Clipboard", nil, Vector3.new(0.75, 1, 0.06), o, "#7A5230", Enum.Material.Wood)
			prop(model, "RightHand", "Paper", nil, Vector3.new(0.62, 0.78, 0.02), o * CFrame.new(0, -0.06, -0.04), "#F4F1EA")
			prop(model, "RightHand", "Clip", nil, Vector3.new(0.34, 0.12, 0.08), o * CFrame.new(0, 0.46, -0.03), "#C9CCD2", Enum.Material.Metal)
		elseif kind == "belt" then
			-- a wide leather lifting belt round the waist (over the muscle meshes: a little wider than the waist) + a buckle
			local w = math.max(ws.X, ws.Z) * 1.22
			prop(model, "LowerTorso", "Belt", cyl, Vector3.new(ws.Y * 0.95, w, w * 0.62), CFrame.new(0, ws.Y * 0.15, 0) * UPRIGHT, "#3A2414", Enum.Material.Leather)
			prop(model, "LowerTorso", "Buckle", nil, Vector3.new(0.5, ws.Y * 0.7, 0.08), CFrame.new(0, ws.Y * 0.15, -w * 0.31 - 0.03), "#C9CCD2", Enum.Material.Metal)
		elseif kind == "wraps" then
			for _, side in ipairs({ "Left", "Right" }) do
				local arm = model:FindFirstChild(side .. "LowerArm")
				local s = arm and arm.Size or Vector3.new(0.6, 1, 0.6)
				prop(model, side .. "LowerArm", "WristWrap", cyl, Vector3.new(s.Y * 0.28, math.max(s.X, s.Z) * 1.18, math.max(s.X, s.Z) * 1.18),
					CFrame.new(0, -s.Y * 0.34, 0) * UPRIGHT, color, Enum.Material.Fabric)
			end
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
		-- (the body under the clothes is skin colored: the clothing templates have bare parts, arms in a tank, legs in shorts)
		local spec = { name = trainer.id, skin = look.skin, shirt = look.skin, pants = look.skin, hairIds = look.hairIds, faceId = look.faceId,
			animated = true, noLabel = true }
		local ok, model = pcall(NpcService.Build, spec, CFrame.new(0, -500, 0))
		if ok and model then
			model.Name = trainer.id
			-- his height (owner, 19 Oct: Config/Trainers heightInches, the players' height system; the whole rig scales with
			-- the same body, proportions and widths; clients put his feet on the floor from his hip height)
			if trainer.heightInches then
				local scale = math.min(trainer.heightInches, 84) / BodyShape.BaseHeight
				NpcService.ApplyBody(model, scale)
				-- (owner, 19 Oct: width grows with height, no thin stick frames) every width and depth by the same amount as the
				-- height, the frame's shoulders and the full-look shoulder bonus on top
				local shoulders = scale * Genetics.ShoulderWidth(trainer.frame) * (trainer.shoulderBonus or 1)
				local f = { shoulders = shoulders, hips = scale, arms = scale, legs = scale, depth = scale }
				BodyShape.ApplyWidths(model, f)
				model:SetAttribute("BodyWidths", string.format("%.3f,%.3f,%.3f,%.3f,%.3f", f.shoulders, f.hips, f.arms, f.legs, f.depth))
				model:SetAttribute("FrameWidth", f.shoulders)
				model:SetAttribute("WaistWidth", f.hips)
			end
			-- our own clothes (image templates), a face texture when he has one, his props
			for _, old in ipairs(model:GetChildren()) do
				if old:IsA("Shirt") or old:IsA("Pants") or old:IsA("ShirtGraphic") then old:Destroy() end
			end
			local shirt = Instance.new("Shirt")
			shirt.ShirtTemplate = look.shirt
			shirt.Parent = model
			local pants = Instance.new("Pants")
			pants.PantsTemplate = look.pants
			pants.Parent = model
			-- his face: the description's head is a dynamic head whose own face is blank, and face images map wrongly onto
			-- it, so it is hidden under a classic Roblox head (the "Head" mesh) carrying the face image, welded in its place
			local head = model:FindFirstChild("Head")
			if look.faceTexture and head and head:IsA("BasePart") then
				local old = head:FindFirstChild("face")
				if old then old:Destroy() end
				head.Transparency = 1
				local classic = Instance.new("Part")
				classic.Name = "ClassicHead"
				classic.Size = Vector3.new(2, 1, 1)
				classic.Color = head.Color
				classic.Material = Enum.Material.SmoothPlastic
				classic.CanCollide, classic.CanQuery, classic.CanTouch, classic.Massless = false, false, false, true
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Head
				mesh.Scale = Vector3.new(1.25, 1.25, 1.25) * (head.Size.Y / 1.2)
				mesh.Parent = classic
				local face = Instance.new("Decal")
				face.Name = "face"
				face.Face = Enum.NormalId.Front
				face.Texture = look.faceTexture
				face.Parent = classic
				classic.CFrame = head.CFrame
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = head, classic
				weld.Parent = classic
				classic.Parent = model
			end
			extras(model, look)
			attachAccessories(model)
			-- his muscles: the static muscle stages, like every NPC (MuscleClient reads this; Pump coach the biggest)
			model:SetAttribute("MuscleG", BodyService.EncodeShare(look.muscle or 1))
			model:SetAttribute("Trainer", trainer.id)
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
	-- (owner, 14 Oct: trainers never bump into players) a collision group that collides with nothing; TrainerFollowClient
	-- puts every part of the trainer models in it (groups are registered here, on the server, and replicate)
	local PhysicsService = game:GetService("PhysicsService")
	pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered("Trainers") then PhysicsService:RegisterCollisionGroup("Trainers") end
		for _, group in ipairs(PhysicsService:GetRegisteredCollisionGroups()) do
			PhysicsService:CollisionGroupSetCollidable("Trainers", group.name, false)
		end
	end)
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
