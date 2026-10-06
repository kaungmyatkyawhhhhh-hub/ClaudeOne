-- Fix list 3, part 5: one-off fixes for overlapping / flickering parts in the saved place. Run once in Studio (with
-- Kit and TownKit loaded next to it in ServerStorage._Builders), then save the place:
--   require(game.ServerStorage._Builders.Fix3Overlaps).Run()
-- The Town / TownKit recipes contain the same fixes for a rebuild from scratch. Running it again is safe (it only
-- touches what is still broken). Returns a short report.
--  1. Park: the fountain ring was 28 straight slabs that overlapped each other and the 4 straight paths. Now ONE
--     part (TownKit.pathRing, CSG) with the straights merged in; the path edge strips stop at the ring.
--  2. Umbrellas (plaza carts, smoothie bar, beach): the canopy was 8 flat slats that overlapped in the middle and
--     looked like spokes from below. Now a solid 8-panel canopy (TownKit.umbrella), same colors and size.
--  3. Path edge strips sat 0.01 above the paving (flicker): now clearly above it.
--  4. Everything else: two parts showing a face on the same plane in the same place (a trim flush with a wall, an inlay
--     flush with a floor, a rail level with a post top, paths on paths). The smaller face's part moves out by 0.04
--     studs (or grows by 0.04 on both sides if both of its faces on that axis are shared). Only anchored parts, never
--     characters, never same-color plain plastic (that can't flicker visibly).
local TownKit = require(script.Parent.TownKit)

local Fix = {}

local NUDGE = 0.04          -- studs: enough to stop z-fighting at any distance, too small to see
local PLANE_TOLERANCE = 0.025
local PLAIN = { [Enum.Material.SmoothPlastic] = true, [Enum.Material.Plastic] = true, [Enum.Material.Neon] = true }

------------------------------------------------------------------------
-- 1. Park ring path
------------------------------------------------------------------------
local function stoneEnds(stone)
	local axis = stone.CFrame.LookVector * stone.Size.Z / 2
	return stone.Position - axis, stone.Position + axis
end

local function parkRing(report)
	local town = workspace:FindFirstChild("Town")
	local park = town and town:FindFirstChild("Park")
	if not park then return table.insert(report, "park: not found") end
	if park:FindFirstChild("PathRing") then return table.insert(report, "park: ring already merged") end
	local ringModel, straights = nil, {}
	local center, color = nil, nil
	for _, model in ipairs(park:GetChildren()) do
		if model:IsA("Model") and model.Name == "Path" then
			local stones = {}
			for _, piece in ipairs(model:GetChildren()) do
				if piece.Name == "PathStone" then table.insert(stones, piece) end
			end
			if #stones > 10 then
				ringModel = model
				local sum = Vector3.zero
				for _, stone in ipairs(stones) do sum += stone.Position end
				center = sum / #stones
				color = stones[1].Color
			end
		end
	end
	if not ringModel then return table.insert(report, "park: ring path not found") end
	local radius, slabs = 0, 0
	for _, piece in ipairs(ringModel:GetChildren()) do
		if piece.Name == "PathStone" then
			radius += Vector2.new(piece.Position.X - center.X, piece.Position.Z - center.Z).Magnitude
			slabs += 1
		end
	end
	radius /= slabs
	local width = ringModel:FindFirstChild("PathStone").Size.X
	local outer = radius + width / 2
	for _, model in ipairs(park:GetChildren()) do
		if model ~= ringModel and model:IsA("Model") and model.Name == "Path" then
			for _, piece in ipairs(model:GetChildren()) do
				if piece.Name == "PathStone" then
					local a, b = stoneEnds(piece)
					local near = math.min(Vector2.new(a.X - center.X, a.Z - center.Z).Magnitude, Vector2.new(b.X - center.X, b.Z - center.Z).Magnitude)
					if near < outer then
						table.insert(straights, model)
						break
					end
				end
			end
		end
	end
	local part = TownKit.pathRing(park, Vector3.new(center.X, center.Y, center.Z), radius, width, color, straights)
	if part then
		ringModel:Destroy()
		table.insert(report, string.format("park: ring (%d slabs) + %d straight paths merged into one PathRing part", slabs, #straights))
	else
		table.insert(report, "park: CSG failed, ring left as it was")
	end
end

------------------------------------------------------------------------
-- 2. Umbrellas
------------------------------------------------------------------------
local function umbrellas(report)
	local count = 0
	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Model") and model.Name == "Umbrella" and model.Parent then
			local oldCanopy = nil
			for _, piece in ipairs(model:GetChildren()) do
				if piece.Name == "Canopy" and piece.ClassName == "Part" then oldCanopy = piece break end
			end
			local pole = model:FindFirstChild("Pole")
			if oldCanopy and pole then
				local colorA, colorB = oldCanopy.Color, nil
				for _, piece in ipairs(model:GetChildren()) do
					if piece.Name == "Canopy" and piece.Color ~= colorA then colorB = piece.Color break end
				end
				local scale = pole.Size.X / 6
				local new = TownKit.umbrella(model.Parent, model:GetPivot(), colorA, colorB or colorA)
				if math.abs(scale - 1) > 0.01 then new:ScaleTo(scale) end
				model:Destroy()
				count += 1
			end
		end
	end
	table.insert(report, "umbrellas: " .. count .. " canopies rebuilt as solid panels")
end

------------------------------------------------------------------------
-- 3. Path edges
------------------------------------------------------------------------
local function pathEdges(report)
	local count = 0
	for _, piece in ipairs(workspace:GetDescendants()) do
		if piece:IsA("BasePart") and piece.Name == "PathEdge" and piece.Size.Y < 0.35 then
			piece.Size = Vector3.new(piece.Size.X, 0.4, piece.Size.Z)
			piece.CFrame += piece.CFrame.UpVector * 0.04
			count += 1
		end
	end
	table.insert(report, "path edges raised: " .. count)
end

------------------------------------------------------------------------
-- 4. Coplanar faces everywhere
------------------------------------------------------------------------
local function candidates()
	local list = {}
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("Part") and part.Anchored and part.Transparency < 0.9
			and (part.Shape == Enum.PartType.Block or part.Shape == Enum.PartType.Cylinder) then
			local model = part:FindFirstAncestorWhichIsA("Model")
			if not (model and model:FindFirstChildOfClass("Humanoid")) then table.insert(list, part) end
		end
	end
	return list
end

-- the faces of a part: { part, axis (1..3), sign, normal, center, u, uh, v, vh, area }
local function facesOf(part)
	local cf, s = part.CFrame, part.Size
	local vectors = { cf.RightVector, cf.UpVector, cf.LookVector }
	local halves = { s.X / 2, s.Y / 2, s.Z / 2 }
	local faces = {}
	for axis = 1, 3 do
		-- a cylinder only has flat faces at the ends of its axis (X); its round side never z-fights a flat face
		if part.Shape ~= Enum.PartType.Cylinder or axis == 1 then
			local o1, o2 = axis % 3 + 1, (axis + 1) % 3 + 1
			local uh, vh = halves[o1], halves[o2]
			if part.Shape == Enum.PartType.Cylinder then
				local r = math.min(uh, vh) * 0.85 -- the disc as a slightly smaller square
				uh, vh = r, r
			end
			for _, sign in ipairs({ 1, -1 }) do
				local normal = vectors[axis] * sign
				table.insert(faces, {
					part = part, axis = axis, sign = sign, normal = normal,
					center = cf.Position + normal * halves[axis],
					u = vectors[o1], uh = uh, v = vectors[o2], vh = vh, area = uh * vh * 4,
				})
			end
		end
	end
	return faces
end

local function overlapping(a, b)
	for _, axis in ipairs({ a.u, a.v, b.u, b.v }) do
		local function range(face)
			local c = face.center:Dot(axis)
			local r = math.abs(face.u:Dot(axis)) * face.uh + math.abs(face.v:Dot(axis)) * face.vh
			return c - r, c + r
		end
		local a1, a2 = range(a)
		local b1, b2 = range(b)
		if math.min(a2, b2) - math.max(a1, b1) < 0.05 then return false end
	end
	return true
end

local function scan()
	local buckets = {}
	local function q(x, step) return math.floor(x / step + 0.5) end
	for _, part in ipairs(candidates()) do
		for _, face in ipairs(facesOf(part)) do
			local n = face.normal
			local dist = n:Dot(face.center)
			face.dist = dist
			local key = q(n.X, 0.02) .. "," .. q(n.Y, 0.02) .. "," .. q(n.Z, 0.02)
			local slot = math.floor(dist / PLANE_TOLERANCE)
			buckets[key] = buckets[key] or {}
			buckets[key][slot] = buckets[key][slot] or {}
			table.insert(buckets[key][slot], face)
		end
	end
	local found = {}
	for _, slots in pairs(buckets) do
		for slot, list in pairs(slots) do
			local nextList = slots[slot + 1] or {}
			local function check(a, b)
				if a.part == b.part or math.abs(a.dist - b.dist) > PLANE_TOLERANCE then return end
				local pa, pb = a.part, b.part
				if pa.Color == pb.Color and pa.Material == pb.Material and PLAIN[pa.Material] then return end
				if overlapping(a, b) then table.insert(found, { a, b }) end
			end
			if #list < 800 then
				for i = 1, #list do
					for j = i + 1, #list do check(list[i], list[j]) end
					for _, other in ipairs(nextList) do check(list[i], other) end
				end
			end
		end
	end
	return found
end

local function nudge(found)
	-- [part] = { [axis] = { [sign] = true } }: which faces of which part move out
	local moves = {}
	for _, pair in ipairs(found) do
		local a, b = pair[1], pair[2]
		local mover = (a.area < b.area or (a.area == b.area and a.part.Size.Magnitude < b.part.Size.Magnitude)) and a or b
		moves[mover.part] = moves[mover.part] or {}
		moves[mover.part][mover.axis] = moves[mover.part][mover.axis] or {}
		moves[mover.part][mover.axis][mover.sign] = true
	end
	local count = 0
	for part, axes in pairs(moves) do
		local cf, size = part.CFrame, part.Size
		local vectors = { cf.RightVector, cf.UpVector, cf.LookVector }
		local offset = Vector3.zero
		local grow = { 0, 0, 0 }
		for axis, signs in pairs(axes) do
			if signs[1] and signs[-1] then
				grow[axis] = NUDGE * 2
			else
				offset += vectors[axis] * NUDGE * (signs[1] and 1 or -1)
			end
		end
		part.Size = size + Vector3.new(grow[1], grow[2], grow[3])
		part.CFrame = cf + offset
		count += 1
	end
	return count
end

local function describe(found)
	local groups = {}
	for _, pair in ipairs(found) do
		local key = pair[1].part.Parent:GetFullName()
		groups[key] = (groups[key] or 0) + 1
	end
	local list = {}
	for key, n in pairs(groups) do table.insert(list, { key, n }) end
	table.sort(list, function(x, y) return x[2] > y[2] end)
	return list
end

local function coplanar(report)
	local first = scan()
	local top = describe(first)
	table.insert(report, string.format("coplanar faces found: %d pairs in %d groups", #first, #top))
	for i = 1, math.min(#top, 40) do table.insert(report, string.format("  %4d  %s", top[i][2], top[i][1])) end
	local found, moved = first, 0
	for pass = 1, 4 do
		if #found == 0 then break end
		moved += nudge(found)
		found = scan()
		table.insert(report, string.format("pass %d: %d pairs left", pass, #found))
	end
	table.insert(report, "parts nudged: " .. moved)
	for _, entry in ipairs(describe(found)) do table.insert(report, "  left: " .. entry[2] .. "  " .. entry[1]) end
end

function Fix.Run()
	local report = {}
	parkRing(report)
	umbrellas(report)
	pathEdges(report)
	coplanar(report)
	return table.concat(report, "\n")
end

-- only the scan (nothing changes)
function Fix.Scan()
	return describe(scan())
end

-- the pairs left under one model/folder (by full name prefix), e.g. Fix.Detail("Workspace.Town.Plaza")
function Fix.Detail(prefix)
	local out = {}
	for _, pair in ipairs(scan()) do
		local a, b = pair[1].part, pair[2].part
		if a:GetFullName():sub(1, #prefix) == prefix then
			table.insert(out, string.format("%s / %s  gap %.3f  (%s)", a.Name, b.Name, math.abs(pair[1].dist - pair[2].dist), b.Parent.Name))
		end
	end
	return out
end

return Fix
