-- gen_body_stages: makes the OTHER-PLAYER body stage meshes (owner, 8 Oct night). Run in Studio (Edit mode), because it
-- uses the game's own muscle data and loaders (Shared.MuscleMeshes), so the stages are exactly what your own live meshes
-- show at those looks:
--   1. start tools/gen_body_stages_receive.ps1 (a localhost receiver), turn on HttpService
--   2. in the command bar: require(<this file as a ModuleScript>).Generate()
--   3. turn HttpService off again
-- Writes Downloads\other_player_stages\BS_<region>_<piece>_<stage>.obj (62 files, one mesh each: Import 3D merges a
-- multi-object OBJ into one mesh) and src Config/BodyStages.luau.
--
-- A client holds at most 8 EditableMeshes (measured 8 Oct: count, not size) and your own body uses 7, so other players,
-- NPCs, the statue and the mirror wear STATIC stage meshes (Shared.BodyStages), like the forearm / calf stages: per body
-- region, 7 stages by look (0, 0.2 .. 1.0 and the mass monster) with every muscle of the region at that look. Same part-
-- local coordinates (+X right, +Y up, -Z front, studs), the same triangles and the same UVs as the unified / shell meshes
-- (OBJ v flipped: vt = 1 - v, like the limb stage OBJs), so a classic Shirt / Pants maps the same way. No normals (the
-- importer makes smooth ones, like the limb stages).
-- Objects (each <= 20,000 triangles): Torso Front / Back (the unified torso's halves), Right / Left upper arm, Waist (the
-- snatched LowerTorso), Right / Left thigh Skin and Shorts (the shell meshes, split by the gym shorts).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MuscleMeshes = require(ReplicatedStorage.Shared.MuscleMeshes)
local Muscles = require(ReplicatedStorage.Shared.Config.Muscles)
local Body = require(ReplicatedStorage.Shared.Config.Body)

local URL = "http://localhost:34996/"
local Gen = {}

local STAGES = {
	{ g = 0, tag = "g000" }, { g = 0.2, tag = "g020" }, { g = 0.4, tag = "g040" }, { g = 0.6, tag = "g060" },
	{ g = 0.8, tag = "g080" }, { g = 1, tag = "g100" }, { g = 2, tag = "gmon" },
}
local EXTRA = Body.Widths.MassMonster.muscle_extra

-- the same math as MuscleRig (smooth, meshShown at a uniform look, waistProgress, veins)
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function shown(key: string, g: number): number
	if g <= 1 then return g end
	return MuscleMeshes.MonsterG(key) * (1 + EXTRA) -- (the full mass monster: t = 1)
end
local function waistOf(g: number): number
	return math.floor(smooth(math.min(g, 1)) * 250 + 0.5) / 250
end
local function veinOf(g: number): number
	return if g > 1 then 1 else 0
end

-- one object: positions (Vector3), uvs (Vector2), tris (1-based local triples)
local function unifiedObject(piece, g: number)
	local pos = table.create(piece.verts)
	for l = 1, piece.verts do pos[l] = piece.base[l] end
	for _, muscle in ipairs(piece.muscleNames) do
		local m = piece.muscles[muscle]
		local s = shown(muscle, g)
		for j, l in ipairs(m.idx) do pos[l] += m.disp[j] * s end
	end
	local waistOff = 1 - waistOf(g)
	if piece.morph then for l = 1, piece.verts do pos[l] += piece.morph[l] * waistOff end end
	local v = veinOf(g)
	if v > 0 and piece.vein then for l = 1, piece.verts do pos[l] += piece.vein[l] * v end end
	local tris = table.create(#piece.tris)
	for k, t in ipairs(piece.tris) do tris[k] = t + 1 end
	return pos, piece.uv, tris
end

-- the shell group of one thigh, split into its skin ranges and its shorts ranges
local function shellObjects(groupDef, g: number)
	local data = MuscleMeshes.LoadGroup(groupDef)
	local pos = table.create(data.verts)
	local w = waistOf(g)
	local v = veinOf(g)
	local rangeOf = table.create(data.verts)
	for r, range in ipairs(data.ranges) do
		local gr = shown(range.key, g)
		local others = {}
		for _, key in ipairs(range.blendKeys) do others[key] = shown(key, g) end
		for i = range.first, range.first + range.count - 1 do
			rangeOf[i] = r
			local gv = gr
			local list = data.blends[i]
			if list then
				local weights, sum = 0, 0
				for _, pair in ipairs(list) do
					weights += pair[2]
					sum += pair[2] * (others[pair[1]] or gr)
				end
				gv = (1 - weights) * gr + sum
			end
			if data.hug and data.hug[i] then gv *= data.hug[i] end
			local p = data.base[i] + data.delta[i] * gv
			if data.morph and data.morph[i] then p += data.morph[i] * (1 - w) end
			if v > 0 and data.vein and data.vein[i] then p += data.vein[i] * v end
			pos[i] = p
		end
	end
	-- split: each triangle belongs to one range (the merged list keeps each mesh's triangles together)
	local out = { Skin = { pos = {}, uv = {}, tris = {}, map = {} }, Shorts = { pos = {}, uv = {}, tris = {}, map = {} } }
	local t = data.tris
	for k = 1, #t, 3 do
		local a = t[k] + 1
		local which = if data.ranges[rangeOf[a]].shorts then out.Shorts else out.Skin
		for _, vertex in ipairs({ t[k] + 1, t[k + 1] + 1, t[k + 2] + 1 }) do
			local l = which.map[vertex]
			if not l then
				table.insert(which.pos, pos[vertex])
				table.insert(which.uv, data.uv[vertex])
				l = #which.pos
				which.map[vertex] = l
			end
			table.insert(which.tris, l)
		end
	end
	return out
end

local function waistObject(g: number)
	local data = MuscleMeshes.LoadSnatched("LowerTorso")
	assert(data, "no snatched LowerTorso data")
	local w = waistOf(g)
	local pos = table.create(#data.verts)
	for i, max in ipairs(data.verts) do
		pos[i] = if data.start then data.start[i] + (max - data.start[i]) * w else max
	end
	local tris = table.create(#data.tris)
	for k, t in ipairs(data.tris) do tris[k] = t + 1 end
	return pos, data.uv, tris
end

------------------------------------------------------------------------
-- Writing
------------------------------------------------------------------------
local function send(path: string, body: string)
	HttpService:PostAsync(URL .. path, body, Enum.HttpContentType.TextPlain, false)
end
local CHUNK = 400000
local files = {} -- [file] = { offset (vertices written), started }
local entries = {} -- [object name] = { center, size }

local function writeObject(_group: string, name: string, pos, uv, tris)
	-- ONE OBJ per mesh (8 Oct night: Import 3D merged a multi-object OBJ into one mesh named "default"; the 28 separate limb
	-- stage files imported fine)
	local file = name .. ".obj"
	local f = files[file]
	if not f then
		f = { offset = 0, started = false, buffer = {}, size = 0 }
		files[file] = f
	end
	local lines = f.buffer
	local function add(line: string)
		table.insert(lines, line)
		f.size += #line + 1
		if f.size >= CHUNK then
			send("obj?f=" .. file .. "&mode=" .. (if f.started then "a" else "w"), table.concat(lines, "\n") .. "\n")
			f.started = true
			table.clear(lines)
			f.size = 0
		end
	end
	add("o " .. name)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(pos) do
		add(string.format("v %.5f %.5f %.5f", p.X, p.Y, p.Z))
		minV, maxV = minV:Min(p), maxV:Max(p)
	end
	for _, t in ipairs(uv) do add(string.format("vt %.5f %.5f", t.X, 1 - t.Y)) end
	local o = f.offset
	for k = 1, #tris, 3 do
		local a, b, c = tris[k] + o, tris[k + 1] + o, tris[k + 2] + o
		add(string.format("f %d/%d %d/%d %d/%d", a, a, b, b, c, c))
	end
	f.offset += #pos
	assert(#tris // 3 <= 20000, name .. " has more than 20,000 triangles")
	entries[name] = { center = (minV + maxV) / 2, size = maxV - minV, tris = #tris // 3 }
end
local function flush()
	for file, f in pairs(files) do
		if #f.buffer > 0 then
			send("obj?f=" .. file .. "&mode=" .. (if f.started then "a" else "w"), table.concat(f.buffer, "\n") .. "\n")
			f.started = true
			table.clear(f.buffer)
		end
	end
end

------------------------------------------------------------------------
-- The regions (what Shared.BodyStages draws): a region switches stage as one (its pieces never crack apart)
------------------------------------------------------------------------
local function legGroup(part: string)
	for _, unit in ipairs(MuscleMeshes.Units) do
		if unit.id == "UpperLegs" then
			for _, group in ipairs(unit.groups) do
				if group.part == part then return group end
			end
		end
	end
	error("no UpperLegs group for " .. part)
end

local REGIONS = {
	{ id = "Torso", part = "UpperTorso", file = "other_player_stages_torso.obj", pieces = {
		{ key = "Front", clothing = "Shirt", kind = "top" }, { key = "Back", clothing = "Shirt", kind = "top" } } },
	{ id = "RightArm", part = "RightUpperArm", file = "other_player_stages_body.obj", pieces = { { key = "Arm", clothing = "Shirt", kind = "skin" } } },
	{ id = "LeftArm", part = "LeftUpperArm", file = "other_player_stages_body.obj", pieces = { { key = "Arm", clothing = "Shirt", kind = "skin" } } },
	{ id = "RightLeg", part = "RightUpperLeg", file = "other_player_stages_body.obj", pieces = {
		{ key = "Skin", clothing = "Pants", kind = "skin" }, { key = "Shorts", clothing = "Pants", kind = "shorts" } } },
	{ id = "LeftLeg", part = "LeftUpperLeg", file = "other_player_stages_body.obj", pieces = {
		{ key = "Skin", clothing = "Pants", kind = "skin" }, { key = "Shorts", clothing = "Pants", kind = "shorts" } } },
	{ id = "Waist", part = "LowerTorso", file = "other_player_stages_body.obj", pieces = { { key = "Waist", clothing = "Pants", kind = "shorts" } } },
}

local function objectName(region, piece, stage): string
	return "BS_" .. region.id .. "_" .. piece.key .. "_" .. stage.tag
end

-- the objects of one region at one stage: { { key, pos, uv, tris } }
local function regionObjects(region, stage)
	local out = {}
	if region.id == "Torso" then
		for _, piece in ipairs(region.pieces) do
			local pos, uv, tris = unifiedObject(MuscleMeshes.LoadPiece("UpperTorso__Unified", piece.key), stage.g)
			table.insert(out, { key = piece.key, pos = pos, uv = uv, tris = tris })
		end
	elseif region.pieces[1].key == "Arm" then
		local pos, uv, tris = unifiedObject(MuscleMeshes.LoadPiece(region.part .. "__Unified", nil), stage.g)
		table.insert(out, { key = "Arm", pos = pos, uv = uv, tris = tris })
	elseif region.id == "Waist" then
		local pos, uv, tris = waistObject(stage.g)
		table.insert(out, { key = "Waist", pos = pos, uv = uv, tris = tris })
	else
		local parts = shellObjects(legGroup(region.part), stage.g)
		for _, piece in ipairs(region.pieces) do
			local o = parts[piece.key]
			table.insert(out, { key = piece.key, pos = o.pos, uv = o.uv, tris = o.tris })
		end
	end
	return out
end

-- Preview (Studio, Edit mode): builds the stage objects as EditableMesh parts on a rig's body parts (a Workspace model with
-- R15 part names), for a quick look before exporting. stageIndex 1..7. Returns the folder (delete it after).
function Gen.Preview(rig: Model, stageIndex: number)
	local AssetService = game:GetService("AssetService")
	local folder = Instance.new("Folder")
	folder.Name = "BodyStagePreview"
	folder.Parent = rig
	local stage = STAGES[stageIndex]
	for _, region in ipairs(REGIONS) do
		if region.id == "Waist" and stage.g > 1 then continue end
		local body = rig:FindFirstChild(region.part)
		if not (body and body:IsA("BasePart")) then continue end
		for _, o in ipairs(regionObjects(region, stage)) do
			local mesh = AssetService:CreateEditableMesh()
			local ids = table.create(#o.pos)
			for i, p in ipairs(o.pos) do ids[i] = mesh:AddVertex(p) end
			for k = 1, #o.tris, 3 do mesh:AddTriangle(ids[o.tris[k]], ids[o.tris[k + 1]], ids[o.tris[k + 2]]) end
			local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
			part.Name = region.id .. o.key
			part.Anchored, part.CanCollide = true, false
			-- (a part made from an EditableMesh keeps the mesh's own origin, like MuscleRig's live meshes: no offset; the
			-- IMPORTED meshes are centred on their bounds instead, which Shared.BodyStages undoes with the config's centre)
			part.CFrame = body.CFrame
			part.Color = if o.key == "Shorts" or o.key == "Waist" then Color3.fromHex("#1E1E22") else Color3.fromHex("#E0A878")
			part.Parent = folder
			body.Transparency = 1
		end
	end
	return folder
end

function Gen.Generate()
	HttpService.HttpEnabled = true
	table.clear(files)
	table.clear(entries)
	local muscleLists = {}
	for _, region in ipairs(REGIONS) do
		local list = {}
		if region.id == "Torso" then
			list = table.clone(MuscleMeshes.ByName["UpperTorso__Unified"].muscles)
		elseif region.id == "RightArm" or region.id == "LeftArm" then
			list = table.clone(MuscleMeshes.ByName[region.part .. "__Unified"].muscles)
		elseif region.id == "RightLeg" or region.id == "LeftLeg" then
			list = { "Quads", "Hamstrings", "Glutes" }
		end -- (the waist: every muscle, the overall look)
		muscleLists[region.id] = list
		for _, stage in ipairs(STAGES) do
			if region.id == "Waist" and stage.g > 1 then continue end -- (the waist stops changing at the full look)
			if region.id == "Torso" then
				for _, piece in ipairs(region.pieces) do
					local pos, uv, tris = unifiedObject(MuscleMeshes.LoadPiece("UpperTorso__Unified", piece.key), stage.g)
					writeObject(region.file, objectName(region, piece, stage), pos, uv, tris)
				end
			elseif region.pieces[1].key == "Arm" then
				local pos, uv, tris = unifiedObject(MuscleMeshes.LoadPiece(region.part .. "__Unified", nil), stage.g)
				writeObject(region.file, objectName(region, region.pieces[1], stage), pos, uv, tris)
			elseif region.id == "Waist" then
				local pos, uv, tris = waistObject(stage.g)
				writeObject(region.file, objectName(region, region.pieces[1], stage), pos, uv, tris)
			else
				local parts = shellObjects(legGroup(region.part), stage.g)
				for _, piece in ipairs(region.pieces) do
					local o = parts[piece.key]
					writeObject(region.file, objectName(region, piece, stage), o.pos, o.uv, o.tris)
				end
			end
			task.wait() -- (keep Studio responsive)
		end
	end
	flush()

	-- the config: regions, pieces and stages with each object's bounding box (the importer centres a mesh on its bounds)
	local function v3(v: Vector3): string return string.format("Vector3.new(%.4f, %.4f, %.4f)", v.X, v.Y, v.Z) end
	local lines = {
		"--!strict",
		"-- BodyStages: the static body stage meshes for OTHER players, NPCs, the statue and the mirror (your own character keeps",
		"-- its live EditableMeshes). GENERATED by tools/gen_body_stages.luau (run in Studio) from the game's own muscle data: per",
		"-- region 7 stages (look 0, 0.2 .. 1.0 and the mass monster; the waist 6), every muscle of the region at that look.",
		"-- center / size = each object's bounding box in part-local studs (the importer centres a mesh on its bounds). The meshes",
		"-- are imported with Import 3D (Downloads\\other_player_stages) and turned into the templates in",
		"-- ReplicatedStorage.BodyStages by tools/body_stages_setup.luau. Without them other characters show the plain body.",
		"local BodyStages = {}",
		"",
		"BodyStages.FadeTime = 0.3 -- seconds of cross-fade between two stages",
		"-- Studio's Import 3D turns OBJs 180 degrees around Y (measured with the limb stages): turned back here",
		"BodyStages.ImportTurn = CFrame.Angles(0, math.pi, 0)",
		"",
		"-- kind: how a piece is colored when no Shirt / Pants covers it (skin = the skin + its texture stage, top = the game's top",
		"-- color or the skin, shorts = the gym shorts color); clothing = which classic clothing image it wears",
		"BodyStages.Regions = {",
	}
	for _, region in ipairs(REGIONS) do
		local muscles = muscleLists[region.id]
		table.insert(lines, string.format("\t{ id = %q, part = %q, muscles = %s, pieces = {", region.id, region.part,
			if #muscles > 0 then "{ \"" .. table.concat(muscles, "\", \"") .. "\" }" else "\"all\""))
		for _, piece in ipairs(region.pieces) do
			table.insert(lines, string.format("\t\t{ key = %q, clothing = %q, kind = %q },", piece.key, piece.clothing, piece.kind))
		end
		table.insert(lines, "\t}, stages = {")
		for _, stage in ipairs(STAGES) do
			if region.id == "Waist" and stage.g > 1 then continue end
			local objects = {}
			for _, piece in ipairs(region.pieces) do
				local name = objectName(region, piece, stage)
				local e = entries[name]
				table.insert(objects, string.format("%s = { file = %q, center = %s, size = %s }", piece.key, name, v3(e.center), v3(e.size)))
			end
			table.insert(lines, string.format("\t\t{ g = %s, objects = { %s } },", tostring(stage.g), table.concat(objects, ", ")))
		end
		table.insert(lines, "\t} },")
	end
	table.insert(lines, "}")
	table.insert(lines, "")
	table.insert(lines, "return BodyStages")
	send("config", table.concat(lines, "\n") .. "\n")
	local count, biggest = 0, 0
	for _, e in pairs(entries) do count += 1 biggest = math.max(biggest, e.tris) end
	return string.format("%d objects, the biggest %d triangles", count, biggest)
end

return Gen
