-- MachineSignsClient: a small card above the machine you stand next to (client only, owner's redesign 8 Oct).
--  * The card: a flat solid charcoal rounded rectangle (about CARD.Width x CARD.Height studs), a thin accent stripe on the
--    left in the main muscle's group color (Config/HudIcons.MuscleGroups), one flat muscle shape in that color, and two
--    lines: the machine name (Oswald, white) and the main muscle (Nunito, light gray). No glow, no percentages (the full
--    split shows in the machine HUD after you sit down). A locked machine shows a lock and what unlocks it.
--  * Only the nearest machine within CARD.Near studs shows its card. It faces the camera and keeps its world size (smaller
--    with distance), but never draws smaller than readable (text >= 14 px) or bigger than about 1/6 of the screen.
--    Hidden while you're on that machine and while the camera is closer than CARD.CameraMin studs to it.
--  * Machines you never did a rep on show a small bouncing yellow "!" + "NEW" within BANG.Far studs (gone after the first
--    rep; the save's `machinesUsed`). Everything fades over FADE seconds.
--  * Cheap: one invisible anchor part per machine (made the first time you come near); one card, moved to the nearest.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Machines = require(Config.Machines)
local Muscles = require(Config.Muscles)
local HudIcons = require(Config.HudIcons)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)

local player = Players.LocalPlayer
local New = Theme.New

local CARD = {
	Near = 10,            -- studs from your character: the nearest machine this close shows its card
	CameraMin = 4,        -- studs: hidden when the camera is closer than this to the card
	Width = 2.4, Height = 1.2, -- studs (its world size)
	Lift = 0.9,           -- studs between the machine's top and the card's bottom
	Background = Color3.fromRGB(25, 25, 28),
	Name = Color3.fromRGB(255, 255, 255), Sub = Color3.fromRGB(184, 184, 190),
	MinHeight = 46,       -- px: the smallest it draws (so its text stays >= 14 px)
	MaxScreen = 1 / 6,    -- of the screen height: the biggest it draws
}
-- the "!": world-sized (smaller far away, so a room of new machines stays calm), between MinPx and MaxPx tall; the
-- "NEW" tag only while it is at least TagPx tall (near), so its text never gets tiny
local BANG = { Far = 60, Color = Color3.fromRGB(255, 214, 64), Bounce = 0.25, Speed = 4, Height = 1.1, MinPx = 22, MaxPx = 62, TagPx = 50 }
local FADE = 0.2

local folder = Instance.new("Folder")
folder.Name = "MachineSigns"
folder.Parent = Workspace

local anchors = {} -- [model] = { part, machine, bang, bangLabel, newTag, newLabel, bangAlpha, phase }
local pivots = {}
local localUsed = {} -- machine ids you did a rep on this session (the data catches up)

local function mainMuscle(machine)
	local entry = machine.muscles[1]
	return entry and Muscles.ById[entry.id]
end
local function accentOf(machine): Color3
	local muscle = mainMuscle(machine)
	local group = muscle and HudIcons.MuscleGroups[muscle.group]
	return group and group.accent or HudIcons.DefaultAccent
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
-- The card (one, moved to the nearest machine)
------------------------------------------------------------------------
local card = New("BillboardGui", {
	Name = "MachineCard",
	Size = UDim2.fromOffset(92, CARD.MinHeight),
	AlwaysOnTop = false,
	LightInfluence = 0,
	ResetOnSpawn = false,
	Enabled = false,
	Parent = player:WaitForChild("PlayerGui"),
})
local box = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = CARD.Background, BorderSizePixel = 0, Parent = card },
	{ New("UICorner", { CornerRadius = UDim.new(0.18, 0) }) })
local stripe = New("Frame", { Position = UDim2.new(0, 0, 0.18, 0), Size = UDim2.new(0, 2, 0.64, 0), BorderSizePixel = 0, Parent = box })
-- the muscle shape: one flat rounded muscle belly in the muscle color (our own simple glyph)
local iconSlot = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.07, 0, 0.5, 0), Size = UDim2.fromScale(0.2, 0.6), BackgroundTransparency = 1, Parent = box },
	{ New("UIAspectRatioConstraint", { AspectRatio = 1 }) })
local belly = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 1), Rotation = 28, BorderSizePixel = 0, Parent = iconSlot },
	{ New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
local lockSlot = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = iconSlot })
Icons.Lock(CARD.Name).Parent = lockSlot
local function line(font, color, y, height, minSize, maxSize)
	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		TextScaled = true, -- (world-space UI scales with the card; CARD.MinHeight keeps it >= 14 px)
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		FontFace = font,
		TextColor3 = color,
		Position = UDim2.fromScale(0.33, y),
		Size = UDim2.fromScale(0.62, height),
		Parent = box,
	}, { New("UITextSizeConstraint", { MinTextSize = minSize, MaxTextSize = maxSize }) })
	New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.5, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	return label
end
local nameLabel = line(Theme.Fonts.SemiBold, CARD.Name, 0.15, 0.4, 15, 40)
local subLabel = line(Theme.Fonts.Regular, CARD.Sub, 0.56, 0.3, 14, 30)

local shown = { model = nil, alpha = 0, nameRatio = 0 } -- the card's machine, its fade, the name's width per px of text size
local function fill(machine)
	local accent = accentOf(machine)
	local lock = lockText(machine)
	stripe.BackgroundColor3 = accent
	belly.BackgroundColor3 = accent
	belly.Visible = lock == nil
	lockSlot.Visible = lock ~= nil
	nameLabel.Text = string.upper(machine.name)
	-- how wide the name is (the card widens so it never gets cut off)
	shown.nameRatio = 0.6 * #nameLabel.Text
	task.spawn(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = nameLabel.Text
		params.Font = Theme.Fonts.SemiBold
		params.Size = 100
		params.Width = 100000
		local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		if ok and bounds then shown.nameRatio = bounds.X / 100 end
	end)
	local muscle = mainMuscle(machine)
	subLabel.Text = lock or (if machine.trains == "Stamina" then "Stamina" else (muscle and muscle.name or ""))
end
local function setAlpha(a: number)
	local t = 1 - a
	box.BackgroundTransparency = t
	stripe.BackgroundTransparency = t
	belly.BackgroundTransparency = t
	nameLabel.TextTransparency, subLabel.TextTransparency = t, t
	nameLabel:FindFirstChildOfClass("UIStroke").Transparency = 1 - a * 0.5
	subLabel:FindFirstChildOfClass("UIStroke").Transparency = 1 - a * 0.5
	for _, item in ipairs(lockSlot:GetDescendants()) do
		if item:IsA("UIStroke") then item.Transparency = t end
	end
	card.Enabled = a > 0
end

------------------------------------------------------------------------
-- The anchors and the "!" + "NEW"
------------------------------------------------------------------------
local function build(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	if not machine then return nil end
	local boxCf, boxSize = model:GetBoundingBox()
	local top = boxCf.Position.Y + boxSize.Y / 2
	-- under a low ceiling the card sits just under it
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, folder }
	local lift = CARD.Lift + CARD.Height / 2
	local hit = Workspace:Raycast(Vector3.new(boxCf.Position.X, top + 0.05, boxCf.Position.Z), Vector3.new(0, lift + CARD.Height, 0), params)
	if hit then lift = math.min(lift, math.max(0.3, hit.Position.Y - top - CARD.Height / 2 - 0.2)) end
	local part = Instance.new("Part")
	part.Name = model.Name .. "Sign"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.CFrame = CFrame.new(boxCf.Position.X, top + lift, boxCf.Position.Z)
	part.Parent = folder
	local anchor = { part = part, machine = machine, bangAlpha = 0, phase = math.random() * math.pi * 2 }
	anchor.bang = New("BillboardGui", {
		Size = UDim2.fromOffset(46, 62),
		StudsOffset = Vector3.new(0, 0.6, 0),
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
	local nearest, nearestDistance = nil, CARD.Near
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
		if not mine and distance < nearestDistance then nearest, nearestDistance = model, distance end
		-- the "!" + "NEW" (not on the machine whose card shows: one thing per machine)
		local id = model:GetAttribute("MachineId")
		local carded = model == shown.model and shown.alpha > 0
		local wantBang = if not mine and not carded and id ~= nil and isNew(id) and distance <= BANG.Far then 1 else 0
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
			anchor.bang.StudsOffset = Vector3.new(0, 0.6 + math.abs(math.sin(now * BANG.Speed + anchor.phase)) * BANG.Bounce, 0)
			anchor.bangLabel.TextTransparency = 1 - b
			anchor.bangLabel:FindFirstChildOfClass("UIStroke").Transparency = 1 - b * 0.7
			anchor.newTag.BackgroundTransparency = 1 - b
			anchor.newLabel.TextTransparency = 1 - b
		end
	end
	-- the card: only the nearest machine; a new one takes over once the old card has faded out
	if nearest and nearest ~= shown.model and shown.alpha <= 0 then
		shown.model = nearest
		fill(anchors[nearest].machine)
		card.Adornee = anchors[nearest].part
	end
	local anchor = shown.model and anchors[shown.model]
	local want = 0
	if anchor and nearest == shown.model then
		local cameraDistance = (anchor.part.Position - cameraPosition).Magnitude
		if cameraDistance >= CARD.CameraMin then want = 1 end
		-- its world size in pixels at this distance, kept readable and never too big
		local viewport = camera.ViewportSize
		local pxPerStud = viewport.Y / (2 * math.max(cameraDistance, 0.1) * math.tan(math.rad(camera.FieldOfView) / 2))
		local height = math.clamp(CARD.Height * pxPerStud, CARD.MinHeight, math.max(CARD.MinHeight, viewport.Y * CARD.MaxScreen))
		local nameSize = math.clamp(math.floor(height * 0.4), 15, 40) -- (the name's line: 40% of the card)
		local width = math.max(height * CARD.Width / CARD.Height, (shown.nameRatio * nameSize + 4) / 0.62)
		card.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
	end
	local before = shown.alpha
	shown.alpha = approach(shown.alpha, want, dt)
	if shown.alpha ~= before then setAlpha(shown.alpha) end
	if shown.alpha <= 0 and want == 0 then shown.model = nil end
end)
