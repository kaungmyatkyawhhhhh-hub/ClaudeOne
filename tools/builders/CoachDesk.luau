-- CoachDesk builder (run once in Studio; see tools/bake.md; owner, 15 Oct): Coach Dex's spot at the starter gym's front
-- desk (Gym.StarterGym.Props.FrontDesk; Dex stands behind it, Config/Quests.CoachSpot) becomes his booth:
--   * props on the counter: a protein tub, a shaker, a clipboard with a pen and a whistle on a lanyard
--   * a gold "COACH DEX" sign hanging over the desk (dark wood frame, gold trim, two chains to the ceiling)
--   * one warm spotlight on him (a small black can on the ceiling; no shadows, cheap)
-- Everything goes in Gym.StarterGym.Props.CoachBooth (running it again replaces it). Small props: no collision, no
-- shadows, not queryable.
local Workspace = game:GetService("Workspace")

local props = Workspace.Gym.StarterGym.Props
local old = props:FindFirstChild("CoachBooth")
if old then old:Destroy() end
local booth = Instance.new("Model")
booth.Name = "CoachBooth"

local TOP = 3.8             -- the counter's top surface (FrontDesk.Top)
local DESK_X = 24.5         -- the counter's middle line (it runs along Z, the room is toward -X)
local MID_Z = -12.56        -- Dex's line
local CEILING = 16

local up = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder standing up
local function part(name, size, cf, color, material, shape, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = parent or booth
	return p
end
local function group(name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = booth
	return m
end
local BLACK, WHITE, GOLD = Color3.fromHex("#18171A"), Color3.fromHex("#F1EEE8"), Color3.fromHex("#E8B84A")

-- protein tub: a black tub, a white label band with a red stripe, a black lid
local tub = group("ProteinTub")
local tubAt = Vector3.new(24.15, TOP, -11.2)
part("Tub", Vector3.new(0.9, 0.8, 0.8), CFrame.new(tubAt + Vector3.new(0, 0.45, 0)) * up, BLACK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, tub)
part("Label", Vector3.new(0.42, 0.82, 0.82), CFrame.new(tubAt + Vector3.new(0, 0.45, 0)) * up, WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, tub)
part("Stripe", Vector3.new(0.08, 0.83, 0.83), CFrame.new(tubAt + Vector3.new(0, 0.42, 0)) * up, Color3.fromHex("#D8383F"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, tub)
part("Lid", Vector3.new(0.14, 0.84, 0.84), CFrame.new(tubAt + Vector3.new(0, 0.97, 0)) * up, Color3.fromHex("#0E0D10"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, tub)

-- shaker: a frosted bottle, a black screw cap and its spout
local shaker = group("Shaker")
local shakerAt = Vector3.new(23.95, TOP, -11.95)
part("Bottle", Vector3.new(0.85, 0.42, 0.42), CFrame.new(shakerAt + Vector3.new(0, 0.43, 0)) * up, Color3.fromHex("#D9DDE0"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, shaker).Transparency = 0.15
part("Drink", Vector3.new(0.5, 0.38, 0.38), CFrame.new(shakerAt + Vector3.new(0, 0.27, 0)) * up, Color3.fromHex("#8A5A3A"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, shaker)
part("Cap", Vector3.new(0.18, 0.44, 0.44), CFrame.new(shakerAt + Vector3.new(0, 0.94, 0)) * up, BLACK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, shaker)
part("Spout", Vector3.new(0.12, 0.12, 0.12), CFrame.new(shakerAt + Vector3.new(0, 1.08, 0.1)) * up, BLACK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, shaker)

-- clipboard: a brown board lying on the counter, paper, a metal clip and a pen
local clip = group("Clipboard")
local board = CFrame.new(24.05, TOP + 0.025, -13.25) * CFrame.Angles(0, math.rad(-12), 0)
part("Board", Vector3.new(0.95, 0.05, 1.3), board, Color3.fromHex("#7A5530"), Enum.Material.Wood, nil, clip)
part("Paper", Vector3.new(0.82, 0.02, 1.05), board * CFrame.new(0, 0.035, 0.07), WHITE, Enum.Material.SmoothPlastic, nil, clip)
part("Lines", Vector3.new(0.6, 0.021, 0.02), board * CFrame.new(0, 0.046, -0.15), Color3.fromHex("#7A7F86"), Enum.Material.SmoothPlastic, nil, clip)
part("Lines2", Vector3.new(0.6, 0.021, 0.02), board * CFrame.new(0, 0.046, 0.05), Color3.fromHex("#7A7F86"), Enum.Material.SmoothPlastic, nil, clip)
part("Lines3", Vector3.new(0.45, 0.021, 0.02), board * CFrame.new(-0.07, 0.046, 0.25), Color3.fromHex("#7A7F86"), Enum.Material.SmoothPlastic, nil, clip)
part("Clip", Vector3.new(0.4, 0.07, 0.14), board * CFrame.new(0, 0.06, -0.58), Color3.fromHex("#B8BCC2"), Enum.Material.Metal, nil, clip)
part("Pen", Vector3.new(0.8, 0.05, 0.05), board * CFrame.new(0.55, 0.02, 0) * CFrame.Angles(0, math.rad(80), 0), Color3.fromHex("#1F4FA8"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, clip)

-- whistle: a silver whistle and its red lanyard loop lying on the counter
local whistle = group("Whistle")
local w = CFrame.new(24.3, TOP + 0.09, -12.35) * CFrame.Angles(0, math.rad(30), 0)
part("Body", Vector3.new(0.28, 0.17, 0.17), w * CFrame.Angles(0, math.rad(90), 0), Color3.fromHex("#C9CDD3"), Enum.Material.Metal, Enum.PartType.Cylinder, whistle)
part("Mouth", Vector3.new(0.08, 0.08, 0.2), w * CFrame.new(0, 0.02, -0.2), Color3.fromHex("#C9CDD3"), Enum.Material.Metal, nil, whistle)
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	part("Lanyard", Vector3.new(0.2, 0.03, 0.04), w * CFrame.new(math.cos(a) * 0.4, -0.07, 0.35 + math.sin(a) * 0.3) * CFrame.Angles(0, -a, 0),
		Color3.fromHex("#C8323A"), Enum.Material.Fabric, nil, whistle)
end

-- the sign over the desk, facing the room: a dark wood board in a gold frame, the name in gold, two chains up
local sign = group("CoachSign")
local SIGN_Y = 8.75 -- (under the desk's pendant lamp, over Dex's head)
local face = CFrame.new(DESK_X + 1.0, SIGN_Y, MID_Z) * CFrame.Angles(0, math.rad(90), 0) -- (front face toward -X, the room)
local W, H = 6.4, 1.5
part("Board", Vector3.new(W, H, 0.25), face, Color3.fromHex("#2A1B12"), Enum.Material.Wood, nil, sign)
for _, edge in ipairs({ { 0, H / 2, W + 0.16, 0.12 }, { 0, -H / 2, W + 0.16, 0.12 }, { W / 2, 0, 0.12, H }, { -W / 2, 0, 0.12, H } }) do
	part("Trim", Vector3.new(edge[3], edge[4], 0.32), face * CFrame.new(edge[1], edge[2], 0), GOLD, Enum.Material.Metal, nil, sign)
end
local plate = part("Face", Vector3.new(W - 0.3, H - 0.3, 0.05), face * CFrame.new(0, 0, -0.14), Color3.fromHex("#1A110B"), Enum.Material.SmoothPlastic, nil, sign)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 60
gui.LightInfluence = 0.2
gui.MaxDistance = 120
gui.Parent = plate
local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundTransparency = 1
label.Text = "COACH DEX"
label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Rotation = 90
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromHex("#FFF3C4")), ColorSequenceKeypoint.new(0.35, Color3.fromHex("#F6C75A")),
	ColorSequenceKeypoint.new(0.75, Color3.fromHex("#C98A12")), ColorSequenceKeypoint.new(1, Color3.fromHex("#F2C45A")),
})
gradient.Parent = label
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromHex("#2A1606")
stroke.Thickness = 3
stroke.Parent = label
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
padding.PaddingTop, padding.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
padding.Parent = label
-- a soft warm glow on the board (no shadows)
local glow = Instance.new("SurfaceLight")
glow.Face = Enum.NormalId.Front
glow.Color = Color3.fromHex("#FFCF7A")
glow.Brightness = 0.6
glow.Range = 5
glow.Angle = 80
glow.Shadows = false
glow.Parent = plate
for _, side in ipairs({ -1, 1 }) do
	local top = SIGN_Y + H / 2
	local length = CEILING - top
	local x = side * (W / 2 - 0.5)
	part("Chain", Vector3.new(length, 0.07, 0.07), face * CFrame.new(x, H / 2 + length / 2, 0) * up, Color3.fromHex("#2C2C30"), Enum.Material.Metal,
		Enum.PartType.Cylinder, sign)
	part("Hook", Vector3.new(0.22, 0.22, 0.22), face * CFrame.new(x, H / 2 + 0.05, 0), Color3.fromHex("#2C2C30"), Enum.Material.Metal, Enum.PartType.Ball, sign)
	part("Mount", Vector3.new(0.5, 0.12, 0.5), face * CFrame.new(x, H / 2 + length - 0.06, 0), Color3.fromHex("#2C2C30"), Enum.Material.Metal, nil, sign)
end

-- the spotlight: a short black can on the ceiling over Dex, angled down at him
local can = group("Spotlight")
local lampAt = Vector3.new(24.2, CEILING - 0.45, MID_Z)
local aim = CFrame.lookAt(lampAt, Vector3.new(26.8, 5.2, MID_Z))
part("Mount", Vector3.new(0.5, 0.18, 0.5), CFrame.new(lampAt + Vector3.new(0, 0.36, 0)), BLACK, Enum.Material.Metal, nil, can)
part("Can", Vector3.new(0.75, 0.55, 0.55), aim * CFrame.Angles(0, math.rad(90), 0), BLACK, Enum.Material.Metal, Enum.PartType.Cylinder, can)
local lens = part("Lens", Vector3.new(0.05, 0.46, 0.46), aim * CFrame.new(0, 0, -0.38) * CFrame.Angles(0, math.rad(90), 0), Color3.fromHex("#FFE7B8"),
	Enum.Material.Neon, Enum.PartType.Cylinder, can)
local spot = Instance.new("SpotLight")
spot.Face = Enum.NormalId.Left -- (the lens cylinder's axis is its X: Left points down the can toward Dex)
spot.Color = Color3.fromHex("#FFC98A")
spot.Brightness = 3.2
spot.Range = 16
spot.Angle = 42
spot.Shadows = false
spot.Parent = lens

booth.Parent = props
local count = 0
for _, d in ipairs(booth:GetDescendants()) do if d:IsA("BasePart") then count += 1 end end
return "CoachBooth built: " .. count .. " parts"
