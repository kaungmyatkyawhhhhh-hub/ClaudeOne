-- Converts muscle_v8/ (growdata JSON: base, max, tris, the clothing-template UVs and, when present, nbase / nmax normals,
-- vein offsets and the border "blend" weights) into ModuleScripts under
-- src/ReplicatedStorage/MuscleData (strings of comma separated numbers, chunked so no script is huge) plus an Index module
-- (meshes, body part sizes, the per-mesh mass monster g), the snatched torso modules and the waist morph.
-- Run from the repo root:  lune run tools/gen_muscle_data
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local SRC = "muscle_v8"
local OUT = "src/ReplicatedStorage/MuscleData"
local CHUNK = 90000

if fs.isDir(OUT) then fs.removeDir(OUT) end
fs.writeDir(OUT)

local manifest = serde.decode("json", fs.readFile(SRC .. "/manifest.json"))

local function join(list, decimals)
	local parts = table.create(#list)
	for i, v in ipairs(list) do
		if decimals then
			local text = string.format("%." .. decimals .. "f", v)
			text = string.gsub(text, "(%..-)0+$", "%1")
			text = string.gsub(text, "%.$", "")
			if text == "-0" then text = "0" end
			parts[i] = text
		else
			parts[i] = tostring(v)
		end
	end
	return parts
end

local function chunks(parts)
	local out, current, size = {}, {}, 0
	for _, text in ipairs(parts) do
		if size + #text + 1 > CHUNK and #current > 0 then
			table.insert(out, table.concat(current, ","))
			current, size = {}, 0
		end
		table.insert(current, text)
		size += #text + 1
	end
	if #current > 0 then table.insert(out, table.concat(current, ",")) end
	return out
end

-- UpperTorso: the muscles and the snatched torso under them (worked out once here, so the game does no geometry):
--   * every torso muscle vertex gets a "morph" offset: where the torso surface under it moves between the snatched max
--     and the wide level-0 start (the waist morph), so the muscle shell rides the torso and never sinks into it; the
--     package's own "morph_off" (muscle_v8 growdata, PROMPT.md "jagged dark holes" update) when it has one, else worked
--     out here from the torso under the vertex;
--   * every torso vertex under a muscle gets a "push" (studs, along its normal, inward) so the torso stays at least
--     TORSO_GAP under the shells (no z-fighting); its open edges (waist seam, neck, armholes) don't move;
--   * every torso vertex gets an "owner": the nearest muscle vertex over it ("Mesh:index"), so it takes that muscle's tint.
local SKIN_LIFT, TORSO_GAP, OWNER_REACH = 0.02, 0.05, 0.3
local torsoMorph = serde.decode("json", fs.readFile(SRC .. "/body/torso_waist_morph.json")).UpperTorso
local torso = { max = {}, start = {}, tris = torsoMorph.tris, normals = {} }
for i = 1, #torsoMorph.max // 3 do
	torso.max[i] = vector.create(torsoMorph.max[i * 3 - 2], torsoMorph.max[i * 3 - 1], torsoMorph.max[i * 3])
	torso.start[i] = vector.create(torsoMorph.start[i * 3 - 2], torsoMorph.start[i * 3 - 1], torsoMorph.start[i * 3])
end
do
	local vns = {}
	for line in string.gmatch(fs.readFile(SRC .. "/body/Body_UpperTorso_Snatched.obj"), "[^\r\n]+") do
		if string.sub(line, 1, 3) == "vn " then
			local x, y, z = string.match(line, "vn%s+(%S+)%s+(%S+)%s+(%S+)")
			table.insert(vns, vector.normalize(vector.create(tonumber(x), tonumber(y), tonumber(z))))
		end
	end
	torso.normals = vns
end
-- Split every torso triangle into four (edge midpoints): the same flat shape, about 4x the vertices, so the torso can be
-- pushed under the shells and tinted per muscle at a useful resolution.
do
	local mid = {}
	local max, start, normals = torso.max, torso.start, torso.normals
	local function midpoint(a, b)
		local key = math.min(a, b) * 65536 + math.max(a, b)
		if mid[key] then return mid[key] end
		table.insert(max, (max[a] + max[b]) / 2)
		table.insert(start, (start[a] + start[b]) / 2)
		table.insert(normals, vector.normalize(normals[a] + normals[b]))
		mid[key] = #max
		return #max
	end
	local out = {}
	local tris = torso.tris
	for k = 1, #tris, 3 do
		local a, b, c = tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1
		local ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
		for _, t in ipairs({ { a, ab, ca }, { ab, b, bc }, { ca, bc, c }, { ab, bc, ca } }) do
			for _, v in ipairs(t) do table.insert(out, v - 1) end
		end
	end
	torso.tris = out
end
local torsoNeed = table.create(#torso.max, 0)     -- under the front muscles (built with the torso, always there)
local torsoNeedBack = table.create(#torso.max, 0) -- under the back muscles (only while they are built)
local FRONT = { MidChest = true, UpperChest = true, Abs = true, Obliques = true }
local torsoOwner = {} -- [vertex] = { name, index, distance }
local muscleMorph = {} -- [mesh name] = { offsets (vector) }
local skinStats = {}
local muscleSkin = {}
-- the closest point on the torso's max surface to p (Ericson, Real-Time Collision Detection 5.1.5): point, normal there
local function closestOnTorso(p)
	local best, bestD, bestN = nil, math.huge, nil
	local tris, verts, normals = torso.tris, torso.max, torso.normals
	for k = 1, #tris, 3 do
		local ia, ib, ic = tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1
		local a, b, c = verts[ia], verts[ib], verts[ic]
		local ab, ac, ap = b - a, c - a, p - a
		local d1, d2 = vector.dot(ab, ap), vector.dot(ac, ap)
		local wa, wb, wc
		if d1 <= 0 and d2 <= 0 then
			wa, wb, wc = 1, 0, 0
		else
			local bp = p - b
			local d3, d4 = vector.dot(ab, bp), vector.dot(ac, bp)
			local cp = p - c
			local d5, d6 = vector.dot(ab, cp), vector.dot(ac, cp)
			local vc, vb, va = d1 * d4 - d3 * d2, d5 * d2 - d1 * d6, d3 * d6 - d5 * d4
			if d3 >= 0 and d4 <= d3 then
				wa, wb, wc = 0, 1, 0
			elseif d6 >= 0 and d5 <= d6 then
				wa, wb, wc = 0, 0, 1
			elseif vc <= 0 and d1 >= 0 and d3 <= 0 then
				local t = d1 / (d1 - d3)
				wa, wb, wc = 1 - t, t, 0
			elseif vb <= 0 and d2 >= 0 and d6 <= 0 then
				local t = d2 / (d2 - d6)
				wa, wb, wc = 1 - t, 0, t
			elseif va <= 0 and (d4 - d3) >= 0 and (d5 - d6) >= 0 then
				local t = (d4 - d3) / ((d4 - d3) + (d5 - d6))
				wa, wb, wc = 0, 1 - t, t
			else
				local denom = 1 / (va + vb + vc)
				wb, wc = vb * denom, vc * denom
				wa = 1 - wb - wc
			end
		end
		local q = a * wa + b * wb + c * wc
		local d = vector.magnitude(p - q)
		if d < bestD then
			best, bestD = q, d
			bestN = vector.normalize(normals[ia] * wa + normals[ib] * wb + normals[ic] * wc)
		end
	end
	return best, bestN, bestD
end  -- [mesh name] = { { torso point - base vertex, torso normal } }: the skin edge snaps onto it
-- a ray (origin o, direction d) against the torso's max surface: t, triangle (1-based first index), u, v
local function castTorso(o, d)
	local bestT, bestK, bestU, bestV = nil, nil, nil, nil
	local tris, verts = torso.tris, torso.max
	for k = 1, #tris, 3 do
		local a, b, c = verts[tris[k] + 1], verts[tris[k + 1] + 1], verts[tris[k + 2] + 1]
		local e1, e2 = b - a, c - a
		local h = vector.cross(d, e2)
		local det = vector.dot(e1, h)
		if math.abs(det) > 1e-9 then
			local inv = 1 / det
			local s = o - a
			local u = inv * vector.dot(s, h)
			if u >= 0 and u <= 1 then
				local q = vector.cross(s, e1)
				local v = inv * vector.dot(d, q)
				if v >= 0 and u + v <= 1 then
					local t = inv * vector.dot(e2, q)
					if t > 0 and t < 1.2 and (not bestT or math.abs(t - 0.6) < math.abs(bestT - 0.6)) then
						bestT, bestK, bestU, bestV = t, k, u, v
					end
				end
			end
		end
	end
	return bestT, bestK, bestU, bestV
end
-- the torso's open-edge vertices (an edge used by one triangle): they never move
local torsoEdge = {}
do
	local count = {}
	local tris = torso.tris
	for k = 1, #tris, 3 do
		local corners = { tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1 }
		for e = 1, 3 do
			local a, b = corners[e], corners[e % 3 + 1]
			local key = math.min(a, b) .. "_" .. math.max(a, b)
			count[key] = (count[key] or 0) + 1
		end
	end
	for key, n in pairs(count) do
		if n == 1 then
			local a, b = string.match(key, "(%d+)_(%d+)")
			torsoEdge[tonumber(a)], torsoEdge[tonumber(b)] = true, true
		end
	end
end
for _, entry in ipairs(manifest.meshes) do
	if entry.part == "UpperTorso" then
		local name = string.gsub(entry.file, "%.obj$", "")
		local data = serde.decode("json", fs.readFile(SRC .. "/growdata/" .. name .. ".json"))
		local offsets = {}
		local skins = {}
		-- the skin edge: open-edge vertices that don't blend into a neighbour (seams between muscles are not skin edges), and the
		-- three rows in from them (0-3); the game snaps them onto the torso (MuscleMeshes.EdgeSnap), so the torso doesn't move for
		-- rows 0-1 (they lie on it); rows 2-3, mostly the shell's own, still push it down
		local edgeRow = {}
		do
			local blendSum = {}
			for _, list in pairs(data.blend or {}) do
				for _, pair in ipairs(list) do blendSum[pair[1] + 1] = (blendSum[pair[1] + 1] or 0) + pair[2] end
			end
			local use, adjacent = {}, {}
			local t = data.tris
			for k = 1, #t, 3 do
				local corners = { t[k] + 1, t[k + 1] + 1, t[k + 2] + 1 }
				for c = 1, 3 do
					local a, b = corners[c], corners[c % 3 + 1]
					adjacent[a] = adjacent[a] or {}
					table.insert(adjacent[a], b)
					local key = math.min(a, b) * 65536 + math.max(a, b)
					use[key] = (use[key] or 0) + 1
				end
			end
			for key, n in pairs(use) do
				if n == 1 then
					for _, v in ipairs({ key // 65536, key % 65536 }) do
						if (blendSum[v] or 0) < 0.2 then edgeRow[v] = 0 end
					end
				end
			end
			local frontier = {}
			for v in pairs(edgeRow) do table.insert(frontier, v) end
			for row = 1, 3 do
				local nextFrontier = {}
				for _, v in ipairs(frontier) do
					for _, w in ipairs(adjacent[v] or {}) do
						if edgeRow[w] == nil and (blendSum[w] or 0) < 0.2 then
							edgeRow[w] = row
							table.insert(nextFrontier, w)
						end
					end
				end
				frontier = nextFrontier
			end
		end
		for i = 1, #data.base // 3 do
			local p = vector.create(data.base[i * 3 - 2], data.base[i * 3 - 1], data.base[i * 3])
			local n = vector.normalize(vector.create(data.nbase[i * 3 - 2], data.nbase[i * 3 - 1], data.nbase[i * 3]))
			local shell = p + n * SKIN_LIFT
			-- the torso surface under the shell, along the muscle's normal
			local t, k, u, v = castTorso(shell + n * 0.6, -n)
			local offset = vector.zero
			local skinAt, skinNormal = vector.zero, n
			if t then
				local tris = torso.tris
				local ia, ib, ic = tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1
				local w0 = 1 - u - v
				local onMax = torso.max[ia] * w0 + torso.max[ib] * u + torso.max[ic] * v
				local onStart = torso.start[ia] * w0 + torso.start[ib] * u + torso.start[ic] * v
				offset = onStart - onMax

				local height = vector.dot(shell - onMax, n) -- the shell above the torso (negative = inside it)
				if height < TORSO_GAP and (edgeRow[i] == nil or edgeRow[i] >= 2) then
					local need = TORSO_GAP - height
					local needs = if FRONT[string.match(name, "__(.+)$")] then torsoNeed else torsoNeedBack
					for _, idx in ipairs({ ia, ib, ic }) do needs[idx] = math.max(needs[idx], need) end
				end
			end
			-- the package's offset (muscle_v8 "morph_off", same order as base) wins over the one worked out here
			local mo = data.morph_off
			if mo then offset = vector.create(mo[i * 3 - 2], mo[i * 3 - 1], mo[i * 3]) end
			offsets[i] = offset
			if edgeRow[i] then
				local q, qn, d = closestOnTorso(p)
				-- only where the torso is under the edge (an edge hanging past the torso, like the traps over the shoulder, has
				-- its closest torso point off to the side: it stays as it is)
				local under = d < 0.02 or vector.dot((q - p) / d, -n) > 0.6
				if under then skinAt, skinNormal = q - p, qn end
				skinStats[edgeRow[i]] = skinStats[edgeRow[i]] or {}
				table.insert(skinStats[edgeRow[i]], d)
			end
			skins[i] = { skinAt, skinNormal }
		end
		muscleMorph[name] = offsets
		muscleSkin[name] = skins
		-- owners: each torso vertex looks out along its normal; the muscle shell it meets first (within OWNER_REACH) owns it,
		-- with the hit triangle's nearest corner (for its tint band)
		local shellPos = {}
		for i = 1, #data.base // 3 do
			local p = vector.create(data.base[i * 3 - 2], data.base[i * 3 - 1], data.base[i * 3])
			local n = vector.normalize(vector.create(data.nbase[i * 3 - 2], data.nbase[i * 3 - 1], data.nbase[i * 3]))
			shellPos[i] = p + n * SKIN_LIFT
		end
		local lo, hi = vector.create(math.huge, math.huge, math.huge), vector.create(-math.huge, -math.huge, -math.huge)
		for _, p in ipairs(shellPos) do lo, hi = vector.min(lo, p), vector.max(hi, p) end
		local pad = vector.create(OWNER_REACH, OWNER_REACH, OWNER_REACH)
		lo, hi = lo - pad, hi + pad
		local mt = data.tris
		for j = 1, #torso.max do
			local o = torso.max[j]
			if o.x >= lo.x and o.y >= lo.y and o.z >= lo.z and o.x <= hi.x and o.y <= hi.y and o.z <= hi.z then
				local d = torso.normals[j]
				local origin = o - d * OWNER_REACH
				for k = 1, #mt, 3 do
					local ia, ib, ic = mt[k] + 1, mt[k + 1] + 1, mt[k + 2] + 1
					local a, b, c = shellPos[ia], shellPos[ib], shellPos[ic]
					local e1, e2 = b - a, c - a
					local h = vector.cross(d, e2)
					local det = vector.dot(e1, h)
					if math.abs(det) > 1e-9 then
						local inv = 1 / det
						local s = origin - a
						local u = inv * vector.dot(s, h)
						if u >= 0 and u <= 1 then
							local q = vector.cross(s, e1)
							local v = inv * vector.dot(d, q)
							if v >= 0 and u + v <= 1 then
								local t = inv * vector.dot(e2, q)
								local dist = math.abs(t - OWNER_REACH)
								if t > 0 and t < OWNER_REACH * 2 and (not torsoOwner[j] or dist < torsoOwner[j][3]) then
									local w0 = 1 - u - v
									local corner = if w0 >= u and w0 >= v then ia elseif u >= v then ib else ic
									torsoOwner[j] = { name, corner - 1, dist }
								end
							end
						end
					end
				end
			end
		end
	end
end
for row = 0, 3 do
	local list = skinStats[row] or {}
	table.sort(list)
	local far = 0
	for _, d in ipairs(list) do if d >= 0.2 then far += 1 end end
	if #list > 0 then
		print(string.format("edge row %d: %d verts, median %.3f, p90 %.3f, max %.3f, beyond reach %d", row, #list,
			list[#list // 2 + 1], list[math.ceil(#list * 0.9)], list[#list], far))
	end
end
local torsoPush, torsoPushBack = table.create(#torso.max, 0), table.create(#torso.max, 0)
for j = 1, #torso.max do
	if not torsoEdge[j] then
		torsoPush[j] = math.min(torsoNeed[j], 0.25)
		torsoPushBack[j] = math.min(torsoNeedBack[j], 0.25)
	end
end

local index = { meshes = {}, parts = manifest.parts }
local totalBytes = 0
for _, entry in ipairs(manifest.meshes) do
	local name = string.gsub(entry.file, "%.obj$", "")
	local data = serde.decode("json", fs.readFile(SRC .. "/growdata/" .. name .. ".json"))
	local uv = data.uv -- one u,v per vertex on the classic 585x559 clothing template
	assert(#uv / 2 == #data.base / 3, name .. ": uv count does not match vertex count")
	local fields = { base = join(data.base, 4), max = join(data.max, 4), tris = join(data.tris), uv = join(uv, 4) }
	-- smooth, no seams (muscle_v8 updates): per-vertex normals for base / max, the vein offsets, and "blend" = how much a
	-- border vertex (0-based) follows a neighbouring muscle's growth, as "Name:vertex,weight,vertex,weight|Name2:..."
	local extra = {}
	if data.nbase and data.nmax then
		fields.nbase, fields.nmax = join(data.nbase, 3), join(data.nmax, 3)
		table.insert(extra, "nbase")
		table.insert(extra, "nmax")
	end
	if data.vein then
		fields.vein = join(data.vein, 4)
		table.insert(extra, "vein")
	end
	if muscleMorph[name] then
		local flat = {}
		for _, offset in ipairs(muscleMorph[name]) do
			table.insert(flat, offset.x)
			table.insert(flat, offset.y)
			table.insert(flat, offset.z)
		end
		fields.morph = join(flat, 4)
		table.insert(extra, "morph")
		local skin = {}
		for _, entry in ipairs(muscleSkin[name]) do
			for _, value in ipairs({ entry[1].x, entry[1].y, entry[1].z, entry[2].x, entry[2].y, entry[2].z }) do table.insert(skin, value) end
		end
		fields.skin = join(skin, 4)
		table.insert(extra, "skin")
	end
	if data.blend and next(data.blend) then
		local parts = {}
		local others = {}
		for other, list in pairs(data.blend) do
			if #list > 0 then table.insert(others, other) end
		end
		table.sort(others)
		for _, other in ipairs(others) do
			local flat = {}
			for _, pair in ipairs(data.blend[other]) do
				table.insert(flat, tostring(pair[1]))
				table.insert(flat, (join({ pair[2] }, 3))[1])
			end
			table.insert(parts, other .. ":" .. table.concat(flat, ","))
		end
		if #parts > 0 then
			fields.blend = chunks({ table.concat(parts, "|") })
			table.insert(extra, "blend")
		end
	end
	local record = { name = name, part = entry.part, muscle = entry.muscle, shorts = entry.shorts or string.find(name, "_Shorts$") ~= nil, clothing = entry.clothing_template or "Shirt", verts = #data.base / 3, chunks = {} }
	local fieldNames = { "base", "max", "tris", "uv" }
	for _, field in ipairs(extra) do table.insert(fieldNames, field) end
	for _, field in ipairs(fieldNames) do
		local list = if field == "blend" then fields.blend else chunks(fields[field])
		record.chunks[field] = #list
		for k, text in ipairs(list) do
			local source = "return \"" .. text .. "\"\n"
			fs.writeFile(OUT .. "/" .. name .. "__" .. field .. k .. ".luau", source)
			totalBytes += #source
		end
	end
	table.insert(index.meshes, record)
end

-- the Index module: the list of meshes and how many chunk modules each field has, plus the body part reference sizes
local lines = { "-- GENERATED by tools/gen_muscle_data.luau from muscle_v8/: do not edit by hand.", "return {" }
table.insert(lines, "\tparts = {")
for part, info in pairs(index.parts) do
	table.insert(lines, string.format("\t\t%s = { size = Vector3.new(%s, %s, %s) },", part, tostring(info.size[1]), tostring(info.size[2]), tostring(info.size[3])))
end
table.insert(lines, "\t},")
table.insert(lines, "\tmeshes = {")
for _, r in ipairs(index.meshes) do
	local chunkList = {}
	for _, field in ipairs({ "base", "max", "tris", "uv", "nbase", "nmax", "vein", "blend", "morph", "skin" }) do
		if r.chunks[field] then table.insert(chunkList, field .. " = " .. r.chunks[field]) end
	end
	table.insert(lines, string.format("\t\t{ name = %q, part = %q, muscle = %q, shorts = %s, clothing = %q, verts = %d, chunks = { %s } },",
		r.name, r.part, r.muscle, tostring(r.shorts), r.clothing, r.verts, table.concat(chunkList, ", ")))
end
table.insert(lines, "\t},")
-- the mass monster size of each mesh's muscle (manifest mass_monster.g, by the mesh's own name: DeltCap, UpperTraps too)
table.insert(lines, "\tmonsterG = {")
local monsterNames = {}
for name in pairs(manifest.mass_monster.g) do table.insert(monsterNames, name) end
table.sort(monsterNames)
for _, name in ipairs(monsterNames) do table.insert(lines, string.format("\t\t%s = %s,", name, tostring(manifest.mass_monster.g[name]))) end
table.insert(lines, "\t},")
table.insert(lines, string.format("\tmonsterDefaultG = %s,", tostring(manifest.mass_monster.default_g)))
table.insert(lines, "}")
fs.writeFile(OUT .. "/Index.luau", table.concat(lines, "\n") .. "\n")
print(string.format("wrote %d mesh records, %.2f MB of data modules", #index.meshes, totalBytes / 1048576))

-- the snatched-waist torso meshes (body/*.obj): one module each, { verts = {x,y,z,...}, uv = {u,v,...}, tris = {0-based},
-- normals = {x,y,z,...} (the OBJ's vn, one per vertex) }
-- clothing-template UVs for a snatched torso part (the box projection of muscle_v8/source/uvmap.py: TORSO rects, BANDS
-- UpperTorso 0-0.8, LowerTorso 0.8-1), from its positions and normals
local function clothingUVs(part, verts, normals)
	local uvs = {}
	local TW, TH = 585, 559
	local rects = { F = { 231, 74, 128, 128 }, B = { 427, 74, 128, 128 }, R = { 165, 74, 64, 128 }, L = { 361, 74, 64, 128 }, U = { 231, 8, 128, 64 } }
	local b0, b1 = 0.0, 0.8
	if part == "LowerTorso" then b0, b1 = 0.8, 1.0 end
	local size = manifest.parts[part].size
	local W, H, D = size[1], size[2], size[3]
	for i = 1, #verts / 3 do
		local x, y, z = verts[i * 3 - 2], verts[i * 3 - 1], verts[i * 3]
		local dx, dy, dz = normals[i * 3 - 2], normals[i * 3 - 1], normals[i * 3]
		local fy = math.clamp(0.5 - y / H, 0, 1)
		local vv = b0 + (b1 - b0) * fy
		local ax = if math.abs(dx) >= math.abs(dy) and math.abs(dx) >= math.abs(dz) then 0 elseif math.abs(dy) >= math.abs(dz) then 1 else 2
		local r, u, v
		if ax == 1 and dy > 0 and fy < 0.12 then
			r, u, v = rects.U, 0.5 - x / W, 0.5 + z / D
		elseif ax == 0 then
			if dx > 0 then r, u = rects.R, 0.5 + z / D else r, u = rects.L, 0.5 - z / D end
			v = vv
		else
			if dz < 0 then r, u = rects.F, 0.5 - x / W else r, u = rects.B, 0.5 + x / W end
			v = vv
		end
		u, v = math.clamp(u, 0.01, 0.99), math.clamp(v, 0.01, 0.99)
		uvs[i * 2 - 1] = (r[1] + u * r[3]) / TW
		uvs[i * 2] = (r[2] + v * r[4]) / TH
	end
	return uvs
end

for _, part in ipairs({ "UpperTorso", "LowerTorso" }) do
	local verts, uvs, tris, vns = {}, {}, {}, {}
	for line in string.gmatch(fs.readFile(SRC .. "/body/Body_" .. part .. "_Snatched.obj"), "[^\r\n]+") do
		local kind = string.match(line, "^(%S+)")
		if kind == "v" then
			for n in string.gmatch(string.sub(line, 3), "%S+") do table.insert(verts, tonumber(n)) end
		elseif kind == "vn" then
			for n in string.gmatch(string.sub(line, 4), "%S+") do table.insert(vns, tonumber(n)) end
		elseif kind == "vt" then
			local u, v = string.match(line, "vt%s+(%S+)%s+(%S+)")
			table.insert(uvs, tonumber(u))
			table.insert(uvs, tonumber(v))
		elseif kind == "f" then
			local corners = {}
			for corner in string.gmatch(string.sub(line, 3), "%S+") do
				table.insert(corners, tonumber(string.match(corner, "^(%d+)")) - 1)
			end
			for k = 2, #corners - 1 do
				table.insert(tris, corners[1])
				table.insert(tris, corners[k])
				table.insert(tris, corners[k + 1])
			end
		end
	end
	assert(#uvs / 2 == #verts / 3, part .. " snatched: uv count does not match vertex count")
	-- the snatched OBJs come without real UVs (all 0): give them clothing-template UVs with the same box projection the
	-- package uses for the muscles (muscle_v8/source/uvmap.py: TORSO rects, BANDS UpperTorso 0-0.8, LowerTorso 0.8-1)
	local allZero = true
	for _, value in ipairs(uvs) do if value ~= 0 then allZero = false break end end
	if allZero then
		uvs = clothingUVs(part, verts, vns)
	end
	-- the waist that tightens (body/torso_waist_morph.json): "start" (level 0, a wide straight waist) and "max" (the snatched
	-- V) per vertex, same order as the OBJ
	local morph = serde.decode("json", fs.readFile(SRC .. "/body/torso_waist_morph.json"))[part]
	local startList = nil
	if morph and morph.start and #morph.start == #verts then
		startList = morph.start
		-- (the morph's max is the newest snatched shape: it replaces the OBJ's positions; same vertices and triangles, so the
		-- OBJ's normals and the UVs made above still fit)
		assert(#morph.tris == #tris, part .. " waist morph: its triangles do not match the snatched OBJ")
		for i, value in ipairs(morph.tris) do assert(value == tris[i], part .. " waist morph: triangle order differs") end
		for i, value in ipairs(morph.max) do verts[i] = value end
	end
	if part == "UpperTorso" then
		-- the subdivided torso (same shape, more vertices): positions, normals, triangles, the start shape; UVs again below
		verts, vns, tris, startList, uvs = {}, {}, {}, {}, {}
		for i, p in ipairs(torso.max) do
			table.insert(verts, p.x) table.insert(verts, p.y) table.insert(verts, p.z)
			local n = torso.normals[i]
			table.insert(vns, n.x) table.insert(vns, n.y) table.insert(vns, n.z)
			local s = torso.start[i]
			table.insert(startList, s.x) table.insert(startList, s.y) table.insert(startList, s.z)
		end
		for _, t in ipairs(torso.tris) do table.insert(tris, t) end
		uvs = clothingUVs(part, verts, vns)
	end
	local source = "-- GENERATED by tools/gen_muscle_data.luau from " .. SRC .. "/body: the snatched-waist " .. part .. ".\nreturn {\n"
		.. "\tverts = { " .. table.concat(join(verts, 4), ", ") .. " },\n"
		.. "\tuv = { " .. table.concat(join(uvs, 4), ", ") .. " },\n"
		.. "\ttris = { " .. table.concat(join(tris), ", ") .. " },\n"
		.. (if #vns == #verts then "\tnormals = { " .. table.concat(join(vns, 4), ", ") .. " },\n" else "")
		.. (if startList then "\tstart = { " .. table.concat(join(startList, 4), ", ") .. " },\n" else "")
		.. (if part == "UpperTorso" then "\tpush = { " .. table.concat(join(torsoPush, 4), ", ") .. " },\n" else "")
		.. (if part == "UpperTorso" then "\tpushBack = { " .. table.concat(join(torsoPushBack, 4), ", ") .. " },\n" else "")
		.. (if part == "UpperTorso" then (function()
			local owners = {}
			for j = 1, #torsoPush do owners[j] = if torsoOwner[j] then string.format("%q", torsoOwner[j][1] .. ":" .. torsoOwner[j][2]) else '""' end
			return "\towner = { " .. table.concat(owners, ", ") .. " },\n"
		end)() else "")
		.. "}\n"
	fs.writeFile(OUT .. "/Snatched" .. part .. ".luau", source)
end
print("wrote the snatched torso modules")

-- Config/MuscleBulge: how far each muscle sticks out from the skin at its full aesthetic look (g = 1), in studs: the 95th
-- percentile of |max - base| over its meshes (the right side and the torso; the shorts meshes left out). The look balance cap
-- (Config/LookBalance) compares muscles in studs with it.
do
	local MESH_IDS = { UpperTraps = "Traps", DeltCap = "SideDelts" }
	local bulge = {}
	for _, file in fs.readDir(SRC .. "/growdata") do
		local part, key = string.match(file, "^(.-)__(.-)%.json$")
		if part and not string.find(key, "_Shorts$") and not string.find(part, "^Left") then
			local d = serde.decode("json", fs.readFile(SRC .. "/growdata/" .. file))
			local mags = {}
			for i = 1, #d.base / 3 do
				local dx, dy, dz = d.max[i * 3 - 2] - d.base[i * 3 - 2], d.max[i * 3 - 1] - d.base[i * 3 - 1], d.max[i * 3] - d.base[i * 3]
				table.insert(mags, math.sqrt(dx * dx + dy * dy + dz * dz))
			end
			table.sort(mags)
			local id = MESH_IDS[key] or key
			bulge[id] = math.max(bulge[id] or 0, mags[math.max(1, math.floor(#mags * 0.95))])
		end
	end
	local ids = {}
	for id in pairs(bulge) do table.insert(ids, id) end
	table.sort(ids)
	local out = { "-- GENERATED by tools/gen_muscle_data.luau from muscle_v8/growdata: do not edit by hand.",
		"-- Studs each muscle sticks out from the skin at its full aesthetic look (g = 1; p95 of max - base over its meshes).",
		"return {" }
	for _, id in ipairs(ids) do table.insert(out, string.format("\t%s = %.4f,", id, bulge[id])) end
	table.insert(out, "}")
	fs.writeFile("src/ReplicatedStorage/Shared/Config/MuscleBulge.luau", table.concat(out, "\n") .. "\n")
	print("wrote Config/MuscleBulge")
end
