-- SpotPoints builder (run once in Studio, Edit mode; see tools/bake.md): the spotting stand spots on every machine
-- (owner's spotting redo, 8 Oct night). Each Machine-tagged model gets an invisible part "SpotPoints" at its pivot with
-- Attachments (each one's LookVector = the way the spotter faces, its Y = the floor):
--   Spot_Left1, Spot_Left2, Spot_Right1, Spot_Right2, Spot_Middle: "hands" spotting at the bar (benches, squat rack,
--     overhead press; measured with a lifter on them: squat / press lifter faces pivot +Z, bar 1.2 studs ahead; bench
--     lifter lies head toward pivot -Z under the bar)
--   Hype_1..5: a loose half-circle in front of the lifter, facing them, moved clear of walls and other machines and to
--     where the machine itself doesn't block the view (e.g. beside the pro cable towers, not behind them).
-- SpotService uses them (and works out the same spots itself for a machine without them). Running it again replaces them.
--   require(game.ServerStorage._Builders.SpotPoints).Build()  -> report string
local CollectionService = game:GetService("CollectionService")

local SpotPoints = {}

-- pivot space: the bar's z, the middle spotter's z, the sides' x, where the lifter is (hype circle centre)
local HANDS = {
	FlatBench = { barZ = -2.05, middleZ = -4.3, sideX = 3.8, secondZ = -1.3, lifter = Vector3.new(0, 0, -0.9) },
	InclineBench = { barZ = -1.75, middleZ = -3.7, sideX = 3.8, secondZ = -1.3, lifter = Vector3.new(0, 0, -0.5) },
	SquatRack = { barZ = 1.55, middleZ = -1.4, sideX = 3.9, secondZ = -1.3, lifter = Vector3.new(0, 0, 0.4) },
	OverheadPress = { barZ = 1.85, middleZ = -1.4, sideX = 3.9, secondZ = -1.3, lifter = Vector3.new(0, 0, 0.4) },
}
local HYPE_ANGLES = { -72, -36, 0, 36, 72 } -- degrees around the lifter's front (+Z)
local HYPE_RADIUS_JITTER = { 0.4, -0.3, 0.6, -0.2, 0.3 } -- (a loose half-circle, not a perfect arc)

-- a spot is clear when a standing body there (2 x 5 x 2) touches nothing solid but the floor
local function clear(worldCF: CFrame, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = false
	for _, part in ipairs(workspace:GetPartBoundsInBox(worldCF * CFrame.new(0, 2.9, 0), Vector3.new(2, 5, 2), params)) do
		local visible = part.Transparency < 0.9
		if visible and part.CanCollide and part.Size.Y > 0.6 then return false end
	end
	return true
end

-- the spotter at `worldCF` can see the lifter (`lifter`, world) without their own machine in between (e.g. not behind a
-- cable tower)
local function sees(worldCF: CFrame, lifter: Vector3, model: Instance): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local eye = worldCF.Position + Vector3.new(0, 4.4, 0)
	local target = lifter + Vector3.new(0, 3, 0)
	local hit = workspace:Raycast(eye, (target - eye) * 0.9, params)
	return hit == nil or not (hit.Instance.Transparency < 0.9 and hit.Instance.Size.Magnitude > 1)
end

-- local CFrame at `local` facing `target` (both pivot space, y = floor)
local function facing(at: Vector3, target: Vector3): CFrame
	local flat = Vector3.new(target.X, at.Y, target.Z)
	if (flat - at).Magnitude < 1e-3 then return CFrame.new(at) end
	return CFrame.lookAt(at, flat)
end

local function attach(holder: BasePart, name: string, cf: CFrame)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a.Parent = holder
	return a
end

function SpotPoints.Build()
	local made, blocked = 0, {}
	for _, model in ipairs(CollectionService:GetTagged("Machine")) do
		if not (model:IsA("Model") and model:IsDescendantOf(workspace)) then continue end
		local id = model:GetAttribute("MachineId")
		local old = model:FindFirstChild("SpotPoints")
		if old then old:Destroy() end
		if id == "Treadmill" then continue end
		local pivot = model:GetPivot()
		local holder = Instance.new("Part")
		holder.Name = "SpotPoints"
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.Transparency = 1
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow = true, false, false, false, false
		holder.CFrame = pivot
		holder.Parent = model
		local ignore = { model }
		for _, item in ipairs(workspace:GetChildren()) do
			if item:IsA("Terrain") or item.Name == "NPCs" then table.insert(ignore, item) end
		end
		local hands = HANDS[id]
		if hands then
			local bar = Vector3.new(0, 0, hands.barZ)
			for _, side in ipairs({ { "Right", -1 }, { "Left", 1 } }) do -- (the lifter's right is -X)
				local x = side[2] * hands.sideX
				local first = Vector3.new(x, 0, hands.barZ)
				local second = Vector3.new(x, 0, hands.barZ + hands.secondZ)
				attach(holder, "Spot_" .. side[1] .. "1", facing(first, Vector3.new(0, 0, hands.barZ)))
				attach(holder, "Spot_" .. side[1] .. "2", facing(second, Vector3.new(0, 0, hands.barZ + hands.secondZ)))
			end
			attach(holder, "Spot_Middle", facing(Vector3.new(0, 0, hands.middleZ), bar))
		end
		-- the hype half-circle: just outside the machine, in front of the lifter
		local center = hands and hands.lifter or Vector3.zero
		local _, size = model:GetBoundingBox()
		local radius = math.max(size.X, size.Z) / 2 + 2.2
		for i, degrees in ipairs(HYPE_ANGLES) do
			local chosen = nil
			-- try the spot, then a little further out / turned toward the sides, until one is clear
			-- (turned further toward the lifter's sides when the machine is in the way, e.g. the pro cable towers)
			local tries = { { 0, 0 }, { 0, 1.5 }, { 18, 0 }, { -18, 0 }, { 18, 1.5 }, { -18, 1.5 }, { 40, 0 }, { -40, 0 },
				{ 60, 0.5 }, { -60, 0.5 }, { 80, 1 }, { -80, 1 }, { 0, 3 } }
			local lifterWorld = pivot * center
			for _, try in ipairs(tries) do
				local a = math.rad(degrees + try[1] * (if degrees >= 0 then 1 else -1))
				local r = radius + HYPE_RADIUS_JITTER[i] + try[2]
				local at = center + Vector3.new(math.sin(a) * r, 0, math.cos(a) * r)
				local cf = facing(at, center)
				if clear(pivot * cf, ignore) and sees(pivot * cf, lifterWorld, model) then
					chosen = cf
					break
				end
				chosen = chosen or cf
			end
			local a = attach(holder, "Hype_" .. i, chosen :: CFrame)
			if not (clear(pivot * a.CFrame, ignore) and sees(pivot * a.CFrame, lifterWorld, model)) then
				table.insert(blocked, model:GetFullName() .. "." .. a.Name)
			end
		end
		made += 1
	end
	return string.format("spot points on %d machines; hype spots still not clear or blocked: %d %s", made, #blocked,
		table.concat(blocked, ", ", 1, math.min(#blocked, 6)))
end

return SpotPoints
