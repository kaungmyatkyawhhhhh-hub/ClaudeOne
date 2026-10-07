-- LimbStages: Forearms and Calves on one character as STATIC stage meshes (client side, used by MuscleRig).
-- Each limb mesh (Config.LimbStages) has 7 stages by look g; the stage nearest to the muscle's displayed look (after the look
-- balance cap) is a MeshPart welded to its LowerArm / LowerLeg, and a stage change cross-fades the two over FadeTime. The
-- parts are clones of the templates in ReplicatedStorage.LimbStages (made once in Studio by tools/limb_stages_setup.luau
-- from the uploaded meshes). They are ordinary MeshParts: no EditableMesh, no limit, so every character can have them.
--   * size and weld follow the body part's size (golden ratio, Growth Spurts, widths): scale = body.Size / reference size;
--   * clothing: TextureID = the character's Shirt (forearms) / Pants (calves) image, Color = the skin, so see-through areas
--     of the clothing show skin like on the real body part; layered clothing on that part hides them;
--   * the rep flash and the stats hover highlight tint the part's Color like the other muscles.
--   local limbs = LimbStages.new(model, folder, static)  -- nil when the templates aren't there
--   limbs:Update(getG, style, tints, covered)            -- every frame
--   limbs:Destroy()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.Config.LimbStages)
-- the body part reference sizes the mesh data was made for (MuscleData.Index; not MuscleMeshes, which requires this module)
local PARTS = (require(ReplicatedStorage:WaitForChild("MuscleData"):WaitForChild("Index")) :: any).parts

local LimbStages = {}
LimbStages.__index = LimbStages

local templates = ReplicatedStorage:FindFirstChild("LimbStages")

-- True when every stage template is there (then MuscleMeshes leaves the EditableMesh forearms / calves out).
function LimbStages.Available(): boolean
	if not templates then return false end
	for _, mesh in pairs(Config.Meshes) do
		for _, stage in ipairs(mesh.stages) do
			local template = templates:FindFirstChild(stage.file)
			if not (template and template:IsA("MeshPart")) then return false end
		end
	end
	return true
end
local available = LimbStages.Available()
function LimbStages.IsOn(): boolean return available end

-- The muscle ids drawn by stages (MuscleMeshes leaves their units out).
LimbStages.Muscles = { Forearms = true, Calves = true }

local function nearestStage(stages, g: number): number
	local best, bestDistance = 1, math.huge
	for index, stage in ipairs(stages) do
		local distance = math.abs(stage.g - g)
		if distance < bestDistance then best, bestDistance = index, distance end
	end
	return best
end

function LimbStages.new(model: Model, folder: Instance, static: boolean)
	if not available then return nil end
	local self = setmetatable({ model = model, folder = folder, static = static, limbs = {} }, LimbStages)
	for name, mesh in pairs(Config.Meshes) do
		self.limbs[name] = { def = mesh, stage = nil, part = nil, weld = nil, fading = {} }
	end
	return self
end

local function place(self, limb, part: MeshPart, body: BasePart, stage)
	local ref = PARTS[limb.def.part] and PARTS[limb.def.part].size or body.Size
	local scale = body.Size / ref
	part.Size = part.MeshSize * scale
	local offset = CFrame.new(stage.center * scale)
	if self.static then
		part.CFrame = body.CFrame * offset
	else
		local weld = part:FindFirstChildOfClass("Weld")
		if weld then
			weld.C0 = offset
		end
	end
end

local function makePart(self, limb, body: BasePart, stage): MeshPart?
	local template = templates and templates:FindFirstChild(stage.file)
	if not template then return nil end
	local part = template:Clone() :: MeshPart
	part.Name = limb.def.part .. limb.def.muscle .. "Stage"
	part:SetAttribute("Stage", stage.file)
	part.Anchored = self.static
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.Massless = true
	if not self.static then
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = body, part
		weld.Parent = part
	end
	place(self, limb, part, body, stage)
	part.Parent = self.folder
	return part
end

local function fade(part: Instance, to: number, time: number, done: (() -> ())?)
	local tween = TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Sine), { Transparency = to })
	if done then tween.Completed:Connect(done) end
	tween:Play()
end

-- getG(muscleId, meshKey) -> the displayed look g; style = { skin, shirt, pants }; tint(muscleId, base) -> Color3;
-- covered = { [bodyPartName] = true } under layered clothing; marble = the statue look.
function LimbStages.Update(self, getG, style, tint, covered, marble)
	for _, limb in pairs(self.limbs) do
		local def = limb.def
		local body = self.model:FindFirstChild(def.part)
		if not (body and body:IsA("BasePart")) then continue end
		-- an outfit change can swap the body parts: start again on the new one
		if limb.part and limb.body ~= body then
			limb.part:Destroy()
			limb.part, limb.stage = nil, nil
		end
		limb.body = body
		local g = getG(def.muscle, def.muscle)
		local index = nearestStage(def.stages, g)
		local hidden = covered and covered[def.part] == true
		if index ~= limb.stage then
			local stage = def.stages[index]
			local new = makePart(self, limb, body, stage)
			if new then
				local old = limb.part
				local first = old == nil
				new.Transparency = if first or hidden then (hidden and 1 or 0) else 1
				if old and not hidden then
					fade(new, 0, Config.FadeTime)
					fade(old, 1, Config.FadeTime, function() old:Destroy() end)
				elseif old then
					old:Destroy()
				end
				limb.part, limb.stage, limb.size = new, index, nil
			end
		end
		local part = limb.part
		if not part then continue end
		-- the body part's size changed (Growth Spurt, widths): re-fit
		if limb.size ~= body.Size then
			limb.size = body.Size
			place(self, limb, part, body, def.stages[limb.stage])
		end
		if self.static then part.CFrame = body.CFrame * CFrame.new(def.stages[limb.stage].center * (body.Size / (PARTS[def.part] and PARTS[def.part].size or body.Size))) end
		-- clothing and color (the skin shows where the clothing image is see-through)
		local template = if marble then "" else (if def.clothing == "Pants" then style.pants else style.shirt) or ""
		if part.TextureID ~= template then part.TextureID = template end
		local base = if marble then Color3.fromHex("#C9C6BF") else (style.skin or body.Color)
		part.Color = tint(def.muscle, base)
		if marble and part.Material ~= Enum.Material.Marble then part.Material = Enum.Material.Marble end
		if not marble and part.Material ~= Enum.Material.SmoothPlastic then part.Material = Enum.Material.SmoothPlastic end
		-- layered clothing on this part hides it (not while a fade runs)
		if hidden and part.Transparency < 1 then part.Transparency = 1 end
		if not hidden and part.Transparency >= 1 and limb.shownHidden then part.Transparency = 0 end
		limb.shownHidden = hidden
	end
end

function LimbStages.Destroy(self)
	for _, limb in pairs(self.limbs) do
		if limb.part then limb.part:Destroy() end
		limb.part = nil
	end
end

return LimbStages
