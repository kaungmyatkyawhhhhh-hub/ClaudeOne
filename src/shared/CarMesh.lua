--[[
	CarMesh
	Procedural car bodywork as real meshes. Pure geometry (only Vector3), so the
	exact same code runs in Roblox and in offline tools.

	Every car in the roster has its own design (Cars.lua id -> DESIGNS below):
	plan shape, hood / deck lines, fender haunches, character lines, cabin
	shape, grille, headlight and taillight signatures, intakes, vents, wings,
	exhausts and wheels.

	How the body is built
	  * Lengthwise lines (plan width, sill, character line, shoulder, hood /
	    deck edge, hood centre, roof line) are functions of z shaped by each
	    design: wedge or upright nose, hood rake, fender haunches that always
	    clear the wheels, widebody flares, ducktail, fastback / notchback.
	  * At every station a hard-edged cross section is built from those lines
	    (sill, rocker, character line, shoulder, top edge, belt, side glass,
	    roof rail, roof) and the sections are lofted. Every section point is a
	    crease, so panels stay crisp; panels between creases bulge slightly.
	    Over each wheel the lower points ride over the arch, cutting the
	    wheel openings.
	  * Bands of the loft become paint, glass, pillars, roof, sill trim.
	  * Details are patches projected onto the finished shell (ray cast from
	    the front, rear, side or top): grilles, lamp housings, LED
	    signatures, intakes, side scoops, vents, louvres, shut lines,
	    liveries, plates. Wings, mirrors, exhausts, splitter and diffuser
	    fins are solid parts; wheels are built separately.

	Output: { [layerName] = { verts, normals, tris } } where tris is a flat
	index list. Each layer becomes one MeshPart with its own material:
	  Paint, Accent, Trim (black), Chrome, Glass, Lamp (white LEDs),
	  Tail (red LEDs), Plate, Interior
	Coordinates match CarBuilder: origin at ground centre, -Z forward, +Y up.
]]

local CarMesh = {}

export type Layer = { verts: { Vector3 }, normals: { Vector3 }, tris: { number } }
export type Layers = { [string]: Layer }

local V3 = Vector3.new
local UP = V3(0, 1, 0)

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
local function sstep(e0: number, e1: number, x: number): number
	local t = clamp01((x - e0) / (e1 - e0))
	return t * t * (3 - 2 * t)
end

---------------------------------------------------------------------
-- Mesh building
---------------------------------------------------------------------
local function getLayer(layers: Layers, name: string): Layer
	local L = layers[name]
	if not L then
		L = { verts = {}, normals = {}, tris = {} }
		layers[name] = L
	end
	return L
end

local function addVert(L: Layer, p: Vector3, n: Vector3): number
	local i = #L.verts + 1
	L.verts[i] = p
	L.normals[i] = n
	return i
end

-- triangle wound so its face normal agrees with the vertex normals
local function addTri(L: Layer, a: number, b: number, c: number)
	local va, vb, vc = L.verts[a], L.verts[b], L.verts[c]
	local fn = (vb - va):Cross(vc - va)
	if fn.Magnitude < 1e-9 then
		return
	end
	if fn:Dot(L.normals[a] + L.normals[b] + L.normals[c]) < 0 then
		a, c = c, a
	end
	local t = L.tris
	t[#t + 1] = a
	t[#t + 1] = b
	t[#t + 1] = c
end

local function mirrorX(v: Vector3): Vector3
	return V3(-v.X, v.Y, v.Z)
end

type Grid = { { any } } -- Vector3, or false for a missing sample

-- normals of a sampled surface by central differences, oriented by a hint
local function gridNormals(pts: Grid, hint: (r: number, c: number, p: Vector3) -> Vector3): Grid
	local rows, cols = #pts, #pts[1]
	local out = {}
	for r = 1, rows do
		local row = {}
		for c = 1, cols do
			local du = pts[r][math.min(c + 1, cols)] - pts[r][math.max(c - 1, 1)]
			local dv = pts[math.min(r + 1, rows)][c] - pts[math.max(r - 1, 1)][c]
			local h = hint(r, c, pts[r][c])
			local n = du:Cross(dv)
			if du.Magnitude < 1e-6 or dv.Magnitude < 1e-6 or n.Magnitude < 1e-9 then
				n = h
			else
				n = n.Unit
				if n:Dot(h) < 0 then
					n = -n
				end
			end
			-- on the mirror plane the true normal has no sideways component
			if math.abs(pts[r][c].X) < 1e-4 and math.abs(n.X) < 0.9 then
				n = V3(0, n.Y, n.Z)
				n = if n.Magnitude > 1e-6 then n.Unit else h
			end
			row[c] = n
		end
		out[r] = row
	end
	return out
end

-- quads of a grid; pick(r, c) may route individual quads to other layers
local function addGrid(layers: Layers, name: string, pts: Grid, nrm: Grid, mirror: boolean, pick: ((r: number, c: number) -> any)?)
	local rows, cols = #pts, #pts[1]
	for pass = 1, if mirror then 2 else 1 do
		-- vertices are created lazily per layer so a routed quad gets its own copies
		local index: { [string]: { [number]: number } } = {}
		local function vid(L: Layer, lname: string, r: number, c: number): number
			local map = index[lname]
			if not map then
				map = {}
				index[lname] = map
			end
			local key = (r - 1) * cols + c
			local id = map[key]
			if not id then
				local p, n = pts[r][c], nrm[r][c]
				if pass == 2 then
					p, n = mirrorX(p), mirrorX(n)
				end
				id = addVert(L, p, n)
				map[key] = id
			end
			return id
		end
		for r = 1, rows - 1 do
			for c = 1, cols - 1 do
				if not (pts[r][c] and pts[r][c + 1] and pts[r + 1][c] and pts[r + 1][c + 1]) then
					continue
				end
				local picked = if pick then pick(r, c) else nil
				if picked == false then
					continue
				end
				local lname = picked or name
				local L = getLayer(layers, lname)
				local a = vid(L, lname, r, c)
				local b = vid(L, lname, r, c + 1)
				local d = vid(L, lname, r + 1, c)
				local e = vid(L, lname, r + 1, c + 1)
				addTri(L, a, b, e)
				addTri(L, a, e, d)
			end
		end
	end
end

-- a parametric patch F(a, b), a in [a0, a1], b in [lo(a), hi(a)], lifted along its normal
local function patch(
	layers: Layers,
	name: string,
	F: (number, number) -> (Vector3?, Vector3?),
	a0: number,
	a1: number,
	range: (number) -> (number, number),
	na: number,
	nb: number,
	lift: number,
	mirror: boolean,
	hint: (Vector3) -> Vector3
)
	local pts: Grid = {}
	local nrm: Grid = {}
	local eps = 0.01
	for j = 0, nb do
		pts[j + 1] = {}
		nrm[j + 1] = {}
	end
	for i = 0, na do
		local a = lerp(a0, a1, i / na)
		local lo, hi = range(a)
		for j = 0, nb do
			local b = lerp(lo, hi, j / nb)
			local p, n = F(a, b)
			if not p then
				pts[j + 1][i + 1] = false
				nrm[j + 1][i + 1] = false
				continue
			end
			if not n then
				local pa, pb, pc, pd = F(a + eps, b), F(a - eps, b), F(a, b + eps), F(a, b - eps)
				if pa and pb and pc and pd then
					n = (pa - pb):Cross(pc - pd)
				end
			end
			local h = hint(p)
			n = if n and n.Magnitude > 1e-9 then n.Unit else h
			if n:Dot(h) < 0 then
				n = -n
			end
			pts[j + 1][i + 1] = p + n * lift
			nrm[j + 1][i + 1] = n
		end
	end
	addGrid(layers, name, pts, nrm, mirror)
end

-- a band of width w following a path through F's parameter space
local function stroke(layers: Layers, name: string, F: (number, number) -> (Vector3?, Vector3?), path: { Vector3 }, w: number, lift: number, mirror: boolean, hint: (Vector3) -> Vector3, samples: number?)
	-- path points use X, Y as the two parameters; resample by length
	local lens = { 0 }
	for i = 2, #path do
		lens[i] = lens[i - 1] + (path[i] - path[i - 1]).Magnitude
	end
	local total = lens[#path]
	if total <= 0 then
		return
	end
	local function at(d: number): (Vector3, Vector3)
		local k = 2
		while k < #path and lens[k] < d do
			k += 1
		end
		local seg = path[k] - path[k - 1]
		local f = if lens[k] > lens[k - 1] then (d - lens[k - 1]) / (lens[k] - lens[k - 1]) else 0
		local p = path[k - 1] + seg * clamp01(f)
		local dir = if seg.Magnitude > 1e-9 then seg.Unit else V3(1, 0, 0)
		return p, V3(-dir.Y, dir.X, 0)
	end
	local n = samples or math.max(2, math.ceil(total / 0.08))
	local G = function(a: number, b: number): (Vector3?, Vector3?)
		local p, perp = at(a)
		local q = p + perp * b
		return F(q.X, q.Y)
	end
	patch(layers, name, G, 0, total, function()
		return -w / 2, w / 2
	end, n, 1, lift, mirror, hint)
end

-- closed box with flat faces (cf: centre frame, size)
local function box(layers: Layers, name: string, cf: CFrame, size: Vector3, mirror: boolean, inward: boolean?)
	local L = getLayer(layers, name)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local faces = {
		{ V3(1, 0, 0), V3(0, 1, 0), V3(0, 0, 1), hx, hy, hz },
		{ V3(-1, 0, 0), V3(0, 1, 0), V3(0, 0, 1), hx, hy, hz },
		{ V3(0, 1, 0), V3(1, 0, 0), V3(0, 0, 1), hy, hx, hz },
		{ V3(0, -1, 0), V3(1, 0, 0), V3(0, 0, 1), hy, hx, hz },
		{ V3(0, 0, 1), V3(1, 0, 0), V3(0, 1, 0), hz, hx, hy },
		{ V3(0, 0, -1), V3(1, 0, 0), V3(0, 1, 0), hz, hx, hy },
	}
	for pass = 1, if mirror then 2 else 1 do
		for _, f in faces do
			local n, a, b, d, ea, eb = f[1], f[2], f[3], f[4], f[5], f[6]
			local ids = {}
			for _, s in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
				local lp = n * d + a * (s[1] * ea) + b * (s[2] * eb)
				local p = cf:PointToWorldSpace(lp)
				local wn = cf:VectorToWorldSpace(if inward then -n else n)
				if pass == 2 then
					p, wn = mirrorX(p), mirrorX(wn)
				end
				table.insert(ids, addVert(L, p, wn))
			end
			addTri(L, ids[1], ids[2], ids[3])
			addTri(L, ids[1], ids[3], ids[4])
		end
	end
end

-- surface of revolution around the local X axis: profile = {(x, r)} as Vector3(x, r, 0)
local function revolve(layers: Layers, name: string, cf: CFrame, profile: { Vector3 }, segs: number, mirror: boolean, inward: boolean?)
	local pts: Grid = {}
	for i, q in profile do
		local row = {}
		for k = 0, segs do
			local a = k / segs * math.pi * 2
			row[k + 1] = cf:PointToWorldSpace(V3(q.X, q.Y * math.cos(a), q.Y * math.sin(a)))
		end
		pts[i] = row
	end
	local axisO = cf.Position
	local axisD = cf.RightVector
	local nrm = gridNormals(pts, function(_, _, p)
		local rel = p - axisO
		local radial = rel - axisD * rel:Dot(axisD)
		local h = if radial.Magnitude > 1e-6 then radial.Unit else axisD
		return if inward then -h else h
	end)
	addGrid(layers, name, pts, nrm, mirror)
end

-- flat annulus (or disc) in the local YZ plane facing local +X (or -X)
local function annulus(layers: Layers, name: string, cf: CFrame, r0: number, r1: number, segs: number, facing: number, mirror: boolean)
	local profile = { V3(0, r0, 0), V3(0, r1, 0) }
	local pts: Grid = {}
	for i, q in profile do
		local row = {}
		for k = 0, segs do
			local a = k / segs * math.pi * 2
			row[k + 1] = cf:PointToWorldSpace(V3(q.X, q.Y * math.cos(a), q.Y * math.sin(a)))
		end
		pts[i] = row
	end
	local n = cf.RightVector * facing
	local nrm: Grid = {}
	for i = 1, #pts do
		nrm[i] = table.create(#pts[i], n)
	end
	addGrid(layers, name, pts, nrm, mirror)
end

-- extrude a closed 2D profile (X = local Y, Y = local Z ... given as Vector3(y, z)) along local X from x0 to x1
local function extrude(layers: Layers, name: string, cf: CFrame, profile: { Vector3 }, x0: number, x1: number, mirror: boolean)
	local L = getLayer(layers, name)
	for pass = 1, if mirror then 2 else 1 do
		local function P(x: number, q: Vector3): Vector3
			local p = cf:PointToWorldSpace(V3(x, q.X, q.Y))
			return if pass == 2 then mirrorX(p) else p
		end
		local function N(v: Vector3): Vector3
			local n = cf:VectorToWorldSpace(v)
			return if pass == 2 then mirrorX(n) else n
		end
		local m = #profile
		local cx, cy = 0, 0
		for _, q in profile do
			cx += q.X / m
			cy += q.Y / m
		end
		for i = 1, m do
			local q0, q1 = profile[i], profile[i % m + 1]
			local e = q1 - q0
			local out = V3(0, e.Y, -e.X).Unit -- local (x, y, z) with the edge in the y/z plane
			local mid = (q0 + q1) / 2
			if out.Y * (mid.X - cx) + out.Z * (mid.Y - cy) < 0 then
				out = -out
			end
			local n = N(out)
			local a = addVert(L, P(x0, q0), n)
			local b = addVert(L, P(x0, q1), n)
			local c = addVert(L, P(x1, q1), n)
			local d = addVert(L, P(x1, q0), n)
			addTri(L, a, b, c)
			addTri(L, a, c, d)
		end
		for _, side in { { x0, -1 }, { x1, 1 } } do
			local n = N(V3(side[2], 0, 0))
			local c0 = addVert(L, P(side[1], V3(cx, cy, 0)), n)
			local ids = {}
			for i = 1, m do
				ids[i] = addVert(L, P(side[1], profile[i]), n)
			end
			for i = 1, m do
				addTri(L, c0, ids[i], ids[i % m + 1])
			end
		end
	end
end

-- ellipsoid (for mirrors, light pods)
local function ellipsoid(layers: Layers, name: string, cf: CFrame, radii: Vector3, segs: number, mirror: boolean)
	local pts: Grid = {}
	for i = 0, segs do
		local th = i / segs * math.pi
		local row = {}
		for k = 0, segs * 2 do
			local ph = k / (segs * 2) * math.pi * 2
			local v = V3(math.cos(th), math.sin(th) * math.cos(ph), math.sin(th) * math.sin(ph))
			row[k + 1] = cf:PointToWorldSpace(v * radii)
		end
		pts[i + 1] = row
	end
	local nrm = gridNormals(pts, function(_, _, p)
		return (p - cf.Position).Unit
	end)
	addGrid(layers, name, pts, nrm, mirror)
end

local function smax(a: number, b: number, k: number): number
	return (a + b + math.sqrt((a - b) ^ 2 + k * k)) / 2
end

---------------------------------------------------------------------
-- Designs
---------------------------------------------------------------------
type Design = { [string]: any }

--[[
	Heights are absolute studs unless noted; *F values are fractions.
	nose*/tail*: the very tip of the car (its front / rear face)
	  H top, B bottom, W half-width fraction, Len how far back the plan
	  rounds off, Pow 1 = sharp chamfer .. 2 = round corner
	beltF   : edge of the hood / deck at the windscreen (P5 line)
	cowlDrop: hood centre below its edges (+ = valley / V-hood, - = crown)
	shoulderDrop: side crease below the top edge
	tumble / topIn / tuck: insets of the shoulder, top edge and sill
	tumbleG: how far the side glass leans in at the roof
]]
local function classDefaults(class: string, D: { [string]: number }): Design
	local clr, belt = D.clr, D.belt
	if class == "Supercar" or class == "Hypercar" then
		local hyper = class == "Hypercar"
		return {
			noseH = clr + 0.55, noseB = clr + 0.12, noseW = 0.68, noseLen = 1.4, nosePow = 1.4, faceLen = 0.5,
			hoodK = 1.35, beltF = belt + 0.02, cowlDrop = 0.1, shoulderDrop = 0.42, midF = 0.5,
			tumble = 0.22, topIn = 0.42, tuck = 0.3,
			tailH = belt + 0.1, tailB = clr + 0.35, tailW = 0.9, tailLen = 0.9, tailPow = 1.6, tailFace = 0.7,
			deckH = belt + 0.08, ducktail = 0.08, tailK = 1,
			roofSag = 0.08, wsK = 1.25, fastK = 1.05, tumbleG = 0.62, roofCrown = 0.16,
			flareF = 0.08, flareR = 0.2, waist = if hyper then 0.28 else 0.22, fenderF = 0.12, fenderR = 0.1,
			rimFrac = if hyper then 0.78 else 0.76, wheel = if hyper then "turbine" else "y5",
			rim = { 30, 30, 34 }, caliper = { 230, 170, 10 }, exhaust = if hyper then "center" else "quad",
			grille = "none", head = "y", tailLamp = if hyper then "bar" else "y",
			skirt = true, splitter = true, diffuser = true, sideIntake = true, louvres = true, hoodVents = true,
			chromeDLO = false, plate = not hyper, mid = true, fourDoor = false, blackPillars = true,
			wing = if hyper then "big" else "none",
		}
	elseif class == "SUV" then
		return {
			noseH = belt - 0.32, noseB = clr + 0.35, noseW = 0.9, noseLen = 1.0, nosePow = 2, faceLen = 0.7,
			hoodK = 2.4, beltF = belt + 0.02, cowlDrop = -0.08, shoulderDrop = 0.3, midF = 0.45,
			tumble = 0.12, topIn = 0.3, tuck = 0.22,
			tailH = belt + 0.02, tailB = clr + 0.3, tailW = 0.92, tailLen = 0.8, tailPow = 2, tailFace = 0.4,
			deckH = belt + 0.02, ducktail = 0, tailK = 1,
			roofSag = 0.05, wsK = 1.3, fastK = 1, tumbleG = 0.3, roofCrown = 0.1,
			flareF = 0.08, flareR = 0.08, waist = 0, fenderF = 0, fenderR = 0,
			rimFrac = 0.7, wheel = "six", rim = { 190, 192, 196 }, caliper = { 40, 40, 44 }, exhaust = "dual",
			grille = "suv", head = "slim", tailLamp = "split", skirt = false, splitter = false, diffuser = true,
			chromeDLO = true, plate = true, mid = false, fourDoor = true, rails = true,
		}
	end
	local coupe = class == "Coupe"
	return {
		noseH = belt - (if coupe then 0.5 else 0.42), noseB = clr + 0.25, noseW = 0.86, noseLen = 1.1, nosePow = 2, faceLen = 0.55,
		hoodK = 1.6, beltF = belt + 0.02, cowlDrop = -0.06, shoulderDrop = 0.3, midF = 0.5,
		tumble = 0.13, topIn = 0.32, tuck = 0.26,
		tailH = belt + 0.04, tailB = clr + 0.3, tailW = 0.88, tailLen = 0.95, tailPow = 2, tailFace = 0.55,
		deckH = belt + 0.04, ducktail = if coupe then 0.1 else 0.05, tailK = 1,
		roofSag = 0.1, wsK = 1.4, fastK = if coupe then 1.25 else 1, tumbleG = if coupe then 0.5 else 0.42, roofCrown = 0.12,
		flareF = if coupe then 0.08 else 0.04, flareR = if coupe then 0.1 else 0.05, waist = 0, fenderF = 0, fenderR = 0,
		rimFrac = if coupe then 0.72 else 0.68, wheel = if coupe then "five" else "twin5",
		rim = { 200, 202, 206 }, caliper = { 40, 40, 44 }, exhaust = "dual",
		grille = "wide", head = "sweep", tailLamp = "split", skirt = coupe, splitter = coupe, diffuser = coupe,
		chromeDLO = not coupe, plate = true, mid = false, fourDoor = not coupe,
	}
end

-- per-car styling (keys override the class defaults)
local DESIGNS: { [string]: Design } = {
	aurelia_s4 = {},
	meridian_lx = { grille = "upright", head = "slim", tailLamp = "bar", wheel = "multi", rim = { 210, 212, 216 }, noseW = 0.9, hoodK = 2.0 },
	kensho_m5 = {
		grille = "kidney", head = "angel", tailLamp = "split", wheel = "y5", rim = { 34, 34, 38 }, caliper = { 20, 80, 220 },
		exhaust = "quad", skirt = true, splitter = true, diffuser = true, flareF = 0.1, flareR = 0.12, ducktail = 0.1, chromeDLO = false,
	},
	-- late-90s JDM coupe: upright nose, boxy body, quad round tail lamps, wing, livery
	strada_c2 = {
		noseW = 0.93, noseLen = 0.55, nosePow = 2, faceLen = 0.35, noseH = 2.12, noseB = 0.75, hoodK = 2.6, cowlDrop = -0.03,
		shoulderDrop = 0.22, tumble = 0.08, topIn = 0.22, tailW = 0.94, tailLen = 0.55, tailFace = 0.35, tailH = 2.55,
		grille = "jdm", head = "jdm", tailLamp = "rings", wheel = "six", rim = { 26, 26, 30 }, caliper = { 200, 30, 30 },
		wing = "gt", livery = "stripes", flareF = 0.06, flareR = 0.08, fastK = 1.05, tumbleG = 0.4, roofSag = 0.06,
	},
	-- widebody GT: huge bolt-on flares, big mesh grille, carbon hood, wing
	kaizen_rz = {
		noseW = 0.84, noseLen = 1.2, noseH = 1.95, noseB = 0.62, hoodK = 1.5, cowlDrop = -0.04,
		grille = "gt", head = "angular", tailLamp = "rings", wheel = "multi", rim = { 22, 22, 26 }, caliper = { 210, 40, 30 },
		wing = "gt", accentHood = true, flareF = 0.34, flareR = 0.4, skirt = true, splitter = true, diffuser = true, exhaust = "quad",
		fastK = 1.35, tumbleG = 0.55, rimFrac = 0.74,
	},
	atlas_x7 = {},
	monolith_gt = {
		grille = "hex", head = "y", tailLamp = "y", wheel = "multi", rim = { 26, 26, 30 }, caliper = { 255, 180, 0 },
		fastK = 1.5, exhaust = "quad", skirt = true, splitter = true, flareF = 0.16, flareR = 0.18, rails = false, chromeDLO = false,
		hoodVents = true, noseH = 3.15, cowlDrop = 0.04,
	},
	vortex_v10 = { head = "y", tailLamp = "y", wheel = "y5", rim = { 28, 28, 32 }, caliper = { 255, 200, 0 } },
	-- V12 wedge: knife nose, faceted V hood, Y lamps, huge side scoops, wing
	spectre_720 = {
		noseH = 0.86, noseB = 0.48, noseW = 0.66, noseLen = 1.45, nosePow = 1.1, hoodK = 1.15, cowlDrop = 0.18,
		shoulderDrop = 0.5, topIn = 0.5, tumble = 0.28, tuck = 0.36, flareR = 0.24, waist = 0.3,
		head = "y", tailLamp = "y", wheel = "y5", rim = { 18, 18, 20 }, caliper = { 255, 120, 20 },
		wing = "big", roofLayer = "Trim", exhaust = "center", tailFace = 0.9, tailB = 0.85,
	},
	rosso_f8 = {
		head = "slim", tailLamp = "rings", wheel = "multi", rim = { 70, 72, 78 }, caliper = { 255, 205, 0 },
		exhaust = "quad", ducktail = 0.16, louvres = false, nosePow = 1.8, noseW = 0.68, cowlDrop = 0.04,
	},
	phantom_w16 = {
		grille = "horseshoe", head = "quad", tailLamp = "bar", wheel = "turbine", rim = { 175, 178, 186 }, caliper = { 20, 40, 120 },
		cline = true, roofLayer = "Accent", wing = "none", ducktail = 0.1, noseW = 0.7, nosePow = 1.8, cowlDrop = 0.04, blackPillars = false,
	},
	eclipse_jx = { head = "slim", tailLamp = "bar", wheel = "multi", rim = { 22, 22, 26 }, caliper = { 150, 60, 255 }, wing = "big", stripe = true },
}

function CarMesh.design(id: string, class: string, D: { [string]: number }): Design
	local d = classDefaults(class, D)
	local over = DESIGNS[id]
	if over then
		for k, v in over do
			d[k] = v
		end
	end
	d.class = class
	return d
end

---------------------------------------------------------------------
-- Projection of details onto the body (ray cast against the shell)
---------------------------------------------------------------------
type Tri = { a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3 }
local CELL = 0.3

local function projector(tris: { Tri }, axis: string): (number, number) -> (Vector3?, Vector3?)
	-- axis: "front" (look along +Z), "rear" (-Z), "side" (from +X), "top" (from +Y)
	local function uvd(p: Vector3): (number, number, number)
		if axis == "front" then
			return p.X, p.Y, -p.Z
		elseif axis == "rear" then
			return p.X, p.Y, p.Z
		elseif axis == "side" then
			return p.Z, p.Y, p.X
		end
		return p.X, p.Z, p.Y
	end
	local bins: { [number]: { Tri } } = {}
	local function key(i: number, j: number): number
		return (i + 2000) * 4000 + (j + 2000)
	end
	for _, t in tris do
		local ua, va = uvd(t.a)
		local ub, vb = uvd(t.b)
		local uc, vc = uvd(t.c)
		for i = math.floor(math.min(ua, ub, uc) / CELL), math.floor(math.max(ua, ub, uc) / CELL) do
			for j = math.floor(math.min(va, vb, vc) / CELL), math.floor(math.max(va, vb, vc) / CELL) do
				local k = key(i, j)
				local list = bins[k]
				if not list then
					list = {}
					bins[k] = list
				end
				table.insert(list, t)
			end
		end
	end
	return function(u: number, v: number): (Vector3?, Vector3?)
		local list = bins[key(math.floor(u / CELL), math.floor(v / CELL))]
		if not list then
			return nil, nil
		end
		local best, bestP, bestN = -math.huge, nil, nil
		for _, t in list do
			local ua, va, da = uvd(t.a)
			local ub, vb, db = uvd(t.b)
			local uc, vc, dc = uvd(t.c)
			local det = (vb - vc) * (ua - uc) + (uc - ub) * (va - vc)
			if math.abs(det) > 1e-10 then
				local l1 = ((vb - vc) * (u - uc) + (uc - ub) * (v - vc)) / det
				local l2 = ((vc - va) * (u - uc) + (ua - uc) * (v - vc)) / det
				local l3 = 1 - l1 - l2
				if l1 >= -1e-6 and l2 >= -1e-6 and l3 >= -1e-6 then
					local d = l1 * da + l2 * db + l3 * dc
					if d > best then
						best = d
						bestP = t.a * l1 + t.b * l2 + t.c * l3
						bestN = (t.na * l1 + t.nb * l2 + t.nc * l3)
					end
				end
			end
		end
		if bestN and bestN.Magnitude > 1e-6 then
			bestN = bestN.Unit
		end
		return bestP, bestN
	end
end

---------------------------------------------------------------------
-- Car
---------------------------------------------------------------------
type Dims = { [string]: number }

function CarMesh.build(id: string, class: string, D: Dims, lite: boolean?): Layers
	local ds = CarMesh.design(id, class, D)
	local layers: Layers = {}
	local L, W, H = D.L, D.W, D.H
	local hw = W / 2
	local zF, zB = -L / 2, L / 2
	local clr, belt = D.clr, D.belt
	local zWs = zF + D.hood
	local zWsTop = zWs + D.ws
	local zRoofEnd = zWsTop + D.roof
	local zRearEnd = zRoofEnd + D.rear
	local isSuper = class == "Supercar" or class == "Hypercar"
	local roofLayer = ds.roofLayer or (if ds.accentRoof then "Accent" else "Paint")
	local pillarLayer = if ds.blackPillars then "Trim" else roofLayer
	local res = if lite then 0.5 else 1
	local function n(k: number): number
		return math.max(2, math.floor(k * res + 0.5))
	end

	-- wheels (must match CarBuilder)
	local R = D.wheelR
	local wheels = {}
	for _, front in { true, false } do
		local rr = if isSuper and not front then R * 1.04 else R
		table.insert(wheels, { z = if front then -D.wb / 2 else D.wb / 2, cy = rr, r = rr, arch = rr + 0.14, xin = hw - D.wheelW - 0.2, front = front })
	end
	local function archY(z: number): number
		local y = -math.huge
		for _, w in wheels do
			local dz = z - w.z
			if math.abs(dz) < w.arch then
				y = math.max(y, w.cy + math.sqrt(w.arch * w.arch - dz * dz))
			end
		end
		return y
	end
	-- top of the fender over each wheel must clear the arch
	local function archClear(z: number): number
		local y = -100
		for _, w in wheels do
			local dz = (z - w.z) / (w.arch * 2.0)
			if dz * dz < 1 then
				y = math.max(y, w.cy + 0.3 + w.arch * (1 - dz * dz) ^ 1.4)
			end
		end
		return y
	end
	local function bump(z: number, front: boolean, width: number): number
		local w = wheels[if front then 1 else 2]
		local d = (z - w.z) / (w.arch * width)
		return if d * d < 1 then (math.cos(d * math.pi) + 1) / 2 else 0
	end
	local function flareAt(z: number): number
		return math.max(ds.flareF * bump(z, true, 1.55), ds.flareR * bump(z, false, 1.55))
	end

	-----------------------------------------------------------------
	-- Lengthwise lines
	-----------------------------------------------------------------
	local tipW, tailW = hw * ds.noseW, hw * ds.tailW
	local function planW(z: number): number
		local e = clamp01((z - zF) / ds.noseLen)
		local wF = tipW + (hw - tipW) * (1 - (1 - e) ^ ds.nosePow) ^ (1 / math.max(1, ds.nosePow * 0.75))
		local r = clamp01((zB - z) / ds.tailLen)
		local wR = tailW + (hw - tailW) * (1 - (1 - r) ^ ds.tailPow) ^ (1 / math.max(1, ds.tailPow * 0.75))
		return math.min(wF, wR)
	end
	local function yBot(z: number): number
		local f = sstep(0, ds.faceLen, z - zF)
		local r = sstep(0, ds.tailFace, zB - z)
		return math.max(lerp(ds.noseB, clr + 0.04, f), lerp(ds.tailB, clr + 0.04, r))
	end
	-- top edge of the body (hood / deck edge), without the wheel humps
	local function edgeLine(z: number): number
		if z <= zWs then
			local t = clamp01((z - zF) / (zWs - zF))
			return ds.noseH + (ds.beltF - ds.noseH) * (1 - (1 - t) ^ ds.hoodK)
		elseif z <= zRearEnd then
			return lerp(ds.beltF, ds.deckH, (z - zWs) / (zRearEnd - zWs))
		end
		local t = clamp01((z - zRearEnd) / (zB - zRearEnd))
		return lerp(ds.deckH, ds.tailH, t ^ ds.tailK) + ds.ducktail * sstep(0.55, 1, t)
	end
	local function yEdge(z: number): number
		local y = edgeLine(z) + ds.fenderF * bump(z, true, 1.7) + ds.fenderR * bump(z, false, 1.7)
		return smax(y, archClear(z), 0.25)
	end
	-- hood / deck centre height
	local function yDeck(z: number): number
		local hood = if z < zWs then sstep(zF, zF + 1.2, z) else (if z > zRearEnd then sstep(zB, zB - 1.0, z) else 1)
		return edgeLine(z) - ds.cowlDrop * hood
	end
	-- cabin roof centre height (or nil outside the greenhouse)
	local zRoofA = zWsTop + (if ds.mid then 0.15 elseif class == "SUV" then 0.1 else 0.25)
	local zRoofB = zRoofEnd - (if ds.mid then 0.3 elseif class == "SUV" then 0.15 else 0.55)
	local roofTop = H - 0.02
	local function roofLine(z: number): number?
		if z <= zWs or z >= zRearEnd then
			return nil
		end
		local base = yDeck(z)
		if z < zRoofA then
			local t = (z - zWs) / (zRoofA - zWs)
			return base + (roofTop - base) * (1 - (1 - t) ^ ds.wsK)
		elseif z <= zRoofB then
			local mid, half = (zRoofA + zRoofB) / 2, math.max(0.3, (zRoofB - zRoofA) / 2)
			return roofTop - ds.roofSag * ((z - mid) / half) ^ 2
		end
		local t = (z - zRoofB) / (zRearEnd - zRoofB)
		local top = roofTop - ds.roofSag
		return top - (top - base) * t ^ ds.fastK
	end
	local hwb = hw - D.inset + 0.05 -- glass base half-width
	local hcMax = roofTop - ds.beltF

	-----------------------------------------------------------------
	-- Cross sections (half, x >= 0), each point flagged as a crease
	-----------------------------------------------------------------
	type SecPt = { x: number, y: number, crease: boolean, band: number }
	local function section(z: number): { SecPt }
		local w = planW(z)
		local fl = flareAt(z)
		local yb = yBot(z)
		local ye = yEdge(z)
		local yd = yDeck(z)
		local ys = ye - ds.shoulderDrop * sstep(zF, zF + 1.2, z) * sstep(zB, zB - 0.8, z)
		local ya = archY(z)
		-- lower points ride over the wheel arches
		local y1 = math.max(yb, ya)
		local yLo = math.max(yb + 0.32 * (ys - yb) * 0.6, ya + 0.02)
		local yM = math.max(yb + ds.midF * (ys - yb), ya + 0.08)
		ys = math.max(ys, yM + 0.1)
		ye = math.max(ye, ys + 0.06)
		local xEdge = w - ds.topIn + fl * 0.3
		local xb = math.min(hwb, xEdge - 0.08)
		-- the cabin waist pinches the upper body between the wheels
		local pinch = ds.waist * sstep(wheels[1].z + wheels[1].arch * 0.8, wheels[1].z + wheels[1].arch * 2.2, z) * sstep(wheels[2].z - wheels[2].arch * 0.6, wheels[2].z - wheels[2].arch * 1.8, z)
		local belt0 = lerp(yd, ye, clamp01(xb / math.max(0.1, xEdge)))
		local roof = roofLine(z)
		local hc = if roof then math.max(0, roof - yd) else 0
		local hk = clamp01(hc / math.max(0.3, hcMax))
		local x7 = xb - ds.tumbleG * hk
		local xr = x7 - 0.22 * sstep(0, 0.35, hc)
		local pts: { SecPt } = {
			{ x = 0, y = yb, crease = true, band = 0 },
			{ x = w - ds.tuck + fl * 0.4, y = y1, crease = true, band = 1 },
			{ x = w - ds.tuck * 0.3 + fl * 0.8, y = yLo, crease = true, band = 2 },
			{ x = w + fl, y = yM, crease = true, band = 3 },
			{ x = w - ds.tumble + fl * 0.6 - pinch, y = ys, crease = true, band = 4 },
			{ x = xEdge - pinch * 0.8, y = ye, crease = true, band = 5 },
			{ x = xb - pinch * 0.6, y = belt0, crease = true, band = 6 },
			{ x = x7 - pinch * 0.4, y = belt0 + hc * 0.8, crease = true, band = 7 },
			{ x = xr - pinch * 0.4, y = lerp(yd, belt0, xr / math.max(0.1, xb)) + hc, crease = true, band = 8 },
			{ x = 0, y = yd + hc + ds.roofCrown * hk, crease = true, band = 9 },
		}
		return pts
	end
	-- segment shaping: subdivisions and outward bulge per band
	local SUB = { [0] = 1, [1] = 1, [2] = 2, [3] = 3, [4] = 1, [5] = 2, [6] = 2, [7] = 1, [8] = 4 }
	local BULGE = { [0] = 0, [1] = 0, [2] = 0.02, [3] = 0.05, [4] = 0, [5] = 0.03, [6] = 0.03, [7] = 0, [8] = 0.05 }
	if lite then
		SUB = { [0] = 1, [1] = 1, [2] = 1, [3] = 2, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 2 }
	end
	-- expand a section into grid columns (crease points doubled)
	local function columns(sec: { SecPt }): ({ Vector3 }, { number }, { boolean })
		local out, bands, split = {}, {}, {}
		for i = 1, #sec - 1 do
			local a, b = sec[i], sec[i + 1]
			local k = SUB[a.band] or 1
			local dx, dy = b.x - a.x, b.y - a.y
			local len = math.sqrt(dx * dx + dy * dy)
			local nx, ny = 0, 0
			if len > 1e-6 then
				nx, ny = dy / len, -dx / len
			end
			for j = 0, k do
				local t = j / k
				local bl = (BULGE[a.band] or 0) * math.sin(math.pi * t) * math.min(1, len / 0.6)
				table.insert(out, V3(a.x + dx * t + nx * bl, a.y + dy * t + ny * bl, 0))
				table.insert(bands, a.band)
				table.insert(split, j == 0 or j == k)
			end
		end
		return out, bands, split
	end

	-- stations along the car (denser at the ends)
	local zs = {}
	local count = if lite then 64 else 128
	for i = 0, count do
		local u = i / count
		table.insert(zs, zF + L * (u - 0.6 * math.sin(u * math.pi * 2) / (math.pi * 2)))
	end

	local pts: Grid = {}
	local bandOf: { number } = {}
	local glassZ = {} -- per station: has cabin
	for si, z in zs do
		local sec = section(z)
		local cols, bands = columns(sec)
		for ci, p in cols do
			pts[ci] = pts[ci] or {}
			pts[ci][si] = V3(p.X, p.Y, z)
			bandOf[ci] = bands[ci]
		end
		glassZ[si] = roofLine(z) ~= nil
	end
	-- rows = section columns, cols = stations
	-- orientation hints per band (outward), leaning fore / aft near the ends
	local BAND_DIR = {
		[0] = V3(0, -1, 0), [1] = V3(1, -0.3, 0), [2] = V3(1, 0, 0), [3] = V3(1, 0, 0), [4] = V3(1, 0.6, 0),
		[5] = V3(0.3, 1, 0), [6] = V3(1, 0.6, 0), [7] = V3(0.6, 1, 0), [8] = V3(0, 1, 0), [9] = V3(0, 1, 0),
	}
	local nrm = gridNormals(pts, function(r, _, p)
		local h = BAND_DIR[bandOf[math.min(r, #bandOf)]] or UP
		local endZ = p.Z - math.clamp(p.Z, zF + 1.2, zB - 1.2)
		return (h.Unit + V3(0, 0, endZ * 1.5)).Unit
	end)
	-- per-quad layer choice
	local doorEnd = if ds.fourDoor then zWsTop + D.roof * 0.48 else zRoofEnd - 0.2
	local sideWinEnd = if ds.mid then zRoofEnd - 0.1 elseif class == "SUV" then zRearEnd - 0.25 else zRoofEnd + D.rear * 0.25
	local function pick(r: number, c: number): any
		local band = bandOf[r]
		local z = (zs[c] + zs[c + 1]) / 2
		local roof = roofLine(z)
		local hc = if roof then roof - yDeck(z) else 0
		if pts[r][c] == pts[r + 1][c] and pts[r][c + 1] == pts[r + 1][c + 1] then
			return false
		end
		if band == 0 then
			return "Trim"
		elseif band == 1 then
			return if ds.skirt then "Trim" else nil
		elseif band == 5 or band == 4 then
			if ds.accentHood and z < zWs + 0.05 and band == 5 then
				return "Accent"
			end
			return nil
		elseif band == 6 then
			if hc > 0.04 and z > zWs + 0.05 and z < sideWinEnd then
				if ds.fourDoor and math.abs(z - doorEnd) < 0.16 then
					return "Trim"
				end
				return "Glass"
			end
			if hc > 0.04 then
				return if ds.mid then pillarLayer else roofLayer
			end
			if ds.accentHood and z < zWs then
				return "Accent"
			end
			return nil
		elseif band == 7 then
			if hc > 0.04 then
				return pillarLayer
			end
			if ds.accentHood and z < zWs then
				return "Accent"
			end
			return nil
		elseif band == 8 then
			if hc > 0.04 then
				if z < zRoofA or z > zRoofB then
					return "Glass"
				end
				return roofLayer
			end
			if ds.accentHood and z < zWs then
				return "Accent"
			end
			return nil
		end
		return nil
	end
	addGrid(layers, "Paint", pts, nrm, true, pick)

	-- end caps (flat faces at the very nose and tail)
	for _, endInfo in { { 1, -1 }, { #zs, 1 } } do
		local si, dir = endInfo[1], endInfo[2]
		local ring = {}
		for ci = 1, #pts do
			ring[ci] = pts[ci][si]
		end
		local Lp = getLayer(layers, "Paint")
		local nz = V3(0, 0, dir)
		local cy = 0
		for _, p in ring do
			cy += p.Y / #ring
		end
		for pass = 1, 2 do
			local function m(p: Vector3): Vector3
				return if pass == 2 then mirrorX(p) else p
			end
			local c0 = addVert(Lp, m(V3(0, cy, ring[1].Z)), nz)
			local ids = {}
			for i, p in ring do
				ids[i] = addVert(Lp, m(p), nz)
			end
			for i = 1, #ring - 1 do
				addTri(Lp, c0, ids[i], ids[i + 1])
			end
		end
	end

	-- collect the shell for projecting details
	local shell: { Tri } = {}
	for _, lname in { "Paint", "Accent", "Trim", "Glass" } do
		local Lr = layers[lname]
		if Lr then
			for i = 1, #Lr.tris, 3 do
				local a, b, c = Lr.tris[i], Lr.tris[i + 1], Lr.tris[i + 2]
				if Lr.verts[a].X >= -0.05 or Lr.verts[b].X >= -0.05 or Lr.verts[c].X >= -0.05 then
					table.insert(shell, { a = Lr.verts[a], b = Lr.verts[b], c = Lr.verts[c], na = Lr.normals[a], nb = Lr.normals[b], nc = Lr.normals[c] })
				end
			end
		end
	end
	local frontF = projector(shell, "front")
	local rearF = projector(shell, "rear")
	local sideF0 = projector(shell, "side")
	local topF0 = projector(shell, "top")
	local function sideF(z: number, y: number): (Vector3?, Vector3?)
		return sideF0(z, y)
	end
	local function topF(x: number, z: number): (Vector3?, Vector3?)
		return topF0(x, z)
	end
	local function outward(p: Vector3): Vector3
		local axis = V3(0, math.clamp(p.Y, clr + 0.4, belt - 0.2), math.clamp(p.Z, zF + 2, zB - 2))
		local d = p - axis
		return if d.Magnitude > 1e-6 then d.Unit else UP
	end
	local function upward(_: Vector3): Vector3
		return UP
	end
	local function rect(lo: number, hi: number): (number) -> (number, number)
		return function()
			return lo, hi
		end
	end
	-- rounded "lens" between two edges: lower/upper are linear across [a0, a1]
	local function lens(a0: number, a1: number, lo0: number, hi0: number, lo1: number, hi1: number, round: number): (number) -> (number, number)
		return function(a: number)
			local f = clamp01((a - a0) / (a1 - a0))
			local lo, hi = lerp(lo0, lo1, f), lerp(hi0, hi1, f)
			local e = math.min(f, 1 - f) / math.max(round, 1e-3)
			if e < 1 then
				local k = math.sqrt(math.max(0, 1 - (1 - e) ^ 2))
				local mid = (lo + hi) / 2
				lo, hi = mid - (mid - lo) * k, mid + (hi - mid) * k
			end
			return lo, hi
		end
	end
	local function circle(ca: number, cb: number, r: number): (number) -> (number, number)
		return function(a: number)
			local h = math.sqrt(math.max(0, r * r - (a - ca) ^ 2))
			return cb - h, cb + h
		end
	end

	-- front face heights (from the actual body)
	local faceTop = yEdge(zF + 0.15)
	local faceBot = yBot(zF)
	local noseFaceH = faceTop - faceBot

	-----------------------------------------------------------------
	-- Interior tub (seen through the glass), wheel wells, underbody
	-----------------------------------------------------------------
	do
		-- lower tub (door cards, floor, dash) and a headliner box under the roof
		local z0 = zWs + 0.6
		local z1 = if ds.mid then zRoofB + 0.5 else zRearEnd - 0.7
		local x = hwb - 0.2
		local y0, y1 = clr + 0.3, ds.beltF + 0.08
		box(layers, "Interior", CFrame.new(0, (y0 + y1) / 2, (z0 + z1) / 2), V3(x * 2, y1 - y0, z1 - z0), false, true)
		local hx = hwb - ds.tumbleG - 0.3
		local ya, yb = ds.beltF + 0.08, roofTop - 0.16
		local za, zb = zRoofA + 0.1, zRoofB - 0.1
		if zb > za and hx > 0.5 then
			box(layers, "Interior", CFrame.new(0, (ya + yb) / 2, (za + zb) / 2), V3(hx * 2, yb - ya, zb - za), false, true)
		end
	end
	for _, w in wheels do
		local x0, x1 = w.xin - 0.05, hw + 0.3
		local arch = w.arch + 0.01
		local segs = n(14)
		local prof: Grid = {}
		for i = 0, 1 do
			local x = if i == 0 then x0 else x1
			local row = {}
			for k = 0, segs do
				local a = lerp(-0.12, math.pi + 0.12, k / segs)
				row[k + 1] = V3(x, w.cy + math.sin(a) * arch, w.z + math.cos(a) * arch)
			end
			prof[i + 1] = row
		end
		local nr = gridNormals(prof, function(_, _, p)
			return (V3(p.X, w.cy, w.z) - p).Unit
		end)
		addGrid(layers, "Trim", prof, nr, true)
		local disc: Grid = { {}, {} }
		for k = 0, segs do
			local a = lerp(-0.12, math.pi + 0.12, k / segs)
			disc[1][k + 1] = V3(x0, w.cy, w.z)
			disc[2][k + 1] = V3(x0, w.cy + math.sin(a) * arch, w.z + math.cos(a) * arch)
		end
		local dn: Grid = { table.create(segs + 1, V3(1, 0, 0)), table.create(segs + 1, V3(1, 0, 0)) }
		addGrid(layers, "Trim", disc, dn, true)
	end

	-----------------------------------------------------------------
	-- Splitter, sills, diffuser
	-----------------------------------------------------------------
	if ds.splitter then
		local y = faceBot - 0.04
		local z0 = zF - 0.18
		local shape = { V3(0, z0, 0), V3(tipW + 0.1, z0 + 0.05, 0), V3(math.min(hw, tipW + 0.9), z0 + 1.0, 0), V3(math.min(hw, tipW + 0.9) - 0.2, z0 + 1.6, 0), V3(0, z0 + 1.6, 0) }
		local prof = {}
		for i = #shape, 1, -1 do
			table.insert(prof, V3(shape[i].Y, shape[i].X, 0))
		end
		-- thin plate: extrude a plan outline downwards
		local Lp = getLayer(layers, "Trim")
		for pass = 1, 2 do
			local sgn = if pass == 2 then -1 else 1
			local function P(q: Vector3, yy: number): Vector3
				return V3(q.X * sgn, yy, q.Y)
			end
			local up = addVert(Lp, P(shape[1], y), UP)
			local dn = addVert(Lp, P(shape[1], y - 0.06), -UP)
			local prevU, prevD
			for i = 2, #shape do
				local u = addVert(Lp, P(shape[i], y), UP)
				local d = addVert(Lp, P(shape[i], y - 0.06), -UP)
				if prevU then
					addTri(Lp, up, prevU, u)
					addTri(Lp, dn, prevD, d)
				end
				prevU, prevD = u, d
			end
			for i = 1, #shape - 1 do
				local a, b = shape[i], shape[i + 1]
				local e = b - a
				local nn = V3(e.Y, 0, -e.X).Unit * sgn
				nn = V3(nn.X, 0, nn.Z)
				local i1 = addVert(Lp, P(a, y), nn)
				local i2 = addVert(Lp, P(b, y), nn)
				local i3 = addVert(Lp, P(b, y - 0.06), nn)
				local i4 = addVert(Lp, P(a, y - 0.06), nn)
				addTri(Lp, i1, i2, i3)
				addTri(Lp, i1, i3, i4)
			end
		end
		local _ = prof
	end
	if ds.diffuser then
		for i = 0, 3 do
			local x = 0.25 + i * 0.6
			local p = rearF(x, yBot(zB) + 0.1)
			if p then
				box(layers, "Trim", CFrame.new(x, yBot(zB) + 0.1, p.Z - 0.3), V3(0.06, 0.2, 0.7), true)
			end
		end
	end
	-- rear valance
	do
		local yb = yBot(zB)
		patch(layers, "Trim", rearF, 0, tailW * 0.92, rect(yb + 0.02, yb + (if ds.diffuser then 0.5 else 0.32)), n(16), n(3), 0.012, true, outward)
	end

	-----------------------------------------------------------------
	-- Front end
	-----------------------------------------------------------------
	local function chromeFrame(F: any, a0: number, a1: number, range: (number) -> (number, number), pad: number)
		patch(layers, "Chrome", F, a0, a1 + pad, function(a)
			local lo, hi = range(math.clamp(a, a0, a1))
			return lo - pad, hi + pad
		end, n(16), n(4), 0.012, true, outward)
	end
	local grille = ds.grille
	local gy0, gy1 = faceBot + noseFaceH * 0.35, faceTop - noseFaceH * 0.1
	if grille == "wide" then
		local gw = tipW * 0.55
		local shape = lens(-gw, gw, gy0, gy1, gy0, gy1, 0.12)
		chromeFrame(frontF, 0, gw, shape, 0.06)
		patch(layers, "Trim", frontF, 0, gw, shape, n(16), n(6), 0.026, true, outward)
		for i = 1, 3 do
			local y = lerp(gy0, gy1, i / 4)
			patch(layers, "Chrome", frontF, 0, gw - 0.12, rect(y - 0.025, y + 0.025), n(12), 1, 0.036, true, outward)
		end
	elseif grille == "upright" then
		local gw = tipW * 0.4
		chromeFrame(frontF, 0, gw, rect(gy0 - 0.1, gy1), 0.08)
		patch(layers, "Trim", frontF, 0, gw, rect(gy0 - 0.1, gy1), n(12), n(6), 0.026, true, outward)
		for i = 0, 6 do
			local x = (i + 0.5) * gw / 7
			patch(layers, "Chrome", frontF, x - 0.03, x + 0.03, rect(gy0 - 0.06, gy1 - 0.04), 1, n(6), 0.036, true, outward)
		end
	elseif grille == "kidney" then
		local x0, x1 = 0.12, tipW * 0.36
		local shape = lens(x0, x1, gy0 - 0.1, gy1 - 0.04, gy0 - 0.04, gy1, 0.25)
		chromeFrame(frontF, x0, x1, shape, 0.05)
		patch(layers, "Trim", frontF, x0, x1, shape, n(10), n(6), 0.026, true, outward)
		for i = 1, 5 do
			local x = lerp(x0, x1, i / 6)
			local lo, hi = shape(x)
			patch(layers, "Chrome", frontF, x - 0.022, x + 0.022, rect(lo + 0.03, hi - 0.03), 1, n(4), 0.036, true, outward)
		end
	elseif grille == "suv" then
		local gw = tipW * 0.55
		chromeFrame(frontF, 0, gw, rect(gy0 - 0.15, gy1), 0.08)
		patch(layers, "Trim", frontF, 0, gw, rect(gy0 - 0.15, gy1), n(14), n(8), 0.026, true, outward)
		for i = 1, 4 do
			local y = lerp(gy0 - 0.15, gy1, i / 5)
			patch(layers, "Chrome", frontF, 0, gw - 0.05, rect(y - 0.035, y + 0.035), n(12), 1, 0.036, true, outward)
		end
	elseif grille == "jdm" then
		-- slim upper grille between the lamps + a big open bumper mouth
		local gw = tipW * 0.36
		patch(layers, "Trim", frontF, 0, gw, rect(faceTop - 0.42, faceTop - 0.12), n(10), n(3), 0.026, true, outward)
		patch(layers, "Chrome", frontF, 0, 0.16, rect(faceTop - 0.34, faceTop - 0.2), 2, 1, 0.036, true, outward)
		local mw = tipW * 0.62
		patch(layers, "Trim", frontF, 0, mw, lens(-mw, mw, faceBot + 0.18, faceBot + 0.62, faceBot + 0.18, faceBot + 0.62, 0.1), n(16), n(5), 0.026, true, outward)
		-- fog lamps either side of the mouth
		patch(layers, "Lamp", frontF, mw + 0.15, mw + 0.5, rect(faceBot + 0.3, faceBot + 0.48), 3, 2, 0.03, true, outward)
	elseif grille == "gt" then
		-- huge trapezoid mouth with mesh
		local gwT, gwB = tipW * 0.5, tipW * 0.62
		local g0, g1 = faceBot + 0.12, faceTop - 0.12
		local shape = function(x: number)
			local f = math.abs(x) / gwB
			local top = lerp(g1, g1 - 0.25, sstep(gwT / gwB, 1, f))
			return g0, top
		end
		chromeFrame(frontF, 0, gwB, shape, 0.05)
		patch(layers, "Trim", frontF, 0, gwB, shape, n(16), n(8), 0.026, true, outward)
		for i = 1, (if lite then 0 else 5) do
			local y = lerp(g0 + 0.06, g1 - 0.06, i / 6)
			patch(layers, "Chrome", frontF, 0.02, gwB - 0.1, rect(y - 0.012, y + 0.012), n(10), 1, 0.034, true, outward)
		end
		-- canards
		for k = 0, 1 do
			local y = faceBot + 0.25 + k * 0.25
			local p = frontF(tipW * 0.9, y)
			if p then
				box(layers, "Trim", CFrame.new(p + V3(0.15, 0, -0.05)) * CFrame.Angles(0, 0.25, -0.25), V3(0.55, 0.04, 0.3), true)
			end
		end
	elseif grille == "hex" then
		local gw = tipW * 0.62
		local shape = lens(-gw, gw, faceBot + 0.15, faceTop - 0.1, faceBot + 0.4, faceTop - 0.05, 0.1)
		patch(layers, "Trim", frontF, 0, gw, shape, n(16), n(8), 0.026, true, outward)
	elseif grille == "horseshoe" then
		local cy, rr0 = faceBot + noseFaceH * 0.55, math.min(0.55, noseFaceH * 0.42)
		patch(layers, "Chrome", frontF, 0, rr0, function(x)
			local lo, hi = circle(0, cy, rr0)(x)
			return lo - 0.12, hi
		end, n(12), n(8), 0.014, true, outward)
		patch(layers, "Trim", frontF, 0, rr0 - 0.07, function(x)
			local lo, hi = circle(0, cy, rr0 - 0.07)(x)
			return lo - 0.08, hi
		end, n(12), n(8), 0.026, true, outward)
	end

	-- lower intakes
	if isSuper then
		-- big corner intakes with a body-colour blade through them
		local ix0, ix1 = tipW * 0.32, tipW * 1.0
		local by0, by1 = faceBot + 0.05, faceTop + 0.25
		local shape = lens(ix0, ix1, by0, by1 - 0.2, by0 + 0.02, by1, 0.15)
		patch(layers, "Trim", frontF, ix0, ix1, shape, n(14), n(6), 0.02, true, outward)
		patch(layers, "Trim", frontF, 0, ix0 + 0.05, rect(by0, by0 + 0.22), n(6), n(2), 0.02, true, outward)
		if not lite then
			local y = (by0 + by1) / 2
			patch(layers, "Paint", frontF, ix0 + 0.1, ix1 - 0.1, rect(y - 0.03, y + 0.03), n(10), 1, 0.03, true, outward)
		end
	elseif grille ~= "hex" and grille ~= "jdm" and grille ~= "gt" then
		local iw = tipW * 0.66
		patch(layers, "Trim", frontF, 0, iw, lens(-iw, iw, faceBot + 0.06, faceBot + 0.3, faceBot + 0.08, faceBot + 0.26, 0.12), n(14), n(4), 0.02, true, outward)
	end

	-- supercars: slim lamps lying on the upper nose corners
	if isSuper then
		local za, zb = zF + 0.3, zF + 1.35
		local function inner(z: number): number
			return lerp(tipW * 0.45, planW(z) * 0.5, (z - za) / (zb - za))
		end
		local function outer(z: number): number
			return planW(z) - ds.topIn * 0.6
		end
		local shape = function(z: number)
			local f = clamp01((z - za) / (zb - za))
			local lo, hi = inner(z), outer(z)
			-- tapered tail end
			local k = math.sqrt(math.max(0, 1 - math.max(0, f - 0.7) / 0.3))
			return hi - (hi - lo) * k, hi
		end
		local TF = function(z: number, x: number)
			return topF(x, z)
		end
		patch(layers, "Trim", TF, za, zb, shape, n(16), n(5), 0.02, true, upward)
		local function at(f: number, g: number): Vector3
			local z = lerp(za, zb, f)
			local lo, hi = shape(z)
			return V3(z, lerp(lo, hi, g), 0)
		end
		local function lit(path: { Vector3 })
			stroke(layers, "Lamp", TF, path, 0.05, 0.034, true, upward)
		end
		if ds.head == "y" then
			local c = at(0.35, 0.55)
			lit({ at(0.05, 0.15), c })
			lit({ at(0.05, 0.92), c })
			lit({ c, at(0.85, 0.85) })
		elseif ds.head == "quad" then
			for i = 0, 3 do
				local p = at(0.15 + i * 0.18, 0.6)
				patch(layers, "Lamp", TF, p.X - 0.07, p.X + 0.07, rect(p.Y - 0.12, p.Y + 0.12), 2, 2, 0.034, true, upward)
			end
		elseif ds.head == "eye" then
			local path = {}
			for i = 0, 10 do
				table.insert(path, at(lerp(0.04, 0.9, i / 10), 0.92))
			end
			for i = 10, 0, -1 do
				table.insert(path, at(lerp(0.04, 0.9, i / 10), 0.1))
			end
			table.insert(path, path[1])
			lit(path)
		else
			local path = {}
			for i = 0, 8 do
				table.insert(path, at(lerp(0.04, 0.9, i / 8), 0.85))
			end
			lit(path)
			local p = at(0.3, 0.45)
			patch(layers, "Lamp", TF, p.X - 0.08, p.X + 0.08, rect(p.Y - 0.1, p.Y + 0.1), 2, 2, 0.034, true, upward)
		end
	end
	-- headlights (placed on the upper nose corners)
	if not isSuper then
		local style = ds.head
		local hx0, hx1 = tipW * 0.5, tipW * 0.98
		local ylo, yhi
		if isSuper then
			ylo, yhi = faceTop + 0.04, faceTop + 0.32
		else
			ylo, yhi = faceTop - 0.4, faceTop - 0.08
		end
		local housingShape
		if style == "round" or style == "jdm" then
			housingShape = lens(hx0, hx1, ylo + 0.04, yhi, ylo, yhi - 0.02, 0.15)
		elseif style == "angular" then
			housingShape = lens(hx0, hx1, ylo + 0.12, yhi, ylo - 0.02, yhi + 0.06, 0.06)
		elseif isSuper then
			housingShape = lens(hx0, hx1, ylo + 0.1, yhi + 0.04, ylo - 0.02, yhi - 0.04, 0.1)
		else
			housingShape = lens(hx0, hx1, ylo + 0.04, yhi - 0.02, ylo + 0.06, yhi + 0.02, 0.18)
		end
		patch(layers, "Trim", frontF, hx0, hx1, housingShape, n(18), n(6), 0.02, true, outward)
		local function lit(path: { Vector3 }, w: number)
			stroke(layers, "Lamp", frontF, path, w, 0.034, true, outward)
		end
		local function dot(xc: number, yc: number, r: number)
			patch(layers, "Chrome", frontF, xc - r - 0.04, xc + r + 0.04, circle(xc, yc, r + 0.04), n(8), n(4), 0.028, true, outward)
			patch(layers, "Lamp", frontF, xc - r, xc + r, circle(xc, yc, r), n(8), n(4), 0.036, true, outward)
		end
		local function edge(f: number, top: boolean, inset: number): Vector3
			local x = lerp(hx0, hx1, f)
			local lo, hi = housingShape(x)
			return V3(x, if top then hi - inset else lo + inset, 0)
		end
		local function mid(f: number): (number, number)
			local x = lerp(hx0, hx1, f)
			local lo, hi = housingShape(x)
			return x, (lo + hi) / 2
		end
		if style == "sweep" or style == "slim" then
			local path = {}
			for i = 0, 10 do
				table.insert(path, edge(lerp(0.05, 0.95, i / 10), true, 0.05))
			end
			lit(path, 0.05)
			if style == "sweep" then
				local x1, y1 = mid(0.32)
				local x2, y2 = mid(0.6)
				dot(x1, y1 - 0.03, 0.09)
				dot(x2, y2 - 0.03, 0.09)
			else
				for i = 0, 3 do
					local x = lerp(hx0, hx1, 0.25 + i * 0.15)
					local lo, hi = housingShape(x)
					patch(layers, "Lamp", frontF, x - 0.06, x + 0.06, rect(lo + 0.05, lerp(lo, hi, 0.55)), 2, 2, 0.036, true, outward)
				end
			end
		elseif style == "y" then
			local cx, cy = mid(0.55)
			local c = V3(cx, cy, 0)
			lit({ edge(0.08, true, 0.04), c }, 0.05)
			lit({ c, edge(0.97, true, 0.04) }, 0.05)
			lit({ c, edge(0.62, false, 0.03) }, 0.05)
			local px, py = mid(0.3)
			dot(px, py - 0.02, 0.06)
		elseif style == "angel" or style == "round" or style == "jdm" then
			for _, f in (if style == "jdm" then { 0.26, 0.56 } else { 0.3, 0.68 }) :: { number } do
				local x = lerp(hx0, hx1, f)
				local lo, hi = housingShape(x)
				local yc, r = (lo + hi) / 2, math.min(0.15, (hi - lo) / 2 - 0.03)
				if style == "angel" then
					local ring = {}
					for k = 0, 16 do
						local a = k / 16 * math.pi * 2
						table.insert(ring, V3(x + math.cos(a) * r, yc + math.sin(a) * r, 0))
					end
					lit(ring, 0.04)
				else
					dot(x, yc, r)
				end
			end
			if style == "jdm" then
				-- amber corner lamp
				local x = lerp(hx0, hx1, 0.86)
				local lo, hi = housingShape(x)
				patch(layers, "Chrome", frontF, x - 0.08, x + 0.08, rect(lo + 0.05, hi - 0.05), 2, 2, 0.034, true, outward)
			end
		elseif style == "angular" then
			lit({ edge(0.04, false, 0.05), edge(0.45, false, 0.05), edge(0.97, true, 0.07) }, 0.05)
			local x, y = mid(0.55)
			dot(x, y + 0.02, 0.08)
			local x2, y2 = mid(0.3)
			dot(x2, y2 + 0.04, 0.07)
		elseif style == "quad" then
			for i = 0, 3 do
				local x = lerp(hx0, hx1, 0.16 + i * 0.22)
				local lo, hi = housingShape(x)
				patch(layers, "Lamp", frontF, x - 0.08, x + 0.08, rect(lo + 0.05, hi - 0.05), 2, 2, 0.036, true, outward)
			end
		end
	end

	-- hood vents / creases
	if ds.hoodVents then
		local zc = lerp(zF, zWs, 0.62)
		local xc = hw * 0.26
		patch(layers, "Trim", function(z, x)
			return topF(x, z)
		end, zc - 0.5, zc + 0.5, lens(zc - 0.5, zc + 0.5, xc - 0.03, xc + 0.06, xc + 0.05, xc + 0.16, 0.2), n(10), n(2), 0.016, true, upward)
	end
	if not lite and not ds.accentHood then
		-- hood shut line just inside the edges
		local x = math.min(hwb, planW(zWs) - ds.topIn) - 0.1
		stroke(layers, "Trim", function(a, b)
			return topF(a, b)
		end, { V3(x * 0.95, zF + ds.noseLen * 0.5 + 0.3, 0), V3(x, zWs - 0.2, 0) }, 0.025, 0.01, true, upward, 24)
	end

	-----------------------------------------------------------------
	-- Sides
	-----------------------------------------------------------------
	local doorFront = zWs + 0.2
	local doorRearEnd = if ds.fourDoor then zRoofEnd + 0.1 else doorEnd
	if not lite then
		local function shut(z0: number, z1: number)
			local yLo = yBot((z0 + z1) / 2) + 0.4
			local yHi = yEdge((z0 + z1) / 2) - 0.08
			stroke(layers, "Trim", sideF, { V3(z0, yLo, 0), V3(z1, yHi, 0) }, 0.026, 0.008, true, outward, 12)
		end
		shut(doorFront + 0.08, doorFront)
		shut(doorEnd, doorEnd + 0.1)
		if ds.fourDoor then
			shut(doorRearEnd, doorRearEnd + 0.12)
		end
		local hy = yEdge(doorEnd) - 0.36
		for _, z in (if ds.fourDoor then { doorEnd - 0.75, doorRearEnd - 0.65 } else { doorEnd - 0.8 }) :: { number } do
			patch(layers, if isSuper then "Trim" else "Chrome", sideF, z - 0.28, z + 0.28, lens(z - 0.28, z + 0.28, hy - 0.05, hy + 0.05, hy - 0.05, hy + 0.05, 0.3), 4, 2, 0.02, true, outward)
		end
	end
	if ds.sideIntake then
		-- big scoop ahead of the rear wheel
		local rw = wheels[2]
		local z0, z1 = zRoofEnd - 1.0, rw.z - rw.arch - 0.1
		local y0, y1 = yBot(z1) + 0.45, yEdge(z1) - 0.12
		local shape = lens(z0, z1, y1 - 0.25, y1, y0, y1 + 0.05, 0.12)
		patch(layers, "Trim", sideF, z0, z1, shape, n(14), n(8), 0.016, true, outward)
		if not lite then
			for i = 1, 3 do
				local y = lerp(y0 + 0.1, y1 - 0.05, i / 4)
				patch(layers, "Paint", sideF, lerp(z0, z1, 0.35), z1 - 0.05, rect(y - 0.02, y + 0.02), n(8), 1, 0.026, true, outward)
			end
		end
	end
	if ds.cline then
		local zc = zRoofEnd - 0.2
		local path = {}
		for i = 0, 16 do
			local a = lerp(-math.pi / 2, math.pi / 2, i / 16)
			table.insert(path, V3(zc - math.cos(a) * 1.2, lerp(yBot(zc), yEdge(zc), 0.5) + math.sin(a) * (yEdge(zc) - yBot(zc)) * 0.38, 0))
		end
		stroke(layers, "Chrome", sideF, path, 0.16, 0.016, true, outward)
	end
	if ds.stripe then
		stroke(layers, "Accent", sideF, { V3(zF + 1.4, yEdge(zF + 1.4) - 0.1, 0), V3(zB - 1.0, yEdge(zB - 1.0) - 0.1, 0) }, 0.05, 0.012, true, outward, 60)
	end
	if ds.livery == "stripes" and not lite then
		-- blue livery: long arrows along the lower side and over the arches
		local function stripe(z0: number, z1: number, y0: number, y1: number, w: number)
			stroke(layers, "Accent", sideF, { V3(z0, y0, 0), V3(z1, y1, 0) }, w, 0.014, true, outward, 40)
		end
		local yl = clr + 0.75
		stripe(zF + 1.0, zB - 1.4, yl, yl + 0.3, 0.12)
		stripe(zF + 2.2, zB - 2.2, yl + 0.22, yl + 0.55, 0.08)
		for i = 0, 3 do
			local z = doorFront + 0.6 + i * 0.45
			stroke(layers, "Accent", sideF, { V3(z, yl + 0.2, 0), V3(z + 0.55, yEdge(z) - 0.2, 0) }, 0.07, 0.014, true, outward, 16)
		end
	end
	if not isSuper and not lite then
		local zm = wheels[1].z + wheels[1].arch + 0.35
		local ym = yEdge(zm) - 0.3
		patch(layers, "Lamp", sideF, zm - 0.16, zm + 0.16, lens(zm - 0.16, zm + 0.16, ym - 0.03, ym + 0.03, ym - 0.03, ym + 0.03, 0.4), 3, 1, 0.02, true, outward)
	end

	-----------------------------------------------------------------
	-- Rear end
	-----------------------------------------------------------------
	do
		local style = ds.tailLamp
		local tTop = yEdge(zB - 0.1)
		local ty1 = tTop - 0.1
		local ty0 = ty1 - (if isSuper then 0.32 else 0.42)
		local function tailBand(x0: number, x1: number, lo: number, hi: number)
			patch(layers, "Trim", rearF, x0, x1, lens(x0, x1, lo, hi, lo + 0.04, hi + 0.02, 0.12), n(14), n(3), 0.016, true, outward)
		end
		if style == "bar" or style == "thin" then
			local h = if style == "thin" then 0.08 else 0.12
			patch(layers, "Trim", rearF, 0, tailW * 0.98, rect(ty0, ty1), n(18), n(3), 0.016, true, outward)
			patch(layers, "Tail", rearF, 0, tailW * 0.97, rect(ty1 - 0.06 - h, ty1 - 0.06), n(18), 1, 0.03, true, outward)
		elseif style == "split" then
			tailBand(tailW * 0.42, tailW * 0.99, ty0, ty1)
			local path = {}
			for i = 0, 8 do
				table.insert(path, V3(lerp(tailW * 0.46, tailW * 0.96, i / 8), ty1 - 0.08 - 0.06 * (i / 8), 0))
			end
			stroke(layers, "Tail", rearF, path, 0.07, 0.03, true, outward)
			patch(layers, "Tail", rearF, tailW * 0.52, tailW * 0.92, rect(ty0 + 0.08, ty0 + 0.16), n(8), 1, 0.026, true, outward)
			patch(layers, "Plate", rearF, tailW * 0.54, tailW * 0.66, rect(ty0 + 0.2, ty1 - 0.18), 2, 1, 0.028, true, outward)
		elseif style == "y" then
			tailBand(tailW * 0.3, tailW * 0.99, ty0 - 0.05, ty1)
			local cx, cy = tailW * 0.7, (ty0 + ty1) / 2
			stroke(layers, "Tail", rearF, { V3(tailW * 0.36, ty1 - 0.08, 0), V3(cx, cy, 0) }, 0.06, 0.03, true, outward)
			stroke(layers, "Tail", rearF, { V3(cx, cy, 0), V3(tailW * 0.96, ty1 - 0.06, 0) }, 0.06, 0.03, true, outward)
			stroke(layers, "Tail", rearF, { V3(cx, cy, 0), V3(tailW * 0.86, ty0 + 0.02, 0) }, 0.06, 0.03, true, outward)
		elseif style == "rings" then
			local cy = (ty0 + ty1) / 2
			local r = math.min(0.22, (ty1 - ty0) / 2 + 0.02)
			patch(layers, "Trim", rearF, tailW * 0.32, tailW * 0.99, rect(cy - r - 0.06, cy + r + 0.06), n(12), n(3), 0.016, true, outward)
			for _, f in { 0.5, 0.82 } do
				local cx = tailW * f
				local ring = {}
				for k = 0, 18 do
					local a = k / 18 * math.pi * 2
					table.insert(ring, V3(cx + math.cos(a) * r * 0.75, cy + math.sin(a) * r * 0.75, 0))
				end
				stroke(layers, "Tail", rearF, ring, r * 0.42, 0.03, true, outward)
			end
		elseif style == "tri" then
			tailBand(tailW * 0.42, tailW * 0.99, ty0, ty1)
			for i = 0, 2 do
				local x = lerp(tailW * 0.52, tailW * 0.88, i / 2)
				patch(layers, "Tail", rearF, x - 0.1, x + 0.1, rect(ty0 + 0.06, ty1 - 0.06), 2, 2, 0.03, true, outward)
			end
		end
		if not isSuper then
			patch(layers, "Tail", rearF, 0, tailW * 0.22, rect(tTop - 0.06, tTop - 0.02), n(6), 1, 0.03, true, outward)
		end
		if ds.plate then
			local yb = yBot(zB)
			local py = lerp(yb, ty0, 0.55)
			patch(layers, "Trim", rearF, 0, 0.66, rect(py - 0.24, py + 0.24), n(4), 2, 0.018, true, outward)
			patch(layers, "Plate", rearF, 0, 0.6, rect(py - 0.19, py + 0.19), n(4), 2, 0.028, true, outward)
		end
	end
	-- exhausts
	do
		local yb = yBot(zB)
		local tips: { { number } }
		if ds.exhaust == "quad" then
			tips = { { tailW * 0.42, yb + 0.2, 0.14 }, { tailW * 0.56, yb + 0.2, 0.14 } }
		elseif ds.exhaust == "center" then
			tips = { { 0.24, yb + 0.28, 0.17 } }
		else
			tips = { { tailW * 0.62, yb + 0.18, 0.15 } }
		end
		for _, t in tips do
			local x, y, r = t[1], t[2], t[3]
			local p = rearF(x, y) or V3(x, y, zB)
			local cf = CFrame.fromMatrix(V3(x, y, p.Z - 0.25), V3(0, 0, 1), UP)
			revolve(layers, "Chrome", cf, { V3(0, r * 0.82, 0), V3(0.36, r * 0.86, 0), V3(0.38, r, 0), V3(0, r, 0) }, if lite then 10 else 18, true)
			annulus(layers, "Trim", cf * CFrame.new(0.3, 0, 0), 0, r * 0.82, if lite then 8 else 14, 1, true)
		end
	end

	-----------------------------------------------------------------
	-- Glass details: louvres, mirrors, roof bits, wings
	-----------------------------------------------------------------
	if ds.louvres and not lite then
		for i = 1, 6 do
			local z = lerp(zRoofB + 0.3, zRearEnd - 0.2, i / 7)
			patch(layers, "Trim", function(x, zz)
				return topF(x, zz)
			end, 0, hwb - ds.tumbleG * 0.5 - 0.15, rect(z - 0.06, z + 0.06), n(8), 1, 0.016, true, upward)
		end
	end
	do
		local z = zWs + 0.55
		local sec = section(z)
		local base = V3(sec[7].x, sec[7].y + 0.25, z)
		local out = V3(1, 0, 0)
		local head = base + out * 0.42 + UP * 0.1 + V3(0, 0, 0.12)
		box(layers, "Trim", CFrame.lookAt((base + head) / 2, head), V3(0.07, 0.06, (head - base).Magnitude + 0.1), true)
		local mcf = CFrame.new(head + out * 0.12)
		ellipsoid(layers, if ds.blackPillars then "Trim" else "Paint", mcf, V3(0.26, 0.16, 0.13), if lite then 5 else 8, true)
		annulus(layers, "Chrome", CFrame.fromMatrix(head + out * 0.12 + V3(0, 0, 0.115), V3(0, 0, 1), UP), 0, 0.11, 10, 1, true)
	end
	if ds.rails then
		local x = hwb - ds.tumbleG - 0.35
		local path = {}
		for i = 0, 10 do
			local z = lerp(zRoofA + 0.3, zRoofB - 0.2, i / 10)
			table.insert(path, V3(x, (roofLine(z) or roofTop) - 0.02 + 0.14, z))
		end
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			box(layers, "Chrome", CFrame.lookAt((a + b) / 2, b), V3(0.1, 0.08, (b - a).Magnitude + 0.02), true)
		end
		for _, i in { 1, #path } do
			box(layers, "Trim", CFrame.new(path[i] - UP * 0.07), V3(0.12, 0.14, 0.3), true)
		end
	end
	if ds.wing == "big" or ds.wing == "gt" then
		local big = ds.wing == "big"
		local span = hw - (if big then 0.15 else 0.3)
		local wz = zB - (if big then 0.85 else 0.7)
		local wy = yEdge(wz) + (if big then 0.95 else 0.75)
		local chord = if big then 1.25 else 0.95
		local foil = {}
		for i = 0, 10 do
			local t = i / 10
			table.insert(foil, V3(0.1 * math.sin(math.pi * t ^ 0.7) * (1 - t * 0.3), -chord / 2 + chord * t, 0))
		end
		for i = 9, 1, -1 do
			local t = i / 10
			table.insert(foil, V3(-0.03 * math.sin(math.pi * t), -chord / 2 + chord * t, 0))
		end
		local cf = CFrame.new(0, wy, wz) * CFrame.Angles(math.rad(-8), 0, 0)
		extrude(layers, "Trim", cf, foil, -span, span, false)
		local plate = { V3(-0.35, -chord / 2 - 0.1, 0), V3(0.22, -chord / 2 + 0.1, 0), V3(0.22, chord / 2 + 0.15, 0), V3(-0.25, chord / 2 + 0.05, 0) }
		extrude(layers, "Trim", CFrame.new(span, wy, wz), plate, -0.04, 0.04, true)
		local x = hw * 0.4
		local p0 = (topF(x, wz + 0.3)) or V3(x, yEdge(wz), wz + 0.3)
		local p1 = V3(x, wy + 0.04, wz - 0.1)
		box(layers, "Trim", CFrame.lookAt((p0 + p1) / 2, p1), V3(0.07, 0.22, (p1 - p0).Magnitude), true)
		if class == "Hypercar" then
			box(layers, "Accent", CFrame.new(span - 0.02, wy + 0.03, wz) * CFrame.Angles(math.rad(-8), 0, 0), V3(0.1, 0.05, chord + 0.04), true)
		end
	end
	if not isSuper and not lite then
		-- shark fin antenna
		local z = zRoofB - 0.25
		local y = roofLine(z) or roofTop
		extrude(layers, roofLayer, CFrame.new(0, y - 0.02, z), { V3(0, -0.3, 0), V3(0.16, 0.12, 0), V3(0, 0.3, 0) }, -0.04, 0.04, false)
	end

	for name, Lr in layers do
		if #Lr.tris == 0 then
			layers[name] = nil
		end
	end
	return layers
end

---------------------------------------------------------------------
-- Wheels: tyre + rim (spins), caliper (steers only)
-- local X is the axle with the outer face at +X; origin at the hub
---------------------------------------------------------------------
function CarMesh.wheel(style: string, R: number, width: number, rimFrac: number, lite: boolean?): Layers
	local layers: Layers = {}
	local segs = if lite then 22 else 40
	local xo = width / 2
	local Rr = R * rimFrac
	local side = R - Rr
	local I = CFrame.new()

	-- tyre cross-section from the outer bead round to the inner bead
	local prof = {
		V3(xo * 0.78, Rr + 0.005, 0),
		V3(xo * 0.92, Rr + side * 0.15, 0),
		V3(xo * 1.0, Rr + side * 0.5, 0),
		V3(xo * 0.97, Rr + side * 0.82, 0),
		V3(xo * 0.86, R - 0.015, 0),
		V3(xo * 0.7, R, 0),
	}
	if not lite then
		-- tread grooves
		for _, g in { 0.38, 0.0, -0.38 } do
			table.insert(prof, V3(xo * (g + 0.07), R, 0))
			table.insert(prof, V3(xo * (g + 0.05), R - 0.03, 0))
			table.insert(prof, V3(xo * (g - 0.05), R - 0.03, 0))
			table.insert(prof, V3(xo * (g - 0.07), R, 0))
		end
	end
	for i = 6, 1, -1 do
		local p = prof[i]
		table.insert(prof, V3(-p.X, p.Y, 0))
	end
	-- outward normals of the tyre: away from the middle of the section
	local pts: Grid = {}
	for i, q in prof do
		local row = {}
		for k = 0, segs do
			local a = k / segs * math.pi * 2
			row[k + 1] = V3(q.X, q.Y * math.cos(a), q.Y * math.sin(a))
		end
		pts[i] = row
	end
	local midR = (R + Rr) / 2
	local nrm = gridNormals(pts, function(_, _, p)
		local radial = V3(0, p.Y, p.Z)
		local rdir = if radial.Magnitude > 1e-6 then radial.Unit else UP
		return (p - rdir * midR).Unit
	end)
	addGrid(layers, "Tire", pts, nrm, false)

	-- rim: outer lip, barrel, spokes, hub, brake disc
	local lipX = xo * 0.84
	revolve(layers, "Rim", I, { V3(lipX - 0.04, Rr - 0.025, 0), V3(lipX + 0.02, Rr - 0.04, 0), V3(lipX + 0.03, Rr - 0.1, 0), V3(lipX - 0.02, Rr - 0.13, 0) }, segs, false)
	revolve(layers, "Rim", I, { V3(lipX - 0.02, Rr - 0.13, 0), V3(-xo * 0.7, Rr - 0.1, 0) }, segs, false, true)
	local rh = R * 0.2
	local rTip = Rr - 0.12
	local dish = if style == "multi" or style == "turbine" then 0.24 else 0.18
	local function faceX(r: number): number
		local f = clamp01((r - rh) / (rTip - rh))
		return lipX - dish * (1 - f) ^ 1.4 - 0.01
	end
	local function spoke(angle: number, wHub: number, wTip: number, twist: number, depth: number)
		local rows = if lite then 3 else 7
		local sp: Grid = {}
		for j = 0, rows do
			local f = j / rows
			local r = lerp(rh * 0.9, rTip + 0.04, f)
			local a = angle + twist * f
			local radial = V3(0, math.cos(a), math.sin(a))
			local tang = V3(0, -math.sin(a), math.cos(a))
			local hwid = lerp(wHub, wTip, f) / 2
			local x = faceX(r)
			local base = radial * r
			sp[j + 1] = {
				base + tang * (-hwid * 1.05) + V3(x - depth, 0, 0),
				base + tang * (-hwid) + V3(x, 0, 0),
				base + V3(x + 0.015, 0, 0),
				base + tang * hwid + V3(x, 0, 0),
				base + tang * (hwid * 1.05) + V3(x - depth, 0, 0),
			}
		end
		local sn = gridNormals(sp, function(_, c)
			local a = angle
			local tang = V3(0, -math.sin(a), math.cos(a))
			if c == 1 then
				return -tang
			elseif c == 5 then
				return tang
			end
			return V3(1, 0, 0)
		end)
		addGrid(layers, "Rim", sp, sn, false)
	end
	local count, wHub, wTip, twist = 5, 0.3, 0.22, 0
	if style == "twin5" then
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			spoke(a - 0.1, 0.16, 0.12, -0.06, 0.1)
			spoke(a + 0.1, 0.16, 0.12, 0.06, 0.1)
		end
		count = 0
	elseif style == "y5" then
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			spoke(a, 0.26, 0.16, 0, 0.12)
			spoke(a - 0.06, 0.08, 0.13, -0.3, 0.1)
			spoke(a + 0.06, 0.08, 0.13, 0.3, 0.1)
		end
		count = 0
	elseif style == "six" then
		count, wHub, wTip = 6, 0.26, 0.2
	elseif style == "multi" then
		count, wHub, wTip = 10, 0.13, 0.1
	elseif style == "turbine" then
		count, wHub, wTip, twist = 12, 0.11, 0.12, 0.45
	end
	for k = 0, count - 1 do
		spoke(k / count * math.pi * 2, wHub, wTip, twist, 0.1)
	end
	-- hub + centre cap + lug nuts
	local hx = faceX(rh) + 0.01
	revolve(layers, "Rim", I, { V3(hx + 0.04, 0, 0), V3(hx + 0.035, rh * 0.5, 0), V3(hx, rh * 1.02, 0), V3(hx - 0.1, rh * 1.02, 0) }, if lite then 12 else 24, false)
	if not lite then
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + 0.3
			local c = V3(hx + 0.03, math.cos(a) * rh * 0.62, math.sin(a) * rh * 0.62)
			revolve(layers, "Rim", CFrame.new(c), { V3(0.03, 0, 0), V3(0.03, 0.045, 0), V3(-0.03, 0.045, 0) }, 6, false)
		end
	end
	-- brake disc (spins with the wheel)
	local discX = -xo * 0.1
	local rDisc = Rr - 0.16
	annulus(layers, "Rim", CFrame.new(discX, 0, 0), R * 0.24, rDisc, segs, 1, false)
	annulus(layers, "Rim", CFrame.new(discX - 0.08, 0, 0), R * 0.24, rDisc, segs, -1, false)
	revolve(layers, "Rim", I, { V3(discX, rDisc, 0), V3(discX - 0.08, rDisc, 0) }, segs, false)

	-- caliper, centred 40 degrees from the top towards local +Z
	do
		local a0, a1 = math.rad(18), math.rad(68)
		local rIn, rOut = rDisc - 0.3, rDisc + 0.05
		local x0, x1 = discX - 0.2, discX + 0.12
		local steps = if lite then 4 else 8
		local function P(x: number, r: number, a: number): Vector3
			return V3(x, r * math.cos(a), r * math.sin(a))
		end
		local faces = {
			-- outer face (+X), radial outer, radial inner, two ends
			{ "x", x1, V3(1, 0, 0) },
			{ "r", rOut },
			{ "r", rIn },
		}
		for _, f in faces do
			local g: Grid = { {}, {} }
			for k = 0, steps do
				local a = lerp(a0, a1, k / steps)
				if f[1] == "x" then
					g[1][k + 1] = P(f[2], rIn, a)
					g[2][k + 1] = P(f[2], rOut, a)
				else
					g[1][k + 1] = P(x0, f[2], a)
					g[2][k + 1] = P(x1, f[2], a)
				end
			end
			local gn = gridNormals(g, function(_, _, p)
				if f[1] == "x" then
					return V3(1, 0, 0)
				end
				local rad = V3(0, p.Y, p.Z).Unit
				return if f[2] == rOut then rad else -rad
			end)
			addGrid(layers, "Caliper", g, gn, false)
		end
		for _, a in { a0, a1 } do
			local tang = V3(0, -math.sin(a), math.cos(a)) * (if a == a0 then -1 else 1)
			local g: Grid = { { P(x0, rIn, a), P(x1, rIn, a) }, { P(x0, rOut, a), P(x1, rOut, a) } }
			local gn: Grid = { { tang, tang }, { tang, tang } }
			addGrid(layers, "Caliper", g, gn, false)
		end
	end
	return layers
end

return CarMesh
