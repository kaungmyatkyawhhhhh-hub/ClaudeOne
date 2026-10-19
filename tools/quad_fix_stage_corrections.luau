-- quad_fix_stage_corrections (19 Oct, owner's bug "inner quad bulge"): the body stage meshes for other players / NPCs are
-- the owner's low-poly copies of the stages tools/gen_body_stages made, so they can't simply be made again from the fixed
-- muscle data. This writes, for every thigh stage object (BS_<Left|Right>Leg_<Skin|Shorts>_<stage>), each high-res vertex's
-- OLD position (as the stage was made: the raw quad growth and the mass monster sizes of that time) and its correction (the
-- fixed quad growth of Shared.MuscleMeshes minus the old one), in the high-res OBJ's vertex order. tools/quad_fix_lowpoly.py
-- then moves the low-poly vertices by the corrections of the nearest high-res vertices.
-- Run in Studio (Edit mode) with a receiver on localhost:34995 (POST /?f=<file>&mode=w|a) and HttpService on.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MuscleMeshes = require(ReplicatedStorage.Shared.MuscleMeshes:Clone()) -- (a fresh copy: the command bar keeps an old one)
local Body = require(ReplicatedStorage.Shared.Config.Body)

local URL = "http://127.0.0.1:34995/"
local EXTRA = Body.Widths.MassMonster.muscle_extra
-- the mass monster sizes the stage meshes were made with (MuscleData.Index monsterG before the owner's 19 Oct values)
local OLD_MONSTER = { Quads = 2.132, Hamstrings = 2, Glutes = 1.8 }
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

local function send(file: string, mode: string, body: string)
	HttpService:PostAsync(URL .. "?f=" .. file .. "&mode=" .. mode, body, Enum.HttpContentType.TextPlain, false)
end

local function run()
	for _, side in ipairs({ "Left", "Right" }) do
		local group = legGroup(side .. "UpperLeg")
		local data = MuscleMeshes.LoadGroup(group) -- (the fixed quad growth)
		-- the raw growth (MuscleMeshes.Load is the data as stored), in the merged order
		local rawDelta, rawVein = table.create(data.verts), table.create(data.verts)
		for r, name in ipairs(group.records) do
			local raw = MuscleMeshes.Load(name)
			local range = data.ranges[r]
			for i = 1, range.count do
				rawDelta[range.first + i - 1] = raw.delta[i]
				rawVein[range.first + i - 1] = raw.vein and raw.vein[i] or nil
			end
		end
		for _, stage in ipairs(STAGES) do
			local w = math.floor(smooth(math.min(stage.g, 1)) * 250 + 0.5) / 250
			local v = if stage.g > 1 then 1 else 0
			local oldPos, fix = table.create(data.verts), table.create(data.verts)
			local rangeOf = table.create(data.verts)
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
					local p = data.base[i] + rawDelta[i] * gv
					if data.morph and data.morph[i] then p += data.morph[i] * (1 - w) end
					local veinFix = Vector3.zero
					if v > 0 and rawVein[i] then
						p += rawVein[i] * v
						veinFix = (data.vein[i] - rawVein[i]) * v
					end
					oldPos[i] = p
					fix[i] = (data.delta[i] - rawDelta[i]) * gv + veinFix
					-- (19 Oct: the adductor fill, the thigh's shape layer)
					if data.shape and data.shape[i] then fix[i] += data.shape[i] * shown(data.shapeMuscle .. "@shape", stage.g) end
				end
			end
			-- the same split and vertex order as tools/gen_body_stages (first use in the triangle list)
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
					send(file, if c == 1 then "w" else "a", table.concat(lines, "\n", c, math.min(c + 1999, #lines)) .. "\n")
				end
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
