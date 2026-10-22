-- RollCinematic (prompt 55, 23 Oct): the trainer roll's cutscene IN THE WORLD for a Legendary or better (TrainerClient's
-- roll reveal plays it after the name roller lands). Our own effects and sounds (Roblox's library, Config.AlterThemes
-- sounds); every number is in Config.RollReveal.Cinematic.
--   * Black letterbox bars slide in, every other screen hides, the music goes to silence.
--   * The colours grade to the rarity (a ColorCorrectionEffect of our own; Legendary, the light version: none).
--   * The camera (scriptable) orbits the player ~90 degrees, low, looking up; particles in the rarity colour swirl in
--     around him (<= 60 alive), a low rumble and a rising tone.
--   * The peak: a beam of light hits the ground beside him, a shockwave ring spreads over the floor, a white flash, and the
--     trainer's own model stands in the beam in his flex pose. The camera pushes in on the two of them, his NAME fades in
--     big (white, stroked, spaced letters, a gold shimmer across it once) with the rarity in its colour and the chance.
--   * Secret: 1 s of black and silence first, one heartbeat, a glitch flicker, then the cutscene in white-gold light.
--   * Reduced Motion: the camera stays still (a fade instead of the orbit and the push), no flicker.
--   * Whatever happens (a skip, a reset, an error) the camera, the colours, the screens and the music come back.
--   RollCinematic.Play(spec) -> true (played) / false (skipped). spec = { trainer, rarity, color, chanceText, skipped = fn,
--   onTap = fn (a tap on the cutscene: the reveal decides whether it skips) }
--   RollCinematic.Beam(position, color, light) -- the beam and the shockwave alone (other players see these)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = script.Parent.Parent
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Audio = require(Shared.Audio)
local AlterFX = require(script.Parent.AlterFX)
local PoseApply = require(Shared.PoseApply)
local RollReveal = require(Shared.Config.RollReveal)

local New = Theme.New
local CFG = RollReveal.Cinematic
local RV = RollReveal.Volume
local INK = Color3.fromHex("#0A090B")
local GOLD = Color3.fromHex("#F6C75A")

local RollCinematic = {}

local function tween(instance, props, time, style, direction)
	local t = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- the floor under a point (a ray down; the point itself if nothing)
local function floorAt(position: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else position - Vector3.new(0, 3, 0)
end

local function ghostPart(props)
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.Neon
	for k, v in pairs(props) do part[k] = v end
	part.Parent = Workspace
	return part
end

-- The beam of light and the shockwave ring at `ground` (a floor point). Returns the parts (destroyed by themselves after
-- `hold` seconds, or by the caller).
local function beamAndRing(ground: Vector3, color: Color3, light: boolean, hold: number)
	local width = if light then CFG.lightBeamWidth else CFG.beamWidth
	local beam = ghostPart({ Name = "RollBeam", Shape = Enum.PartType.Cylinder, Color = color, Transparency = 0.15,
		Size = Vector3.new(CFG.beamHeight, 0.2, 0.2), CFrame = CFrame.new(ground + Vector3.new(0, CFG.beamHeight / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	local core = ghostPart({ Name = "RollBeamCore", Shape = Enum.PartType.Cylinder, Color = Color3.new(1, 1, 1), Transparency = 0.1,
		Size = Vector3.new(CFG.beamHeight, 0.1, 0.1), CFrame = beam.CFrame })
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = color, 24, 0
	glow.Parent = core
	tween(beam, { Size = Vector3.new(CFG.beamHeight, width, width) }, 0.18, Enum.EasingStyle.Back)
	tween(core, { Size = Vector3.new(CFG.beamHeight, width * 0.35, width * 0.35) }, 0.18)
	tween(glow, { Brightness = 6 }, 0.15)
	-- bright as it hits, then a see-through glow (the trainer stands in it and must show)
	task.delay(0.3, function()
		if beam.Parent then tween(beam, { Transparency = 0.72 }, 0.6) end
		if core.Parent then tween(core, { Transparency = 0.8 }, 0.6) end
	end)
	-- the shockwave ring on the floor (the shockwave texture on a flat part)
	local size = if light then CFG.lightRingSize else CFG.ringSize
	local ring = ghostPart({ Name = "RollRing", Transparency = 1, Size = Vector3.new(2, 0.05, 2), CFrame = CFrame.new(ground + Vector3.new(0, 0.08, 0)) })
	local decal = Instance.new("Decal")
	decal.Face, decal.Texture, decal.Color3, decal.Transparency = Enum.NormalId.Top, AlterFX.TEX.ring, color, 0
	decal.Parent = ring
	tween(ring, { Size = Vector3.new(size, 0.05, size) }, 0.9, Enum.EasingStyle.Quint)
	tween(decal, { Transparency = 1 }, 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local parts = { beam, core, ring }
	task.delay(hold, function()
		tween(beam, { Transparency = 1, Size = Vector3.new(CFG.beamHeight, width * 1.6, width * 1.6) }, 0.5)
		tween(core, { Transparency = 1 }, 0.4)
		tween(glow, { Brightness = 0 }, 0.4)
		task.delay(0.55, function() for _, p in ipairs(parts) do p:Destroy() end end)
	end)
	return parts
end

-- (other players) the beam and the shockwave beside a player who rolled a Legendary+, with its sound in the world
function RollCinematic.Beam(position: Vector3, color: Color3, light: boolean?)
	local ground = floorAt(position, {})
	local parts = beamAndRing(ground, color, light == true, 1.6)
	AlterFX.Sound("FlashBoom", { parent = parts[1], volume = 0.7 })
	AlterFX.Sound("Shing", { parent = parts[1], volume = 0.6, delay = 0.05 })
end

------------------------------------------------------------------------
-- The cutscene
------------------------------------------------------------------------
local active = nil -- the running cutscene's cleanup (only one at a time)

function RollCinematic.Play(spec): boolean
	local player = Players.LocalPlayer
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return true end
	if active then active() end
	local rarity, trainer = spec.rarity, spec.trainer
	local look = CFG[rarity.id] or CFG.Mythic
	local length = look.length
	local light = look.light == true
	local color = if look.color then Color3.fromHex(look.color) else spec.color
	local reduced = Theme.ReducedMotion()
	local skipped = spec.skipped or function() return false end
	local camera = Workspace.CurrentCamera
	local playerGui = player:WaitForChild("PlayerGui")

	-- everything to put back
	local hiddenGuis, parts, connections, sounds, blurs = {}, {}, {}, {}, {}
	local grade, gui, model = nil, nil, nil
	local cameraType, cameraSubject = camera.CameraType, camera.CameraSubject
	local done = false
	local function cleanup()
		if done then return end
		done = true
		active = nil
		for _, c in ipairs(connections) do c:Disconnect() end
		for _, p in ipairs(parts) do if p.Parent then p:Destroy() end end
		for _, s in ipairs(sounds) do if s.Parent then AlterFX.FadeOut(s, 0.3) end end
		if model then model:Destroy() end
		if grade then
			tween(grade, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }, 0.4)
			local g = grade
			task.delay(0.45, function() g:Destroy() end)
		end
		camera.CameraType = if cameraType == Enum.CameraType.Scriptable then Enum.CameraType.Custom else cameraType
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		camera.CameraSubject = hum or cameraSubject
		for g in pairs(hiddenGuis) do if g.Parent then g.Enabled = true end end
		for b in pairs(blurs) do if b.Parent then b.Enabled = true end end
		if gui then gui:Destroy() end
		Audio.Duck(RollReveal.MusicDuck, 0.4)
	end
	active = cleanup

	local ok, result = pcall(function()
		-- the letterbox, the big words, the black / flash layer (over the roll overlay)
		gui = Theme.ScreenGui({ Name = "RollCinematic", DisplayOrder = 56, Parent = playerGui })
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
		local top = New("Frame", { Name = "BarTop", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, CFG.letterbox), ZIndex = 5, Parent = gui })
		local bottom = New("Frame", { Name = "BarBottom", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, CFG.letterbox), ZIndex = 5, Parent = gui })
		local cover = New("Frame", { Name = "Cover", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
			ZIndex = 20, Parent = gui })
		local textRoot = Kit.Root(gui, "Words")
		textRoot.ZIndex = 10
		-- a tap anywhere: the reveal's skip (the roll overlay and its own tap catcher are hidden while this plays)
		local tap = New("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = gui })
		tap.Activated:Connect(function() if spec.onTap then spec.onTap() end end)

		-- every other screen hides (the roll overlay too: the world is the show), and stays hidden: a screen that turns
		-- itself on during the cutscene (the right cards follow the window state) goes off again the same frame
		local function hideScreens()
			for _, g in ipairs(playerGui:GetChildren()) do
				if g:IsA("ScreenGui") and g.Enabled and g ~= gui then
					hiddenGuis[g] = true
					g.Enabled = false
				end
			end
		end
		hideScreens()
		table.insert(connections, RunService.RenderStepped:Connect(function() if not done then hideScreens() end end))
		-- the world sharp: the windows' and the reveal's blur off while it plays
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("BlurEffect") and effect.Enabled then
				blurs[effect] = true
				effect.Enabled = false
			end
		end
		-- a reset or a respawn ends it at once
		table.insert(connections, player.CharacterAdded:Connect(function() cleanup() end))
		table.insert(connections, humanoid.Died:Connect(function() cleanup() end))

		local function wait_(t: number): boolean
			local t0 = os.clock()
			while os.clock() - t0 < t do
				if done or skipped() then return false end
				task.wait()
			end
			return not done and not skipped()
		end

		-- Secret: black and silence, one heartbeat, a glitch flicker
		if look.blackout then
			cover.BackgroundTransparency = 0
			Audio.Duck(0, 0.1)
			if not wait_(look.blackout) then return false end
			table.insert(sounds, AlterFX.Sound("Heartbeat", { volume = RV.heartbeat * 1.3, pitch = 0.8, maxLength = 1 }))
			if not wait_(0.55) then return false end
			if reduced then
				tween(cover, { BackgroundTransparency = 1 }, 0.4)
			else
				for _, a in ipairs({ 0.6, 0, 0.3, 0.9, 0.1, 0.7, 1 }) do
					cover.BackgroundTransparency = a
					textRoot.Position = UDim2.fromOffset(math.random(-6, 6), 0)
					if not wait_(0.045) then return false end
				end
				textRoot.Position = UDim2.new()
				cover.BackgroundTransparency = 1
			end
		end

		-- the bars in, the music out, the colours graded
		tween(top, { Position = UDim2.fromScale(0, CFG.letterbox) }, CFG.barsTime)
		tween(bottom, { Position = UDim2.fromScale(0, 1 - CFG.letterbox) }, CFG.barsTime)
		Audio.Duck(0, 0.5)
		if not light then
			grade = New("ColorCorrectionEffect", { Name = "RollGrade", Parent = Lighting })
			local g = CFG.grade
			tween(grade, { Brightness = g.brightness, Contrast = g.contrast, Saturation = g.saturation, TintColor = color:Lerp(Color3.new(1, 1, 1), g.tint) }, length * 0.35)
		end
		table.insert(sounds, AlterFX.Sound("Swell", { volume = RV.rumble, pitch = 0.55, fadeIn = 0.6, maxLength = length }))
		table.insert(sounds, AlterFX.Sound("Riser", { volume = RV.swell, pitch = 0.9, fadeIn = 0.3, maxLength = length * CFG.peakAt }))

		-- where: the player, the floor, the beam to his right
		local center = root.Position
		local ground = floorAt(center, { character })
		local forward = (root.CFrame.LookVector * Vector3.new(1, 0, 1))
		forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
		local right = forward:Cross(Vector3.new(0, 1, 0)).Unit
		local beamGround = floorAt(center + right * CFG.beamSide, { character })
		local focus = (center + beamGround + Vector3.new(0, center.Y - beamGround.Y, 0)) / 2

		-- the particles swirling in round him (an emitter on a ring, inward, rising)
		local swirl = ghostPart({ Name = "RollSwirl", Transparency = 1, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(ground + Vector3.new(0, 0.5, 0)) })
		table.insert(parts, swirl)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = AlterFX.TEX.spark
		emitter.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color)
		emitter.LightEmission, emitter.LightInfluence = 1, 0
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(1.2, 1.5)
		emitter.Shape, emitter.ShapeStyle, emitter.ShapeInOut = Enum.ParticleEmitterShape.Cylinder, Enum.ParticleEmitterShapeStyle.Surface, Enum.ParticleEmitterShapeInOut.Inward
		emitter.Speed = NumberRange.new(5, 8)
		emitter.Acceleration = Vector3.new(0, 4, 0)
		emitter.RotSpeed = NumberRange.new(-120, 120)
		emitter.Rate = 0
		emitter.LockedToPart = false
		emitter.Parent = swirl
		swirl.Size = Vector3.new(16, 1, 16)
		local maxRate = CFG.particles / 1.35 -- (alive at once = rate x lifetime)

		-- the camera: scriptable, low, looking up, orbiting (Reduced Motion: still)
		camera.CameraType = Enum.CameraType.Scriptable
		local startAngle = math.atan2(forward.X, forward.Z) - math.rad(35) -- (in front of him, a little to the side)
		local t0 = os.clock()
		local nameLabel, subLabel, shimmer = nil, nil, nil
		-- his flex pose (Config/Trainers pose; one that isn't a PoseData pose: the front double biceps)
		local poseData = require(ReplicatedStorage:WaitForChild("PoseData"))
		local poseTable = poseData[trainer.pose or ""] or poseData.FrontDoubleBiceps
		local function place(k: number)
			local orbit = if reduced then 0 else math.rad(CFG.orbit) * k
			local push = if k > CFG.peakAt and not reduced then (k - CFG.peakAt) / (1 - CFG.peakAt) else 0
			local distance = CFG.distance * (1 - (1 - CFG.pushIn) * math.sin(push * math.pi / 2))
			local angle = startAngle + orbit
			local target = (if k > CFG.peakAt then focus else center) + Vector3.new(0, CFG.lookUp - 1, 0)
			local eye = Vector3.new(center.X, center.Y + CFG.height, center.Z) + Vector3.new(math.sin(angle), 0, math.cos(angle)) * distance
			camera.CFrame = CFrame.lookAt(eye, target)
		end
		place(0)
		table.insert(connections, RunService.RenderStepped:Connect(function()
			if done then return end
			local k = math.clamp((os.clock() - t0) / length, 0, 1)
			place(k)
			-- the particles build up toward the peak, then ease off
			emitter.Rate = if k < CFG.peakAt then maxRate * (0.2 + 0.8 * k / CFG.peakAt) else maxRate * math.max(0, 1 - (k - CFG.peakAt) * 3)
			if model and poseTable then PoseApply.Apply(model, poseTable, 1) end
		end))

		-- the peak
		if not wait_(length * CFG.peakAt) then return false end
		cover.BackgroundColor3 = Color3.new(1, 1, 1)
		cover.BackgroundTransparency = if reduced then 0.5 else 0
		tween(cover, { BackgroundTransparency = 1 }, 0.35)
		for _, p in ipairs(beamAndRing(beamGround, color, light, length * (1 - CFG.peakAt) - 0.2)) do table.insert(parts, p) end
		table.insert(sounds, AlterFX.Sound("FlashBoom", { volume = RV.sub }))
		table.insert(sounds, AlterFX.Sound("ImpactPunch", { volume = RV.impact }))
		table.insert(sounds, AlterFX.Sound("Shing", { volume = RV.shine, delay = 0.05 }))
		-- the trainer in the beam, flexing, facing the camera side
		local template = ReplicatedStorage:FindFirstChild("TrainerModels") and ReplicatedStorage.TrainerModels:FindFirstChild(trainer.id)
		if template then
			model = template:Clone()
			local mroot = model:FindFirstChild("HumanoidRootPart")
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide, part.CanTouch, part.CanQuery = false, false, false end
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator", hum) end
			if mroot then
				mroot.Anchored = true
				local height = if hum then hum.HipHeight + mroot.Size.Y / 2 else 3
				local faceTo = Vector3.new(center.X, beamGround.Y + height, center.Z) + forward * 6
				model.Parent = Workspace
				model:PivotTo(CFrame.lookAt(beamGround + Vector3.new(0, height, 0), faceTo))
			else
				model:Destroy()
				model = nil
			end
		end

		-- the words
		if not wait_(length * (CFG.textAt - CFG.peakAt)) then return false end
		local spaced = table.concat(string.split(string.upper(trainer.name), ""), " ")
		-- a soft dark band behind the words (low on the screen, over the bottom bar's edge)
		local band = New("Frame", { Name = "Band", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40),
			Size = UDim2.new(1, 0, 0, 104), BackgroundTransparency = 1, ZIndex = 10, Parent = textRoot }, {
			New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35),
				NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) }) }),
		})
		tween(band, { BackgroundTransparency = 0 }, 0.4)
		nameLabel = Kit.Text({ Name = "Name", Text = spaced, Font = "Title", TextSize = 46, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -82),
			Size = UDim2.new(1, -40, 0, 54), TextTransparency = 1, ZIndex = 11, Parent = textRoot })
		Kit.Fit(nameLabel, 46, 22)
		local stroke = nameLabel:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Parent = nameLabel })
		stroke.Color, stroke.Thickness, stroke.Transparency = INK, 3, 1
		shimmer = New("UIGradient", { Offset = Vector2.new(-1.2, 0), Rotation = 15, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.44, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(0.56, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)) }), Parent = nameLabel })
		local wordColor = if look.color then color else spec.color
		subLabel = Kit.Text({ Name = "Rarity", Text = string.format('<font color="#%s">%s</font>  ·  %s', wordColor:ToHex(), string.upper(rarity.name), spec.chanceText),
			Font = "Chunky", TextSize = 22, RichText = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -50), Size = UDim2.new(1, -40, 0, 28),
			TextTransparency = 1, ZIndex = 11, Parent = textRoot })
		local subStroke = subLabel:FindFirstChildOfClass("UIStroke") or New("UIStroke", { Parent = subLabel })
		subStroke.Color, subStroke.Thickness, subStroke.Transparency = INK, 2, 1
		tween(nameLabel, { TextTransparency = 0 }, 0.4)
		tween(stroke, { Transparency = 0 }, 0.4)
		task.delay(0.2, function()
			if subLabel.Parent then
				tween(subLabel, { TextTransparency = 0 }, 0.35)
				tween(subStroke, { Transparency = 0 }, 0.35)
			end
		end)
		task.delay(0.45, function() if shimmer.Parent then tween(shimmer, { Offset = Vector2.new(1.2, 0) }, 0.7, Enum.EasingStyle.Sine) end end)
		table.insert(sounds, AlterFX.Sound("TitleHit", { volume = RV.sting }))
		table.insert(sounds, AlterFX.Sound("Brass", { volume = RV.sting * 0.6, delay = 0.08 }))

		-- the end: the bars away, then everything comes back
		if not wait_(length * (1 - CFG.textAt) - CFG.barsTime) then return false end
		tween(top, { Position = UDim2.fromScale(0, 0) }, CFG.barsTime)
		tween(bottom, { Position = UDim2.fromScale(0, 1) }, CFG.barsTime)
		tween(nameLabel, { TextTransparency = 1 }, CFG.barsTime)
		tween(band, { BackgroundTransparency = 1 }, CFG.barsTime)
		tween(stroke, { Transparency = 1 }, CFG.barsTime)
		tween(subLabel, { TextTransparency = 1 }, CFG.barsTime)
		tween(subStroke, { Transparency = 1 }, CFG.barsTime)
		return wait_(CFG.barsTime)
	end)
	if not ok then warn("[RollCinematic] " .. tostring(result)) end
	cleanup()
	return ok and result ~= false
end

-- (a cutscene that's still running when the reveal closes: put everything back now)
function RollCinematic.Stop()
	if active then active() end
end

return RollCinematic
