-- Gear (prompt 34): the planner's gear meshes on a character, fitted to its body. Used by the trainers (TrainerService,
-- Config/Trainers look.gear) and the players' shop gear (CosmeticService: belts, wraps, straps, knee sleeves).
-- The meshes: ReplicatedStorage.GearMeshes.<Belt | Wraps | Sleeves | Straps | Whistle>, models imported from Blender
-- (Downloads\gym_arc_gear_meshes, 1 Blender unit = 1 stud), one MeshPart per piece so each takes its own color:
--   Belt: Belt_Leather (the ring, width 2 x depth ~1.24, buckle at the front), Belt_Stitch (2), Belt_Buckle, Belt_Prong
--   Wraps: Wrap_Band (a ring, radius 1 = the wrist), Wrap_Stripe (3), Wrap_ThumbLoop
--   Sleeves: Sleeve (radius 1 = the knee, height 1.6), Sleeve_Band (2)
--   Straps: Strap_Loop (radius 1 = the wrist), Strap_Tail, Strap_Stripe
--   Whistle: Whistle_Body, Whistle_Mouth, Whistle_Ring, Lanyard
--   Sneaker (prompt 35): Shoe_Upper, Shoe_Midsole, Shoe_Outsole, Shoe_Collar, Shoe_Opening, Shoe_Tongue, Shoe_Lace (4),
--     Shoe_Stripe (2), Shoe_HeelTab; sole at the bottom. Fitted to each foot as one piece (one size for the whole shoe),
--     never smaller than the foot, the sole on the foot's bottom, the toe forward (the heel tab says which end is the
--     heel, so the import's facing doesn't matter); the block foot under it is hidden. Gear.Has("Sneakers") = the model is
--     there (until then everyone keeps their old feet).
-- (The .glb import keeps Blender's front, -Y, as the body's front, -Z: the buckle, the strap tails and the whistle face
-- forward as they are. Each import was a "Scene" of Models holding one MeshPart each: moved into one Model per kind with
-- every MeshPart named after its piece, centred on the main piece.)
--   Gear.Build(character, kind, colors, parent?)  -- server: clones the pieces, colors them, welds them on, a first fit
--                                           from the body parts; returns the gear models (in `parent`, default the
--                                           character). colors = { color, trim, metal, shiny } (hex or Color3)
--   Gear.Fit(character)                   -- client: re-fits every gear model to the body you SEE (the muscle stage meshes
--                                           or your own live muscle meshes: their bounds on the body part), cheap when
--                                           nothing changed. GearClient calls it about twice a second.
-- Nothing on the gear collides, is touched, is hit by rays or casts a shadow.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gear = {}

local TURN = CFrame.new()
local FLIP = CFrame.Angles(math.pi, 0, 0) -- (the wraps' thumb loop points up in the file: down to the hand)

-- fit: where it sits (see fitTarget); main = the piece whose size is the ring the fit scales; only = the pieces used
Gear.Kinds = {
	Belt = { mesh = "Belt", main = "Belt_Leather", fit = "waist", parts = { "LowerTorso" }, material = Enum.Material.Leather,
		colors = { color = "#4A2E1C", trim = "#D9B25C", metal = "#C9CCD2" } },
	-- (Atlas's thin gold waistband: the belt's ring alone, thin)
	Waistband = { mesh = "Belt", main = "Belt_Leather", only = { Belt_Leather = true }, fit = "waist", thin = true, parts = { "LowerTorso" },
		colors = { color = "#F6C75A" } },
	Wraps = { mesh = "Wraps", main = "Wrap_Band", fit = "wrist", turn = FLIP, parts = { "LeftLowerArm", "RightLowerArm" },
		colors = { color = "#2B2B30", trim = "#F4F1EA" } },
	-- (Atlas's gold cuffs: the wrap's band and stripes, no thumb loop)
	Cuffs = { mesh = "Wraps", main = "Wrap_Band", only = { Wrap_Band = true, Wrap_Stripe = true }, fit = "wrist", parts = { "LeftLowerArm", "RightLowerArm" },
		colors = { color = "#F6C75A", trim = "#FFF3C4" } },
	Straps = { mesh = "Straps", main = "Strap_Loop", fit = "wrist", low = true, parts = { "LeftLowerArm", "RightLowerArm" },
		colors = { color = "#2B2B30", trim = "#F4F1EA" } },
	Sleeves = { mesh = "Sleeves", main = "Sleeve", fit = "knee", parts = { "LeftLowerLeg", "RightLowerLeg" },
		colors = { color = "#2B2B30", trim = "#16161A" } },
	Whistle = { mesh = "Whistle", main = "Whistle_Body", fit = "chest", parts = { "UpperTorso" },
		colors = { color = "#C8262C", metal = "#D9DCE0" } },
	-- (prompt 35) color = the upper, trim = the stripes and heel tab, sole = midsole and laces, outsole = the tread
	Sneakers = { mesh = "Sneaker", main = "Shoe_Midsole", fit = "foot", parts = { "LeftFoot", "RightFoot" },
		colors = { color = "#16161A", trim = "#F4F1EA", sole = "#F4F1EA", outsole = "#2B2B30" } },
}

-- each piece's color: the gear's color, its trim or metal (".001" copies count as their first)
local ROLE = {
	Belt_Leather = "color", Belt_Stitch = "trim", Belt_Buckle = "metal", Belt_Prong = "metal",
	Wrap_Band = "color", Wrap_Stripe = "trim", Wrap_ThumbLoop = "color",
	Sleeve = "color", Sleeve_Band = "trim",
	Strap_Loop = "color", Strap_Tail = "color", Strap_Stripe = "trim",
	Whistle_Body = "metal", Whistle_Mouth = "metal", Whistle_Ring = "metal", Lanyard = "color",
	Shoe_Upper = "color", Shoe_Collar = "color", Shoe_Tongue = "color", Shoe_Opening = "outsole", Shoe_Midsole = "sole", Shoe_Lace = "sole",
	Shoe_Outsole = "outsole", Shoe_Stripe = "trim", Shoe_HeelTab = "trim",
}
local function baseName(name: string): string
	return (string.gsub(name, "%.%d+$", ""))
end

local function templateOf(def)
	local folder = ReplicatedStorage:FindFirstChild("GearMeshes")
	return folder and folder:FindFirstChild(def.mesh)
end
-- (prompt 35) is this gear kind's model there? (the sneaker is imported by hand: until then nobody wears it)
function Gear.Has(kind: string): boolean
	local def = Gear.Kinds[kind]
	return def ~= nil and templateOf(def) ~= nil
end

-- the whole template's box in its main piece's space, and where the heel tab sits along Z (cached per template)
local boxes = {}
local function templateBox(template: Instance, main: BasePart): (Vector3, Vector3, number?)
	local hit = boxes[template]
	if hit and hit.main == main then return hit.lo, hit.hi, hit.heel end
	local lo, hi, heel
	for _, part in ipairs(template:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		local cf = main.CFrame:ToObjectSpace(part.CFrame)
		local h = part.Size / 2
		for _, c in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
			Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) }) do
			local p = cf * (h * c)
			lo = if lo then lo:Min(p) else p
			hi = if hi then hi:Max(p) else p
		end
		if string.gsub(part.Name, "%.%d+$", "") == "Shoe_HeelTab" then heel = cf.Position.Z end
	end
	lo, hi = lo or -main.Size / 2, hi or main.Size / 2
	boxes[template] = { main = main, lo = lo, hi = hi, heel = heel }
	return lo, hi, heel
end

local function mainOf(template, def): BasePart?
	local main = template:FindFirstChild(def.main, true)
	if main and main:IsA("BasePart") then return main end
	-- (a single merged import: its one part)
	return template:FindFirstChildWhichIsA("BasePart", true)
end

------------------------------------------------------------------------
-- Measuring the body you see
------------------------------------------------------------------------
-- The box (min, max, in the body part's space) of what stands in for a body part: the muscle stage meshes / live muscle
-- meshes in the character's MuscleMeshes folder (BodyStages / LimbStages pieces carry a BodyPart attribute, live meshes
-- are named after the part), else the body part itself.
local function boundsOf(model: Model, body: BasePart): (Vector3, Vector3, boolean)
	local folder = model:FindFirstChild("MuscleMeshes")
	local lo, hi
	if folder then
		local name = body.Name
		for _, part in ipairs(folder:GetChildren()) do
			if not part:IsA("BasePart") or part.Transparency >= 0.99 then continue end
			local owner = part:GetAttribute("BodyPart")
			if owner ~= name and not (owner == nil and string.sub(part.Name, 1, #name) == name) then continue end
			local cf = body.CFrame:ToObjectSpace(part.CFrame)
			local h = part.Size / 2
			for _, c in ipairs({ Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) }) do
				local p = cf * (h * c)
				lo = if lo then lo:Min(p) else p
				hi = if hi then hi:Max(p) else p
			end
		end
	end
	if lo then return lo, hi, true end
	return -body.Size / 2, body.Size / 2, false
end

-- Where a gear piece sits and how big its ring is: (center in the body part's space, the main piece's target size).
local function fitTarget(model: Model, body: BasePart, def): (CFrame, Vector3)
	local lo, hi, seen = boundsOf(model, body)
	local size, mid = hi - lo, (hi + lo) / 2
	local s = body.Size
	if def.fit == "waist" then
		-- round the top of the hips (where the waist meets the abs), a little wider than the body there and deep enough for
		-- the bottom of the abs (the chest's own depth, less the pecs)
		local torso = model:FindFirstChild("UpperTorso")
		local chestDepth = 0
		if torso and torso:IsA("BasePart") then
			local tlo, thi = boundsOf(model, torso)
			chestDepth = (thi.Z - tlo.Z) * 0.8
		end
		local w, d = size.X * 1.06, math.max(size.Z * 1.12, chestDepth)
		local h = if def.thin then math.max(w * 0.045, 0.06) else w * 0.36
		-- (a thin waistband sits where the shorts show under the abs, a little lower than a belt's top)
		local y = if def.thin then hi.Y - size.Y * 0.32 else hi.Y - h * 0.22
		return CFrame.new(mid.X, y, mid.Z), Vector3.new(w, h, d)
	elseif def.fit == "wrist" then
		-- the wrist: the forearm's own width (the bulk of a big forearm is near the elbow), at its lower end
		local r = math.max(math.max(s.X, s.Z) * 1.02, (if seen then math.max(size.X, size.Z) * 0.62 else 0))
		local h = s.Y * (if def.low then 0.14 else 0.24)
		local y = lo.Y + h * (if def.low then 0.2 else 0.65)
		return CFrame.new(mid.X, y, mid.Z), Vector3.new(r, h, r)
	elseif def.fit == "knee" then
		-- over the knee: the top of the calf, below the thigh's bulge
		local r = math.max(math.max(s.X, s.Z) * 1.16, (if seen then math.max(size.X, size.Z) * 0.92 else 0))
		local h = s.Y * 0.46
		return CFrame.new(mid.X, hi.Y - h * 0.58, mid.Z), Vector3.new(r, h, r)
	elseif def.fit == "foot" then
		-- (prompt 35) the sneaker's length and width: the foot's, but a big calf (the muscle stage meshes on the lower leg)
		-- gets a big shoe under it (a mass monster's), never smaller than the foot
		local w, l = s.X * 0.95, s.Z * 1.1
		local leg = model:FindFirstChild((string.gsub(body.Name, "Foot$", "LowerLeg")))
		if leg and leg:IsA("BasePart") then
			local llo, lhi, legSeen = boundsOf(model, leg)
			if legSeen then
				local calf = math.max(lhi.X - llo.X, lhi.Z - llo.Z)
				w, l = math.max(w, calf * 0.8), math.max(l, calf * 1.35)
			end
		end
		return CFrame.new(mid), Vector3.new(w, 0, l)
	else -- chest: the whistle at the front of the chest (Fit draws the lanyard round the neck)
		return CFrame.new(0, hi.Y - size.Y * 0.42, lo.Z - 0.04), size
	end
end

------------------------------------------------------------------------
-- Fitting
------------------------------------------------------------------------
local function fitOne(model: Model, gear: Model)
	local def = Gear.Kinds[gear:GetAttribute("GearKind")]
	local body = model:FindFirstChild(gear:GetAttribute("GearPart") or "")
	local template = def and templateOf(def)
	if not (def and body and body:IsA("BasePart") and template) then return end
	local main = mainOf(template, def)
	if not main then return end
	local center, target = fitTarget(model, body, def)
	local key = string.format("%.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f %.2f", center.X, center.Y, center.Z, target.X, target.Y, target.Z,
		body.Size.X, body.Size.Y, body.Size.Z)
	if gear:GetAttribute("FitKey") == key then return end
	gear:SetAttribute("FitKey", key)
	local turn = TURN * (def.turn or CFrame.new())
	if def.fit == "foot" then
		-- (prompt 35) the sneaker: one size for the whole shoe, long and wide enough to cover the foot (bigger feet on a
		-- mass monster = a bigger shoe), the sole on the foot's bottom, the toe forward (-Z), the heel at the back
		local lo, hi = boundsOf(model, body)
		local size, mid = hi - lo, (hi + lo) / 2
		local tlo, thi, heel = templateBox(template, main)
		local tsize = thi - tlo
		local shoeTurn = if heel and heel < (tlo.Z + thi.Z) / 2 then CFrame.Angles(0, math.pi, 0) else CFrame.new()
		-- the length (and height) from fitTarget's length; the width from its width (a Robloxian foot is wide for its
		-- length), never narrower than the shoe's own shape. The block foot is hidden, so nothing pokes out.
		local u = target.Z / math.max(tsize.Z, 0.01)
		local sx = math.max(u, target.X / math.max(tsize.X, 0.01))
		local S = Vector3.new(sx, u, u)
		local offset = shoeTurn:VectorToWorldSpace(Vector3.new((tlo.X + thi.X) / 2, 0, (tlo.Z + thi.Z) / 2) * S)
		-- (a touch forward: the ankle sits over the back half of a real foot)
		local place = CFrame.new(mid.X - offset.X, lo.Y - tlo.Y * u, mid.Z - offset.Z - size.Z * 0.04)
		for _, part in ipairs(gear:GetChildren()) do
			local from = part:IsA("BasePart") and template:FindFirstChild(part:GetAttribute("From") or "", true)
			local weld = part:FindFirstChild("GearWeld")
			if not (from and weld) then continue end
			local rel = main.CFrame:ToObjectSpace(from.CFrame)
			-- each of the piece's own axes stretched by how much the shoe stretches along it (exact for straight and
			-- quarter-turned pieces, close for the tilted stripes and tongue)
			local function along(axis: Vector3): number return (axis * S).Magnitude end
			part.Size = from.Size * Vector3.new(along(rel.RightVector), along(rel.UpVector), along(-rel.LookVector))
			weld.C0 = place * shoeTurn * CFrame.new(rel.Position * S) * rel.Rotation
		end
		return
	end
	if def.fit == "chest" then
		-- the whistle a size that suits the head, the lanyard from it up and round the back of the neck
		local head = model:FindFirstChild("Head")
		local hw = if head and head:IsA("BasePart") then head.Size.X else 1.2
		local u = hw * 0.24 / main.Size.X
		local top = center.Y + target.Y * 0.42
		local neckBack = math.max(center.Z + target.Z * 0.62, center.Z + 0.3)
		for _, part in ipairs(gear:GetChildren()) do
			local from = part:IsA("BasePart") and template:FindFirstChild(part:GetAttribute("From") or "", true)
			local weld = part:FindFirstChild("GearWeld")
			if not (from and weld) then continue end
			if baseName(from.Name) == "Lanyard" then
				local bottom = center.Y + main.Size.Y * u * 0.4
				local width = hw * 0.62
				part.Size = Vector3.new(width, math.max(top + hw * 0.12 - bottom, 0.2), math.max(neckBack - center.Z, 0.2))
				weld.C0 = CFrame.new(0, (top + hw * 0.12 + bottom) / 2, (center.Z + neckBack) / 2) * turn
			else
				local rel = main.CFrame:ToObjectSpace(from.CFrame)
				part.Size = from.Size * u
				weld.C0 = center * turn * CFrame.new(rel.Position * u) * rel.Rotation
			end
		end
		return
	end
	local scale = target / main.Size
	for _, part in ipairs(gear:GetChildren()) do
		local from = part:IsA("BasePart") and template:FindFirstChild(part:GetAttribute("From") or "", true)
		local weld = part:FindFirstChild("GearWeld")
		if not (from and weld) then continue end
		local rel = main.CFrame:ToObjectSpace(from.CFrame)
		part.Size = from.Size * scale
		-- (the wraps' stripe rings are a little wider than the band in the file: kept snug on it, not loose round it)
		if baseName(from.Name) == "Wrap_Stripe" then
			part.Size = Vector3.new(target.X * 1.03, part.Size.Y, target.Z * 1.03)
		end
		weld.C0 = center * turn * CFrame.new(rel.Position * scale) * rel.Rotation
	end
end

function Gear.Fit(model: Model)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("GearKind") then
			fitOne(model, child)
		elseif child:IsA("Folder") then
			-- (a player's shop gear is in the character's Cosmetics folder)
			for _, inner in ipairs(child:GetChildren()) do
				if inner:IsA("Model") and inner:GetAttribute("GearKind") then fitOne(model, inner) end
			end
		end
	end
end

-- The players' gear levels (Config/PumpShop GearLevels: the level's color is the gear's color): the trim and metal
-- that go with it.
Gear.LevelColors = {
	Basic = { trim = "#9A9AA2", metal = "#C9CCD2" },
	Pro = { trim = "#F4F1EA", metal = "#C9CCD2" },
	Elite = { trim = "#2B2B30", metal = "#E8EAEE" },
	Champion = { trim = "#FFF3C4", metal = "#F6C75A" },
}

------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------
-- Puts a gear kind on a character: one gear model per body part it goes on (both wrists, both knees). colors = { color,
-- trim, metal (a color), shiny = true (the whole piece metal: Atlas's gold cuffs) }; missing ones = the kind's own.
local function toColor(value: any): Color3
	return if typeof(value) == "Color3" then value else Color3.fromHex(value)
end

function Gear.Build(model: Model, kind: string, colors: any?, parent: Instance?): { Model }
	local def = Gear.Kinds[kind]
	local template = def and templateOf(def)
	if not template then return {} end
	colors = colors or {}
	local built = {}
	for _, partName in ipairs(def.parts) do
		local body = model:FindFirstChild(partName)
		if not (body and body:IsA("BasePart")) then continue end
		local gear = Instance.new("Model")
		gear.Name = "Gear" .. kind .. (if #def.parts > 1 then string.gsub(partName, "Lower%a+", "") else "")
		gear:SetAttribute("GearKind", kind)
		gear:SetAttribute("GearPart", partName)
		for _, from in ipairs(template:GetDescendants()) do
			if not from:IsA("BasePart") then continue end
			local name = baseName(from.Name)
			if def.only and not def.only[name] then continue end
			local part = from:Clone()
			for _, child in ipairs(part:GetChildren()) do
				if not child:IsA("SurfaceAppearance") then child:Destroy() end
			end
			part:SetAttribute("From", from.Name)
			local role = ROLE[name] or "color"
			local hex = colors[role] or def.colors[role] or colors.color or def.colors.color
			part.Color = toColor(hex)
			part.Material = if role == "metal" or colors.shiny then Enum.Material.Metal
				elseif role == "color" and def.material then def.material
				elseif role == "sole" or role == "outsole" then Enum.Material.SmoothPlastic
				else Enum.Material.Fabric
			part.Anchored = false
			part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow, part.Massless = false, false, false, false, true
			local weld = Instance.new("Weld")
			weld.Name = "GearWeld"
			weld.Part0, weld.Part1 = body, part
			weld.Parent = part
			part.Parent = gear
		end
		gear.Parent = parent or model
		table.insert(built, gear)
		-- (prompt 35) the block foot hides under its sneaker
		if def.fit == "foot" then body.Transparency = 1 end
	end
	Gear.Fit(model)
	return built
end

return Gear
