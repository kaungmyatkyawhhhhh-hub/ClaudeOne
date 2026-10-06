-- SkateParkExtras: fills the skate park's empty concrete (Workspace.Town.SkatePark.Extras). Run once in Studio with
-- Kit + TownKit loaded next to it, then save:  require(game.ServerStorage._Builders.SkateParkExtras).Build()
-- Running it again replaces the Extras folder.
--  * Painted floor: three big round "plates" in the bumper colors (mint, sunny, coral) with a white ring, laid on the
--    slab with a clear gap between them (nothing overlaps, so nothing flickers).
--  * South-west: a low manual pad with metal coping, beside the sunny plate.
--  * East middle: a flat bar (two posts, a long round bar) and a kicker (roll in from the funbox, launch east).
--  * The two ledges get a painted side stripe.
local Kit = require(script.Parent.Kit)
local TownKit = require(script.Parent.TownKit)

local Extras = {}

local hex, rad = Kit.hex, math.rad
local M = Enum.Material
local p, cyl = TownKit.p, TownKit.cyl
local up = CFrame.Angles(0, 0, rad(90))

local SLAB_TOP = 0.3
local COLOR = {
	Concrete = hex("#B8B3A9"), ConcreteDark = hex("#A8A49C"), Metal = hex("#C9CCD2"), Iron = hex("#2B2C2F"),
	Mint = hex("#7CC6A5"), Sunny = hex("#F2C14E"), Coral = hex("#E86A6A"), White = hex("#F2EEE6"), Ocean = hex("#2E6E8E"),
}

-- a flat painted disc with a thin white ring around it (ring = a slightly bigger, slightly lower disc)
local function paintedPlate(parent, x, z, diameter, color)
	cyl(parent, "PaintRing", 0.05, diameter + 0.5, CFrame.new(x, SLAB_TOP + 0.025, z) * up, COLOR.White, M.SmoothPlastic)
	cyl(parent, "Paint", 0.05, diameter, CFrame.new(x, SLAB_TOP + 0.06, z) * up, color, M.SmoothPlastic)
	cyl(parent, "PaintHub", 0.05, diameter * 0.28, CFrame.new(x, SLAB_TOP + 0.095, z) * up, COLOR.White, M.SmoothPlastic)
end

-- a kicker ramp: a wedge with a metal lip plate at the top edge and side cheeks
local function kicker(parent, cframe, width, length, height, color)
	local w = Kit.wedge(parent, "Kicker", Vector3.new(width, height, length), cframe * CFrame.new(0, SLAB_TOP + height / 2, 0), color or COLOR.Concrete, M.Concrete)
	w.CastShadow = true
	p(parent, "KickerLip", Vector3.new(width + 0.08, 0.12, 0.3), cframe * CFrame.new(0, SLAB_TOP + height - 0.02, -length / 2 + 0.15), COLOR.Metal, M.Metal)
	p(parent, "KickerBack", Vector3.new(width, height, 0.25), cframe * CFrame.new(0, SLAB_TOP + height / 2, -length / 2 - 0.125), COLOR.ConcreteDark, M.Concrete, true)
	return w
end

function Extras.Build()
	local park = workspace:FindFirstChild("Town") and workspace.Town:FindFirstChild("SkatePark")
	assert(park, "Workspace.Town.SkatePark is missing")
	local old = park:FindFirstChild("Extras")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Extras"
	folder.Parent = park

	-- painted plates on the open floor (a gap of 2+ studs between them and every obstacle)
	paintedPlate(folder, -141.5, 190, 8, COLOR.Sunny)
	paintedPlate(folder, -106, 207, 7, COLOR.Mint)
	paintedPlate(folder, -133, 209, 5.5, COLOR.Coral)

	-- manual pad (south-west, running north-south), low and long, metal coping on both long edges
	local pad = CFrame.new(-133.5, 0, 190.5) * CFrame.Angles(0, rad(90), 0)
	p(folder, "ManualPad", Vector3.new(9, 0.9, 3.2), pad * CFrame.new(0, SLAB_TOP + 0.45, 0), COLOR.Concrete, M.Concrete, true)
	for _, s in ipairs({ -1, 1 }) do
		p(folder, "PadCoping", Vector3.new(9.08, 0.14, 0.18), pad * CFrame.new(0, SLAB_TOP + 0.92, s * 1.55), COLOR.Metal, M.Metal)
	end
	p(folder, "PadStripe", Vector3.new(9.02, 0.2, 3.22), pad * CFrame.new(0, SLAB_TOP + 0.2, 0), COLOR.Ocean, M.Concrete)

	-- a kicker between the funbox and the east quarter pipe (roll in from the funbox, launch east)
	kicker(folder, CFrame.new(-107, 0, 199.5) * CFrame.Angles(0, rad(-90), 0), 3.2, 3.6, 1.2)

	-- flat bar (east middle, along z)
	local bar = CFrame.new(-102, 0, 212)
	for _, z in ipairs({ -3.5, 3.5 }) do
		p(folder, "BarPost", Vector3.new(0.25, 1.1, 0.25), bar * CFrame.new(0, SLAB_TOP + 0.55, z), COLOR.Iron, M.Metal, true)
		p(folder, "BarFoot", Vector3.new(0.7, 0.1, 0.7), bar * CFrame.new(0, SLAB_TOP + 0.05, z), COLOR.Iron, M.Metal)
	end
	cyl(folder, "FlatBar", 8.6, 0.28, bar * CFrame.new(0, SLAB_TOP + 1.2, 0) * CFrame.Angles(0, rad(90), 0), COLOR.Metal, M.Metal, true)
	for _, z in ipairs({ -4.3, 4.3 }) do
		cyl(folder, "BarCap", 0.12, 0.34, bar * CFrame.new(0, SLAB_TOP + 1.2, z) * CFrame.Angles(0, rad(90), 0), COLOR.Iron, M.Metal)
	end

	-- painted side stripes on the two ledges (a thin layer just proud of the ledge face)
	for _, ledge in ipairs(park:GetChildren()) do
		if ledge.Name == "Ledge" and ledge:IsA("BasePart") then
			for _, s in ipairs({ -1, 1 }) do
				p(folder, "LedgeStripe", Vector3.new(ledge.Size.X - 0.4, 0.28, 0.04), ledge.CFrame * CFrame.new(0, -0.15, s * (ledge.Size.Z / 2 + 0.02)), ledge.Position.Z > 200 and COLOR.Coral or COLOR.Mint, M.SmoothPlastic)
			end
		end
	end

	return folder
end

return Extras
