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
	RearDelts = 1.45, Rhomboids = 1.7, SideDelts = 1.5, Traps = 2.625, Triceps = 2.083, UpperChest = 1.522, Lats = 1.318 }
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

local was = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, err = pcall(run)
HttpService.HttpEnabled = was
return if ok then "ok" else "FAILED: " .. tostring(err)
