-- ProGymValley (prompt 58, 23 Oct): the lower area the Pro Gym's east windows look down on. The Pro Gym stands on the
-- ground at the north-east corner of the town, so instead of raising the gym the land EAST of it (outside the town
-- boundary at x 200 / z -98, where nobody can walk) is cut down into a wide valley:
--   * the valley floor is flat concrete at y -72 (the gym floor is at y 0), from the gym's east wall (x 157) out to
--     x 1400, between z -600 and z -8 (and from x 244 also south to z 150, behind the town's east edge);
--   * every terrain column just outside the cut becomes a rock cliff from the floor up to its old surface (its top voxel
--     keeps its grass), so the edges read as cliffs, never as floating grass;
--   * the hill objects that stood in the cut (a tree and the old far "Distant" buildings) go to
--     ServerStorage.ProGymValleyBackup; the terrain before is saved there too (TerrainRegion "Before").
-- The city itself is a client-side backdrop (tools/builders/ProGymCity, ReplicatedStorage.Backdrops.ProGymCity).
-- Run once: require(this).Run(). Undo: Terrain:PasteRegion(backup.Before, backup.Before:GetAttribute("Corner"), true).
local ProGymValley = {}

local FLOOR_Y = -72
local BOTTOM_Y = -96
local TOP_Y = 104
local MIN_X, MAX_X = 157, 1400
local MIN_Z, MAX_Z = -600, 150
local EDGE = 8 -- studs of rock cliff round the cut

local function inCut(x: number, z: number): boolean
	if x < MIN_X or x > MAX_X or z < MIN_Z or z > MAX_Z then return false end
	if z > -8 and x < 244 then return false end -- (the town's east edge: the buildings along z 0..113 stay on the hill)
	return true
end

local function nearCut(x: number, z: number): boolean
	for _, d in ipairs({ { EDGE, 0 }, { -EDGE, 0 }, { 0, EDGE }, { 0, -EDGE }, { EDGE, EDGE }, { -EDGE, -EDGE }, { EDGE, -EDGE }, { -EDGE, EDGE } }) do
		if inCut(x + d[1], z + d[2]) then return true end
	end
	return false
end

function ProGymValley.Run()
	local SS = game:GetService("ServerStorage")
	local T = workspace.Terrain
	assert(not SS:FindFirstChild("ProGymValleyBackup"), "already cut (ServerStorage.ProGymValleyBackup exists)")
	local backup = Instance.new("Folder")
	backup.Name = "ProGymValleyBackup"
	-- the terrain before (the whole box, cliffs included)
	local box = Region3int16.new(Vector3int16.new((MIN_X - 16) // 4, BOTTOM_Y // 4, (MIN_Z - 16) // 4),
		Vector3int16.new((MAX_X + 16) // 4, TOP_Y // 4, (MAX_Z + 16) // 4))
	local ok, before = pcall(function() return T:CopyRegion(box) end)
	if ok and before then
		before.Name = "Before"
		before:SetAttribute("Corner", Vector3.new((MIN_X - 16) // 4, BOTTOM_Y // 4, (MIN_Z - 16) // 4))
		before.Parent = backup
	else
		warn("[ProGymValley] terrain backup failed: " .. tostring(before))
	end
	-- objects standing in the cut
	for _, folder in ipairs({ workspace.Town.Greenery, workspace.Town.Buildings }) do
		for _, item in ipairs(folder:GetChildren()) do
			local p = if item:IsA("Model") then item:GetPivot().Position elseif item:IsA("BasePart") then item.Position else nil
			if p and inCut(p.X, p.Z) then
				item:SetAttribute("WasIn", folder:GetFullName())
				item.Parent = backup
			end
		end
	end
	local distant = workspace.Town.Buildings:FindFirstChild("Distant")
	if distant then
		local p = distant:IsA("Model") and distant:GetPivot().Position or Vector3.new(300, 0, -300)
		if inCut(p.X, p.Z) then distant.Parent = backup end
	end
	backup.Parent = SS

	-- the cut, in chunks of 64 x 64 studs
	local Air, Floor, Rock = Enum.Material.Air, Enum.Material.Concrete, Enum.Material.Rock
	local floorTop = (FLOOR_Y - BOTTOM_Y) // 4 -- voxels from the bottom up to the floor
	for cx = MIN_X - EDGE - 4, MAX_X + EDGE, 64 do
		for cz = MIN_Z - EDGE - 4, MAX_Z + EDGE, 64 do
			local region = Region3.new(Vector3.new(cx, BOTTOM_Y, cz), Vector3.new(cx + 64, TOP_Y, cz + 64)):ExpandToGrid(4)
			local mats, occ = T:ReadVoxels(region, 4)
			local size = mats.Size
			local x0, z0 = region.CFrame.Position.X - region.Size.X / 2, region.CFrame.Position.Z - region.Size.Z / 2
			local changed = false
			for ix = 1, size.X do
				local x = x0 + (ix - 0.5) * 4
				for iz = 1, size.Z do
					local z = z0 + (iz - 0.5) * 4
					if inCut(x, z) then
						changed = true
						for iy = 1, size.Y do
							if iy <= floorTop then
								mats[ix][iy][iz], occ[ix][iy][iz] = Floor, 1
							else
								mats[ix][iy][iz], occ[ix][iy][iz] = Air, 0
							end
						end
					elseif nearCut(x, z) then
						-- a cliff: rock from the bottom up to the old surface (the top voxel keeps its material)
						local top = 0
						for iy = size.Y, 1, -1 do
							if mats[ix][iy][iz] ~= Air and occ[ix][iy][iz] > 0.05 then top = iy break end
						end
						if top > 0 then
							changed = true
							for iy = 1, top - 1 do mats[ix][iy][iz], occ[ix][iy][iz] = Rock, 1 end
						end
					end
				end
			end
			if changed then T:WriteVoxels(region, 4, mats, occ) end
			task.wait()
		end
	end
	return "done"
end

return ProGymValley
