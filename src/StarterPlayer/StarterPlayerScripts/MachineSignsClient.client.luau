-- MachineSignsClient: the sign over the machine you stand next to, its prompt and floor outline (client only; owner's
-- brief 8 Oct night, replaces the flat card and Roblox's wide "Use" panel).
--  * A floating glass diamond: a square slab turned 45 degrees, dark tinted glass with a thin glowing white (Neon) border,
--    bobbing gently and turning smoothly toward the camera on both axes (a 3D object, not a flat label). Inside (a
--    SurfaceGui on an upright square face that turns with the glass, clipped to a safe square inside the border, the
--    text shrinking to fit): our own body icon (BodyFigure) in white with the main muscle in red, the
--    main muscle's name in bold white and its share in red ("53%"). Main muscle only.
--  * Above it the machine name (big bold white, dark stroke). Below it the prompt: a small square dark-glass key ("E",
--    the gamepad button, or a tap button on touch screens) and "Occupy" under it ("Unlock · 45 coins" when your next
--    weight can be bought). The machines' ProximityPrompts use the Custom style (MachineService), so this is their UI.
--  * A glowing white rectangle on the floor around the machine's footprint (thin Neon strips), brighter while you stand
--    inside it.
--  * Only the nearest machine within SIGN.Near studs shows all this; from there to BANG.Far studs, machines you never
--    did a rep on show the bouncing yellow "!" + "NEW" (the save's `machinesUsed`); nothing beyond. While you're on a
--    machine the diamond, prompt and outline are hidden. Hidden too while the camera is within SIGN.CameraMin studs.
--  * Cheap: one set of sign parts moved to the nearest machine; one invisible anchor part per machine for its "!".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Machines = require(Config.Machines)
local Muscles = require(Config.Muscles)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local BodyFigure = require(Shared.UI.BodyFigure)

local player = Players.LocalPlayer
local New = Theme.New

local SIGN = {
	Near = 12,            -- studs from your character: the nearest machine this close shows its sign
	CameraMin = 4,        -- studs: the diamond hides when the camera is closer than this
	Side = 2.6,           -- studs: the diamond's square side (its diagonal is ~3.7)
	Safe = 1.68,          -- studs: the content's square in the middle (an upright square fits up to 0.707 x Side)
	Lift = 1.9,           -- studs from the machine's top to the diamond's centre
	Glass = Color3.fromRGB(18, 20, 26), GlassTransparency = 0.3,
	Edge = Color3.fromRGB(255, 255, 255), EdgeWidth = 0.07,
	Bob = 0.12, BobSpeed = 1.7, TurnRate = 5, -- studs, radians/s of the bob, how fast it turns toward the camera
	Red = Color3.fromRGB(255, 70, 70),
	Floor = 0.05,         -- studs: the floor outline's height
	FloorPad = 0.5,       -- studs around the machine's footprint
}
local BANG = { Far = 60, Color = Color3.fromRGB(255, 214, 64), Bounce = 0.25, Speed = 4, Height = 1.1, MinPx = 22, MaxPx = 62, TagPx = 50 }
local FADE = 0.2

local folder = Instance.new("Folder")
folder.Name = "MachineSigns"
folder.Parent = Workspace
local playerGui = player:WaitForChild("PlayerGui")

local anchors = {} -- [model] = { part, machine, bang, bangLabel, newTag, newLabel, bangAlpha, phase }
local pivots = {}
local localUsed = {} -- machine ids you did a rep on this session (the data catches up)

local function mainMuscle(machine)
	local entry = machine.muscles[1]
	return entry and Muscles.ById[entry.id]
end
local function lockText(machine): string?
	local need = Machines.GymUnlock[machine.gym] or 0
	if (ClientData.Get().growthSpurts or 0) < need then return "Growth Spurt " .. need end
	return nil
end
local function isNew(machineId: string): boolean
	if localUsed[machineId] then return false end
	local data = ClientData.Get()
	if data.machinesUsed and data.machinesUsed[machineId] then return false end
	if data.machines and data.machines[machineId] then return false end -- (used before the tag existed)
	return true
end

------------------------------------------------------------------------
-- The sign's 3D parts (one set, moved to the nearest machine)
------------------------------------------------------------------------
local function signPart(name, size, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Transparency = transparency
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Parent = folder
	return part
end
local glass = signPart("SignGlass", Vector3.new(SIGN.Side, SIGN.Side, 0.1), SIGN.Glass, Enum.Material.Glass, 1)
local edges = {}
for i = 1, 4 do
	-- edges 1 / 2 are the top and bottom of the square, 3 / 4 its sides (in the square's own frame)
	local horizontal = i <= 2
	edges[i] = signPart("SignEdge", if horizontal then Vector3.new(SIGN.Side + SIGN.EdgeWidth, SIGN.EdgeWidth, 0.12) else Vector3.new(SIGN.EdgeWidth, SIGN.Side + SIGN.EdgeWidth, 0.12),
		SIGN.Edge, Enum.Material.Neon, 1)
end
-- the name and the prompt (BillboardGuis) hang on an unrotated anchor at the diamond's centre
local signAnchor = signPart("SignAnchor", Vector3.new(0.1, 0.1, 0.1), SIGN.Edge, Enum.Material.SmoothPlastic, 1)
-- the content's face: an upright invisible square just in front of the glass, turned with it (one 3D object), so the
-- icon and the text can never reach the border at any camera angle
local signFace = signPart("SignFace", Vector3.new(SIGN.Safe, SIGN.Safe, 0.02), SIGN.Glass, Enum.Material.SmoothPlastic, 1)
local glow = Instance.new("PointLight")
glow.Color, glow.Range, glow.Brightness, glow.Shadows = SIGN.Edge, 6, 0, false
glow.Parent = glass
local floorStrips = {}
for i = 1, 4 do floorStrips[i] = signPart("SignFloor", Vector3.new(1, SIGN.Floor, 0.08), SIGN.Edge, Enum.Material.Neon, 1) end

------------------------------------------------------------------------
-- The sign's screen parts: name above, content inside, prompt below (BillboardGuis sized in studs)
------------------------------------------------------------------------
local function stroked(label, thickness)
	New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.2, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	return label
end
local function scaledText(props, minSize, maxSize)
	props.BackgroundTransparency = 1
	props.TextScaled = true -- (world-space UI sized in studs; the minimum keeps it >= 14 px)
	local label = New("TextLabel", props, { New("UITextSizeConstraint", { MinTextSize = minSize, MaxTextSize = maxSize }) })
	return label
end

local nameGui = New("BillboardGui", { Name = "MachineSignName", Size = UDim2.new(8, 0, 0.95, 0), LightInfluence = 0, AlwaysOnTop = false, Enabled = false, ResetOnSpawn = false, Parent = playerGui })
local nameLabel = stroked(scaledText({ Size = UDim2.fromScale(1, 1), FontFace = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), Parent = nameGui }, 16, 60), 3)

-- the content: a SurfaceGui on the face (it turns with the diamond), clipped to its square; text shrinks to fit the width
local inside = New("SurfaceGui", { Name = "MachineSignInside", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
	PixelsPerStud = 110, LightInfluence = 0, Enabled = false, Parent = signFace })
local safe = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Parent = inside })
local figureSlot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = safe },
	{ New("UIAspectRatioConstraint", { AspectRatio = 0.4 }) })
local lockSlot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.08), Size = UDim2.fromScale(0.38, 0.38), BackgroundTransparency = 1, Visible = false, Parent = safe })
Icons.Lock(Color3.new(1, 1, 1)).Parent = lockSlot
local muscleLabel = stroked(scaledText({ Position = UDim2.fromScale(0.03, 0.55), Size = UDim2.fromScale(0.94, 0.22), FontFace = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), Parent = safe }, 1, 44), 2)
local shareLabel = stroked(scaledText({ Position = UDim2.fromScale(0.15, 0.78), Size = UDim2.fromScale(0.7, 0.18), FontFace = Theme.Fonts.Bold, TextColor3 = SIGN.Red, Parent = safe }, 1, 36), 2)

-- (not AlwaysOnTop: those did not draw reliably; instead it is pulled toward the camera so the machine never hides it)
local promptGui = New("BillboardGui", { Name = "MachineSignPrompt", Size = UDim2.new(2.6, 0, 1.45, 0), LightInfluence = 0, AlwaysOnTop = false, Active = true, Enabled = false, ResetOnSpawn = false, Parent = playerGui })
local keyButton = New("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.36, 0.62),
	BackgroundColor3 = SIGN.Glass, BackgroundTransparency = 0.25, AutoButtonColor = false, Text = "", Parent = promptGui,
}, {
	New("UIAspectRatioConstraint", { AspectRatio = 1 }),
	New("UICorner", { CornerRadius = UDim.new(0.18, 0) }),
	New("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.25, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
})
local keyLabel = stroked(scaledText({ Size = UDim2.fromScale(1, 1), FontFace = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), Text = "E", Parent = keyButton }, 14, 40), 1)
local tapIcon = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42), BackgroundColor3 = Color3.new(1, 1, 1),
	Visible = false, Parent = keyButton }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local actionLabel = stroked(scaledText({ Position = UDim2.fromScale(0, 0.66), Size = UDim2.fromScale(1, 0.34), FontFace = Theme.Fonts.Bold, TextColor3 = Color3.new(1, 1, 1), Text = "OCCUPY", Parent = promptGui }, 14, 32), 2)

------------------------------------------------------------------------
-- Which machine the sign is on, and its prompt
------------------------------------------------------------------------
local shown = { model = nil, machine = nil, alpha = 0, yaw = nil, inside = false }
local shownPrompts = {} -- [model] = { prompt, inputType } while Roblox shows that machine's prompt

local function machineOf(instance)
	local node = instance
	while node and node ~= Workspace do
		if node:IsA("Model") and CollectionService:HasTag(node, "Machine") then return node end
		node = node.Parent
	end
	return nil
end
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	local model = machineOf(prompt)
	if model and prompt.Style == Enum.ProximityPromptStyle.Custom then shownPrompts[model] = { prompt = prompt, inputType = inputType } end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	local model = machineOf(prompt)
	if model and shownPrompts[model] and shownPrompts[model].prompt == prompt then shownPrompts[model] = nil end
end)
keyButton.Activated:Connect(function()
	local entry = shown.model and shownPrompts[shown.model]
	if not entry then return end
	entry.prompt:InputHoldBegin()
	task.defer(function() entry.prompt:InputHoldEnd() end)
end)

-- the content for this machine: body icon, main muscle, share
local function fill(model, machine)
	shown.model, shown.machine = model, machine
	nameLabel.Text = string.upper(machine.name)
	for _, child in ipairs(figureSlot:GetChildren()) do
		if not child:IsA("UIAspectRatioConstraint") then child:Destroy() end
	end
	local lock = lockText(machine)
	local muscle = mainMuscle(machine)
	figureSlot.Visible = lock == nil
	lockSlot.Visible = lock ~= nil
	if lock then
		muscleLabel.Text = "Locked"
		shareLabel.Text = lock
	elseif machine.trains == "Stamina" then
		BodyFigure.Draw(figureSlot, "Front", function(id) return if id == "Quads" or id == "Calves" then SIGN.Red else nil end, Color3.new(1, 1, 1), 0.05)
		muscleLabel.Text = "Stamina"
		shareLabel.Text = "Cardio"
	else
		local view = if muscle and BodyFigure.Back[muscle.id] then "Back" else "Front"
		BodyFigure.Draw(figureSlot, view, function(id) return if muscle and id == muscle.id then SIGN.Red else nil end, Color3.new(1, 1, 1), 0.05)
		muscleLabel.Text = muscle and muscle.name or ""
		local share = Machines.SharePercents(machine)[1]
		shareLabel.Text = (share and share.pct or 100) .. "%"
	end
end

local function setAlpha(a: number)
	local t = 1 - a
	glass.Transparency = 1 - a * (1 - SIGN.GlassTransparency)
	for _, edge in ipairs(edges) do edge.Transparency = t end
	glow.Brightness = 0.6 * a
	for _, label in ipairs({ nameLabel, muscleLabel, shareLabel }) do
		label.TextTransparency = t
		label:FindFirstChildOfClass("UIStroke").Transparency = 1 - a * 0.8
	end
	for _, frame in ipairs(figureSlot:GetDescendants()) do
		if frame:IsA("Frame") then frame.BackgroundTransparency = math.max(t, if frame.ZIndex == 1 then 0.05 else 0) end
	end
	for _, item in ipairs(lockSlot:GetDescendants()) do
		if item:IsA("UIStroke") then item.Transparency = t end
	end
	nameGui.Enabled, inside.Enabled = a > 0, a > 0
end

-- the floor outline: 4 strips around the footprint, at the floor under the machine
local function placeFloor(model)
	local boxCf, boxSize = model:GetBoundingBox()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { model, folder }
	for _, other in ipairs(Players:GetPlayers()) do if other.Character then table.insert(exclude, other.Character) end end
	params.FilterDescendantsInstances = exclude
	local bottom = boxCf.Position.Y - boxSize.Y / 2
	local hit = Workspace:Raycast(boxCf.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, -boxSize.Y - 2, 0), params)
	local floorY = if hit then hit.Position.Y else bottom
	local flat = CFrame.new(boxCf.Position.X, floorY + SIGN.Floor / 2 + 0.02, boxCf.Position.Z) * (boxCf - boxCf.Position)
	local w, d = boxSize.X + SIGN.FloorPad * 2, boxSize.Z + SIGN.FloorPad * 2
	floorStrips[1].Size, floorStrips[1].CFrame = Vector3.new(w + 0.08, SIGN.Floor, 0.08), flat * CFrame.new(0, 0, -d / 2)
	floorStrips[2].Size, floorStrips[2].CFrame = Vector3.new(w + 0.08, SIGN.Floor, 0.08), flat * CFrame.new(0, 0, d / 2)
	floorStrips[3].Size, floorStrips[3].CFrame = Vector3.new(0.08, SIGN.Floor, d), flat * CFrame.new(-w / 2, 0, 0)
	floorStrips[4].Size, floorStrips[4].CFrame = Vector3.new(0.08, SIGN.Floor, d), flat * CFrame.new(w / 2, 0, 0)
	shown.footprint = { cf = flat, w = w, d = d }
end
local function setFloorAlpha(a: number, bright: boolean)
	local visible = if bright then a else a * 0.55
	for _, strip in ipairs(floorStrips) do strip.Transparency = 1 - visible end
end

------------------------------------------------------------------------
-- The anchors and the "!" + "NEW"
------------------------------------------------------------------------
local function build(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	if not machine then return nil end
	local boxCf, boxSize = model:GetBoundingBox()
	local top = boxCf.Position.Y + boxSize.Y / 2
	-- under a low ceiling the sign sits just under it
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, folder }
	local lift = SIGN.Lift
	local hit = Workspace:Raycast(Vector3.new(boxCf.Position.X, top + 0.05, boxCf.Position.Z), Vector3.new(0, lift + 3.2, 0), params)
	if hit then lift = math.min(lift, math.max(1.2, hit.Position.Y - top - 3)) end
	local part = Instance.new("Part")
	part.Name = model.Name .. "Sign"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame = CFrame.new(boxCf.Position.X, top + lift, boxCf.Position.Z)
	part.Parent = folder
	local anchor = { part = part, machine = machine, top = top, bangAlpha = 0, phase = math.random() * math.pi * 2 }
	anchor.bang = New("BillboardGui", {
		Size = UDim2.fromOffset(46, 62),
		StudsOffset = Vector3.new(0, -0.6, 0),
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = BANG.Far + 5,
		Enabled = false,
		Parent = part,
	})
	anchor.bangLabel = New("TextLabel", { Text = "!", FontFace = Theme.Fonts.SemiBold, TextScaled = true, TextColor3 = BANG.Color, BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0.66), Parent = anchor.bang }, { New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.3, Thickness = 2 }) })
	anchor.newTag = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(40, 18), BackgroundColor3 = BANG.Color,
		BorderSizePixel = 0, Parent = anchor.bang }, { New("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	anchor.newLabel = New("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "NEW", TextSize = 14, FontFace = Theme.Fonts.SemiBold,
		TextColor3 = Color3.fromRGB(20, 20, 24), Parent = anchor.newTag })
	return anchor
end

-- a model you're on: you did a rep there when its Reps count goes up
local function watch(model)
	model:GetAttributeChangedSignal("Reps"):Connect(function()
		if model:GetAttribute("UserId") == player.UserId then
			local id = model:GetAttribute("MachineId")
			if id then localUsed[id] = true end
		end
	end)
end
for _, model in ipairs(CollectionService:GetTagged("Machine")) do watch(model) end
CollectionService:GetInstanceAddedSignal("Machine"):Connect(watch)

local function approach(current: number, target: number, dt: number): number
	local step = dt / FADE
	if current < target then return math.min(target, current + step) end
	return math.max(target, current - step)
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not root or not camera then return end
	local now = os.clock()
	local from = root.Position
	local cameraPosition = camera.CFrame.Position
	-- Studio test hook: a "TestSignCamera" Vector3 on Workspace = the point the sign turns to (screenshots from any angle)
	local testView = if RunService:IsStudio() then Workspace:GetAttribute("TestSignCamera") else nil
	if typeof(testView) == "Vector3" then cameraPosition = testView end
	local nearest, nearestDistance = nil, SIGN.Near
	local onMachine = false
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if model:GetAttribute("UserId") == player.UserId then onMachine = true end
	end
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		local pivot = pivots[model]
		if not pivot then
			if not model:IsDescendantOf(Workspace) then continue end
			local ok, cf = pcall(function() return model:GetPivot() end)
			if not ok then continue end
			pivot = cf.Position
			pivots[model] = pivot
		end
		local distance = (Vector3.new(pivot.X, from.Y, pivot.Z) - from).Magnitude
		local anchor = anchors[model]
		if not anchor then
			if distance > BANG.Far + 5 then continue end
			anchor = build(model)
			if not anchor then continue end
			anchors[model] = anchor
		end
		local mine = model:GetAttribute("UserId") == player.UserId
		if not onMachine and distance < nearestDistance then nearest, nearestDistance = model, distance end
		-- the "!" + "NEW" (not on the machine whose sign shows: one thing per machine)
		local id = model:GetAttribute("MachineId")
		local signed = model == shown.model and shown.alpha > 0
		local wantBang = if not mine and not signed and id ~= nil and isNew(id) and distance <= BANG.Far then 1 else 0
		local before = anchor.bangAlpha
		anchor.bangAlpha = approach(anchor.bangAlpha, wantBang, dt)
		local b = anchor.bangAlpha
		if b > 0 or before > 0 then
			anchor.bang.Enabled = b > 0
			local cameraDistance = math.max((anchor.part.Position - cameraPosition).Magnitude, 0.1)
			local pxPerStud = camera.ViewportSize.Y / (2 * cameraDistance * math.tan(math.rad(camera.FieldOfView) / 2))
			local px = math.clamp(BANG.Height * pxPerStud, BANG.MinPx, BANG.MaxPx)
			local tag = px >= BANG.TagPx
			anchor.bang.Size = UDim2.fromOffset(math.floor(px * 0.75), math.floor(if tag then px else px * 0.68))
			anchor.bangLabel.Size = UDim2.fromScale(1, if tag then 0.66 else 1)
			anchor.newTag.Visible = tag
			anchor.bang.StudsOffset = Vector3.new(0, -0.6 + math.abs(math.sin(now * BANG.Speed + anchor.phase)) * BANG.Bounce, 0)
			anchor.bangLabel.TextTransparency = 1 - b
			anchor.bangLabel:FindFirstChildOfClass("UIStroke").Transparency = 1 - b * 0.7
			anchor.newTag.BackgroundTransparency = 1 - b
			anchor.newLabel.TextTransparency = 1 - b
		end
	end

	-- the sign: only the nearest machine; a new one takes over once the old sign has faded out
	if nearest and nearest ~= shown.model and shown.alpha <= 0 then
		local anchor = anchors[nearest]
		fill(nearest, anchor.machine)
		nameGui.Adornee, promptGui.Adornee = signAnchor, signAnchor
		placeFloor(nearest)
		shown.turn = nil
	end
	local anchor = shown.model and anchors[shown.model]
	local want = 0
	if anchor and nearest == shown.model then
		want = 1
		-- bob, and turn smoothly toward the camera on both axes (like a billboard, so it never looks squashed): the glass,
		-- its border and the content's face move as one object, the square standing on a corner
		local centre = anchor.part.Position + Vector3.new(0, math.sin(now * SIGN.BobSpeed) * SIGN.Bob, 0)
		local target = CFrame.lookAt(centre, cameraPosition).Rotation
		shown.turn = if shown.turn then shown.turn:Lerp(target, math.min(1, dt * SIGN.TurnRate)) else target
		local frame = CFrame.new(centre) * shown.turn
		glass.CFrame = frame * CFrame.Angles(0, 0, math.rad(45))
		signFace.CFrame = frame * CFrame.new(0, 0, -0.08) -- (a hair in front of the glass, toward the camera)
		signAnchor.CFrame = CFrame.new(centre)
		local half = SIGN.Side / 2
		edges[1].CFrame = glass.CFrame * CFrame.new(0, half, 0)
		edges[2].CFrame = glass.CFrame * CFrame.new(0, -half, 0)
		edges[3].CFrame = glass.CFrame * CFrame.new(-half, 0, 0)
		edges[4].CFrame = glass.CFrame * CFrame.new(half, 0, 0)
		-- the name above and the prompt below, offset on the SCREEN (camera space): they stay clear of the diamond at any
		-- camera angle; the prompt is pulled toward the camera so the machine's frame doesn't hide it
		local diagonal = SIGN.Side * math.sqrt(2) / 2
		nameGui.StudsOffset = Vector3.new(0, diagonal + 0.7, 0)
		promptGui.StudsOffset = Vector3.new(0, -diagonal - 1.05, math.min(2.2, (cameraPosition - centre).Magnitude * 0.4))
		-- too close to the camera: hide the diamond (the floor outline stays)
		if (centre - cameraPosition).Magnitude < SIGN.CameraMin then want = 0 end
		-- standing inside the outline makes it brighter
		local fp = shown.footprint
		if fp then
			local localPos = fp.cf:PointToObjectSpace(from)
			shown.inside = math.abs(localPos.X) <= fp.w / 2 and math.abs(localPos.Z) <= fp.d / 2
		end
	end
	local before = shown.alpha
	shown.alpha = approach(shown.alpha, want, dt)
	if shown.alpha ~= before then setAlpha(shown.alpha) end
	-- the floor outline follows the sign's machine (it stays while the camera is close)
	local floorWant = if anchor and nearest == shown.model then 1 else 0
	shown.floorAlpha = approach(shown.floorAlpha or 0, floorWant, dt)
	setFloorAlpha(shown.floorAlpha, shown.inside)
	-- the prompt: while Roblox shows this machine's prompt (it decides distance / exclusivity)
	local entry = shown.model and shownPrompts[shown.model]
	local promptOn = entry ~= nil and shown.alpha > 0.5 and entry.prompt.Enabled
	promptGui.Enabled = promptOn
	if promptOn then
		local touch = entry.inputType == Enum.ProximityPromptInputType.Touch
		local gamepad = entry.inputType == Enum.ProximityPromptInputType.Gamepad
		tapIcon.Visible = touch
		keyLabel.Visible = not touch
		keyLabel.Text = if gamepad then string.gsub(entry.prompt.GamepadKeyCode.Name, "^Button", "") else entry.prompt.KeyboardKeyCode.Name
		local coins = string.match(entry.prompt.ObjectText, "unlocks for (%d+) coins")
		actionLabel.Text = if coins then "UNLOCK · " .. coins .. " COINS" else "OCCUPY"
	end
	if shown.alpha <= 0 and want == 0 and (shown.floorAlpha or 0) <= 0 then shown.model = nil end
end)
