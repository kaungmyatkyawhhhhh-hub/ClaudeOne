-- MirrorService: the progress mirror on the entrance hall's right wall. "Look" opens the before/after screen
-- (MirrorClient): your day-one body next to your body now, with height and level under each, made for screenshots.
-- Day one is saved once per player (data.dayOne): the height and body scales from their first join. Saves from before
-- the mirror existed get the starting height (4'0") and plain scales, which is what every player started with.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local PlayerData = require(script.Parent.PlayerData)
local Guard = require(script.Parent.Guard)

local Remotes = ReplicatedStorage.Remotes

local MirrorService = {}

local SPOT = CFrame.lookAt(Vector3.new(9.85, 4.3, 5), Vector3.new(0, 4.3, 5)) -- on the hall's right wall, facing in
local BASE_HEIGHT = 60 -- inches at height scale 1 (same as BodyService)

local function saveDayOne(player, data)
	if type(data.dayOne) == "table" then return end
	local fresh = (data.stats and data.stats.totalReps or 0) == 0 and (data.growthSpurts or 0) == 0
	local height = fresh and GrowthSpurts.GetHeight(data.growthSpurts or 0) or GrowthSpurts.StartHeight
	PlayerData.SetTable(player, "dayOne", {
		height = height,                 -- inches
		heightScale = height / BASE_HEIGHT,
		muscleScale = 1,                 -- no muscle thickening on day one
		level = 0,
		at = os.time(),
		estimated = not fresh,           -- saved later than the real first join
	})
end

local function buildMirror()
	local model = Instance.new("Model")
	model.Name = "ProgressMirror"
	local function piece(name, size, offset, color, material, props)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = SPOT * offset
		p.Color = color
		p.Material = material
		p.Anchored = true
		p.CastShadow = false
		for key, value in pairs(props or {}) do p[key] = value end
		p.Parent = model
		return p
	end
	local frame = Color3.fromHex("#1E1E22")
	piece("Back", Vector3.new(4.4, 7.4, 0.2), CFrame.new(0, 0, 0.1), frame, Enum.Material.Metal)
	local glass = piece("Glass", Vector3.new(4, 7, 0.1), CFrame.new(0, 0, -0.05), Color3.fromHex("#C9D3D8"), Enum.Material.Glass,
		{ Reflectance = 0.55, Transparency = 0.1, CanCollide = false })
	for _, x in ipairs({ -2.15, 2.15 }) do
		piece("Side", Vector3.new(0.15, 7.4, 0.3), CFrame.new(x, 0, -0.05), frame, Enum.Material.Metal, { CanCollide = false })
	end
	for _, y in ipairs({ -3.65, 3.65 }) do
		piece("Edge", Vector3.new(4.4, 0.15, 0.3), CFrame.new(0, y, -0.05), frame, Enum.Material.Metal, { CanCollide = false })
	end
	-- small label above it
	local label = piece("Label", Vector3.new(4, 0.7, 0.05), CFrame.new(0, 4.2, -0.05), frame, Enum.Material.SmoothPlastic, { CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = label
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "Progress mirror"
	text.TextColor3 = Theme.Colors.Text
	text.FontFace = Theme.Fonts.SemiBold
	text.TextScaled = true -- world-space sign: the only place text may scale
	text.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Look"
	prompt.ObjectText = "Progress mirror"
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = glass
	Guard.OnTriggered(prompt, function(player)
		local data = PlayerData.Get(player)
		if not data then return end
		saveDayOne(player, data)
		Remotes.PlayerEvent:FireClient(player, "OpenMirror", {})
	end)
	model.Parent = Workspace
end

function MirrorService.Start()
	buildMirror()
	PlayerData.Loaded:Connect(saveDayOne)
end

return MirrorService
