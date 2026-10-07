--[[
	FacadeTex
	Procedural building facade textures (pure Luau, only uses `buffer`, so the
	exact same code runs in Roblox and in offline tools).

	A texture tile is 8 window modules wide x 8 floors high. Each style paints
	its own wall (glass curtain wall, office panels, limestone, brick), window
	frames, floor slabs and glass. Lit windows show a room interior: ceiling
	light falloff, blinds on some, desks/furniture silhouettes on others, warm
	or cool colour temperatures and a few whole floors left on late at night.

	Maps produced (RGBA8 buffers, SIZE x SIZE):
	  color    : albedo; lit rooms carry their interior colour
	  emissive : grayscale mask of what glows (lit rooms only)
	  normal   : window recesses / frame bevels
	  rough    : glass is glossy, walls are matte
	  metal    : glass and metal frames reflect the environment
]]

local FacadeTex = {}

FacadeTex.SIZE = 256
FacadeTex.COLS = 8
FacadeTex.ROWS = 8
FacadeTex.FLOOR_STUDS = 11

local CELL = FacadeTex.SIZE // FacadeTex.COLS

export type Style = {
	pier: number, -- px of wall either side of a window (per side)
	spandrel: number, -- px of floor slab under the window
	head: number, -- px of wall above the window
	wall: { number },
	wallNoise: number,
	frame: { number },
	glass: { number },
	sky: number, -- reflection brightening toward the top of each pane
	pattern: string, -- "plain" | "brick" | "stone" | "panel"
	glassRough: number,
	glassMetal: number,
	wallRough: number,
	frameMetal: number,
}

FacadeTex.STYLES = {
	glass = { pier = 1, spandrel = 6, head = 1, wall = { 62, 68, 80 }, wallNoise = 2, frame = { 92, 98, 110 }, glass = { 18, 28, 44 }, sky = 22, pattern = "plain", glassRough = 20, glassMetal = 190, wallRough = 120, frameMetal = 200 },
	panel = { pier = 3, spandrel = 9, head = 2, wall = { 50, 53, 61 }, wallNoise = 3, frame = { 30, 31, 36 }, glass = { 16, 22, 32 }, sky = 16, pattern = "panel", glassRough = 26, glassMetal = 150, wallRough = 170, frameMetal = 160 },
	stone = { pier = 7, spandrel = 9, head = 5, wall = { 128, 118, 102 }, wallNoise = 9, frame = { 44, 40, 36 }, glass = { 18, 22, 28 }, sky = 14, pattern = "stone", glassRough = 30, glassMetal = 120, wallRough = 225, frameMetal = 0 },
	brick = { pier = 7, spandrel = 9, head = 6, wall = { 116, 62, 46 }, wallNoise = 10, frame = { 196, 190, 178 }, glass = { 16, 20, 26 }, sky = 12, pattern = "brick", glassRough = 30, glassMetal = 110, wallRough = 235, frameMetal = 0 },
}

local WARM = { { 255, 196, 128 }, { 255, 210, 160 }, { 255, 184, 112 }, { 250, 220, 180 } }
local COOL = { { 196, 218, 255 }, { 170, 198, 255 }, { 220, 232, 255 }, { 150, 185, 240 } }

-- deterministic LCG (identical results everywhere; products stay below 2^53)
local function rng(seed: number): () -> number
	local state = seed % 4294967296
	return function(): number
		state = (state * 1664525 + 1013904223) % 4294967296
		return state / 4294967296
	end
end

local function hashSeed(style: string, warm: boolean, busy: boolean): number
	local h = 2166136261
	local key = style .. (if warm then "W" else "C") .. (if busy then "B" else "S")
	for i = 1, #key do
		h = ((h * 16777619) + string.byte(key, i)) % 4294967296
	end
	return h
end

local function put(buf: buffer, x: number, y: number, r: number, g: number, b: number, a: number?)
	local function c(v: number): number
		return math.clamp(math.floor(v + 0.5), 0, 255)
	end
	buffer.writeu32(buf, (y * FacadeTex.SIZE + x) * 4, c(r) + c(g) * 256 + c(b) * 65536 + c(a or 255) * 16777216)
end

-- window rectangle inside a cell, in cell-local pixels (top-left origin)
local function windowRect(st: Style): (number, number, number, number)
	return st.pier, st.head, CELL - 1 - st.pier, CELL - 1 - st.spandrel
end

local function wallColor(st: Style, x: number, y: number, rand: () -> number): (number, number, number)
	local w = st.wall
	local n = (rand() - 0.5) * 2 * st.wallNoise
	local r, g, b = w[1] + n, w[2] + n, w[3] + n
	if st.pattern == "brick" then
		local row = y // 4
		local offset = if row % 2 == 0 then 0 else 4
		if y % 4 == 3 or (x + offset) % 8 == 0 then
			r, g, b = 150 + n * 0.3, 136 + n * 0.3, 122 + n * 0.3 -- mortar
		else
			local tone = ((x + offset) // 8 * 7 + row * 13) % 5 - 2
			r, g, b = r + tone * 4, g + tone * 2, b + tone * 2
		end
	elseif st.pattern == "stone" then
		if y % 16 == 15 or (x % 32 == 0 and (y // 16) % 2 == 0) or ((x + 16) % 32 == 0 and (y // 16) % 2 == 1) then
			r, g, b = r - 18, g - 18, b - 16 -- block joints
		end
	elseif st.pattern == "panel" then
		if x % CELL == 0 or y % CELL == 0 then
			r, g, b = r - 14, g - 14, b - 12 -- panel seams
		end
	end
	return r, g, b
end

--[[
	color + emissive for one lighting mood
	warm: mostly warm interiors; busy: more rooms lit
]]
function FacadeTex.generate(styleName: string, warm: boolean, busy: boolean): (buffer, buffer)
	local st: Style = FacadeTex.STYLES[styleName] or FacadeTex.STYLES.panel
	local N = FacadeTex.SIZE
	local color = buffer.create(N * N * 4)
	local emissive = buffer.create(N * N * 4)
	local rand = rng(hashSeed(styleName, warm, busy))
	local x0, y0, x1, y1 = windowRect(st)

	-- background wall
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local r, g, b = wallColor(st, x, y, rand)
			-- slab line where the floor plate meets the facade
			local cy = y % CELL
			if st.pattern == "plain" and cy >= y1 + 1 then
				r, g, b = 28, 32, 42
			end
			put(color, x, y, r, g, b)
			put(emissive, x, y, 0, 0, 0)
		end
	end

	local litChance = if busy then 0.5 else 0.28
	for row = 0, FacadeTex.ROWS - 1 do
		local floorOn = rand() < (if busy then 0.22 else 0.1) -- whole floor still working
		local floorOff = rand() < 0.18
		for col = 0, FacadeTex.COLS - 1 do
			local lit = if floorOn then rand() < 0.9 elseif floorOff then rand() < 0.05 else rand() < litChance
			local palette = if (rand() < 0.8) == warm then WARM else COOL
			local tint = palette[1 + math.floor(rand() * #palette)]
			local bright = 0.5 + rand() * 0.5
			local blinds = rand() < 0.3
			local furniture = rand() < 0.35
			local tvBlue = not lit and rand() < 0.04 -- the odd TV glow in a dark room
			local gx, gy = col * CELL, row * CELL
			for y = y0, y1 do
				for x = x0, x1 do
					local px, py = gx + x, gy + y
					local edge = x == x0 or x == x1 or y == y0 or y == y1
					if edge then
						local f = st.frame
						put(color, px, py, f[1], f[2], f[3])
					else
						local v = (y - y0) / math.max(1, y1 - y0) -- 0 top .. 1 bottom
						if lit or tvBlue then
							local k = bright * (1 - 0.45 * v) -- ceiling light falls off downwards
							local tr, tg, tb = tint[1], tint[2], tint[3]
							if tvBlue then
								tr, tg, tb, k = 90, 130, 255, 0.35
							end
							if blinds and (y - y0) % 3 == 0 then
								k *= 0.55
							end
							if furniture and v > 0.68 and ((x - x0) // 5) % 3 ~= 1 then
								k *= 0.35 -- desks / sofa silhouettes
							end
							-- mullion in the middle of wide panes
							if (x1 - x0) > 20 and x == (x0 + x1) // 2 then
								local f = st.frame
								put(color, px, py, f[1], f[2], f[3])
								continue
							end
							put(color, px, py, tr * k, tg * k, tb * k)
							local e = 255 * k
							put(emissive, px, py, e, e, e)
						else
							local g = st.glass
							local sky = st.sky * (1 - v) + (rand() - 0.5) * 3
							put(color, px, py, g[1] + sky, g[2] + sky, g[3] + sky * 1.3)
						end
					end
				end
			end
			-- stone / brick: sill under each window
			if st.pattern == "stone" or st.pattern == "brick" then
				for x = x0 - 1, x1 + 1 do
					put(color, gx + x, gy + y1 + 1, st.wall[1] + 26, st.wall[2] + 24, st.wall[3] + 22)
				end
			end
		end
	end
	return color, emissive
end

-- normal / roughness / metalness for a style (shared by every mood)
function FacadeTex.surface(styleName: string): (buffer, buffer, buffer)
	local st: Style = FacadeTex.STYLES[styleName] or FacadeTex.STYLES.panel
	local N = FacadeTex.SIZE
	local normal = buffer.create(N * N * 4)
	local rough = buffer.create(N * N * 4)
	local metal = buffer.create(N * N * 4)
	local x0, y0, x1, y1 = windowRect(st)
	for y = 0, N - 1 do
		for x = 0, N - 1 do
			local cx, cy = x % CELL, y % CELL
			local inside = cx >= x0 and cx <= x1 and cy >= y0 and cy <= y1
			local nx, ny = 128, 128
			if inside then
				-- recess bevel: the reveal around each pane faces inward
				if cx == x0 then
					nx = 200
				elseif cx == x1 then
					nx = 56
				end
				if cy == y0 then
					ny = 56
				elseif cy == y1 then
					ny = 200
				end
			elseif st.pattern == "brick" and (y % 4 == 3) then
				ny = 150 -- mortar grooves
			end
			put(normal, x, y, nx, ny, 255)
			local frameEdge = inside and (cx == x0 or cx == x1 or cy == y0 or cy == y1)
			local r = if inside and not frameEdge then st.glassRough elseif frameEdge then 110 else st.wallRough
			local m = if inside and not frameEdge then st.glassMetal elseif frameEdge then st.frameMetal else 0
			put(rough, x, y, r, r, r)
			put(metal, x, y, m, m, m)
		end
	end
	return normal, rough, metal
end

-- studs covered by one tile horizontally for a given window module
function FacadeTex.tileStudsU(module: number): number
	return module * FacadeTex.COLS
end

function FacadeTex.tileStudsV(): number
	return FacadeTex.FLOOR_STUDS * FacadeTex.ROWS
end

return FacadeTex
