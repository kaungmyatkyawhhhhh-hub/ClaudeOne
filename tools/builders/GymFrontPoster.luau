-- GymFrontPoster: a framed, lit poster box on the starter gym's bare front wall, right of the entrance
-- (Workspace.Town.GymFront.PosterBox). Black metal frame with a bevel, a dark panel with the tagline and three bumper
-- plate discs, two gooseneck lamps with warm spotlights, and a low planter under it. Run once in Studio with Kit +
-- TownKit loaded next to it, then save:  require(game.ServerStorage._Builders.GymFrontPoster).Build()
local Kit = require(script.Parent.Kit)
local TownKit = require(script.Parent.TownKit)
local Theme = require(game:GetService("ReplicatedStorage").Shared.UI.Theme)

local Poster = {}

local hex, rad = Kit.hex, math.rad
local M = Enum.Material
local p, cyl = TownKit.p, TownKit.cyl
local up = CFrame.Angles(0, 0, rad(90))

Poster.Center = Vector3.new(18.5, 5.6, -3.0) -- on the wall's outer face (z = -3)
local W, H = 8, 4.6

function Poster.Build()
	local parent = workspace.Town.GymFront
	local old = parent:FindFirstChild("PosterBox")
	if old then old:Destroy() end
	-- local -Z points away from the wall (toward the street, +Z world)
	local cf = CFrame.lookAt(Poster.Center, Poster.Center + Vector3.new(0, 0, 1))
	local m = TownKit.model(parent, "PosterBox", cf)
	local frameColor, depth = hex("#1C1C1E"), 0.35

	-- back box, then the frame (4 bars with a lighter inner bevel), then the panel
	p(m, "Box", Vector3.new(W, H, depth), cf * CFrame.new(0, 0, -depth / 2 - 0.01), frameColor, M.Metal, true)
	for _, s in ipairs({ -1, 1 }) do
		p(m, "FrameSide", Vector3.new(0.28, H + 0.28, 0.2), cf * CFrame.new(s * (W / 2), 0, -depth - 0.1), frameColor, M.Metal)
		p(m, "FrameTopBottom", Vector3.new(W + 0.28, 0.28, 0.2), cf * CFrame.new(0, s * (H / 2), -depth - 0.1), frameColor, M.Metal)
		p(m, "Bevel", Vector3.new(0.08, H - 0.2, 0.06), cf * CFrame.new(s * (W / 2 - 0.18), 0, -depth - 0.05), hex("#5A5C60"), M.Metal)
		p(m, "Bevel", Vector3.new(W - 0.28, 0.08, 0.06), cf * CFrame.new(0, s * (H / 2 - 0.18), -depth - 0.05), hex("#5A5C60"), M.Metal)
	end
	local panel = p(m, "Panel", Vector3.new(W - 0.44, H - 0.44, 0.04), cf * CFrame.new(0, 0, -depth - 0.03), hex("#141416"), M.SmoothPlastic)
	-- the panel's front face (-Z local) faces the street
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0.4
	gui.Parent = panel
	local function label(text, y, h, font, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.06, y)
		l.Size = UDim2.fromScale(0.88, h)
		l.Text = text
		l.TextScaled = true -- world-space sign: the only place text may scale
		l.FontFace = font
		l.TextColor3 = color
		l.Parent = gui
		return l
	end
	label("Everyone starts tiny.", 0.14, 0.26, Theme.Fonts.SemiBold, hex("#EDE3D3"))
	label("Lift, grow, repeat. Every rep counts.", 0.45, 0.12, Theme.Fonts.Regular, hex("#B8B8BE"))
	for i, bumper in ipairs({ Theme.Bumper.Red, Theme.Bumper.Blue, Theme.Bumper.Yellow }) do
		local disc = Instance.new("Frame")
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5 + (i - 2) * 0.13, 0.78)
		disc.Size = UDim2.fromScale(0.1, 0.17)
		disc.BackgroundColor3 = bumper.Fill
		disc.BorderSizePixel = 0
		disc.Parent = gui
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = disc
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = disc
		local rim = Instance.new("UIStroke")
		rim.Color, rim.Thickness = bumper.Rim, 4
		rim.Parent = disc
	end

	-- two gooseneck lamps above the frame, lighting the panel
	for _, s in ipairs({ -1, 1 }) do
		local base = cf * CFrame.new(s * W * 0.3, H / 2 + 0.55, 0)
		p(m, "LampMount", Vector3.new(0.4, 0.4, 0.12), base * CFrame.new(0, 0, -0.06), frameColor, M.Metal)
		p(m, "LampArm", Vector3.new(0.1, 0.1, 1.3), base * CFrame.new(0, 0.15, -0.7), frameColor, M.Metal)
		local head = cf * CFrame.new(s * W * 0.3, H / 2 + 0.6, -1.4) * CFrame.Angles(rad(-35), 0, 0)
		cyl(m, "LampShade", 0.5, 0.45, head * CFrame.Angles(0, rad(90), 0), frameColor, M.Metal)
		local bulb = p(m, "LampBulb", Vector3.new(0.3, 0.06, 0.3), head * CFrame.new(0, -0.24, 0), hex("#FFE2B8"), M.Neon)
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 70
		light.Range = 8
		light.Brightness = 1.2
		light.Color = hex("#FFD7A8")
		light.Shadows = false
		light.Parent = bulb
	end

	-- a low planter under the poster
	local pl = cf * CFrame.new(0, -Poster.Center.Y + 0.2, -0.9)
	p(m, "PlanterBox", Vector3.new(W - 0.6, 1.1, 1.2), pl * CFrame.new(0, 0.55, 0), hex("#C9C1B4"), M.Concrete, true)
	p(m, "PlanterCap", Vector3.new(W - 0.4, 0.12, 1.4), pl * CFrame.new(0, 1.16, 0), hex("#DDD6CA"), M.Concrete)
	p(m, "PlanterSoil", Vector3.new(W - 1.0, 0.1, 0.9), pl * CFrame.new(0, 1.12, 0), hex("#4A3A2C"), M.Ground)
	local leaves = { hex("#4E7A3E"), hex("#5E8C45"), hex("#3F6B36") }
	for i = 0, 6 do
		local x = -W / 2 + 0.9 + i * (W - 1.8) / 6
		local size = 0.8 + (i % 3) * 0.15
		local ball = p(m, "Shrub", Vector3.new(size, size * 0.85, size), pl * CFrame.new(x, 1.15 + size * 0.35, (i % 2) * 0.12 - 0.06), leaves[i % 3 + 1], M.Grass)
		ball.Shape = Enum.PartType.Ball
	end
	return m
end

return Poster
