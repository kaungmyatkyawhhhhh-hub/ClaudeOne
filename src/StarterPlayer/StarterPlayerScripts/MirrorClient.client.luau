-- MirrorClient: the progress mirror.
--  * Before/after screen (opened from the mirror's Look prompt): two 3D views side by side, your day-one body and your
--    body now (rigs built by MirrorService from your avatar), each with height and level underneath. Made for
--    screenshots.
--  * Live reflection: the glass shows a mirrored copy of you while you're near it (client only, see the bottom).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Muscles = require(Shared.Config.Muscles) -- average level under "Now"
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local MuscleRig = require(Shared.MuscleRig)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local gui = Theme.ScreenGui({ Name = "ProgressMirror", Enabled = false, DisplayOrder = 27, Parent = player:WaitForChild("PlayerGui") })
gui.ScreenInsets = Enum.ScreenInsets.None
local backdrop = New("TextButton", { Name = "Backdrop", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Background, BackgroundTransparency = 0.15, Text = "", AutoButtonColor = false, Parent = gui })
local root = New("Frame", {
	Name = "Root",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.86, 0.86),
	BackgroundTransparency = 1,
	Parent = Theme.SafeArea(backdrop),
}, { Theme.Limit(Vector2.new(420, 280), Vector2.new(900, 620)), Theme.List(Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })

local header = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = root })
local title = Theme.Text({ Font = "SemiBold", TextSize = "Large", Size = UDim2.fromScale(1, 1), Parent = header })
local columns = New("Frame", { LayoutOrder = 2, Size = UDim2.fromScale(1, 0), BackgroundTransparency = 1, Parent = root },
	{ New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.List(Horizontal, "L", Enum.HorizontalAlignment.Center) })
local closeButton = Theme.Button("Secondary", { Name = "Close", LayoutOrder = 3, Size = UDim2.fromOffset(140, Theme.MinTouch), Parent = root }, {
	Theme.Text({ Text = "Close", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

local function column(order)
	local col = New("Frame", { LayoutOrder = order, Size = UDim2.fromScale(0.46, 1), BackgroundTransparency = 1, Parent = columns },
		{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
	local viewport = New("ViewportFrame", {
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		-- posing-stage lighting: a strong golden key from the side and front over a dim warm fill, so every muscle casts a shade
		Ambient = Color3.fromRGB(110, 92, 70),
		LightColor = Color3.fromRGB(255, 205, 120),
		LightDirection = Vector3.new(-0.75, -0.45, -0.6),
		Parent = col,
	}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.Round("Panel"), Theme.Stroke(Colors.Border, 1, Theme.Alpha.Border) })
	local name = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), Parent = col })
	local info = Theme.Text({ LayoutOrder = 3, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), Parent = col })
	return viewport, name, info
end
local beforeView, beforeName, beforeInfo = column(1)
local afterView, afterName, afterInfo = column(2)

-- A copy of a preview rig (built by MirrorService from the avatar's HumanoidDescription) for a viewport: facing the
-- camera (+Z), feet on y = 0 in the middle. Returns the copy and its bounding box size.
local function prepare(rig)
	if typeof(rig) ~= "Instance" or not rig:IsA("Model") then return nil end
	local copy = rig:Clone()
	local rootPart = copy:FindFirstChild("HumanoidRootPart")
	if rootPart then copy.PrimaryPart = rootPart end
	local pivot = copy:GetPivot()
	local look = rootPart and rootPart.CFrame.LookVector or Vector3.new(0, 0, 1)
	local yaw = math.atan2(look.X, look.Z) -- 0 when already facing +Z
	copy:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, -yaw, 0) * pivot.Rotation)
	local cf, size = copy:GetBoundingBox()
	copy:PivotTo(copy:GetPivot() - Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z))
	return copy, size
end

-- the muscle meshes (muscle v7) of the two viewport bodies; built by the client from the numbers the server put on the rigs
local muscleRigs = {}
local function addMuscles(copy)
	local source = copy
	local rig = MuscleRig.new(copy, { static = true, priority = 200, noSnatch = true, style = MuscleRig.StyleFrom(source, copy) })
	rig:Snap(MuscleRig.Decode(source:GetAttribute("MuscleG")))
	table.insert(muscleRigs, rig)
end
local function clearMuscles()
	for _, rig in ipairs(muscleRigs) do rig:Destroy() end
	table.clear(muscleRigs)
end

local function show(viewport, copy, tallest)
	for _, child in ipairs(viewport:GetChildren()) do
		if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
	end
	if not copy then return end
	local world = New("WorldModel", { Parent = viewport })
	copy.Parent = world
	local camera = New("Camera", { FieldOfView = 30, Parent = viewport })
	viewport.CurrentCamera = camera
	-- the same camera for both views, framed on the taller body, so the height difference shows
	local distance = (tallest * 0.62) / math.tan(math.rad(camera.FieldOfView / 2))
	camera.CFrame = CFrame.lookAt(Vector3.new(0, tallest * 0.52, distance), Vector3.new(0, tallest * 0.5, 0))
end

local function averageLevel(data)
	local total = 0
	for _, group in ipairs(Muscles.Groups) do total += Muscles.GetGroupLevel(data.muscles, group.id) end
	return math.floor(total / #Muscles.Groups)
end

local isOpen = false
local function open(rigs)
	if isOpen or UIBus.MenuOpen or type(rigs) ~= "table" then return end
	local data = ClientData.Get()
	local dayOne = data.dayOne or { height = GrowthSpurts.StartHeight, level = 0 }
	local nowHeight = GrowthSpurts.GetHeight(data.growthSpurts)
	-- day one: the starting height, no muscle growth; now: today's height and muscle steps (both built by the server)
	local before, beforeSize = prepare(rigs.before)
	local after, afterSize = prepare(rigs.after)
	if not before or not after then return end
	local tallest = math.max(beforeSize.Y, afterSize.Y)
	show(beforeView, before, tallest)
	show(afterView, after, tallest)
	clearMuscles()
	addMuscles(before)
	addMuscles(after)
	title.Text = player.DisplayName .. " · GYM ARC"
	beforeName.Text = "Day one"
	beforeInfo.Text = GrowthSpurts.FormatHeight(dayOne.height or GrowthSpurts.StartHeight) .. "  ·  Level " .. (dayOne.level or 0)
	afterName.Text = "Now"
	afterInfo.Text = GrowthSpurts.FormatHeight(nowHeight) .. "  ·  Level " .. averageLevel(data)
		.. (data.growthSpurts > 0 and ("  ·  Growth Spurt " .. data.growthSpurts) or "")
	isOpen = true
	gui.Enabled = true
	Audio.PlayUI("Whoosh")
	Theme.Fade(root, true)
end

local function close()
	if not isOpen then return end
	isOpen = false
	local tween = Theme.Fade(root, false)
	if tween then
		tween.Completed:Connect(function()
			if not isOpen then
				gui.Enabled = false
				clearMuscles()
				for _, view in ipairs({ beforeView, afterView }) do
					for _, child in ipairs(view:GetChildren()) do
						if child:IsA("WorldModel") or child:IsA("Camera") then child:Destroy() end
					end
				end
			end
		end)
	else
		gui.Enabled = false
	end
end
closeButton.Activated:Connect(close)

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, payload)
	if kind == "OpenMirror" then open(payload) end
end)

------------------------------------------------------------------------
-- Live reflection on the glass: a ViewportFrame on a SurfaceGui shows a mirrored copy of your character (and of the
-- room in front of the mirror), rendered from your camera through the glass. Only runs within REFLECT_RANGE studs.
-- How: everything is reflected across the glass plane; the viewport camera sits at your camera and looks straight
-- into the glass (perpendicular), so the glass rectangle maps onto the image with a plain scale + offset, and the
-- ViewportFrame is sized and placed on the glass so that rectangle lines up exactly.
------------------------------------------------------------------------
local REFLECT_RANGE = 25 -- studs from the glass
local ROOM_DEPTH = 26    -- studs of room in front of the glass that get a static reflected copy
local PPS = 40           -- SurfaceGui pixels per stud

-- Reflect a CFrame across the plane (point p0, unit normal n): position mirrored, rotation M*R*M (a proper rotation).
local function reflector(p0, n)
	local nx, ny, nz = n.X, n.Y, n.Z
	local m = { -- M = I - 2nn^T
		{ 1 - 2 * nx * nx, -2 * nx * ny, -2 * nx * nz },
		{ -2 * ny * nx, 1 - 2 * ny * ny, -2 * ny * nz },
		{ -2 * nz * nx, -2 * nz * ny, 1 - 2 * nz * nz },
	}
	return function(cf)
		local p = cf.Position
		local q = p - 2 * (p - p0):Dot(n) * n
		local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		local r = { { r00, r01, r02 }, { r10, r11, r12 }, { r20, r21, r22 } }
		local mr, o = {}, {}
		for i = 1, 3 do
			mr[i] = {}
			for j = 1, 3 do mr[i][j] = m[i][1] * r[1][j] + m[i][2] * r[2][j] + m[i][3] * r[3][j] end
		end
		for i = 1, 3 do
			o[i] = {}
			for j = 1, 3 do o[i][j] = mr[i][1] * m[1][j] + mr[i][2] * m[2][j] + mr[i][3] * m[3][j] end
		end
		return CFrame.new(q.X, q.Y, q.Z, o[1][1], o[1][2], o[1][3], o[2][1], o[2][2], o[2][3], o[3][1], o[3][2], o[3][3])
	end
end

local function startReflection(mirrorModel, glass)
	local normal = glass.CFrame.LookVector -- the front face looks into the room
	local planePoint = glass.Position + normal * (glass.Size.Z / 2)
	local reflect = reflector(planePoint, normal)
	local up = Vector3.yAxis
	local right = up:Cross(normal) -- your right when you look into the glass (= the canvas X direction)

	local surface = New("SurfaceGui", {
		Name = "MirrorReflection",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = PPS,
		LightInfluence = 0,
		Brightness = 2.2,
		ClipsDescendants = true,
		Enabled = false,
		ResetOnSpawn = false,
		Adornee = glass,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local clip = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(78, 66, 58), ClipsDescendants = true, Parent = surface })
	local viewport = New("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(120, 98, 72), -- posing-stage lighting (golden key from the side, dim warm fill)
		LightColor = Color3.fromRGB(255, 205, 120),
		LightDirection = Vector3.new(-0.75, -0.45, 0.6),
		Parent = clip,
	})
	-- a faint cool sheen on top so it reads as glass, not a screen
	New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(235, 245, 255), BackgroundTransparency = 0.94, ZIndex = 2, Parent = clip })
	local world = New("WorldModel", { Parent = viewport })
	local camera = New("Camera", { Parent = viewport })
	viewport.CurrentCamera = camera

	local roomBuilt = false
	local mirrored = nil -- { model, pairs = { { source, copy } }, character }

	local function isCharacterPart(part)
		local model = part:FindFirstAncestorWhichIsA("Model")
		while model do
			if model:FindFirstChildOfClass("Humanoid") then return true end
			model = model.Parent and model.Parent:FindFirstAncestorWhichIsA("Model")
		end
		return false
	end

	-- the room in front of the glass, reflected once (static parts only; characters and the mirror itself left out)
	local function buildRoom()
		roomBuilt = true
		local center = planePoint + normal * (ROOM_DEPTH / 2) + Vector3.new(0, 4, 0)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { mirrorModel }
		params.MaxParts = 500
		local box = CFrame.fromMatrix(center, right, up, -normal)
		for _, part in ipairs(workspace:GetPartBoundsInBox(box, Vector3.new(ROOM_DEPTH * 1.6, 18, ROOM_DEPTH), params)) do
			if part.Transparency < 0.95 and not isCharacterPart(part) then
				local wasArchivable = part.Archivable
				part.Archivable = true
				local copy = part:Clone()
				part.Archivable = wasArchivable
				if copy then
					for _, child in ipairs(copy:GetChildren()) do
						if not (child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance")) then child:Destroy() end
					end
					copy.Anchored = true
					copy.CFrame = reflect(part.CFrame)
					copy.Parent = world
				end
			end
		end
	end

	local function buildCharacter(character)
		if mirrored then mirrored.model:Destroy() end
		mirrored = nil
		local wasArchivable = character.Archivable
		character.Archivable = true
		local copy = character:Clone()
		character.Archivable = wasArchivable
		if not copy then return end
		-- pair every part with its copy by its path inside the model (never by position in a list: that went wrong when children
		-- were ordered differently, which left the copy frozen like a statue)
		local function pathOf(item, root)
			local names = {}
			while item and item ~= root do
				table.insert(names, 1, item.Name)
				item = item.Parent
			end
			return names
		end
		local list = {}
		for _, source in ipairs(character:GetDescendants()) do
			if source:IsA("BasePart") then
				local item = copy
				for _, name in ipairs(pathOf(source, character)) do item = item and item:FindFirstChild(name) end
				if item and item:IsA("BasePart") then
					item.Anchored = true
					item.CanCollide = false
					table.insert(list, { source, item })
				end
			end
		end
		for _, item in ipairs(copy:GetDescendants()) do
			if item:IsA("BaseScript") or item:IsA("Sound") or item:IsA("BillboardGui") or item:IsA("ParticleEmitter") then item:Destroy() end
		end
		local sources = character:GetDescendants()
		-- the copy has NO Humanoid, Animator or joints: they could play a pose of their own. Every part is placed from your real
		-- part each frame, so it can only ever show exactly what you do.
		for _, item in ipairs(copy:GetDescendants()) do
			if item:IsA("Humanoid") or item:IsA("Animator") or item:IsA("Motor6D") or item:IsA("AnimationConstraint") or item:IsA("BallSocketConstraint") or item:IsA("Weld") or item:IsA("WeldConstraint") or item:IsA("RigidConstraint") then item:Destroy() end
		end
		-- the muscles: the cloned muscle MeshParts have no shape, so they are replaced by parts that show the SAME live meshes
		local sourceFolder, copyFolder = character:FindFirstChild("MuscleMeshes"), copy:FindFirstChild("MuscleMeshes")
		if copyFolder then
			for index = #list, 1, -1 do
				local pair = list[index]
				if pair[2]:IsDescendantOf(copyFolder) and MuscleRig.MeshOf(pair[1]) then table.remove(list, index) pair[2]:Destroy() end
			end
		end
		copy.Parent = world
		mirrored = { model = copy, pairs = list, character = character, count = #sources, version = character:GetAttribute("BodyVersion") }
		if sourceFolder and copyFolder then
			local pairsList = list
			task.spawn(function()
				for _, source in ipairs(sourceFolder:GetChildren()) do
					local mesh = source:IsA("MeshPart") and MuscleRig.MeshOf(source)
					if mesh then
						local ok, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh)) end)
						if ok and part and copyFolder.Parent then
							part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
							part.Color, part.Material, part.Size = source.Color, source.Material, source.Size
							part.TextureID, part.Transparency = source.TextureID, source.Transparency
							part.Parent = copyFolder
							table.insert(pairsList, { source, part })
						end
					end
				end
			end)
		end
	end

	local active = false
	RunService:BindToRenderStep("MirrorReflection", Enum.RenderPriority.Camera.Value + 1, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local eye = workspace.CurrentCamera.CFrame.Position
		local distance = (eye - planePoint):Dot(normal)
		local near = root ~= nil and (root.Position - glass.Position).Magnitude < REFLECT_RANGE and distance > 0.2
		if near ~= active then
			active = near
			surface.Enabled = near
			if not near and mirrored then
				mirrored.model:Destroy()
				mirrored = nil
			end
		end
		if not near then return end
		if not roomBuilt then buildRoom() end
		-- rebuild the copy when the character changes (respawn, new gear)
		if not mirrored or mirrored.character ~= character or mirrored.count ~= #character:GetDescendants() or mirrored.version ~= character:GetAttribute("BodyVersion") then
			buildCharacter(character)
		end
		if not mirrored then return end
		for _, pair in ipairs(mirrored.pairs) do
			local source, copy = pair[1], pair[2]
			copy.CFrame = reflect(source.CFrame)
			if copy.Size ~= source.Size then copy.Size = source.Size end
		end
		-- camera at your eye, looking straight into the glass; size and place the image so the glass lines up
		local foot = eye - normal * distance
		camera.CFrame = CFrame.fromMatrix(eye, right, up, normal)
		local half = glass.Size / 2
		local reach = 0
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				local offset = glass.Position + right * half.X * sx + up * half.Y * sy - foot
				reach = math.max(reach, math.abs(offset:Dot(right)), math.abs(offset:Dot(up)))
			end
		end
		local tanHalf = math.min(reach * 1.02 / distance, 5.6)
		camera.FieldOfView = math.deg(2 * math.atan(tanHalf))
		local sizePx = 2 * distance * tanHalf * PPS
		local canvas = surface.AbsoluteSize
		local cx = canvas.X / 2 + (foot - glass.Position):Dot(right) * PPS
		local cy = canvas.Y / 2 - (foot - glass.Position):Dot(up) * PPS
		viewport.Size = UDim2.fromOffset(sizePx, sizePx)
		viewport.Position = UDim2.fromOffset(cx - sizePx / 2, cy - sizePx / 2)
	end)
end

task.spawn(function()
	local mirrorModel = workspace:WaitForChild("ProgressMirror", 60)
	local glass = mirrorModel and mirrorModel:WaitForChild("Glass", 30)
	if glass and glass:IsA("BasePart") then startReflection(mirrorModel, glass) end
end)
