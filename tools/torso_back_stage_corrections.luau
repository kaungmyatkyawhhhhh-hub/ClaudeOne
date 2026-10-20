-- torso_back_stage_corrections (20 Oct, owner's prompt 15 "upper traps texture and back shape"): the low-poly torso stage
-- meshes need the same change as the live torso (Shared.MuscleMeshes: the re-meshed top cap, the back sculpt, the data's
-- back growth giving way). Writes, for every stage, every vertex of the whole high-res torso as it was (the previous
-- MuscleMeshes, put temporarily as ReplicatedStorage.Shared.MuscleMeshes_old, e.g. from `git show 2e3f496:<path>`) and as it
-- is now: old_<stage>.txt / new_<stage>.txt, one "x y z" line per vertex in the data's vertex order. tools/
-- torso_back_lowpoly.py then moves the owner's low-poly OBJs and gives them the new texture coordinates.
-- Run in Studio (Edit mode) with a receiver on localhost:34995 (POST /?f=<file>&mode=w|a) and HttpService on.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Body = require(ReplicatedStorage.Shared.Config.Body)

local URL = "http://127.0.0.1:34995/"
local EXTRA = Body.Widths.MassMonster.muscle_extra
-- the mass monster sizes the stage meshes were made with (as tools/reshape_stage_corrections.luau)
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

local function positions(MuscleMeshes, g: number): { Vector3 }
	local function shown(key: string): number
		if g <= 1 then return g end
		if string.find(key, "@shape", 1, true) then return MuscleMeshes.MonsterG(key) * (1 + EXTRA) end
		return (OLD_MONSTER[key] or MuscleMeshes.MonsterG(key)) * (1 + EXTRA)
	end
	local data = MuscleMeshes.LoadUnified("UpperTorso__Unified")
	local pos = table.clone(data.base)
	for muscle, m in pairs(data.muscles) do
		local s = shown(muscle)
		for j, v in ipairs(m.idx) do pos[v] += m.disp[j] * s end
	end
	for muscle, sh in pairs(data.shapes or {}) do
		local s = shown(muscle .. "@shape")
		for j, v in ipairs(sh.idx) do pos[v] += sh.disp[j] * s end
	end
	local waistOff = 1 - math.floor(smooth(math.min(g, 1)) * 250 + 0.5) / 250
	if data.morph then for v = 1, data.verts do pos[v] += data.morph[v] * waistOff end end
	if g > 1 and data.vein then for v = 1, data.verts do pos[v] += data.vein[v] end end
	return pos
end

local function run()
	local versions = {
		old = require(ReplicatedStorage.Shared.MuscleMeshes_old:Clone()),
		new = require(ReplicatedStorage.Shared.MuscleMeshes:Clone()),
	}
	for which, MuscleMeshes in pairs(versions) do
		for _, stage in ipairs(STAGES) do
			local pos = positions(MuscleMeshes, stage.g)
			local lines = table.create(#pos)
			for v, p in ipairs(pos) do lines[v] = string.format("%.5f %.5f %.5f", p.X, p.Y, p.Z) end
			local file = which .. "_" .. stage.tag .. ".txt"
			for c = 1, #lines, 4000 do
				HttpService:PostAsync(URL .. "?f=" .. file .. "&mode=" .. (if c == 1 then "w" else "a"),
					table.concat(lines, "\n", c, math.min(c + 3999, #lines)) .. "\n", Enum.HttpContentType.TextPlain, false)
			end
			task.wait()
		end
	end
	-- faces.txt: every triangle of the new data (1-based vertex ids) and its three texture corners as the live body draws
	-- them (its own corners from applyUVPatch, else the vertices' with MuscleRig's seam rule)
	local data = versions.new.LoadUnified("UpperTorso__Unified")
	local SEAM_UV = 0.035
	local lines = {}
	local t = data.tris
	for k = 1, #t, 3 do
		local a, b, c = t[k] + 1, t[k + 1] + 1, t[k + 2] + 1
		local corners = data.faceUV and data.faceUV[(k + 2) // 3]
		if not corners then
			local pa, pb, pc = data.uv[a], data.uv[b], data.uv[c]
			local dab, dbc, dca = (pa - pb).Magnitude, (pb - pc).Magnitude, (pc - pa).Magnitude
			if math.max(dab, dbc, dca) <= SEAM_UV then corners = { pa, pb, pc }
			elseif math.min(dab, dbc, dca) > SEAM_UV then corners = { pa, pa, pa }
			elseif dab <= dbc and dab <= dca then corners = { pa, pb, (pa + pb) / 2 }
			elseif dbc <= dca then corners = { (pb + pc) / 2, pb, pc }
			else corners = { pa, (pc + pa) / 2, pc } end
		end
		table.insert(lines, string.format("%d %d %d %.5f %.5f %.5f %.5f %.5f %.5f", a, b, c,
			corners[1].X, corners[1].Y, corners[2].X, corners[2].Y, corners[3].X, corners[3].Y))
	end
	for c = 1, #lines, 4000 do
		HttpService:PostAsync(URL .. "?f=faces.txt&mode=" .. (if c == 1 then "w" else "a"),
			table.concat(lines, "\n", c, math.min(c + 3999, #lines)) .. "\n", Enum.HttpContentType.TextPlain, false)
	end
end

local was = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, err = pcall(run)
HttpService.HttpEnabled = was
return if ok then "ok" else "FAILED: " .. tostring(err)
