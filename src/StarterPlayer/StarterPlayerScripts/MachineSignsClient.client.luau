-- MachineSignsClient: a 3D sign above every machine (client only, our own style).
--  * The sign: a thin dark-glass diamond (a square slab turned 45 degrees) with a glowing white neon frame, floating above
--    the machine. Both faces show the machine name, a body figure (Shared.UI.BodyFigure) with the trained muscles colored
--    in (main red, secondaries lighter) and the shares from Config.Machines ("Mid Chest 56%", then the secondaries
--    smaller). A locked machine shows a lock and what unlocks it instead. It turns toward the camera with a little lag and
--    bobs gently, so it reads as an object with perspective.
--  * A glowing white outline on the floor around the machine's footprint, brighter while you stand inside it.
--  * A bouncing yellow "!" and a "NEW" tag above machines you've never done a rep on (gone after the first rep).
--  * Distance stages (from your character): within SIGN.Near the diamond + outline (+ "!" if new); up to SIGN.Far only
--    the "!" + "NEW" (if new), so the gym stays clean but new machines are easy to spot; beyond, nothing. Every change
--    fades over SIGN.Fade. Everything hides on the machine you're using.
--  * Cheap: a machine's 7 parts are only made the first time you come within SIGN.Far, and only signs that show are
--    moved (one BulkMoveTo each).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
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
	Near = 15, Far = 60, Fade = 0.2,
	Side = 3.5,               -- the square's side (studs); turned 45 degrees it is SIGN.Side * 1.414 tall
	Thick = 0.12,
	FrameWidth = 0.09,        -- the neon frame bars
	Gap = 0.7,                -- studs between the machine's top and the diamond's bottom tip
	Bob = 0.14, BobSpeed = 1.3,
	TurnRate = 2.6,           -- how fast it follows the camera (higher = less lag)
	Glass = Color3.fromRGB(16, 18, 24), GlassTransparency = 0.35,
	PixelsPerStud = 64,
	Main = Color3.fromRGB(228, 66, 58), Helper = Color3.fromRGB(255, 166, 150), -- the figure's trained muscles
	Body = Color3.fromRGB(255, 255, 255), BodyTransparency = 0.78,
	Outline = { Margin = 0.5, Height = 0.05, Stroke = 3, Dim = 0.55, Bright = 0.05 },
	Bang = Color3.fromRGB(255, 214, 64), BangBounce = 0.18, BangSpeed = 4,
}
local DIAGONAL = SIGN.Side * math.sqrt(2)

local folder = Instance.new("Folder")
folder.Name = "MachineSigns"
folder.Parent = Workspace

local signs = {} -- [model] = sign
local pivots = {} -- [model] = its position (machines don't move)
local localUsed = {} -- machine ids you did a rep on this session (the data catches up)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do (p :: any)[k] = v end
	return p
end

-- world text: the font and look of our UI, scaled to its box (world-space UI may scale its text)
local function worldText(props, maxSize: number)
	local label = New("TextLabel", {
		BackgroundTransparency = 1,
		TextScaled = true,
		FontFace = Theme.Fonts[props.Font or "Regular"],
		TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
		Text = props.Text or "",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0),
		LayoutOrder = props.LayoutOrder,
		Parent = props.Parent,
	}, { New("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8 }) })
	New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.25, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = label })
	return label
end

-- the shares as whole percents that add up to 100 (the main muscle takes the rounding)
local function percents(machine): { { id: string, pct: number } }
	local total = 0
	for _, entry in ipairs(machine.muscles) do total += entry.share or 1 end
	local out, sum = {}, 0
	for _, entry in ipairs(machine.muscles) do
		local pct = math.floor((entry.share or 1) / total * 100 + 0.5)
		table.insert(out, { id = entry.id, pct = pct })
		sum += pct
	end
	if out[1] then out[1].pct += 100 - sum end
	return out
end

local function lockText(machine): string?
	local need = Machines.GymUnlock[machine.gym] or 0
	local data = ClientData.Get()
	if (data.growthSpurts or 0) < need then return "Growth Spurt " .. need end
	return nil
end

-- One face's content (the diamond's shape: narrow at the top and bottom tips, widest in the middle)
local function buildFace(gui: SurfaceGui, machine)
	local root = New("CanvasGroup", { Name = "Content", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	worldText({ Text = string.upper(machine.name), Font = "SemiBold", Size = UDim2.fromScale(0.5, 0.1), Position = UDim2.fromScale(0.5, 0.17), Parent = root }, 40)
	local shares = percents(machine)
	local lock = lockText(machine)
	-- the body figure: front and back side by side, trained muscles colored in
	local figure = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.28), Size = UDim2.fromScale(0.5, 0.38), BackgroundTransparency = 1, Parent = root },
		{ Theme.List(Enum.FillDirection.Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local role = {}
	for index, entry in ipairs(shares) do role[entry.id] = if index == 1 then "Main" else "Helper" end
	for order, view in ipairs({ "Front", "Back" }) do
		local holder = New("Frame", { LayoutOrder = order, Size = UDim2.fromScale(0.4, 1), BackgroundTransparency = 1, Parent = figure },
			{ New("UIAspectRatioConstraint", { AspectRatio = 0.4 }) })
		BodyFigure.Draw(holder, view, function(id)
			if lock then return nil end
			if role[id] == "Main" then return SIGN.Main, 0 end
			if role[id] == "Helper" then return SIGN.Helper, 0.05 end
			return nil
		end, SIGN.Body, SIGN.BodyTransparency)
	end
	if lock then
		local icon = New("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromScale(0.09, 0.09), BackgroundTransparency = 1, Parent = root })
		Icons.Lock(Color3.new(1, 1, 1)).Parent = icon
		worldText({ Text = lock, Font = "SemiBold", Size = UDim2.fromScale(0.4, 0.075), Position = UDim2.fromScale(0.5, 0.78), Parent = root }, 26)
		return root
	end
	if machine.trains == "Stamina" then
		worldText({ Text = "Stamina", Font = "SemiBold", Size = UDim2.fromScale(0.5, 0.085), Position = UDim2.fromScale(0.5, 0.69), Parent = root }, 30)
		return root
	end
	local main = shares[1]
	if main then
		worldText({ Text = Muscles.ById[main.id].name .. " " .. main.pct .. "%", Font = "SemiBold", Size = UDim2.fromScale(0.6, 0.095), Position = UDim2.fromScale(0.5, 0.665), Parent = root }, 36)
	end
	local helpers = {}
	for index = 2, #shares do
		table.insert(helpers, Muscles.ById[shares[index].id].name .. " " .. shares[index].pct .. "%")
	end
	if #helpers > 0 then
		-- two per line, so the narrowing bottom of the diamond still holds them
		local lines = {}
		for index = 1, #helpers, 2 do table.insert(lines, table.concat({ helpers[index], helpers[index + 1] }, "  ")) end
		for line, textLine in ipairs(lines) do
			worldText({ Text = textLine, Font = "Regular", TextColor3 = Color3.fromRGB(205, 205, 212),
				Size = UDim2.fromScale(0.5 - (line - 1) * 0.13, 0.068), Position = UDim2.fromScale(0.5, 0.765 + (line - 1) * 0.07), Parent = root }, 26)
		end
	end
	return root
end

local function build(model)
	local machine = Machines.ById[model:GetAttribute("MachineId")]
	if not machine then return nil end
	local boxCf, boxSize = model:GetBoundingBox()
	local top = boxCf.Position.Y + boxSize.Y / 2
	-- under a low ceiling (a squat rack in the starter gym) the sign gets smaller so it fits
	local scale, gap = 1, SIGN.Gap
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model, folder }
	local hit = Workspace:Raycast(Vector3.new(boxCf.Position.X, top + 0.05, boxCf.Position.Z), Vector3.new(0, SIGN.Gap + DIAGONAL + 2, 0), params)
	if hit then
		local room = hit.Position.Y - top - 0.3
		if room < SIGN.Gap + DIAGONAL then
			gap = math.min(SIGN.Gap, math.max(room * 0.12, 0.1))
			scale = math.clamp((room - gap) / DIAGONAL, 0.5, 1)
		end
	end
	local side, diagonal = SIGN.Side * scale, DIAGONAL * scale
	local sign = {
		model = model, machine = machine, diagonal = diagonal,
		center = Vector3.new(boxCf.Position.X, top + gap + diagonal / 2, boxCf.Position.Z),
		phase = math.random() * math.pi * 2,
		yaw = 0, diamond = 0, bang = 0, outline = 0, inside = false,
	}
	local group = Instance.new("Model")
	group.Name = model.Name .. "Sign"
	-- the glass slab and its neon frame (built facing -Z, turned 45 degrees about Z)
	sign.slab = part({ Name = "Glass", Size = Vector3.new(side, side, SIGN.Thick), Color = SIGN.Glass, Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.12, Transparency = 1, Parent = group })
	sign.frame = {}
	local half, w = side / 2, SIGN.FrameWidth
	for _, spec in ipairs({
		{ Vector3.new(0, half - w / 2, 0), Vector3.new(side, w, SIGN.Thick + 0.03) },
		{ Vector3.new(0, -half + w / 2, 0), Vector3.new(side, w, SIGN.Thick + 0.03) },
		{ Vector3.new(half - w / 2, 0, 0), Vector3.new(w, side, SIGN.Thick + 0.03) },
		{ Vector3.new(-half + w / 2, 0, 0), Vector3.new(w, side, SIGN.Thick + 0.03) },
	}) do
		local bar = part({ Name = "Frame", Size = spec[2], Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 1, Parent = group })
		table.insert(sign.frame, { part = bar, offset = CFrame.new(spec[1]) })
	end
	-- the faces: an upright see-through holder (the text never turns with the diamond)
	sign.holder = part({ Name = "Face", Size = Vector3.new(diagonal, diagonal, SIGN.Thick + 0.04), Transparency = 1, Parent = group })
	sign.faces = {}
	sign.guis = {}
	sign.lockShown = lockText(machine)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = New("SurfaceGui", {
			Face = face,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = SIGN.PixelsPerStud,
			LightInfluence = 0,
			Brightness = 1.2,
			MaxDistance = SIGN.Near + 10,
			ZOffset = 1,
			Parent = sign.holder,
		})
		local content = buildFace(gui, machine)
		content.GroupTransparency = 1
		table.insert(sign.faces, content)
		table.insert(sign.guis, gui)
	end
	-- "!" + "NEW" for machines you've never used
	sign.billboard = New("BillboardGui", {
		Size = UDim2.fromOffset(84, 118),
		StudsOffset = Vector3.new(0, diagonal / 2 + 1.1, 0),
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = SIGN.Far + 5,
		Enabled = false,
		Parent = sign.holder,
	})
	sign.bangLabel = New("TextLabel", { Text = "!", FontFace = Theme.Fonts.SemiBold, TextScaled = true, TextColor3 = SIGN.Bang, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 84), Parent = sign.billboard }, { New("UIStroke", { Color = Color3.new(0, 0, 0), Transparency = 0.2, Thickness = 3 }) })
	sign.newTag = New("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(52, 24), BackgroundColor3 = SIGN.Bang, Parent = sign.billboard },
		{ Theme.Round("Button") })
	sign.newLabel = New("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "NEW", TextSize = 16, FontFace = Theme.Fonts.SemiBold,
		TextColor3 = Color3.fromRGB(20, 20, 24), Parent = sign.newTag })
	-- the floor outline (a flat see-through part whose top face draws a glowing border)
	local footprint = boxSize + Vector3.new(SIGN.Outline.Margin * 2, 0, SIGN.Outline.Margin * 2)
	local _, yaw, _ = boxCf:ToOrientation()
	sign.outlinePart = part({ Name = "Outline", Size = Vector3.new(footprint.X, SIGN.Outline.Height, footprint.Z), Transparency = 1,
		CFrame = CFrame.new(boxCf.Position.X, boxCf.Position.Y - boxSize.Y / 2 + SIGN.Outline.Height / 2 + 0.01, boxCf.Position.Z) * CFrame.Angles(0, yaw, 0), Parent = group })
	local outlineGui = New("SurfaceGui", { Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 20,
		LightInfluence = 0, Brightness = 2.5, MaxDistance = SIGN.Near + 10, Parent = sign.outlinePart })
	local ring = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = outlineGui }, { Theme.Round("Button") })
	sign.outlineStroke = New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = SIGN.Outline.Stroke, Transparency = 1, Parent = ring })
	sign.footprintCf, sign.footprintSize = sign.outlinePart.CFrame, footprint
	group.Parent = folder
	sign.group = group
	return sign
end

local function isNew(machineId: string): boolean
	if localUsed[machineId] then return false end
	local data = ClientData.Get()
	if data.machinesUsed and data.machinesUsed[machineId] then return false end
	if data.machines and data.machines[machineId] then return false end -- (used before the tag existed)
	return true
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
	local step = dt / SIGN.Fade
	if current < target then return math.min(target, current + step) end
	return math.max(target, current - step)
end

local function apply(sign, dt: number, now: number, cameraPosition: Vector3)
	-- turn toward the camera (yaw only), with a little lag
	local flat = Vector3.new(cameraPosition.X - sign.center.X, 0, cameraPosition.Z - sign.center.Z)
	if flat.Magnitude > 0.01 then
		local want = math.atan2(-flat.X, -flat.Z)
		local diff = (want - sign.yaw + math.pi) % (2 * math.pi) - math.pi
		sign.yaw += diff * (1 - math.exp(-SIGN.TurnRate * dt))
	end
	local bob = math.sin(now * SIGN.BobSpeed + sign.phase) * SIGN.Bob
	local base = CFrame.new(sign.center + Vector3.new(0, bob, 0)) * CFrame.Angles(0, sign.yaw, 0)
	local slabCf = base * CFrame.Angles(0, 0, math.rad(45))
	local list, cframes = { sign.slab, sign.holder }, { slabCf, base }
	for _, bar in ipairs(sign.frame) do
		table.insert(list, bar.part)
		table.insert(cframes, slabCf * bar.offset)
	end
	Workspace:BulkMoveTo(list, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	-- the fades
	local a = sign.diamond
	sign.slab.Transparency = 1 - (1 - SIGN.GlassTransparency) * a
	for _, bar in ipairs(sign.frame) do bar.part.Transparency = 1 - a end
	for _, content in ipairs(sign.faces) do content.GroupTransparency = 1 - a end
	local strokeT = if sign.inside then SIGN.Outline.Bright else SIGN.Outline.Dim
	sign.outlineStroke.Transparency = 1 - (1 - strokeT) * sign.outline
	-- the "!"
	local b = sign.bang
	sign.billboard.Enabled = b > 0
	if b > 0 then
		sign.billboard.StudsOffset = Vector3.new(0, sign.diagonal / 2 + 1.1 + math.abs(math.sin(now * SIGN.BangSpeed + sign.phase)) * SIGN.BangBounce * 3, 0)
		sign.bangLabel.TextTransparency = 1 - b
		local outline = sign.bangLabel:FindFirstChildOfClass("UIStroke")
		if outline then outline.Transparency = 1 - b * 0.8 end
		sign.newTag.BackgroundTransparency = 1 - b
		sign.newLabel.TextTransparency = 1 - b
	end
end

RunService.RenderStepped:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = Workspace.CurrentCamera
	if not root or not camera then return end
	local now = os.clock()
	local from = root.Position
	local cameraPosition = camera.CFrame.Position
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		local id = model:GetAttribute("MachineId")
		local sign = signs[model]
		local pivot = if sign then sign.center else nil
		if not pivot then
			pivot = pivots[model]
			if not pivot then
				if not model:IsDescendantOf(Workspace) then continue end
				local ok, cf = pcall(function() return model:GetPivot() end)
				if not ok then continue end
				pivot = cf.Position
				pivots[model] = pivot
			end
		end
		local distance = (Vector3.new(pivot.X, from.Y, pivot.Z) - from).Magnitude
		if not sign and distance > SIGN.Far + 5 then continue end
		if not sign then
			sign = build(model)
			if not sign then continue end
			signs[model] = sign
		end
		-- a machine that unlocked (or locked) since: its faces again
		if now - (sign.checkedAt or 0) > 2 then
			sign.checkedAt = now
			local lock = lockText(sign.machine)
			if lock ~= sign.lockShown then
				sign.lockShown = lock
				for index, gui in ipairs(sign.guis) do
					sign.faces[index]:Destroy()
					sign.faces[index] = buildFace(gui, sign.machine)
					sign.faces[index].GroupTransparency = 1 - sign.diamond
				end
			end
		end
		local mine = model:GetAttribute("UserId") == player.UserId
		local new = id ~= nil and isNew(id)
		local wantDiamond = if not mine and distance <= SIGN.Near then 1 else 0
		local wantBang = if not mine and new and distance <= SIGN.Far then 1 else 0
		local local_ = sign.footprintCf:PointToObjectSpace(from)
		sign.inside = math.abs(local_.X) <= sign.footprintSize.X / 2 and math.abs(local_.Z) <= sign.footprintSize.Z / 2
		local before = sign.diamond + sign.bang + sign.outline
		sign.diamond = approach(sign.diamond, wantDiamond, dt)
		sign.outline = approach(sign.outline, wantDiamond, dt)
		sign.bang = approach(sign.bang, wantBang, dt)
		if sign.diamond + sign.bang + sign.outline > 0 or before > 0 then
			if sign.group.Parent ~= folder then sign.group.Parent = folder end
			apply(sign, dt, now, cameraPosition)
		elseif sign.group.Parent and distance > SIGN.Far + 5 then
			sign.group.Parent = nil -- (far away: out of the world until you come back)
		end
	end
end)
