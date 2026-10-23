-- ProGymCliffGreenery (prompt 62, 23 Oct): what the Pro Gym's east windows see near by. Workspace.ProGym.CliffGreenery:
--   * a row of big oaks (the town's own Oak, scaled up to ~28 studs) on the strip of town land south-east of the gym
--     (x 165..235, z -5), so the backs of the three Main Street buildings at x 150..210 are hidden from the windows;
--     tall cypresses (the town's Cypress) stand in the gaps between their trunks;
--   * bushes and rocks (the town's Bush / Rock, scaled up) along the cliff top under the east windows (x ~157, z -88..-10),
--     so the edge reads as a natural green rim, not a cut.
-- Copies of Workspace.Town.Greenery models: Anchored, no collisions, no shadows on the small ones. Run once:
-- require(this).Run() (it replaces an older CliffGreenery).
local CliffGreenery = {}

local rng = Random.new(62)

local function quiet(model: Model, shadows: boolean)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.CastShadow = shadows
		end
	end
end

-- a copy of a town greenery model, scaled, standing on the ground at (x, z)
local function plant(template: Model, parent: Instance, x: number, z: number, scale: number, shadows: boolean)
	local m = template:Clone()
	m:ScaleTo(scale)
	local cf, size = m:GetBoundingBox()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain } -- (the ground only: not the cliff guard or a roof)
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -200, 0), params)
	local ground = if hit then hit.Position.Y else 0
	local bottom = cf.Y - size.Y / 2
	m:PivotTo(CFrame.new(x, m:GetPivot().Y - bottom + ground - 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	quiet(m, shadows)
	m.Parent = parent
	return m
end

function CliffGreenery.Run()
	local greenery = workspace.Town.Greenery
	local oak, bush, rock = greenery:FindFirstChild("Oak"), greenery:FindFirstChild("Bush"), greenery:FindFirstChild("Rock")
	assert(oak and bush and rock, "Workspace.Town.Greenery needs an Oak, a Bush and a Rock to copy")
	local old = workspace.ProGym:FindFirstChild("CliffGreenery")
	if old then old:Destroy() end
	local root = Instance.new("Model")
	root.Name = "CliffGreenery"
	root.Parent = workspace.ProGym
	-- the screen of oaks
	local trees = 0
	for x = 165, 235, 14 do
		plant(oak, root, x + rng:NextNumber(-2, 2), -5 + rng:NextNumber(-1, 1), rng:NextNumber(2.2, 2.6), true)
		trees += 1
	end
	-- tall cypresses in the gaps between the oak trunks (the buildings' lower walls showed through)
	local cypress = greenery:FindFirstChild("Cypress")
	if cypress then
		for x = 158, 228, 14 do
			plant(cypress, root, x + rng:NextNumber(-1, 1), -6.5, rng:NextNumber(1.9, 2.3), true)
			trees += 1
		end
	end
	-- the green rim along the cliff top under the east windows
	local small = 0
	for z = -88, -10, 5 do
		local useRock = rng:NextNumber() < 0.35
		plant(if useRock then rock else bush, root, 157 + rng:NextNumber(-0.8, 0.8), z + rng:NextNumber(-1.5, 1.5),
			if useRock then rng:NextNumber(1.8, 2.6) else rng:NextNumber(1.6, 2.2), false)
		small += 1
	end
	return trees .. " trees, " .. small .. " bushes / rocks"
end

return CliffGreenery
