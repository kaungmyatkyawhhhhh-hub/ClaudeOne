-- Converts muscle_v8/ (the muscle package; since 8 Oct the v9 "unified" package, whose folder is still called muscle_v8) into
-- ModuleScripts under src/ReplicatedStorage/MuscleData (strings of comma separated numbers, chunked so no script is huge)
-- plus an Index module (meshes, body part sizes, the per-mesh mass monster g), the snatched LowerTorso and its waist morph.
-- Two kinds of mesh:
--   * "unified" (format unified-v1: UpperTorso, RightUpperArm, LeftUpperArm): ONE welded mesh per body part, the whole skin
--     of the part. base (skin + 0.012), tris, uv, vein, morph_off (torso), and per muscle its vertex list (idx, 0-based) and
--     displacement at its full look (disp). In the game: pos = base + morph_off * (1 - waistT) + sum(g_m * disp_m) + vein * v.
--     The generator adds the normals (one welded mesh: area-weighted face normals): nbase at g = 0, and per muscle the change
--     of the normal at its full look alone (nidx / ndisp, only where it changes), so the game blends normals the same way.
--     It also CLOSES the meshes' top openings (the torso is open across its whole top, under the upper traps shell; the arms
--     have a pinhole at the shoulder): a fan of triangles from each top rim to a new centre vertex, so no view through a gap
--     ever shows the sky. (The rim's normals are worked out before the cap: its shading doesn't change.)
--   * "shell" (the legs, forearms, calves, the upper traps): base, max, tris, uv, nbase / nmax, vein, blend, morph_off.
-- Run from the repo root:  lune run tools/gen_muscle_data
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local SRC = "muscle_v8"
local DOME = 0.085 -- studs the torso cap's centre rises above its rim (to the Robloxian torso top, 0.919)
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

-- Area-weighted vertex normals of a welded mesh (positions = list of vectors, tris 0-based).
local function vertexNormals(positions, tris)
	local sums = table.create(#positions, vector.zero)
	for k = 1, #tris, 3 do
		local a, b, c = tris[k] + 1, tris[k + 1] + 1, tris[k + 2] + 1
		local n = vector.cross(positions[b] - positions[a], positions[c] - positions[a])
		sums[a] += n
		sums[b] += n
		sums[c] += n
	end
	for i, n in ipairs(sums) do
		sums[i] = if vector.magnitude(n) > 1e-12 then vector.normalize(n) else vector.create(0, 1, 0)
	end
	return sums
end

local index = { meshes = {}, parts = manifest.parts }
local totalBytes = 0

local function writeField(name, field, list)
	local pieces = chunks(list)
	for k, text in ipairs(pieces) do
		local source = "return \"" .. text .. "\"\n"
		fs.writeFile(OUT .. "/" .. name .. "__" .. field .. k .. ".luau", source)
		totalBytes += #source
	end
	return #pieces
end

-- Meshes in the package the game doesn't use: the upper traps shell was made for the old separate torso muscles; on the
-- unified torso (which grows the traps itself) it floated above the chest with a gap at higher levels (removed 8 Oct).
local SKIP = { UpperTorso__UpperTraps = true }

for _, entry in ipairs(manifest.meshes) do
	local name = string.gsub(entry.file, "%.obj$", "")
	if SKIP[name] then continue end
	local data = serde.decode("json", fs.readFile(SRC .. "/growdata/" .. name .. ".json"))
	local verts = #data.base // 3
	assert(#data.uv / 2 == verts, name .. ": uv count does not match vertex count")
	local record = {
		name = name, part = entry.part, clothing = entry.clothing_template or "Shirt", verts = verts, chunks = {},
		hidePart = entry.hide_part == true or entry.format == "unified-v1" or entry.muscle == "Calves",
	}
	if data.format == "unified-v1" then
		record.format = "unified"
		-- the caps: every open loop whose rim is above the part's centre gets a fan to its centre point (new vertex)
		local capTris, capCentres = {}, {}
		do
			local edgeUse, directed = {}, {}
			for k = 1, #data.tris, 3 do
				local c = { data.tris[k], data.tris[k + 1], data.tris[k + 2] }
				for e = 1, 3 do
					local a, b = c[e], c[e % 3 + 1]
					local key = math.min(a, b) * 65536 + math.max(a, b)
					edgeUse[key] = (edgeUse[key] or 0) + 1
					directed[key] = { a, b }
				end
			end
			local adjacent = {}
			for key, n in pairs(edgeUse) do
				if n == 1 then
					local a, b = directed[key][1], directed[key][2]
					adjacent[a] = adjacent[a] or {}
					adjacent[b] = adjacent[b] or {}
					table.insert(adjacent[a], key)
					table.insert(adjacent[b], key)
				end
			end
			local seen = {}
			for start in pairs(adjacent) do
				if not seen[start] then
					local loop, stack = {}, { start }
					seen[start] = true
					while #stack > 0 do
						local v = table.remove(stack)
						table.insert(loop, v)
						for _, key in ipairs(adjacent[v]) do
							for _, w in ipairs(directed[key]) do
								if not seen[w] then seen[w] = true table.insert(stack, w) end
							end
						end
					end
					local centre = vector.zero
					for _, v in ipairs(loop) do centre += vector.create(data.base[v * 3 + 1], data.base[v * 3 + 2], data.base[v * 3 + 3]) end
					centre /= #loop
					if centre.y > 0 then
						-- a wide opening (the torso's top) closes as a low dome up to the real torso top (the head sits on it,
						-- the shoulders slope down to the rim like a beginner's traps); a pinhole (the arms) just closes
						local top = -math.huge
						for _, v in ipairs(loop) do top = math.max(top, data.base[v * 3 + 2]) end
						local span = 0
						for _, v in ipairs(loop) do span = math.max(span, math.abs(data.base[v * 3 + 1] - centre.x)) end
						if span > 0.5 then centre = vector.create(centre.x, top + DOME, centre.z) end
						table.insert(capCentres, { loop = loop, centre = centre })
					end
				end
			end
			-- add the centre vertices (base, uv, vein, morph: the rim's average) and the fan triangles (each rim edge reversed)
			local count = verts
			for _, cap in ipairs(capCentres) do
				local inLoop = {}
				for _, v in ipairs(cap.loop) do inLoop[v] = true end
				local u, w, morph = 0, 0, vector.zero
				for _, v in ipairs(cap.loop) do
					u += data.uv[v * 2 + 1]
					w += data.uv[v * 2 + 2]
					if data.morph_off then morph += vector.create(data.morph_off[v * 3 + 1], data.morph_off[v * 3 + 2], data.morph_off[v * 3 + 3]) end
				end
				local n = #cap.loop
				table.insert(data.base, cap.centre.x)
				table.insert(data.base, cap.centre.y)
				table.insert(data.base, cap.centre.z)
				table.insert(data.uv, u / n)
				table.insert(data.uv, w / n)
				if data.vein then for _ = 1, 3 do table.insert(data.vein, 0) end end
				if data.morph_off then
					morph /= n
					table.insert(data.morph_off, morph.x)
					table.insert(data.morph_off, morph.y)
					table.insert(data.morph_off, morph.z)
				end
				local centre = count
				count += 1
				for key, used in pairs(edgeUse) do
					if used == 1 then
						local a, b = directed[key][1], directed[key][2]
						if inLoop[a] and inLoop[b] then
							table.insert(capTris, b)
							table.insert(capTris, a)
							table.insert(capTris, centre)
						end
					end
				end
				print(string.format("%s: capped a %d-vertex top opening at y %.2f", name, n, cap.centre.y))
			end
		end
		local surfaceTris = table.clone(data.tris) -- (the normals come from the surface without the caps)
		for _, v in ipairs(capTris) do table.insert(data.tris, v) end
		verts = #data.base // 3
		record.verts = verts
		record.chunks.base = writeField(name, "base", join(data.base, 4))
		record.chunks.tris = writeField(name, "tris", join(data.tris))
		record.chunks.uv = writeField(name, "uv", join(data.uv, 4))
		if data.vein then record.chunks.vein = writeField(name, "vein", join(data.vein, 4)) end
		if data.morph_off then record.chunks.morph = writeField(name, "morph", join(data.morph_off, 4)) end
		-- normals: at g = 0 (no waist morph: it moves the surface, it hardly turns it), and each muscle's change at its full look
		local base = table.create(verts)
		for i = 1, verts do base[i] = vector.create(data.base[i * 3 - 2], data.base[i * 3 - 1], data.base[i * 3]) end
		local nbase = vertexNormals(base, surfaceTris)
		for i = verts - #capCentres + 1, verts do nbase[i] = vector.create(0, 1, 0) end
		-- (outward: the normals must point away from the part's centre on average)
		local centre = vector.zero
		for _, p in ipairs(base) do centre += p end
		centre /= verts
		local outward = 0
		for i, p in ipairs(base) do outward += vector.dot(nbase[i], p - centre) end
		local flip = outward < 0
		if flip then
			for i, n in ipairs(nbase) do nbase[i] = -n end
			for k = 1, #data.tris, 3 do data.tris[k + 1], data.tris[k + 2] = data.tris[k + 2], data.tris[k + 1] end
			for k = 1, #surfaceTris, 3 do surfaceTris[k + 1], surfaceTris[k + 2] = surfaceTris[k + 2], surfaceTris[k + 1] end
			record.chunks.tris = writeField(name, "tris", join(data.tris))
			print(name .. ": triangles flipped to face outward")
		end
		local flat = table.create(verts * 3)
		for i, n in ipairs(nbase) do flat[i * 3 - 2], flat[i * 3 - 1], flat[i * 3] = n.x, n.y, n.z end
		record.chunks.nbase = writeField(name, "nbase", join(flat, 3))
		record.muscles = {}
		local muscleNames = {}
		for muscle in pairs(data.muscles) do table.insert(muscleNames, muscle) end
		table.sort(muscleNames)
		for _, muscle in ipairs(muscleNames) do
			local m = data.muscles[muscle]
			assert(#m.disp == #m.idx * 3, name .. " " .. muscle .. ": disp does not match idx")
			record.chunks["idx_" .. muscle] = writeField(name, "idx_" .. muscle, join(m.idx))
			record.chunks["disp_" .. muscle] = writeField(name, "disp_" .. muscle, join(m.disp, 4))
			-- the normals with only this muscle at its full look, compared with nbase
			local moved = table.clone(base)
			for j, v in ipairs(m.idx) do
				moved[v + 1] = base[v + 1] + vector.create(m.disp[j * 3 - 2], m.disp[j * 3 - 1], m.disp[j * 3])
			end
			local n1 = vertexNormals(moved, surfaceTris)
			for i = verts - #capCentres + 1, verts do n1[i] = vector.create(0, 1, 0) end
			local nidx, ndisp = {}, {}
			for i = 1, verts do
				local d = n1[i] - nbase[i]
				if vector.magnitude(d) > 0.002 then
					table.insert(nidx, i - 1)
					table.insert(ndisp, d.x)
					table.insert(ndisp, d.y)
					table.insert(ndisp, d.z)
				end
			end
			record.chunks["nidx_" .. muscle] = writeField(name, "nidx_" .. muscle, join(nidx))
			record.chunks["ndisp_" .. muscle] = writeField(name, "ndisp_" .. muscle, join(ndisp, 3))
			table.insert(record.muscles, muscle)
		end
		record.tris = #data.tris // 3
	else
		record.format = "shell"
		record.muscle = entry.muscle
		record.shorts = entry.shorts or string.find(name, "_Shorts$") ~= nil
		record.chunks.base = writeField(name, "base", join(data.base, 4))
		record.chunks.max = writeField(name, "max", join(data.max, 4))
		record.chunks.tris = writeField(name, "tris", join(data.tris))
		record.chunks.uv = writeField(name, "uv", join(data.uv, 4))
		if data.nbase and data.nmax then
			record.chunks.nbase = writeField(name, "nbase", join(data.nbase, 3))
			record.chunks.nmax = writeField(name, "nmax", join(data.nmax, 3))
		end
		if data.vein then record.chunks.vein = writeField(name, "vein", join(data.vein, 4)) end
		if data.morph_off then record.chunks.morph = writeField(name, "morph", join(data.morph_off, 4)) end
		-- border "blend": how much a border vertex (0-based) follows a neighbouring muscle mesh, "Name:vertex,weight,...|Name2:..."
		if data.blend and next(data.blend) then
			local parts, others = {}, {}
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
				local pieces = chunks({ table.concat(parts, "|") })
				for k, text in ipairs(pieces) do
					local source = "return \"" .. text .. "\"\n"
					fs.writeFile(OUT .. "/" .. name .. "__blend" .. k .. ".luau", source)
					totalBytes += #source
				end
				record.chunks.blend = #pieces
			end
		end
		record.tris = #data.tris // 3
	end
	table.insert(index.meshes, record)
end

-- the Index module: the list of meshes and how many chunk modules each field has, plus the body part reference sizes
local lines = { "-- GENERATED by tools/gen_muscle_data.luau from muscle_v8/ (the v9 unified package): do not edit by hand.", "return {" }
table.insert(lines, "\tparts = {")
local partNames = {}
for part in pairs(index.parts) do table.insert(partNames, part) end
table.sort(partNames)
for _, part in ipairs(partNames) do
	local info = index.parts[part]
	table.insert(lines, string.format("\t\t%s = { size = Vector3.new(%s, %s, %s) },", part, tostring(info.size[1]), tostring(info.size[2]), tostring(info.size[3])))
end
table.insert(lines, "\t},")
table.insert(lines, "\tmeshes = {")
for _, r in ipairs(index.meshes) do
	local fields = {}
	for field in pairs(r.chunks) do table.insert(fields, field) end
	table.sort(fields)
	local chunkList = {}
	for _, field in ipairs(fields) do table.insert(chunkList, string.format("[%q] = %d", field, r.chunks[field])) end
	local muscleList = {}
	for _, m in ipairs(r.muscles or {}) do table.insert(muscleList, string.format("%q", m)) end
	table.insert(lines, string.format("\t\t{ name = %q, format = %q, part = %q, muscle = %s, muscles = { %s }, shorts = %s, hidePart = %s, clothing = %q, verts = %d, tris = %d, chunks = { %s } },",
		r.name, r.format, r.part, if r.muscle then string.format("%q", r.muscle) else "nil", table.concat(muscleList, ", "),
		tostring(r.shorts == true), tostring(r.hidePart == true), r.clothing, r.verts, r.tris, table.concat(chunkList, ", ")))
end
table.insert(lines, "\t},")
-- the mass monster size of each mesh's muscle (manifest mass_monster.g, by name)
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

-- The snatched-waist LowerTorso (body/Body_LowerTorso_Snatched.obj + the waist morph): one module { verts, uv, tris, normals,
-- start } in part-local studs (the UpperTorso is part of the unified torso mesh now).
-- clothing-template UVs for the snatched part (the box projection of muscle_v8/source/uvmap.py: TORSO rects, BAND 0.8-1)
local function clothingUVs(part, verts, normals)
	local uvs = {}
	local TW, TH = 585, 559
	local rects = { F = { 231, 74, 128, 128 }, B = { 427, 74, 128, 128 }, R = { 165, 74, 64, 128 }, L = { 361, 74, 64, 128 }, U = { 231, 8, 128, 64 } }
	local b0, b1 = 0.8, 1.0
	local size = manifest.parts[part].size
	local W, H, D = size[1], size[2], size[3]
	for i = 1, #verts / 3 do
		local x, y, z = verts[i * 3 - 2], verts[i * 3 - 1], verts[i * 3]
		local dx, dy, dz = normals[i * 3 - 2], normals[i * 3 - 1], normals[i * 3]
		local fy = math.clamp(0.5 - y / H, 0, 1)
		local vv = b0 + (b1 - b0) * fy
		local ax = if math.abs(dx) >= math.abs(dy) and math.abs(dx) >= math.abs(dz) then 0 elseif math.abs(dy) >= math.abs(dz) then 1 else 2
		local r, u, v
		if ax == 0 then
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

do
	local part = "LowerTorso"
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
	local allZero = true
	for _, value in ipairs(uvs) do if value ~= 0 then allZero = false break end end
	if allZero then uvs = clothingUVs(part, verts, vns) end
	-- the waist that tightens: "start" (level 0, wide and straight) and "max" (the snatched V) per vertex, same order as the OBJ
	local morph = serde.decode("json", fs.readFile(SRC .. "/body/torso_waist_morph.json"))[part]
	local startList = nil
	if morph and morph.start and #morph.start == #verts then
		startList = morph.start
		assert(#morph.tris == #tris, part .. " waist morph: its triangles do not match the snatched OBJ")
		for i, value in ipairs(morph.max) do verts[i] = value end
	end
	local source = "-- GENERATED by tools/gen_muscle_data.luau from " .. SRC .. "/body: the snatched-waist " .. part .. ".\nreturn {\n"
		.. "\tverts = { " .. table.concat(join(verts, 4), ", ") .. " },\n"
		.. "\tuv = { " .. table.concat(join(uvs, 4), ", ") .. " },\n"
		.. "\ttris = { " .. table.concat(join(tris), ", ") .. " },\n"
		.. (if #vns == #verts then "\tnormals = { " .. table.concat(join(vns, 4), ", ") .. " },\n" else "")
		.. (if startList then "\tstart = { " .. table.concat(join(startList, 4), ", ") .. " },\n" else "")
		.. "}\n"
	fs.writeFile(OUT .. "/Snatched" .. part .. ".luau", source)
	print("wrote the snatched LowerTorso")
end
