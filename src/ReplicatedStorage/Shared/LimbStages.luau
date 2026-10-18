-- LimbStages: Forearms and Calves on one character as STATIC stage meshes (client side, used by MuscleRig).
-- Each limb mesh (Config.LimbStages) has 7 stages by look g; the stage nearest to the muscle's displayed look is a MeshPart
-- welded to its LowerArm / LowerLeg, and a stage change cross-fades the two over FadeTime. The
-- parts are clones of the templates in ReplicatedStorage.LimbStages (made once in Studio by tools/limb_stages_setup.luau
-- from the uploaded meshes). They are ordinary MeshParts: no EditableMesh, no limit, so every character can have them.
--   * size and weld follow the body part's size (golden ratio, Growth Spurts, widths): scale = body.Size / reference size;
--   * clothing: TextureID = the character's Shirt (forearms) / Pants (calves) image on the stage part, made a hair
--     see-through (CLOTH_TRANSPARENCY) so the image's see-through areas show the "Skin" part just inside it (the same mesh,
--     no image, the skin color), like the muscle meshes. Bug, 13 Oct ("Wardrobe clothes broken"): a fully solid part
--     ignores the image's transparency, so the see-through pixels (stored as black) drew BLACK: the dark bands on the
--     forearms (short sleeves) and calves. Layered clothing on that part hides them;
--   * the rep flash and the stats hover highlight tint the part's Color like the other muscles;
--   * a stage is the whole lower arm / leg, so the plain body part under it is hidden (its square ends would poke out at
--     the wrist and ankle); it shows again under layered clothing and when the stages go away.
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

local CLOTH_TRANSPARENCY = 0.02 -- the clothed stage part (see the header)
local SKIN_SCALE = 0.97        -- the skin part just inside it
-- Joint fillers (owner, 19 Oct: "see-through holes at the elbows and knees"): the upper and lower limb meshes are open at the
-- joint, so a bent elbow / knee opened a gap you could see through. Each forearm / calf stage gets a skin-colored ball on
-- its joint (the elbow / knee rig attachment of its LowerArm / LowerLeg, so it follows the pose), sized from the stage's
-- girth (JOINT_SIZE x its smaller width, so it grows with the muscle; inside the limb while it's straight). Cheap: one Ball
-- part per limb, resized only when the stage or the body size changes.
local JOINT_SIZE = { Forearms = 0.74, Calves = 0.78 }
local JOINT_DROP = { Forearms = 0.04, Calves = 0.04 } -- studs the ball sits below the joint (into the lower limb), unscaled

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
	local offset = CFrame.new(stage.center * scale) * Config.ImportTurn
	local skin = part:FindFirstChild("Skin")
	if skin then skin.Size = skin.MeshSize * scale * SKIN_SCALE end
	if self.static then
		part.CFrame = body.CFrame * offset
		if skin then skin.CFrame = part.CFrame end
	else
		local weld = part:FindFirstChildOfClass("Weld")
		if weld then
			weld.C0 = offset
		end
		local skinWeld = skin and skin:FindFirstChildOfClass("Weld")
		if skinWeld then skinWeld.C0 = offset end
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
	-- the skin just inside it (shows only while the stage wears a clothing image; see the header)
	local skin = template:Clone() :: MeshPart
	skin.Name = "Skin"
	skin.TextureID = ""
	skin.Anchored = self.static
	skin.CanCollide, skin.CanQuery, skin.CanTouch, skin.CastShadow = false, false, false, false
	skin.Massless = true
	skin.Transparency = 1
	if not self.static then
		local skinWeld = Instance.new("Weld")
		skinWeld.Part0, skinWeld.Part1 = body, skin
		skinWeld.Parent = skin
	end
	skin.Parent = part
	place(self, limb, part, body, stage)
	part.Parent = self.folder
	return part
end

-- the joint ball of one limb: made once, then placed / sized from the stage part
local function jointAttachment(body: BasePart): Attachment?
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("Attachment") and (child.Name:find("ElbowRigAttachment") or child.Name:find("KneeRigAttachment")) then return child end
	end
	return nil
end
local function updateJoint(self, limb, body: BasePart, part: MeshPart?, color: Color3, material: Enum.Material, hidden: boolean)
	local attachment = jointAttachment(body)
	local ball = limb.joint
	if not (attachment and part) then
		if ball then ball.Transparency = 1 end
		return
	end
	if not ball then
		ball = Instance.new("Part")
		ball.Name = limb.def.part .. "JointFill"
		ball.Shape = Enum.PartType.Ball
		ball.Anchored = self.static
		ball.CanCollide, ball.CanQuery, ball.CanTouch, ball.CastShadow = false, false, false, false
		ball.Massless = true
		ball.TopSurface, ball.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if not self.static then
			local weld = Instance.new("Weld")
			weld.Part0, weld.Part1 = body, ball
			weld.Parent = ball
		end
		ball.Parent = self.folder
		limb.joint = ball
	end
	local muscle = limb.def.muscle
	local size = math.min(part.Size.X, part.Size.Z) * (JOINT_SIZE[muscle] or 0.75)
	local scaleY = body.Size.Y / ((PARTS[limb.def.part] and PARTS[limb.def.part].size or body.Size).Y)
	local offset = CFrame.new(attachment.Position - Vector3.new(0, (JOINT_DROP[muscle] or 0) * scaleY, 0))
	if math.abs(ball.Size.X - size) > 0.002 then ball.Size = Vector3.new(size, size, size) end
	if self.static then
		ball.CFrame = body.CFrame * offset
	else
		local weld = ball:FindFirstChildOfClass("Weld")
		if weld and weld.Part0 ~= body then weld.Part0 = body end
		if weld and weld.C0 ~= offset then weld.C0 = offset end
	end
	if ball.Color ~= color then ball.Color = color end
	if ball.Material ~= material then ball.Material = material end
	local t = if hidden then 1 else 0
	if ball.Transparency ~= t then ball.Transparency = t end
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
			if limb.joint then limb.joint:Destroy() end
			limb.part, limb.stage, limb.joint = nil, nil, nil
			if limb.body and limb.body.Parent then limb.body.Transparency = 0 end
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
		local skin = part:FindFirstChild("Skin") :: MeshPart?
		if self.static then
			part.CFrame = body.CFrame * CFrame.new(def.stages[limb.stage].center * (body.Size / (PARTS[def.part] and PARTS[def.part].size or body.Size))) * Config.ImportTurn
			if skin then skin.CFrame = part.CFrame end
		end
		-- clothing and color (the skin part shows where the clothing image is see-through)
		local template = if marble then "" else (if def.clothing == "Pants" then style.pants else style.shirt) or ""
		if part.TextureID ~= template then part.TextureID = template end
		local base = if marble then Color3.fromHex("#C9C6BF") else (style.skin or body.Color)
		part.Color = tint(def.muscle, base)
		local clothed = template ~= ""
		-- (a clothed part is a hair see-through, so the image's see-through pixels show the skin part instead of black)
		if part.Transparency < 0.5 then
			local want = if clothed then CLOTH_TRANSPARENCY else 0
			if part.Transparency ~= want and part.Transparency < 0.03 then part.Transparency = want end
		end
		if skin then
			skin.Color = part.Color
			if skin.Material ~= part.Material then skin.Material = part.Material end
			local skinT = if clothed and not hidden and part.Transparency < 0.5 then 0 else 1
			if skin.Transparency ~= skinT then skin.Transparency = skinT end
		end
		if marble and part.Material ~= Enum.Material.Marble then part.Material = Enum.Material.Marble end
		if not marble and part.Material ~= Enum.Material.SmoothPlastic then part.Material = Enum.Material.SmoothPlastic end
		-- layered clothing on this part hides it (not while a fade runs)
		if hidden and part.Transparency < 1 then part.Transparency = 1 end
		if not hidden and part.Transparency >= 1 and limb.shownHidden then part.Transparency = 0 end
		limb.shownHidden = hidden
		-- the ball that closes the elbow / knee (skin colored; the clothing color under a sleeve or pants leg doesn't matter:
		-- it only shows inside a bent joint)
		local skinColor = if marble then Color3.fromHex("#C9C6BF") else (style.skin or body.Color)
		updateJoint(self, limb, body, part, tint(def.muscle, skinColor), if marble then Enum.Material.Marble else Enum.Material.SmoothPlastic, hidden)
		-- the stage replaces the plain body part (shown again under layered clothing)
		local bodyTransparency = if hidden then 0 else 1
		if body.Transparency ~= bodyTransparency then body.Transparency = bodyTransparency end
	end
end

function LimbStages.Destroy(self)
	for _, limb in pairs(self.limbs) do
		if limb.part then limb.part:Destroy() end
		if limb.joint then limb.joint:Destroy() end
		limb.part, limb.joint = nil, nil
		if limb.body and limb.body.Parent then limb.body.Transparency = 0 end
	end
end

return LimbStages
