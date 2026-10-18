-- upper_traps_stage_corrections (19 Oct, owner's bug "upper traps missing"): like tools/quad_fix_stage_corrections, for the
-- torso. Shared.MuscleMeshes now adds an upper traps slope to the Traps growth (addUpperTraps); the owner's low-poly torso
-- stage meshes need the same. For every torso stage object (BS_Torso_<Front|Back>_<stage>) this writes each high-res vertex's
-- OLD position (as the stage was made, without the slope) and its correction (the slope x the Traps growth at that stage),
-- in the high-res OBJ's vertex order; tools/quad_fix_lowpoly.py then moves the low-poly vertices.
-- Run in Studio (Edit mode) with a receiver on localhost:34995 (POST /?f=<file>&mode=w|a) and HttpService on.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MuscleMeshes = require(ReplicatedStorage.Shared.MuscleMeshes)
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
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function shown(key: string, g: number): number
	if g <= 1 then return g end
	return (OLD_MONSTER[key] or MuscleMeshes.MonsterG(key)) * (1 + EXTRA)
end

local function run()
	local whole = MuscleMeshes.LoadUnified("UpperTorso__Unified")
	local slope = whole.upperTraps or {}
	for _, half in ipairs({ "Front", "Back" }) do
		local piece = MuscleMeshes.LoadPiece("UpperTorso__Unified", half)
		for _, stage in ipairs(STAGES) do
			-- (the same math as tools/gen_body_stages unifiedObject; the Traps growth there included the slope, taken out here)
			local pos = table.create(piece.verts)
			for l = 1, piece.verts do pos[l] = piece.base[l] end
			for _, muscle in ipairs(piece.muscleNames) do
				local m = piece.muscles[muscle]
				local s = shown(muscle, stage.g)
				for j, l in ipairs(m.idx) do pos[l] += m.disp[j] * s end
			end
			local waistOff = 1 - math.floor(smooth(math.min(stage.g, 1)) * 250 + 0.5) / 250
			if piece.morph then for l = 1, piece.verts do pos[l] += piece.morph[l] * waistOff end end
			if stage.g > 1 and piece.vein then for l = 1, piece.verts do pos[l] += piece.vein[l] end end
			local traps = shown("Traps", stage.g)
			local lines = table.create(piece.verts)
			for l = 1, piece.verts do
				local fix = (slope[piece.global[l]] or Vector3.zero) * traps
				local old = pos[l] - fix
				lines[l] = string.format("%.5f %.5f %.5f %.6f %.6f %.6f", old.X, old.Y, old.Z, fix.X, fix.Y, fix.Z)
			end
			local file = "BS_Torso_" .. half .. "_" .. stage.tag .. ".txt"
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
