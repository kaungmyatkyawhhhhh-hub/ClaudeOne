-- MirrorClient: the progress mirror.
--  * Before/after screen (opened from the mirror's Look prompt): two 3D views side by side, your day-one body and your
--    body now (rigs built by MirrorService from your avatar), each with height and level underneath. Made for
--    screenshots.
--  (The live reflection on the glass was removed, owner 15 Oct: the mirrors are plain glass now, no scripts, for
--  performance. The card never needed it: it builds its own two bodies.)
local Players = game:GetService("Players")
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
local BodyStages = require(Shared.BodyStages)
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

-- The gym's own light at the mirror (so the before / after card looks like the room around it): the
-- nearby lamps (each weighted by how much of it reaches the spot in front of the glass) give the key light's color and
-- direction, the place's Ambient gives the fill. Tune with MIRROR_LIGHT.
local MIRROR_LIGHT = {
	Reach = 40,      -- studs: lamps further than this from the glass are ignored
	Key = 0.8,       -- key light strength (the ViewportFrame light has no falloff, so it needs toning down; 0.55 left the muscles flat)
	Ambient = 0.8,   -- share of Lighting.Ambient used as the fill
}
local function gymLight(point: Vector3)
	local Lighting = game:GetService("Lighting")
	local dir, color, total = Vector3.zero, Vector3.zero, 0
	for _, light in ipairs(workspace:GetDescendants()) do
		if light:IsA("Light") and light.Enabled and light.Parent and light.Parent:IsA("BasePart") then
			local from = light.Parent.Position
			local offset = point - from
			local distance = offset.Magnitude
			if distance < MIRROR_LIGHT.Reach and distance < light.Range and distance > 0.01 then
				local w = light.Brightness * (1 - distance / light.Range) ^ 2
				if light:IsA("SpotLight") then
					local face = light.Parent.CFrame:VectorToWorldSpace(Vector3.fromNormalId(light.Face))
					if math.deg(math.acos(math.clamp(face:Dot(offset.Unit), -1, 1))) > light.Angle / 2 then w *= 0.15 end
				end
				dir += offset.Unit * w
				color += Vector3.new(light.Color.R, light.Color.G, light.Color.B) * w
				total += w
			end
		end
	end
	local ambient = Lighting.Ambient
	ambient = Color3.new(ambient.R * MIRROR_LIGHT.Ambient, ambient.G * MIRROR_LIGHT.Ambient, ambient.B * MIRROR_LIGHT.Ambient)
	if total <= 0 then return ambient, Color3.new(0, 0, 0), Vector3.new(0, -1, 0) end
	local c = color / total * math.min(total, 1) * MIRROR_LIGHT.Key
	return ambient, Color3.new(math.min(c.X, 1), math.min(c.Y, 1), math.min(c.Z, 1)), dir.Unit
end
local cardViewports = {} -- the before / after card's viewports (lit like the gym when the mirror is found)

local function column(order)
	local col = New("Frame", { LayoutOrder = order, Size = UDim2.fromScale(0.46, 1), BackgroundTransparency = 1, Parent = columns },
		{ Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top) })
	local viewport = New("ViewportFrame", {
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Colors.Panel,
		BackgroundTransparency = Theme.Alpha.Panel,
		-- (lit like the gym around the mirror: lightCard when it opens)
		Ambient = Color3.fromRGB(110, 96, 82),
		LightColor = Color3.fromRGB(140, 110, 76),
		LightDirection = Vector3.new(0.3, -0.9, -0.3),
		Parent = col,
	}, { New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }), Theme.Round("Panel"), Theme.Stroke(Colors.Border, 1, Theme.Alpha.Border) })
	table.insert(cardViewports, viewport)
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

-- A part that shows one of your live muscle meshes (the muscles, their clothing and color layers): its EditableMesh.
local function liveMeshOf(part: Instance): any
	if not part:IsA("MeshPart") then return nil end
	local ok, content = pcall(function() return part.MeshContent end)
	local object = ok and content and content.Object
	return if object and object:IsA("EditableMesh") then object else nil
end
-- The Size a copy of a live mesh part needs to draw the mesh like its source: a MeshPart made from an EditableMesh scales
-- the mesh by Size / its own MeshSize, which is the mesh's bounds when that part was made (different for every part).
local function copySize(source: MeshPart, copy: MeshPart): Vector3
	return copy.MeshSize * (source.Size / source.MeshSize)
end
-- A new part showing the same live mesh with the same look (color, material, clothing texture, skin stage).
local function copyLiveMesh(source: MeshPart): MeshPart?
	local mesh = liveMeshOf(source)
	if not mesh then return nil end
	local ok, part = pcall(function() return AssetService:CreateMeshPartAsync(Content.fromObject(mesh)) end)
	if not ok or not part then return nil end
	part.Name = source.Name
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Color, part.Material, part.Size = source.Color, source.Material, copySize(source, part)
	part.TextureID, part.Transparency = source.TextureID, source.Transparency
	local skin = source:FindFirstChild("SkinStage") -- (the skin texture stage, Config.SkinStages)
	if skin then skin:Clone().Parent = part end
	return part
end
-- Mirror mode (MuscleRig.SetMirrorMode) while the before / after card shows your muscles: a ViewportFrame honours the
-- meshes' vertex alpha (the color layer's), so they are made opaque meanwhile.
local mirrorUsers = { card = false }
local function setMirrorUser(name: string, on: boolean)
	mirrorUsers[name] = on
	local character = player.Character
	if character then MuscleRig.SetMirrorMode(character, mirrorUsers.card) end
end

-- the card lit like the gym in front of the mirror (looking into the glass: its normal -> +Z, your right -> +X)
local function lightCard()
	local mirrorModel = workspace:FindFirstChild("ProgressMirror")
	local glass = mirrorModel and mirrorModel:FindFirstChild("Glass")
	if not (glass and glass:IsA("BasePart")) then return end
	local normal, up = glass.CFrame.LookVector, Vector3.yAxis
	local right = up:Cross(normal)
	local ambient, keyColor, keyDir = gymLight(glass.Position + normal * (glass.Size.Z / 2 + 3) + up)
	local cardDir = Vector3.new(keyDir:Dot(right), keyDir:Dot(up), keyDir:Dot(normal))
	for _, card in ipairs(cardViewports) do
		card.Ambient, card.LightColor, card.LightDirection = ambient, keyColor, cardDir
	end
end

-- The muscles of the "Now" body: parts that show the SAME live meshes as your character's muscles (like the reflection on
-- the glass). A new muscle rig here would need meshes of its own, and the client can only hold 8: it took them from your
-- character, whose muscles vanished. "Day one" has no growth, so it needs no muscles.
local openCount = 0
local function addLiveMuscles(copy)
	local character = player.Character
	local sourceFolder = character and character:FindFirstChild("MuscleMeshes")
	if not sourceFolder then return end
	local folder = Instance.new("Folder")
	folder.Name = "MuscleMeshes"
	folder.Parent = copy
	-- the body looks like your character's (MuscleRig paints it plain skin / top / gym shorts)
	for _, liveBody in ipairs(character:GetChildren()) do
		local copyBody = copy:FindFirstChild(liveBody.Name)
		if liveBody:IsA("BasePart") and copyBody and copyBody:IsA("BasePart") and liveBody.Name ~= "HumanoidRootPart" then
			copyBody.Color, copyBody.Material = liveBody.Color, liveBody.Material
			if not liveBody:FindFirstChildOfClass("SurfaceAppearance") then
				local sa = copyBody:FindFirstChildOfClass("SurfaceAppearance")
				if sa then sa:Destroy() end
			end
		end
	end
	-- plain parts (the gym shorts on the thighs) and the forearm / calf stage meshes (Shared.LimbStages): placed on the same
	-- body part, same offset; a stage replaces its body part, like on the character
	for _, source in ipairs(sourceFolder:GetChildren()) do
		local weld = source:FindFirstChildOfClass("Weld")
		local liveBody = weld and weld.Part0
		local copyBody = liveBody and copy:FindFirstChild(liveBody.Name)
		local stage = source:IsA("MeshPart") and source:GetAttribute("Stage") ~= nil
		if (source:IsA("Part") or stage) and copyBody and copyBody:IsA("BasePart") and source.Transparency < 1 then
			local part = source:Clone()
			part:ClearAllChildren()
			part.Anchored = true
			part.CFrame = copyBody.CFrame * liveBody.CFrame:ToObjectSpace(source.CFrame)
			part.Parent = folder
			if stage then copyBody.Transparency = 1 end
		end
	end
	-- body parts your muscle meshes cover (the torso, upper arms, thighs) are hidden on the copy too
	for _, liveBody in ipairs(character:GetChildren()) do
		local copyBody = copy:FindFirstChild(liveBody.Name)
		if liveBody:IsA("BasePart") and copyBody and copyBody:IsA("BasePart") and liveBody.Name ~= "HumanoidRootPart" and liveBody.Transparency >= 1 then
			copyBody.Transparency = 1
		end
	end
	local session = openCount
	task.spawn(function()
		for _, source in ipairs(sourceFolder:GetChildren()) do
			local weld = source:FindFirstChildOfClass("Weld")
			local liveBody = weld and weld.Part0
			local copyBody = liveBody and copy:FindFirstChild(liveBody.Name)
			if liveMeshOf(source) and liveBody and copyBody and copyBody:IsA("BasePart") then
				local part = copyLiveMesh(source)
				if not part then continue end
				if session ~= openCount or not folder.Parent then
					part:Destroy()
					return
				end
				part.Size = copySize(source, part) * (copyBody.Size / liveBody.Size) -- (the same body, so normally 1)
				part.CFrame = copyBody.CFrame * liveBody.CFrame:ToObjectSpace(source.CFrame)
				part.Parent = folder
			end
		end
	end)
end
local function clearMuscles()
	openCount += 1
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
	pcall(lightCard)
	local data = ClientData.Get()
	local dayOne = data.dayOne or { height = GrowthSpurts.StartHeight, level = 0 }
	local nowHeight = GrowthSpurts.PlayerHeight(data)
	-- day one: the starting height, no muscle growth; now: today's height and muscle steps (both built by the server)
	local before, beforeSize = prepare(rigs.before)
	local after, afterSize = prepare(rigs.after)
	if not before or not after then return end
	local tallest = math.max(beforeSize.Y, afterSize.Y)
	-- "Day one" wears the first body stages (look 0: the plain skinny body, no blocky Robloxian parts), dressed like you
	local stages = BodyStages.new(before, before, true)
	if stages then
		local character = player.Character
		local style = MuscleRig.StyleFrom(player, character or before)
		stages:Update(function() return 0 end, style, function(_, base) return base end, nil, false)
	end
	show(beforeView, before, tallest)
	show(afterView, after, tallest)
	clearMuscles()
	setMirrorUser("card", true)
	addLiveMuscles(after)
	title.Text = player.DisplayName .. " · GYM ARC"
	beforeName.Text = "Day one"
	beforeInfo.Text = GrowthSpurts.FormatHeight(dayOne.height or GrowthSpurts.StartHeight) .. "  ·  " .. Muscles.FormatExp(Muscles.Shown(dayOne.level or 0)) .. " exp"
	afterName.Text = "Now"
	afterInfo.Text = GrowthSpurts.FormatHeight(nowHeight) .. "  ·  " .. Muscles.FormatExp(Muscles.TotalExp(data.muscles) / #Muscles.List) .. " exp"
		.. (data.growthSpurts > 0 and ("  ·  Growth Spurt " .. data.growthSpurts) or "")
	isOpen = true
	gui.Enabled = true
	Audio.PlayUI("Whoosh")
	Theme.Fade(root, true)
end

local function close()
	if not isOpen then return end
	isOpen = false
	setMirrorUser("card", false)
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
