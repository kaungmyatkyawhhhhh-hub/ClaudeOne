-- TrainerService (owner's feature run, task 7B; coin rolls since prompt 24, 21 Oct): personal trainers (Config/Trainers).
--   * The Trainer Agency: the desks at the front of each gym (invisible TrainerPoint parts, tag "TrainerDesk",
--     tools/builders/TrainerDesks; the odds boards: tools/builders/TrainerAgency) with the "Roll trainers" prompt; it opens
--     the Agency window (TrainerClient).
--   * Remote "Trainers": client -> server "Roll" (count 1 / 3, auto), "Equip" (slot, copy uid), "Unequip" (slot), "Evolve"
--     (copy uid), "EvolveAll", "AutoDelete" (rarity, on); server -> client "Open" | "Rolled" | "Failed" | "Evolved" |
--     "LevelUp", and to everyone "Pulled" and (prompt 33) "Discovered" (a player reached a stage for the first time)
--     (Legendary or better: the whole server is told). Every roll is made HERE (Config.Trainers.Roll with the pity counter);
--     coins only. Saved in data.trainers (see Config/Trainers); old saves (a list of hired ids) become one of each.
--   * The equipped trainers' total boost (Trainers.Bonus, capped) is one BoostService source "Trainers" (gains, coins);
--     max stamina (PlayerData.RefreshMaxStamina) and progress (Config.GrowthSpurts / Config.Alters) read data.trainers.bonus.
--     The player attribute "Trainers" lists the following entries ("PumpCoach,RookieCoach@3": @stage) for every client to draw;
--     "TrainerSlots" the slots.
--   * The trainer models: one template per trainer, built here at start from a HumanoidDescription (NpcService), our own
--     outfit (prompt 34: images on the muscle stage pieces, Shared/Outfit, never a classic Shirt / Pants), part-built props (look.extras) and the static
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
local Gear = require(ReplicatedStorage.Shared.Gear)
local Genetics = require(ReplicatedStorage.Shared.Config.Genetics)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local TrainerService = {}

local remote: RemoteEvent
local desks = {} -- TrainerPoint parts
local rng = Random.new()
local flushXp -- (below: trainer levels)

local function send(player, kind, info)
	remote:FireClient(player, kind, info or {})
end

local function slotsOf(player): number
	local data = PlayerData.Get(player)
	local alter = data and Alters.State(data).highest or 0
	return Trainers.SlotsFor(player:GetAttribute("Pass_" .. Trainers.ExtraSlotPass) == true, data and data.growthSpurts or 0, alter)
end

-- a copy of the saved state (old saves migrated: Trainers.Migrate), safe to change
local function stateOf(player)
	local data = PlayerData.Get(player)
	local t = Trainers.Migrate(data and data.trainers)
	local copies = {}
	for _, copy in ipairs(t.copies) do table.insert(copies, table.clone(copy)) end
	return { copies = copies, equipped = table.clone(t.equipped), discovered = t.discovered and table.clone(t.discovered), nextUid = t.nextUid,
		rolls = t.rolls, pity = t.pity, autoDelete = table.clone(t.autoDelete), freeRolls = t.freeRolls, rebalance = t.rebalance }
end

-- (prompt 33) trainer EXP from reps waits here ([player] = { [uid] = exp }) and is saved every FlushSeconds or on a level up
local pendingXp = {}

-- write the state, the boosts and the attributes everyone reads
local function apply(player, state)
	-- (owner's bug, 19 Oct: the save keeps up to the most slots anyone can have; only the trainers that follow you now are
	-- capped to your slots, so a slot that isn't known yet at join, like the pass, never loses its trainer)
	state.equipped = Trainers.CleanEquipped(state, Trainers.MaxSlots)
	local _, active = Trainers.CleanEquipped(state, slotsOf(player))
	local bonus = Trainers.Bonus(active)
	state.bonus = bonus
	if PlayerData.Get(player) then PlayerData.SetTable(player, "trainers", state) end
	-- (prompt 25: staminaRegen = the stamina refill, BoostService.Regen)
	BoostService.SetPlayer(player, "Trainers", if bonus.gains > 0 or bonus.coins > 0 or bonus.staminaRegen > 0
		then { gains = 1 + bonus.gains, coins = 1 + bonus.coins, regen = 1 + bonus.staminaRegen } else nil)
	for _, trainer in ipairs(Trainers.List) do BoostService.SetPlayer(player, "Trainer_" .. trainer.id, nil) end -- (the old per-trainer sources)
	PlayerData.RefreshMaxStamina(player)
	-- every client draws them from these: "PumpCoach,VoltaCoach@3" (prompt 33: @stage)
	local entries = {}
	for _, copy in ipairs(active) do table.insert(entries, Trainers.Entry(copy.id, copy.s)) end
	player:SetAttribute("Trainers", table.concat(entries, ","))
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

local function newCopy(state, id: string, stage: number, level: number?)
	local copy = { u = state.nextUid, id = id, s = stage, l = level or 1, x = 0 }
	state.nextUid += 1
	table.insert(state.copies, copy)
	-- (owner, 23 Oct) the stage counts as discovered from now on (the evolutions chart), even after this copy is gone
	state.discovered = state.discovered or { Base = true }
	if Trainers.Stages[stage] then state.discovered[Trainers.Stages[stage].id] = true end
	return copy
end
local function hasTrainer(state, id: string): boolean
	for _, copy in ipairs(state.copies) do
		if copy.id == id then return true end
	end
	return false
end

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
	local state = stateOf(player)
	-- (prompt 27c) a free roll (the rebalance gift) goes before coins, one roll at a time
	if count == 1 and state.freeRolls > 0 then
		state.freeRolls -= 1
	elseif not PlayerData.SpendCoins(player, each * count) then
		send(player, "Failed", { text = "Not enough coins", need = each * count, auto = auto == true })
		return
	end
	local slots = slotsOf(player)
	local results, refund = {}, 0
	for _ = 1, count do
		local rarityId
		rarityId, state.pity = Trainers.Roll(rng:NextNumber(), state.pity)
		-- Studio: Workspace attribute TestRollRarity = "Mythic" makes every roll that rarity (to see the reveals)
		local forced = if game:GetService("RunService"):IsStudio() then Workspace:GetAttribute("TestRollRarity") else nil
		if type(forced) == "string" and Trainers.RarityById[forced] then rarityId = forced end
		state.rolls += 1
		local trainer = Trainers.ByRarity[rarityId]
		-- (auto-delete only the rarities the player picked, and only a duplicate; a full collection pays out too)
		local deleted = (state.autoDelete[rarityId] == true and hasTrainer(state, trainer.id)) or #state.copies >= Trainers.MaxCopies
		if deleted then
			refund += math.floor(each * Trainers.AutoDeleteRefund)
		else
			local copy = newCopy(state, trainer.id, 1)
			-- a free slot: he starts following right away
			if #Trainers.CleanEquipped(state, slots) < slots then table.insert(state.equipped, copy.u) end
		end
		-- (count = his BASE copies, toward the next evolution; new = the first of him at any stage)
		local same, any = 0, 0
		for _, c in ipairs(state.copies) do
			if c.id == trainer.id then
				any += 1
				if c.s == 1 then same += 1 end
			end
		end
		table.insert(results, { id = trainer.id, rarity = rarityId, deleted = deleted, count = same, new = not deleted and any == 1 })
		Analytics.Event(player, "TrainerRoll", Trainers.RarityById[rarityId].index)
		-- (owner, prompt 48: only Secret and Eternal are told to the whole server)
		if Trainers.RarityById[rarityId].announce == "banner" then
			remote:FireAllClients("Pulled", { userId = player.UserId, name = player.DisplayName, rarity = rarityId, trainer = trainer.id })
		end
	end
	if auto then Analytics.Event(player, "TrainerAutoRoll", count) end
	if refund > 0 then PlayerData.AddCoins(player, refund) end
	apply(player, state)
	send(player, "Rolled", { results = results, pity = state.pity, rolls = state.rolls, refund = refund, auto = auto == true })
end

-- (prompt 33) equip a copy into a slot (an empty slot past the list = add it; a copy already following moves there)
local function equip(player, slot, uid)
	slot, uid = tonumber(slot), tonumber(uid)
	if not slot or not uid then return end
	local slots = slotsOf(player)
	slot = math.floor(slot)
	if slot < 1 or slot > slots then return end
	local state = stateOf(player)
	if not Trainers.CopyByUid(state)[uid] then return end
	local list = Trainers.CleanEquipped(state, slots)
	local at = table.find(list, uid)
	if at then table.remove(list, at) end
	if slot > #list then table.insert(list, uid) else list[slot] = uid end
	state.equipped = list
	apply(player, state)
end

local function unequip(player, slot)
	slot = tonumber(slot)
	if not slot then return end
	local state = stateOf(player)
	local list = Trainers.CleanEquipped(state, slotsOf(player))
	if not list[math.floor(slot)] then return end
	table.remove(list, math.floor(slot))
	state.equipped = list
	apply(player, state)
end

-- 3 of the same trainer at the same stage -> 1 at the next, keeping the highest level; it takes the slot of one that was following
local function combine(state, set)
	local first = set[1]
	local level = 1
	local slot = nil
	for _, c in ipairs(set) do
		level = math.max(level, c.l)
		local at = table.find(state.equipped, c.u)
		if at and (not slot or at < slot) then slot = at end
	end
	local remove = {}
	for _, c in ipairs(set) do remove[c.u] = true end
	for i = #state.copies, 1, -1 do
		if remove[state.copies[i].u] then table.remove(state.copies, i) end
	end
	for i = #state.equipped, 1, -1 do
		if remove[state.equipped[i]] then table.remove(state.equipped, i) end
	end
	local made = newCopy(state, first.id, first.s + 1, level)
	if slot then table.insert(state.equipped, math.min(slot, #state.equipped + 1), made.u) end
	return made
end

local lastEvolve = {}
local function evolve(player, uid)
	uid = tonumber(uid)
	if not uid or os.clock() - (lastEvolve[player] or 0) < 0.4 then return end
	lastEvolve[player] = os.clock()
	flushXp(player)
	local state = stateOf(player)
	local copy = Trainers.CopyByUid(state)[uid]
	if not copy or copy.s >= #Trainers.Stages then return end
	local set = Trainers.EvolveSet(state, copy)
	if #set < Trainers.EvolveCount then return end
	local made = combine(state, set)
	apply(player, state)
	Analytics.Event(player, "TrainerEvolve", made.s)
	send(player, "Evolved", { results = { { id = made.id, stage = made.s, level = made.l, u = made.u } } })
end

-- every set there is, lowest stages first (so a fresh IRON-BORN set goes on to BEAST-MODE in the same go)
local function evolveAll(player)
	if os.clock() - (lastEvolve[player] or 0) < 0.4 then return end
	lastEvolve[player] = os.clock()
	flushXp(player)
	local state = stateOf(player)
	local results = {}
	for stage = 1, #Trainers.Stages - 1 do
		for _, trainer in ipairs(Trainers.List) do
			while true do
				local group = {}
				for _, c in ipairs(state.copies) do
					if c.id == trainer.id and c.s == stage then table.insert(group, c) end
				end
				if #group < Trainers.EvolveCount then break end
				-- (the highest levels together: each new one keeps the best level of its 3)
				table.sort(group, function(a, b) return a.l > b.l end)
				local made = combine(state, { group[1], group[2], group[3] })
				table.insert(results, { id = made.id, stage = made.s, level = made.l, u = made.u })
			end
		end
	end
	if #results == 0 then return end
	apply(player, state)
	Analytics.Event(player, "TrainerEvolveAll", #results)
	send(player, "Evolved", { results = results, all = true })
end

local function setAutoDelete(player, rarity, on)
	if type(rarity) ~= "string" or not table.find(Trainers.AutoDeleteRarities, rarity) then return end
	local state = stateOf(player)
	state.autoDelete[rarity] = if on == true then true else nil
	apply(player, state)
end

------------------------------------------------------------------------
-- (prompt 33) Trainer levels: every equipped trainer gains trainer EXP from your reps
------------------------------------------------------------------------
-- puts the waiting EXP into the save (level ups included); -> the level ups { { id, level } }
function flushXp(player)
	local pending = pendingXp[player]
	if not pending or next(pending) == nil then return {} end
	pendingXp[player] = {}
	local state = stateOf(player)
	local map = Trainers.CopyByUid(state)
	local ups = {}
	for u, xp in pairs(pending) do
		local copy = map[u]
		if copy and copy.l < Trainers.MaxLevel then
			copy.x += xp
			while copy.l < Trainers.MaxLevel and copy.x >= Trainers.LevelXp(copy.l, copy.s) do
				copy.x -= Trainers.LevelXp(copy.l, copy.s)
				copy.l += 1
				table.insert(ups, { id = copy.id, level = copy.l, stage = copy.s, u = copy.u })
			end
			if copy.l >= Trainers.MaxLevel then copy.x = 0 end
		end
	end
	apply(player, state)
	return ups
end

-- MachineService calls this on every rep (gains = the weight tier's multiplier)
function TrainerService.OnRep(player, gains: number?)
	local data = PlayerData.Get(player)
	if not data then return end
	local t = Trainers.Migrate(data.trainers)
	local _, active = Trainers.CleanEquipped(t, slotsOf(player))
	if #active == 0 then return end
	local pending = pendingXp[player] or {}
	pendingXp[player] = pending
	local xp = Trainers.RepXp(gains)
	local levelUp = false
	for _, copy in ipairs(active) do
		if copy.l < Trainers.MaxLevel then
			pending[copy.u] = (pending[copy.u] or 0) + xp
			if copy.x + pending[copy.u] >= Trainers.LevelXp(copy.l, copy.s) then levelUp = true end
		end
	end
	if levelUp then
		for _, up in ipairs(flushXp(player)) do send(player, "LevelUp", up) end
	end
end

------------------------------------------------------------------------
-- Templates
------------------------------------------------------------------------
-- The small props each trainer carries (Config/Trainers look.extras), built from parts welded to his body. Kept small
-- and close to the body so nothing floats or clips: a headband, a water bottle in the left hand, a cap, a clipboard in
-- the right hand. (prompt 34: whistles, belts, wraps, knee sleeves and cuffs are the gear meshes, Shared/Gear; the box
-- shorts and Volta's tied jacket are gone, the outfit is on the muscle pieces)
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
	local hs = head and head.Size or Vector3.new(1.2, 1.2, 1.2)
	local ts = torso and torso.Size or Vector3.new(2, 1.6, 1)
	local d = math.max(hs.X, hs.Z)
	for _, kind in ipairs(look.extras or {}) do
		if kind == "headband" then
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
		elseif kind == "cape" then
			-- (prompt 24) a cape from the shoulders down the back (narrower than the shoulders), a collar bar across the top
			prop(model, "UpperTorso", "CapeCollar", nil, Vector3.new(ts.X * 0.9, 0.22, 0.3), CFrame.new(0, ts.Y * 0.42, ts.Z * 0.5), color, Enum.Material.Metal)
			prop(model, "UpperTorso", "Cape", nil, Vector3.new(ts.X * 0.8, ts.Y * 2.2, 0.08), CFrame.new(0, -ts.Y * 0.68, ts.Z * 0.62) * CFrame.Angles(math.rad(-8), 0, 0),
				color, Enum.Material.Fabric)
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
		elseif kind == "buzzcut" then
			-- short grey hair: a thin shell over the top and the back of the head (the face stays clear)
			local hair = look.hair or "#2A2A2E"
			prop(model, "Head", "BuzzTop", ball, Vector3.new(d * 1.04, hs.Y * 0.42, d * 1.04), CFrame.new(0, hs.Y * 0.36, d * 0.03), hair, Enum.Material.Sand)
			prop(model, "Head", "BuzzBack", ball, Vector3.new(d * 1.02, hs.Y * 0.78, d * 0.62), CFrame.new(0, hs.Y * 0.1, d * 0.24), hair, Enum.Material.Sand)
		elseif kind == "beard" then
			-- a short grey beard hugging the jaw and chin (rounded, under the mouth), a thin moustache over it
			local hair = look.hair or "#2A2A2E"
			prop(model, "Head", "Beard", ball, Vector3.new(d * 1.0, hs.Y * 0.46, d * 0.86), CFrame.new(0, -hs.Y * 0.36, -d * 0.1), hair, Enum.Material.Sand)
			prop(model, "Head", "Moustache", ball, Vector3.new(d * 0.42, hs.Y * 0.09, d * 0.12), CFrame.new(0, -hs.Y * 0.1, -d * 0.5), hair, Enum.Material.Sand)
		elseif kind == "hoodback" then
			-- the hoodie's hood, down, bunched behind the neck (gold edge)
			prop(model, "UpperTorso", "HoodDown", ball, Vector3.new(ts.X * 0.55, ts.Y * 0.32, ts.Z * 0.62), CFrame.new(0, ts.Y * 0.46, ts.Z * 0.52), "#141418", Enum.Material.Fabric)
			prop(model, "UpperTorso", "HoodEdge", cyl, Vector3.new(0.08, ts.X * 0.5, ts.Z * 0.5), CFrame.new(0, ts.Y * 0.58, ts.Z * 0.52) * UPRIGHT, color, Enum.Material.Fabric)
		elseif kind == "chalk" then
			-- chalk on his hands: a white dusting over each hand
			-- (a white haze of chalk round each hand; TrainerFollowClient's puff of chalk when he claps)
			for _, side in ipairs({ "Left", "Right" }) do
				local hand = model:FindFirstChild(side .. "Hand")
				local s = hand and hand.Size or Vector3.new(0.4, 0.4, 0.4)
				local p = prop(model, side .. "Hand", "Chalk", ball, s * 1.12, CFrame.new(0, -s.Y * 0.04, 0), "#F4F2EC", Enum.Material.Sand)
				if p then p.Transparency = 0.45 end
			end
		elseif kind == "ponytail" then
			-- a long high ponytail: hair over the head, a tie at the crown, the tail falling down the back of the head
			local hair = look.hair or "#2A1A14"
			prop(model, "Head", "HairCap", ball, Vector3.new(d * 1.06, hs.Y * 0.46, d * 1.06), CFrame.new(0, hs.Y * 0.35, d * 0.03), hair, Enum.Material.SmoothPlastic)
			prop(model, "Head", "HairBack", ball, Vector3.new(d * 1.04, hs.Y * 0.8, d * 0.62), CFrame.new(0, hs.Y * 0.1, d * 0.25), hair, Enum.Material.SmoothPlastic)
			prop(model, "Head", "HairTie", cyl, Vector3.new(0.14, d * 0.26, d * 0.26), CFrame.new(0, hs.Y * 0.56, d * 0.34) * CFrame.Angles(math.rad(-50), 0, 0) * UPRIGHT,
				look.extraColor or "#D8283E")
			local tail = { { 0.62, 0.52, 0.32, 0.36 }, { 0.32, 0.7, 0.3, 0.42 }, { -0.04, 0.76, 0.27, 0.42 }, { -0.4, 0.74, 0.22, 0.38 }, { -0.7, 0.7, 0.16, 0.3 } }
			for _, t in ipairs(tail) do
				prop(model, "Head", "Ponytail", ball, Vector3.new(d * t[3], hs.Y * t[4], d * t[3]), CFrame.new(0, hs.Y * t[1], d * t[2]), hair, Enum.Material.SmoothPlastic)
			end
			-- loose locks down the sides of the face
			for _, side in ipairs({ -1, 1 }) do
				prop(model, "Head", "HairLock", ball, Vector3.new(d * 0.2, hs.Y * 0.8, d * 0.36), CFrame.new(side * d * 0.5, -hs.Y * 0.02, -d * 0.12), hair, Enum.Material.SmoothPlastic)
			end
		elseif kind == "deephood" then
			-- a deep black hood that hides the face in shadow, two calm glowing white eyes, faint purple seams, the hood's cloth
			-- over the shoulders
			local seam = look.extraColor2 or "#6E3FB0"
			-- the hood: a round shell over the head, peaked a little at the back, a soft overhang at the front
			prop(model, "Head", "Hood", ball, Vector3.new(d * 1.42, hs.Y * 1.5, d * 1.36), CFrame.new(0, hs.Y * 0.14, d * 0.1), color, Enum.Material.Fabric)
			prop(model, "Head", "HoodPeak", ball, Vector3.new(d * 0.8, hs.Y * 0.8, d * 0.8), CFrame.new(0, hs.Y * 0.4, d * 0.42), color, Enum.Material.Fabric)
			prop(model, "Head", "HoodBrim", ball, Vector3.new(d * 1.24, hs.Y * 0.42, d * 0.62), CFrame.new(0, hs.Y * 0.52, -d * 0.42), color, Enum.Material.Fabric)
			-- the opening: a faint purple seam round a dark oval (the face in shadow), two calm glowing eyes in it
			prop(model, "Head", "HoodSeam", cyl, Vector3.new(0.05, hs.Y * 1.04, d * 0.98), CFrame.new(0, -hs.Y * 0.04, -d * 0.6) * CFrame.Angles(0, math.rad(90), 0),
				seam, Enum.Material.Fabric)
			-- (Neon black: no light or shine ever shows on the shadow)
			prop(model, "Head", "FaceShadow", cyl, Vector3.new(0.06, hs.Y * 0.94, d * 0.86), CFrame.new(0, -hs.Y * 0.04, -d * 0.63) * CFrame.Angles(0, math.rad(90), 0),
				"#000000", Enum.Material.Neon)
			for _, side in ipairs({ -1, 1 }) do
				prop(model, "Head", "Eye", ball, Vector3.new(d * 0.15, hs.Y * 0.075, 0.05), CFrame.new(side * d * 0.17, hs.Y * 0.04, -d * 0.67), "#EAF2FF", Enum.Material.Neon)
			end
			-- the hood's cloth over the shoulders
			prop(model, "UpperTorso", "HoodMantle", ball, Vector3.new(ts.X * 0.86, ts.Y * 0.36, ts.Z * 1.3), CFrame.new(0, ts.Y * 0.46, ts.Z * 0.08), color, Enum.Material.Fabric)
		elseif kind == "laurel" then
			-- a gold laurel wreath: a thin band and leaves round the head, open at the front
			prop(model, "Head", "LaurelBand", cyl, Vector3.new(0.07, d * 1.06, d * 1.06), CFrame.new(0, hs.Y * 0.24, 0.02) * UPRIGHT, color, Enum.Material.Metal)
			for i = 1, 14 do
				local a = math.rad(-150 + (i - 1) * (300 / 13)) -- (front = -Z: angles from the back round each side)
				local side = if i <= 7 then -1 else 1
				local x, z = math.sin(a) * d * 0.54, math.cos(a) * d * 0.54
				prop(model, "Head", "LaurelLeaf", nil, Vector3.new(0.07, d * 0.13, d * 0.28),
					CFrame.new(x, hs.Y * 0.27 + (i % 2) * 0.05, z) * CFrame.Angles(0, a + math.pi / 2, 0) * CFrame.Angles(side * math.rad(28), 0, 0), color, Enum.Material.Metal)
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
				-- (prompt 25: trainers may pass the players' 7'0" cap, up to Trainers.MaxHeightInches: Atlas 7'6")
				local scale = math.min(trainer.heightInches, Trainers.MaxHeightInches) / BodyShape.BaseHeight
				NpcService.ApplyBody(model, scale)
				-- (owner, 19 Oct: width grows with height, no thin stick frames) every width and depth by the same amount as the
				-- height, the frame's shoulders and the full-look shoulder bonus on top
				local shoulders = scale * Genetics.ShoulderWidth(trainer.frame) * (trainer.shoulderBonus or 1)
				-- (prompt 25: widths = his own build on top, Duke's thick waist and forearms)
				local w = trainer.widths or {}
				local f = { shoulders = shoulders, hips = scale * (w.hips or 1), arms = scale * (w.arms or 1), legs = scale * (w.legs or 1),
					depth = scale * (w.depth or 1) }
				BodyShape.ApplyWidths(model, f)
				model:SetAttribute("BodyWidths", string.format("%.3f,%.3f,%.3f,%.3f,%.3f", f.shoulders, f.hips, f.arms, f.legs, f.depth))
				model:SetAttribute("FrameWidth", f.shoulders)
				model:SetAttribute("WaistWidth", f.hips)
			end
			-- our own clothes (image templates), a face texture when he has one, his props
			for _, old in ipairs(model:GetChildren()) do
				if old:IsA("Shirt") or old:IsA("Pants") or old:IsA("ShirtGraphic") then old:Destroy() end
			end
			-- (prompt 34) his outfit is not a classic Shirt / Pants (those tore on the muscle meshes): clean images made for the
			-- stage meshes, worn by the muscle pieces themselves (Shared/Outfit; MuscleRig.StyleFrom reads these attributes)
			local outfit = look.outfit or {}
			model:SetAttribute("OutfitShirt", outfit.shirt)
			model:SetAttribute("OutfitPants", outfit.pants)
			model:SetAttribute("OutfitSleeves", outfit.sleeves)
			model:SetAttribute("OutfitLegs", outfit.legs)
			model:SetAttribute("OutfitShirtColor", if outfit.shirtColor then Color3.fromHex(outfit.shirtColor) else nil)
			model:SetAttribute("OutfitPantsColor", if outfit.pantsColor then Color3.fromHex(outfit.pantsColor) else nil)
			if not outfit.shirt then model:SetAttribute("BareChest", true) end
			-- (owner, 23 Oct: no shoes on anyone; his feet are bare, in his skin color)
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
				if look.material then classic.Material = Enum.Material[look.material] end
				classic.CFrame = head.CFrame
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = head, classic
				weld.Parent = classic
				classic.Parent = model
			end
			extras(model, look)
			-- (prompt 34) his gear: the planner's meshes, fitted to his body (Shared/Gear; GearClient re-fits them to his muscles)
			for _, gear in ipairs(look.gear or {}) do
				Gear.Build(model, gear.kind, gear)
			end
			attachAccessories(model)
			-- (prompt 25) a marble body (Atlas): his muscles (MuscleRig marble mode, MuscleClient reads these attributes) and his own
			-- body parts in white marble with gold veins (the MaterialVariant, Config/Trainers Materials)
			if look.marble then
				model:SetAttribute("MuscleMarble", true)
				model:SetAttribute("MarbleColor", Color3.fromHex(look.marble.color))
				model:SetAttribute("MarbleVariant", look.marble.variant)
				for _, name in ipairs({ "Head", "ClassicHead", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
					"LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }) do
					local part = model:FindFirstChild(name)
					if part and part:IsA("BasePart") then
						part.Color = Color3.fromHex(look.marble.color)
						part.Material = Enum.Material.Marble
						part.MaterialVariant = look.marble.variant
					end
				end
			end
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
			-- (prompt 34) how many parts he has, so a client clones him only once he has fully arrived (a clone made while he
			-- was still replicating had no right leg, hair or gear)
			local parts = 0
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then parts += 1 end
			end
			model:SetAttribute("Parts", parts)
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
-- (prompt 47) MY TRAINERS' "GO TO TRAINER AGENCY": in front of the nearest Agency desk (10 s cooldown)
local lastAgencyTeleport = {}
local function teleportAgency(player)
	local clock = os.clock()
	if clock - (lastAgencyTeleport[player] or -math.huge) < 10 then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart or player:GetAttribute("PosingComp") then return end
	local best, bestDistance = nil, math.huge
	for _, desk in ipairs(desks) do
		if desk.Parent then
			local d = (desk.Position - root.Position).Magnitude
			if d < bestDistance then best, bestDistance = desk, d end
		end
	end
	if not best then return end
	lastAgencyTeleport[player] = clock
	local spot = (best.CFrame * CFrame.new(0, 0, -5)).Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
	local floorY = if hit then hit.Position.Y else best.Position.Y - best.Size.Y / 2
	local at = Vector3.new(spot.X, floorY + humanoid.HipHeight + root.Size.Y / 2, spot.Z)
	character:PivotTo(CFrame.lookAt(at, Vector3.new(best.Position.X, at.Y, best.Position.Z)))
end

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
		elseif action == "Evolve" then
			evolve(player, a)
		elseif action == "EvolveAll" then
			evolveAll(player)
		elseif action == "TeleportAgency" then
			teleportAgency(player)
		elseif action == "AutoDelete" then
			setAutoDelete(player, a, b)
		elseif action == "SeenRebalance" then
			-- (prompt 27c) the popup was shown: never again
			local state = stateOf(player)
			if state.rebalance == 1 then
				state.rebalance = 2
				apply(player, state)
			end
		end
	end)

	task.spawn(buildTemplates)
	Players.PlayerRemoving:Connect(function(player)
		pcall(flushXp, player)
		lastRoll[player], lastEvolve[player], pendingXp[player], lastAgencyTeleport[player] = nil, nil, nil, nil
	end)
	-- (prompt 33) the waiting trainer EXP goes into the save every FlushSeconds
	task.spawn(function()
		while true do
			task.wait(Trainers.FlushSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				if pendingXp[player] and next(pendingXp[player]) then
					local ok, ups = pcall(flushXp, player)
					if ok then for _, up in ipairs(ups) do send(player, "LevelUp", up) end end
				end
			end
		end
	end)

	if #CollectionService:GetTagged("TrainerDesk") == 0 then
		warn("[TrainerService] no Trainer Desks (tag TrainerDesk): build them with tools/builders/TrainerDesks.luau")
	end
	for _, part in ipairs(CollectionService:GetTagged("TrainerDesk")) do addDesk(part) end
	CollectionService:GetInstanceAddedSignal("TrainerDesk"):Connect(addDesk)

	-- (owner, prompt 27c) the boosts were rebalanced (lowered): anyone who already owned trainers gets a gift once, with a
	-- popup; everyone else is just marked done (a new player's later trainers already have the new numbers)
	local function rebalanceGift(player, state)
		if state.rebalance ~= 0 then return end
		if #state.copies > 0 then
			state.rebalance = 1
			state.freeRolls += Trainers.RebalanceGift.rolls
			PlayerData.AddCoins(player, Trainers.RebalanceGift.coins)
			Analytics.Event(player, "TrainerRebalanceGift", 1)
		else
			state.rebalance = 2
		end
	end
	local function ready(player)
		local state = stateOf(player)
		rebalanceGift(player, state)
		apply(player, state)
		-- the pass (bought later, or found at join) adds a slot
		player:GetAttributeChangedSignal("Pass_" .. Trainers.ExtraSlotPass):Connect(function() apply(player, stateOf(player)) end)
	end
	PlayerData.Loaded:Connect(ready)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Get(player) then ready(player) end
	end

	-- Studio: Workspace attribute TestTrainers = "RookieCoach,PumpCoach@3" gives every player those trainers (stage 3 =
	-- BEAST-MODE) and equips them; "AeonCoach@5#20" = at LV 20
	-- (TestTrainerSlots = 2 acts out the Extra Trainer pass; TestRebalanceGift = true gives the prompt 27c gift again)
	if game:GetService("RunService"):IsStudio() then
		local function test()
			local list = Workspace:GetAttribute("TestTrainers")
			if type(list) ~= "string" then return end
			for _, player in ipairs(Players:GetPlayers()) do
				if Workspace:GetAttribute("TestTrainerSlots") == 2 then player:SetAttribute("Pass_" .. Trainers.ExtraSlotPass, true) end
				local state = stateOf(player)
				state.equipped = {}
				for entry in string.gmatch(list, "[^,]+") do
					local level = tonumber(string.match(entry, "#(%d+)$"))
					local id, stage = Trainers.ParseEntry((string.gsub(entry, "#%d+$", "")))
					if id then table.insert(state.equipped, newCopy(state, id, stage, level and math.clamp(level, 1, Trainers.MaxLevel)).u) end
				end
				-- (prompt 33) TestTrainerCopies = "RookieCoach:9,VoltaCoach:3" adds that many BASE copies (to evolve)
				local extra = Workspace:GetAttribute("TestTrainerCopies")
				if type(extra) == "string" then
					for id, n in string.gmatch(extra, "([%w_]+):(%d+)") do
						if Trainers.ById[id] then for _ = 1, math.min(tonumber(n) or 0, 200) do newCopy(state, id, 1) end end
					end
				end
				if Workspace:GetAttribute("TestRebalanceGift") == true then
					state.rebalance = 0
					rebalanceGift(player, state)
				end
				apply(player, state)
			end
		end
		Workspace:GetAttributeChangedSignal("TestTrainers"):Connect(test)
		Workspace:GetAttributeChangedSignal("TestTrainerSlots"):Connect(test)
	end
end

return TrainerService
