-- TrainerService (owner's feature run, task 7B; coin rolls since prompt 24, 21 Oct): personal trainers (Config/Trainers).
--   * The Trainer Agency: the desks at the front of each gym (invisible TrainerPoint parts, tag "TrainerDesk",
--     tools/builders/TrainerDesks; the odds boards: tools/builders/TrainerAgency) with the "Roll trainers" prompt; it opens
--     the Agency window (TrainerClient).
--   * Remote "Trainers": client -> server "Roll" (count 1 / 3, auto), "Equip" (slot, entry), "Unequip" (slot), "Golden" (id),
--     "AutoDelete" (rarity, on); server -> client "Open" | "Rolled" | "Failed" | "Golden", and to everyone "Pulled"
--     (Legendary or better: the whole server is told). Every roll is made HERE (Config.Trainers.Roll with the pity counter);
--     coins only. Saved in data.trainers (see Config/Trainers); old saves (a list of hired ids) become one of each.
--   * The equipped trainers' total boost (Trainers.Bonus, capped) is one BoostService source "Trainers" (gains, coins);
--     max stamina (PlayerData.RefreshMaxStamina) and progress (Config.GrowthSpurts / Config.Alters) read data.trainers.bonus.
--     The player attribute "Trainers" lists the following entries ("PumpCoach,RookieCoach@g") for every client to draw;
--     "TrainerSlots" the slots.
--   * The trainer models: one template per trainer, built here at start from a HumanoidDescription (NpcService), our own
--     clothing templates (none on the rare ones: they show their muscles), part-built props (look.extras) and the static
--     muscle stages; no name tag, nothing collides. Into ReplicatedStorage.TrainerModels; clients clone them.
-- Slots: Config.Trainers.SlotsFor (1, 2 at Growth Spurt 2, 3 at the first alter, +1 with the Extra Trainer pass).
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Trainers = require(ReplicatedStorage.Shared.Config.Trainers)
local PumpShop = require(ReplicatedStorage.Shared.Config.PumpShop)
local Alters = require(ReplicatedStorage.Shared.Config.Alters)
local PlayerData = require(script.Parent.PlayerData)
local BoostService = require(script.Parent.BoostService)
local NpcService = require(script.Parent.NpcService)
local BodyService = require(script.Parent.BodyService)
local Analytics = require(script.Parent.Analytics)
local BodyShape = require(ReplicatedStorage.Shared.BodyShape)
local Genetics = require(ReplicatedStorage.Shared.Config.Genetics)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local TrainerService = {}

local remote: RemoteEvent
local desks = {} -- TrainerPoint parts
local rng = Random.new()

local function send(player, kind, info)
	remote:FireClient(player, kind, info or {})
end

local function slotsOf(player): number
	local data = PlayerData.Get(player)
	local alter = data and Alters.State(data).highest or 0
	return Trainers.SlotsFor(player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) == true, data and data.growthSpurts or 0, alter)
end

-- a copy of the saved state (old saves migrated), safe to change
local function stateOf(player)
	local data = PlayerData.Get(player)
	local t = Trainers.Migrate(data and data.trainers)
	return { owned = table.clone(t.owned), golden = table.clone(t.golden), equipped = table.clone(t.equipped), rolls = t.rolls, pity = t.pity,
		autoDelete = table.clone(t.autoDelete) }
end

-- write the state, the boosts and the attributes everyone reads
local function apply(player, state)
	-- (owner's bug, 19 Oct: the save keeps up to the most slots anyone can have; only the trainers that follow you now are
	-- capped to your slots, so a slot that isn't known yet at join, like the pass, never loses its trainer)
	state.equipped = Trainers.CleanEquipped(state.equipped, state.owned, state.golden, Trainers.MaxSlots)
	local active = Trainers.CleanEquipped(state.equipped, state.owned, state.golden, slotsOf(player))
	local bonus = Trainers.Bonus(active)
	state.bonus = bonus
	if PlayerData.Get(player) then PlayerData.SetTable(player, "trainers", state) end
	BoostService.SetPlayer(player, "Trainers", if bonus.gains > 0 or bonus.coins > 0 then { gains = 1 + bonus.gains, coins = 1 + bonus.coins } else nil)
	for _, trainer in ipairs(Trainers.List) do BoostService.SetPlayer(player, "Trainer_" .. trainer.id, nil) end -- (the old per-trainer sources)
	PlayerData.RefreshMaxStamina(player)
	player:SetAttribute("Trainers", table.concat(active, ","))
	player:SetAttribute("TrainerSlots", slotsOf(player))
end

-- Growth Spurts and alters can add a slot (ActionService calls this after them)
function TrainerService.Refresh(player)
	if PlayerData.Get(player) then apply(player, stateOf(player)) end
end

local function rollPrice(player): number
	local data = PlayerData.Get(player)
	return Trainers.RollPrice(PumpShop.Rate(data and data.growthSpurts or 0))
end
TrainerService.RollPrice = rollPrice

local lastRoll = {} -- [player] = os.clock() (one roll request at a time)
local function roll(player, count, auto)
	local data = PlayerData.Get(player)
	if not data then return end
	if os.clock() - (lastRoll[player] or 0) < 0.35 then return end
	lastRoll[player] = os.clock()
	count = if count == Trainers.MultiRoll then Trainers.MultiRoll else 1
	if count > 1 and (data.growthSpurts or 0) < Trainers.MultiRollFromSpurt then
		send(player, "Failed", { text = "Roll x" .. Trainers.MultiRoll .. " opens at Growth Spurt " .. Trainers.MultiRollFromSpurt .. "." })
		return
	end
	local each = rollPrice(player)
	if not PlayerData.SpendCoins(player, each * count) then
		send(player, "Failed", { text = "Not enough coins", need = each * count, auto = auto == true })
		return
	end
	local state = stateOf(player)
	local slots = slotsOf(player)
	local results, refund = {}, 0
	local announceFrom = Trainers.RarityById[Trainers.AnnounceFrom].index
	for _ = 1, count do
		local rarityId
		rarityId, state.pity = Trainers.Roll(rng:NextNumber(), state.pity)
		-- Studio: Workspace attribute TestRollRarity = "Mythic" makes every roll that rarity (to see the reveals)
		local forced = if game:GetService("RunService"):IsStudio() then Workspace:GetAttribute("TestRollRarity") else nil
		if type(forced) == "string" and Trainers.RarityById[forced] then rarityId = forced end
		state.rolls += 1
		local trainer = Trainers.ByRarity[rarityId]
		local deleted = state.autoDelete[rarityId] == true and (state.owned[trainer.id] or 0) >= 1
		if deleted then
			refund += math.floor(each * Trainers.AutoDeleteRefund)
		else
			state.owned[trainer.id] = (state.owned[trainer.id] or 0) + 1
			-- a free slot: he starts following right away
			if #Trainers.CleanEquipped(state.equipped, state.owned, state.golden, slots) < slots then table.insert(state.equipped, trainer.id) end
		end
		table.insert(results, { id = trainer.id, rarity = rarityId, deleted = deleted, count = state.owned[trainer.id] or 0 })
		Analytics.Event(player, "TrainerRoll", Trainers.RarityById[rarityId].index)
		if Trainers.RarityById[rarityId].index >= announceFrom then
			remote:FireAllClients("Pulled", { userId = player.UserId, name = player.DisplayName, rarity = rarityId, trainer = trainer.id })
		end
	end
	if auto then Analytics.Event(player, "TrainerAutoRoll", count) end
	if refund > 0 then PlayerData.AddCoins(player, refund) end
	apply(player, state)
	send(player, "Rolled", { results = results, pity = state.pity, rolls = state.rolls, refund = refund, auto = auto == true })
end

local function equip(player, slot, entry)
	local id, golden = Trainers.ParseEntry(entry)
	slot = tonumber(slot)
	if not id or not slot then return end
	local slots = slotsOf(player)
	slot = math.floor(slot)
	if slot < 1 or slot > slots then return end
	local state = stateOf(player)
	local list = Trainers.CleanEquipped(state.equipped, state.owned, state.golden, slots)
	local key = Trainers.Entry(id, golden)
	-- enough of him for one more slot (duplicates can fill several slots)?
	local have = if golden then (state.golden[id] or 0) else (state.owned[id] or 0)
	local used = 0
	for i, e in ipairs(list) do
		if e == key and i ~= slot then used += 1 end
	end
	if used >= have then return end
	if slot > #list then table.insert(list, key) else list[slot] = key end
	state.equipped = list
	apply(player, state)
end

local function unequip(player, slot)
	slot = tonumber(slot)
	if not slot then return end
	local state = stateOf(player)
	local list = Trainers.CleanEquipped(state.equipped, state.owned, state.golden, slotsOf(player))
	if not list[math.floor(slot)] then return end
	table.remove(list, math.floor(slot))
	state.equipped = list
	apply(player, state)
end

-- 5 of the same trainer -> 1 Golden (1.5x his boost)
local function makeGolden(player, id)
	if type(id) ~= "string" or not Trainers.ById[id] then return end
	local state = stateOf(player)
	if (state.owned[id] or 0) < Trainers.GoldenCount then return end
	state.owned[id] -= Trainers.GoldenCount
	if state.owned[id] <= 0 then state.owned[id] = nil end
	state.golden[id] = (state.golden[id] or 0) + 1
	apply(player, state)
	Analytics.Event(player, "TrainerGolden", Trainers.ById[id].index)
	send(player, "Golden", { id = id })
end

local function setAutoDelete(player, rarity, on)
	if type(rarity) ~= "string" or not table.find(Trainers.AutoDeleteRarities, rarity) then return end
	local state = stateOf(player)
	state.autoDelete[rarity] = if on == true then true else nil
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
		elseif kind == "cape" then
			-- (prompt 24) a cape from the shoulders down the back (narrower than the shoulders), a collar bar across the top
			prop(model, "UpperTorso", "CapeCollar", nil, Vector3.new(ts.X * 0.9, 0.22, 0.3), CFrame.new(0, ts.Y * 0.42, ts.Z * 0.5), color, Enum.Material.Metal)
			prop(model, "UpperTorso", "Cape", nil, Vector3.new(ts.X * 0.8, ts.Y * 2.2, 0.08), CFrame.new(0, -ts.Y * 0.68, ts.Z * 0.62) * CFrame.Angles(math.rad(-8), 0, 0),
				color, Enum.Material.Fabric)
		elseif kind == "shorts" then
			-- (prompt 24) part-built shorts: round the waist and the top of each leg
			local shorts = look.shorts or "#1E1E22"
			prop(model, "LowerTorso", "Shorts", nil, Vector3.new(ws.X * 1.1, ws.Y * 1.2, ws.Z * 1.14), CFrame.new(0, -ws.Y * 0.05, 0), shorts, Enum.Material.Fabric)
			for _, side in ipairs({ "Left", "Right" }) do
				local leg = model:FindFirstChild(side .. "UpperLeg")
				local s = leg and leg.Size or Vector3.new(0.8, 1.2, 0.8)
				prop(model, side .. "UpperLeg", "ShortsLeg", nil, Vector3.new(s.X * 1.14, s.Y * 0.6, s.Z * 1.14), CFrame.new(0, s.Y * 0.2, 0), shorts, Enum.Material.Fabric)
			end
		elseif kind == "shoes" then
			for _, side in ipairs({ "Left", "Right" }) do
				local foot = model:FindFirstChild(side .. "Foot")
				local s = foot and foot.Size or Vector3.new(0.8, 0.3, 1)
				prop(model, side .. "Foot", "Shoe", nil, Vector3.new(s.X * 1.15, s.Y * 1.25, s.Z * 1.12), CFrame.new(0, 0.02, -0.03), "#1E1E22", Enum.Material.SmoothPlastic)
			end
		elseif kind == "hood" then
			-- (prompt 24) a hood over the back and top of the head (the face stays open)
			prop(model, "Head", "Hood", nil, Vector3.new(d * 1.22, hs.Y * 1.2, d * 0.75), CFrame.new(0, hs.Y * 0.08, d * 0.3), color, Enum.Material.Fabric)
			prop(model, "Head", "HoodTop", nil, Vector3.new(d * 1.22, 0.22, d * 1.05), CFrame.new(0, hs.Y * 0.62, 0.05), color, Enum.Material.Fabric)
			for _, side in ipairs({ -1, 1 }) do
				prop(model, "Head", "HoodSide", nil, Vector3.new(0.14, hs.Y * 1.05, d * 0.7), CFrame.new(side * d * 0.58, hs.Y * 0.05, -d * 0.05), color, Enum.Material.Fabric)
			end
		elseif kind == "crown" then
			-- (prompt 24) a small gold crown: a band and five points
			prop(model, "Head", "CrownBand", cyl, Vector3.new(0.28, d * 0.92, d * 0.92), CFrame.new(0, hs.Y / 2 + 0.12, 0) * UPRIGHT, color, Enum.Material.Metal)
			for i = 0, 4 do
				local a = math.rad(i * 72)
				prop(model, "Head", "CrownPoint", nil, Vector3.new(0.14, 0.34, 0.14),
					CFrame.new(math.cos(a) * d * 0.4, hs.Y / 2 + 0.38, math.sin(a) * d * 0.4) * CFrame.Angles(0, -a, 0), color, Enum.Material.Metal)
			end
		elseif kind == "shoulderpads" then
			-- (prompt 24) gold shoulder plates
			for _, side in ipairs({ -1, 1 }) do
				prop(model, "UpperTorso", "ShoulderPad", ball, Vector3.new(ts.X * 0.42, ts.Y * 0.32, ts.Z * 1.15), CFrame.new(side * ts.X * 0.5, ts.Y * 0.42, 0),
					color, Enum.Material.Metal)
			end
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
			-- (prompt 24: the rare ones have no shirt, they show their muscles)
			if look.shirt then
				local shirt = Instance.new("Shirt")
				shirt.ShirtTemplate = look.shirt
				shirt.Parent = model
			end
			if look.pants then
				local pants = Instance.new("Pants")
				pants.PantsTemplate = look.pants
				pants.Parent = model
			end
			if not look.shirt then model:SetAttribute("BareChest", true) end
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
		created.ActionText = "Roll trainers"
		created.ObjectText = "Trainer Agency"
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
	Guard.Remote(remote, "Trainers", 8, 4, function(player, action, a, b)
		if action == "Roll" then
			roll(player, tonumber(a), b == true)
		elseif action == "Equip" then
			equip(player, a, b)
		elseif action == "Unequip" then
			unequip(player, a)
		elseif action == "Golden" then
			makeGolden(player, a)
		elseif action == "AutoDelete" then
			setAutoDelete(player, a, b)
		end
	end)

	task.spawn(buildTemplates)
	Players.PlayerRemoving:Connect(function(player) lastRoll[player] = nil end)

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

	-- Studio: Workspace attribute TestTrainers = "RookieCoach,PumpCoach@g" gives every player those trainers and equips them
	-- (TestTrainerSlots = 2 acts out the Extra Trainer pass)
	if game:GetService("RunService"):IsStudio() then
		local function test()
			local list = Workspace:GetAttribute("TestTrainers")
			if type(list) ~= "string" then return end
			for _, player in ipairs(Players:GetPlayers()) do
				if Workspace:GetAttribute("TestTrainerSlots") == 2 then player:SetAttribute("Pass_" .. Trainers.ExtraSlotPass, true) end
				local state = stateOf(player)
				state.equipped = {}
				for entry in string.gmatch(list, "[^,]+") do
					local id, golden = Trainers.ParseEntry(entry)
					if id then
						local bag = if golden then state.golden else state.owned
						bag[id] = math.max(bag[id] or 0, 1)
						table.insert(state.equipped, entry)
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
