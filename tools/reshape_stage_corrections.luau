-- reshape_stage_corrections (19 Oct, owner's prompts "upper traps missing" + "wide traps and round shoulders"): the owner's
-- low-poly body stage meshes need the same shape changes as the live muscles (Shared.MuscleMeshes: the traps yoke and the
-- round delt caps as shape layers, the data's traps / delts fading under them). For every torso / upper arm stage object
-- (BS_Torso_<Front|Back>_<stage>, BS_<Right|Left>Arm_Arm_<stage>) this writes each high-res vertex's OLD position (as the
-- stage was made: the plain data and the mass monster sizes of that time) and its correction (the new shape minus the old),
-- in the high-res OBJ's vertex order; tools/quad_fix_lowpoly.py then moves the low-poly vertices.
-- Run in Studio (Edit mode) with a receiver on localhost:34995 (POST /?f=<file>&mode=w|a) and HttpService on. Require a
-- fresh copy of MuscleMeshes (the command bar keeps an old one): require(ReplicatedStorage.Shared.MuscleMeshes:Clone()).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MuscleMeshes = require(ReplicatedStorage.Shared.MuscleMeshes:Clone())
local Body = require(ReplicatedStorage.Shared.Config.Body)

local URL = "http://127.0.0.1:34995/"
local EXTRA = Body.Widths.MassMonster.muscle_extra
-- the mass monster sizes the stage meshes were made with (MuscleData.Index monsterG before the owner's 19 Oct values)
local OLD_MONSTER = { Abs = 1.316, Biceps = 2.083, FrontDelts = 1.526, LowerBack = 1.647, MidChest = 1.522, Obliques = 2.909,
	RearDelts = 1.45, Rhomboids = 1.7, SideDelts = 1.5, Traps = 2.625, Triceps = 2.083, UpperChest = 1.522, Lats = 1.318,
	Quads = 2.132, Hamstrings = 2, Glutes = 1.8 }
local STAGES = {
	{ g = 0, tag = "g000" }, { g = 0.2, tag = "g020" }, { g = 0.4, tag = "g040" }, { g = 0.6, tag = "g060" },
	{ g = 0.8, tag = "g080" }, { g = 1, tag = "g100" }, { g = 2, tag = "gmon" },
}
local PIECES = {
	{ mesh = "UpperTorso__Unified", half = "Front", file = "BS_Torso_Front_" },
	{ mesh = "UpperTorso__Unified", half = "Back", file = "BS_Torso_Back_" },
	{ mesh = "RightUpperArm__Unified", file = "BS_RightArm_Arm_" },
	{ mesh = "LeftUpperArm__Unified", file = "BS_LeftArm_Arm_" },
}
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function shown(key: string, g: number): number
	if g <= 1 then return g end
	if string.find(key, "@shape", 1, true) then return MuscleMeshes.MonsterG(key) * (1 + EXTRA) end
	return (OLD_MONSTER[key] or MuscleMeshes.MonsterG(key)) * (1 + EXTRA)
end

local function run()
	for _, def in ipairs(PIECES) do
		local whole = MuscleMeshes.LoadUnified(def.mesh)
		local reshaped = whole.reshape or {}
		local piece = MuscleMeshes.LoadPiece(def.mesh, def.half)
		for _, stage in ipairs(STAGES) do
			-- the new shape (the same math as tools/gen_body_stages unifiedObject, with the old monster sizes)
			local pos = table.create(piece.verts)
			for l = 1, piece.verts do pos[l] = piece.base[l] end
			for _, muscle in ipairs(piece.muscleNames) do
				local m = piece.muscles[muscle]
				local s = shown(muscle, stage.g)
				for j, l in ipairs(m.idx) do pos[l] += m.disp[j] * s end
			end
			local fix = table.create(piece.verts, Vector3.zero)
			for _, muscle in ipairs(piece.shapeNames or {}) do
				local sh = piece.shapes[muscle]
				local s = shown(muscle .. "@shape", stage.g)
				for j, l in ipairs(sh.idx) do
					pos[l] += sh.disp[j] * s
					fix[l] += sh.disp[j] * s
				end
			end
			for muscle, changed in pairs(reshaped) do
				local s = shown(muscle, stage.g)
				for l = 1, piece.verts do
					local d = changed[piece.global[l]]
					if d then fix[l] += d * s end
				end
			end
			local waistOff = 1 - math.floor(smooth(math.min(stage.g, 1)) * 250 + 0.5) / 250
			if piece.morph then for l = 1, piece.verts do pos[l] += piece.morph[l] * waistOff end end
			if stage.g > 1 and piece.vein then for l = 1, piece.verts do pos[l] += piece.vein[l] end end
			local lines = table.create(piece.verts)
			for l = 1, piece.verts do
				local old = pos[l] - fix[l]
				local f = fix[l]
				lines[l] = string.format("%.5f %.5f %.5f %.6f %.6f %.6f", old.X, old.Y, old.Z, f.X, f.Y, f.Z)
			end
			local file = def.file .. stage.tag .. ".txt"
			for c = 1, #lines, 2000 do
				HttpService:PostAsync(URL .. "?f=" .. file .. "&mode=" .. (if c == 1 then "w" else "a"),
					table.concat(lines, "\n", c, math.min(c + 1999, #lines)) .. "\n", Enum.HttpContentType.TextPlain, false)
			end
			task.wait()
		end
	end
end

-- the thighs (prompt 8, the adductors: the LoadGroup shape layer). Old = the stage as now in use (quad fix included, old
-- monster sizes), correction = the adductor fill at that stage. Written as BS_<Left|Right>Leg_<Skin|Shorts>_<stage>.txt in
-- the same split and order as tools/gen_body_stages (vertex order of the quadfix low-poly's high-res source).
local function runLegs()
	for _, side in ipairs({ "Left", "Right" }) do
		local group
		for _, unit in ipairs(MuscleMeshes.Units) do
			if unit.id == "UpperLegs" then
				for _, g in ipairs(unit.groups) do if g.part == side .. "UpperLeg" then group = g end end
			end
		end
		local data = MuscleMeshes.LoadGroup(group)
		for _, stage in ipairs(STAGES) do
			local w = math.floor(smooth(math.min(stage.g, 1)) * 250 + 0.5) / 250
			local v = if stage.g > 1 then 1 else 0
			local sg = shown("Quads@shape", stage.g)
			local oldPos, fix, rangeOf = table.create(data.verts), table.create(data.verts), table.create(data.verts)
			for r, range in ipairs(data.ranges) do
				local gr = shown(range.key, stage.g)
				local others = {}
				for _, key in ipairs(range.blendKeys) do others[key] = shown(key, stage.g) end
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
					oldPos[i] = p
					fix[i] = if data.shape and data.shape[i] then data.shape[i] * sg else Vector3.zero
				end
			end
			local out = { Skin = { lines = {}, map = {} }, Shorts = { lines = {}, map = {} } }
			local t = data.tris
			for k = 1, #t, 3 do
				local which = if data.ranges[rangeOf[t[k] + 1]].shorts then out.Shorts else out.Skin
				for _, vertex in ipairs({ t[k] + 1, t[k + 1] + 1, t[k + 2] + 1 }) do
					if not which.map[vertex] then
						which.map[vertex] = true
						local p, d = oldPos[vertex], fix[vertex]
						table.insert(which.lines, string.format("%.5f %.5f %.5f %.6f %.6f %.6f", p.X, p.Y, p.Z, d.X, d.Y, d.Z))
					end
				end
			end
			for _, piece in ipairs({ "Skin", "Shorts" }) do
				local lines = out[piece].lines
				local file = "BS_" .. side .. "Leg_" .. piece .. "_" .. stage.tag .. ".txt"
				for c = 1, #lines, 2000 do
					HttpService:PostAsync(URL .. "?f=" .. file .. "&mode=" .. (if c == 1 then "w" else "a"),
						table.concat(lines, "\n", c, math.min(c + 1999, #lines)) .. "\n", Enum.HttpContentType.TextPlain, false)
				end
			end
			task.wait()
		end
	end
end

local was = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, err = pcall(function()
	run()
	runLegs()
end)
HttpService.HttpEnabled = was
return if ok then "ok" else "FAILED: " .. tostring(err)
