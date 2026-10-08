-- BodyStages: the muscles of OTHER characters (other players, NPCs, the statue, the mirror's before body) as STATIC stage
-- meshes (client side, used by MuscleRig for every rig that is not your own character; owner, 8 Oct night).
-- A client holds at most 8 EditableMeshes and your own body uses 7, so nobody else can have live muscle meshes. Instead,
-- per body region (Config.BodyStages: the torso, both upper arms, both thighs, the waist) the stage nearest to the region's
-- look (its muscles' replicated look values averaged: up to 1 = the full look, up to 2 = the mass monster) is a clone of a
-- template in ReplicatedStorage.BodyStages (imported meshes, made by tools/gen_body_stages + tools/body_stages_setup). A
-- stage change cross-fades the old and the new parts over FadeTime (never pops); a region's pieces (the torso's halves, a
-- thigh's skin and shorts) always switch together.
--   * size and placement follow the body part (golden ratio, Growth Spurts, widths): scale = body.Size / reference size;
--   * clothing: TextureID = the character's Shirt (torso, arms) / Pants (thighs, waist) image, Color = the skin (or the
--     game's top / gym shorts color when no image covers that piece); layered clothing on a part hides its stages;
--   * the skin texture stage goes on the skin pieces (MuscleRig's skin pass: the parts carry BodyStageKind / Clothing);
--   * the training tint / hover highlight tint the part's Color (the strongest tint among the region's muscles);
--   * the plain body part under a region is hidden while its stage shows.
--   local stages = BodyStages.new(model, folder, static)  -- nil when the templates aren't there
--   stages:Update(getLook, style, tint, covered, marble)  -- often (cheap when nothing changed)
--   stages:Destroy()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config.BodyStages)
local Muscles = require(script.Parent.Config.Muscles)
-- the body part reference sizes the mesh data was made for
local PARTS = (require(ReplicatedStorage:WaitForChild("MuscleData"):WaitForChild("Index")) :: any).parts

local BodyStages = {}
BodyStages.__index = BodyStages

local HYSTERESIS = 0.03 -- a region only moves to another stage once it is clearly nearer (no flicker on a boundary)
local MARBLE = Color3.fromHex("#C9C6BF")

local templates = ReplicatedStorage:FindFirstChild("BodyStages")

-- True when every stage template is there.
function BodyStages.Available(): boolean
	templates = templates or ReplicatedStorage:FindFirstChild("BodyStages")
	if not templates then return false end
	for _, region in ipairs(Config.Regions) do
		for _, stage in ipairs(region.stages) do
			for _, object in pairs(stage.objects) do
				local template = templates:FindFirstChild(object.file)
				if not (template and template:IsA("MeshPart")) then return false end
			end
		end
	end
	return true
end
local available = BodyStages.Available()
function BodyStages.IsOn(): boolean return available end

-- the body parts a region stands in for (MuscleRig's garments / plain thighs)
BodyStages.Parts = {}
for _, region in ipairs(Config.Regions) do BodyStages.Parts[region.part] = true end

-- a region's look: the average up to the full look plus the average way into the mass monster (0 .. 2)
local function regionLook(region, getLook): number
	local list = region.muscles
	local grown, monster, count = 0, 0, 0
	local function add(id: string)
		local g = getLook(id)
		grown += math.min(g, 1)
		monster += math.clamp((g - 1) / math.max(Muscles.MonsterG(id) - 1, 0.01), 0, 1)
		count += 1
	end
	if list == "all" then
		for _, muscle in ipairs(Muscles.List) do add(muscle.id) end
	else
		for _, id in ipairs(list) do add(id) end
	end
	return if count > 0 then (grown + monster) / count else 0
end

local function nearestStage(stages, value: number, current: number?): number
	local best, bestDistance = 1, math.huge
	for index, stage in ipairs(stages) do
		local distance = math.abs(stage.g - value)
		if distance < bestDistance then best, bestDistance = index, distance end
	end
	if current and stages[current] and math.abs(stages[current].g - value) <= bestDistance + HYSTERESIS then return current end
	return best
end

function BodyStages.new(model: Model, folder: Instance, static: boolean)
	if not available then return nil end
	local self = setmetatable({ model = model, folder = folder, static = static, regions = {} }, BodyStages)
	for _, region in ipairs(Config.Regions) do
		self.regions[region.id] = { def = region, stage = nil, parts = {}, body = nil, size = nil }
	end
	return self
end

local function scaleOf(region, body: BasePart): Vector3
	local ref = PARTS[region.part] and PARTS[region.part].size or body.Size
	return Vector3.new(body.Size.X / ref.X, body.Size.Y / ref.Y, body.Size.Z / ref.Z)
end

local function offsetOf(object, scale: Vector3): CFrame
	return CFrame.new(object.center * scale) * Config.ImportTurn
end

local function place(self, part: MeshPart, body: BasePart, object, scale: Vector3)
	part.Size = part.MeshSize * scale
	local offset = offsetOf(object, scale)
	if self.static then
		part.CFrame = body.CFrame * offset
	else
		local weld = part:FindFirstChildOfClass("Weld")
		if weld then weld.C0 = offset end
	end
end

local function makePart(self, region, piece, object, body: BasePart, scale: Vector3): MeshPart?
	local template = templates and templates:FindFirstChild(object.file)
	if not template then return nil end
	local part = template:Clone() :: MeshPart
	part.Name = region.part .. piece.key .. "Stage"
	part:SetAttribute("BodyStageKind", piece.kind)
	part:SetAttribute("Clothing", piece.clothing)
	part.Anchored = self.static
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.Massless = true
	if not self.static then
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = body, part
		weld.Parent = part
	end
	place(self, part, body, object, scale)
	part.Parent = self.folder
	return part
end

local function fade(part: Instance, to: number, done: (() -> ())?)
	local tween = TweenService:Create(part, TweenInfo.new(Config.FadeTime, Enum.EasingStyle.Sine), { Transparency = to })
	if done then tween.Completed:Connect(done) end
	tween:Play()
end

-- getLook(muscleId) -> the displayed look g; style = { skin, shorts, top, shirt, pants }; tint(muscleIds, base, clothed)
-- -> Color3; covered = { [bodyPartName] = true } under layered clothing; marble = the statue look.
function BodyStages.Update(self, getLook, style, tint, covered, marble)
	for _, state in pairs(self.regions) do
		local region = state.def
		local body = self.model:FindFirstChild(region.part)
		if not (body and body:IsA("BasePart")) then continue end
		-- an outfit change can swap the body parts: start again on the new one
		if state.body and state.body ~= body then
			for _, part in pairs(state.parts) do part:Destroy() end
			state.parts, state.stage = {}, nil
			if state.body.Parent then state.body.Transparency = 0 end
		end
		state.body = body
		local hidden = covered ~= nil and covered[region.part] == true
		local index = nearestStage(region.stages, regionLook(region, getLook), state.stage)
		local scale = scaleOf(region, body)
		if index ~= state.stage then
			local stage = region.stages[index]
			local first = state.stage == nil
			local new = {}
			for _, piece in ipairs(region.pieces) do
				local part = makePart(self, region, piece, stage.objects[piece.key], body, scale)
				if part then new[piece.key] = part end
			end
			for key, part in pairs(new) do
				local old = state.parts[key]
				if hidden then
					part.Transparency = 1
					if old then old:Destroy() end
				elseif first or not old then
					part.Transparency = 0
				else
					-- cross-fade: the new stage fades in over the old, which fades out and goes
					part.Transparency = 1
					fade(part, 0)
					fade(old, 1, function() old:Destroy() end)
				end
			end
			state.parts, state.stage, state.size = new, index, body.Size
		end
		-- the body part's size changed (Growth Spurt, widths): re-fit
		if state.size ~= body.Size then
			state.size = body.Size
			for key, part in pairs(state.parts) do place(self, part, body, region.stages[state.stage].objects[key], scale) end
		end
		local skin = (style and style.skin) or body.Color
		for _, piece in ipairs(region.pieces) do
			local part = state.parts[piece.key]
			if not part then continue end
			if self.static then part.CFrame = body.CFrame * offsetOf(region.stages[state.stage].objects[piece.key], scale) end
			-- clothing and color (the skin shows where the clothing image is see-through)
			local template = if marble then "" else ((if piece.clothing == "Pants" then style.pants else style.shirt) or "")
			if part.TextureID ~= template then part.TextureID = template end
			local base
			if marble then
				base = MARBLE
			elseif template ~= "" then
				base = skin
			elseif piece.kind == "shorts" then
				base = style.shorts or body.Color
			elseif piece.kind == "top" then
				base = style.top or skin
			else
				base = skin
			end
			part.Color = tint(region.muscles, base, template ~= "")
			local material = if marble then Enum.Material.Marble
				elseif piece.kind == "shorts" and template == "" then Enum.Material.Fabric
				else Enum.Material.SmoothPlastic
			if part.Material ~= material then part.Material = material end
			-- layered clothing on this part hides it (not while a fade runs)
			if hidden and part.Transparency < 1 then part.Transparency = 1 end
			if not hidden and part.Transparency >= 1 and state.wasHidden then part.Transparency = 0 end
		end
		state.wasHidden = hidden
		-- the stage replaces the plain body part (shown again under layered clothing)
		local bodyTransparency = if hidden then 0 else 1
		if body.Transparency ~= bodyTransparency then body.Transparency = bodyTransparency end
	end
end

function BodyStages.Destroy(self)
	for _, state in pairs(self.regions) do
		for _, part in pairs(state.parts) do part:Destroy() end
		if state.body and state.body.Parent then state.body.Transparency = 0 end
	end
	table.clear(self.regions)
end

return BodyStages
