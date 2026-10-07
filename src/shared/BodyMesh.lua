--[[
	BodyMesh
	Pure-geometry generator for smooth car bodies (no Roblox APIs here, so it
	can be tested anywhere). Produces triangle meshes in the same space as
	CarBuilder (origin at ground centre, -Z forward, +Y up):

	  body  : lofted super-ellipse cross sections along the car. The bottom
	          edge arcs over every wheel (real wheel arches), the top follows a
	          curved hood -> belt line -> rear deck, ends are rounded, and on
	          super/hypercars the fenders bulge up over the wheels.
	  glass : the greenhouse - curved windscreen, side glass with tumblehome,
	          fastback / hatch / boxy rear depending on the class.
	  roof  : a painted roof panel laid over the top of the greenhouse.

	Each mesh is { verts = {Vector3}, tris = {{a, b, c}} } with outward winding.
]]

local BodyMesh = {}

export type Mesh = { verts: { Vector3 }, tris: { { number } } }

type Profile = {
	L: number,
	W: number,
	H: number,
	clr: number,
	belt: number,
	wheelR: number,
	wb: number,
	hood: number,
	ws: number,
	roof: number,
	rear: number,
	inset: number,
	slope: number,
	nose: number,
}

-- per-class styling on top of the CarBuilder dimensions
local STYLE = {
	Sedan = { n = 3.4, gn = 3.0, tumble = 0.16, hoodCurve = 2.4, fender = 0, rearExp = 1.2, endRound = 0.55 },
	Coupe = { n = 3.0, gn = 2.6, tumble = 0.2, hoodCurve = 2.0, fender = 0.06, rearExp = 0.85, endRound = 0.6 },
	SUV = { n = 4.2, gn = 3.8, tumble = 0.1, hoodCurve = 3.0, fender = 0, rearExp = 2.6, endRound = 0.5 },
	Supercar = { n = 2.7, gn = 2.4, tumble = 0.24, hoodCurve = 1.3, fender = 0.22, rearExp = 0.75, endRound = 0.7 },
	Hypercar = { n = 2.5, gn = 2.3, tumble = 0.26, hoodCurve = 1.15, fender = 0.26, rearExp = 0.7, endRound = 0.75 },
}

local function spow(v: number, e: number): number
	local s = if v < 0 then -1 else 1
	return s * math.abs(v) ^ e
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Stations along the car: denser near the ends and around the wheels
local function stations(p: Profile, count: number): { number }
	local list = {}
	for k = 0, count do
		local u = k / count
		-- cosine spacing puts more stations at the nose and tail
		local s = 0.5 - 0.5 * math.cos(u * math.pi)
		table.insert(list, -p.L / 2 + s * p.L)
	end
	return list
end

local function loft(sections: { { Vector3 } }, capStart: boolean, capEnd: boolean, closed: boolean): Mesh
	local verts: { Vector3 } = {}
	local tris: { { number } } = {}
	local ring = #sections[1]
	for _, sec in sections do
		for _, v in sec do
			table.insert(verts, v)
		end
	end
	local segs = if closed then ring else ring - 1
	for s = 1, #sections - 1 do
		local a0 = (s - 1) * ring
		local b0 = s * ring
		for i = 1, segs do
			local i2 = if i == ring then 1 else i + 1
			local a, b = a0 + i, a0 + i2
			local c, d = b0 + i, b0 + i2
			-- sections run front (-Z) to back (+Z) and the ring runs counter-clockwise
			-- in XY, so (b - a) x (c - a) points outwards
			table.insert(tris, { a, b, c })
			table.insert(tris, { b, d, c })
		end
	end
	local function cap(secIndex: number, flip: boolean)
		local sec = sections[secIndex]
		local center = Vector3.zero
		for _, v in sec do
			center += v
		end
		center /= #sec
		table.insert(verts, center)
		local ci = #verts
		local base = (secIndex - 1) * ring
		for i = 1, segs do
			local i2 = if i == ring then 1 else i + 1
			if flip then
				table.insert(tris, { ci, base + i2, base + i })
			else
				table.insert(tris, { ci, base + i, base + i2 })
			end
		end
	end
	if capStart then
		cap(1, true) -- front cap faces -Z
	end
	if capEnd then
		cap(#sections, false) -- rear cap faces +Z
	end
	return { verts = verts, tris = tris }
end

function BodyMesh.generate(class: string, p: Profile): { body: Mesh, glass: Mesh, roof: Mesh }
	local st = STYLE[class] or STYLE.Sedan
	local zFront = -p.L / 2
	local zBack = p.L / 2
	local zWs = zFront + p.hood
	local zWsTop = zWs + p.ws
	local zRoofEnd = zWsTop + p.roof
	local zRearEnd = zRoofEnd + p.rear
	local hw = p.W / 2
	local noseTop = p.clr + (p.belt - p.clr) * p.nose
	local wheelZs = { -p.wb / 2, p.wb / 2 }
	local archR = p.wheelR * 1.14

	local function archBottom(z: number): number
		local y = p.clr + 0.08
		for _, wz in wheelZs do
			local d = math.abs(z - wz)
			if d < archR then
				y = math.max(y, p.wheelR + math.sqrt(archR * archR - d * d) * 0.97)
			end
		end
		return y
	end

	local function fenderBulge(z: number): number
		local b = 0
		for _, wz in wheelZs do
			local d = math.abs(z - wz) / (archR * 1.9)
			if d < 1 then
				b = math.max(b, (math.cos(d * math.pi) + 1) / 2)
			end
		end
		return b
	end

	local function topLine(z: number): number
		local y
		if z <= zWs then
			local u = (z - zFront) / (zWs - zFront)
			y = noseTop + (p.belt + 0.04 - noseTop) * (1 - (1 - u) ^ st.hoodCurve)
		elseif z <= zRearEnd then
			-- belt line kicks up slightly towards the rear ("hips")
			local u = (z - zWs) / (zRearEnd - zWs)
			y = p.belt + 0.04 + 0.08 * u
		else
			local u = (z - zRearEnd) / (zBack - zRearEnd)
			y = p.belt + 0.12 - 0.12 * u
		end
		-- fenders rise over the wheels on low cars so the arches have meat
		local archTop = 0
		for _, wz in wheelZs do
			if math.abs(z - wz) < archR then
				archTop = math.max(archTop, p.wheelR + archR + 0.22)
			end
		end
		y += st.fender * fenderBulge(z)
		return math.max(y, archTop * fenderBulge(z) + y * (1 - fenderBulge(z)), archBottom(z) + 0.28)
	end

	-- rounding factor at the two ends (0 at the very tip, 1 inside)
	local function endRound(z: number): number
		local d = math.min(z - zFront, zBack - z)
		local r = st.endRound
		if d >= r then
			return 1
		end
		local u = d / r
		return math.sqrt(math.max(0, 1 - (1 - u) * (1 - u)))
	end

	-----------------------------------------------------------------
	-- Body
	-----------------------------------------------------------------
	local ringN = 30
	local zs = stations(p, 64)
	local bodySections = {}
	for _, z in zs do
		local e = endRound(z)
		local plan = 0.9 + 0.1 * smoothstep((math.min(z - zFront, zBack - z)) / 1.6)
		local w = hw * plan * (0.25 + 0.75 * e) + st.fender * 0.25 * fenderBulge(z)
		local top = topLine(z)
		local bottom = archBottom(z)
		local yc = (top + bottom) / 2
		local hh = (top - bottom) / 2 * (0.35 + 0.65 * e)
		-- lift the rounded tip towards the bumper line
		local tipY = if z < 0 then (p.clr + noseTop) / 2 else (p.clr + p.belt) / 2
		yc = yc * e + tipY * (1 - e)
		local sec = {}
		for i = 0, ringN - 1 do
			local th = (i / ringN) * math.pi * 2
			local c, s = math.cos(th), math.sin(th)
			local x = w * spow(c, 2 / st.n)
			local y = yc + hh * spow(s, 2 / st.n)
			-- flatter underside, more rounded shoulder
			if s < 0 then
				y = yc + hh * spow(s, 2 / (st.n + 2))
			end
			table.insert(sec, Vector3.new(x, y, z))
		end
		table.insert(bodySections, sec)
	end
	local body = loft(bodySections, true, true, true)

	-----------------------------------------------------------------
	-- Greenhouse (glass) + roof panel
	-----------------------------------------------------------------
	local gTop = p.H - 0.02
	local function roofLine(z: number): number
		if z <= zWsTop then
			local u = (z - zWs) / p.ws
			return p.belt + (gTop - p.belt) * (1 - (1 - u) ^ 1.5)
		elseif z <= zRoofEnd then
			local mid = (zWsTop + zRoofEnd) / 2
			local half = math.max(0.01, (zRoofEnd - zWsTop) / 2)
			return gTop - 0.07 * ((z - mid) / half) ^ 2
		end
		local u = (z - zRoofEnd) / math.max(0.01, p.rear)
		return gTop - (gTop - p.belt) * u ^ st.rearExp
	end
	local glassN = 18
	local gz = {}
	local gCount = 40
	for k = 0, gCount do
		table.insert(gz, zWs + 0.05 + (zRearEnd - 0.05 - zWs - 0.05) * k / gCount)
	end
	local baseW = hw - p.inset + 0.12
	local glassSections = {}
	local roofSections = {}
	for _, z in gz do
		local top = roofLine(z)
		local hgt = math.max(0.02, top - p.belt)
		-- greenhouse narrows slightly at its ends
		local endK = math.min(z - zWs, zRearEnd - z)
		local wz = baseW * (0.94 + 0.06 * smoothstep(endK / 1.2))
		local sec = {}
		local rsec = {}
		for i = 0, glassN do
			local th = (i / glassN) * math.pi -- 0 = right side, pi = left side
			local c, s = math.cos(th), math.sin(th)
			local yy = p.belt - 0.02 + hgt * spow(s, 2 / st.gn)
			local frac = (yy - p.belt) / hgt
			local x = wz * spow(c, 2 / st.gn) * (1 - st.tumble * frac)
			table.insert(sec, Vector3.new(x, yy, z))
			if th > 0.62 and th < math.pi - 0.62 then
				table.insert(rsec, Vector3.new(x * 1.012, yy + 0.03, z))
			end
		end
		table.insert(glassSections, sec)
		if z >= zWsTop - 0.15 and z <= zRoofEnd + 0.25 then
			table.insert(roofSections, rsec)
		end
	end
	local glass = loft(glassSections, false, false, false)
	local roof = loft(roofSections, false, false, false)
	return { body = body, glass = glass, roof = roof }
end

-- Smooth vertex normals (area weighted)
function BodyMesh.normals(mesh: Mesh): { Vector3 }
	local n = table.create(#mesh.verts, Vector3.zero)
	for _, t in mesh.tris do
		local a, b, c = mesh.verts[t[1]], mesh.verts[t[2]], mesh.verts[t[3]]
		local fn = (b - a):Cross(c - a)
		n[t[1]] += fn
		n[t[2]] += fn
		n[t[3]] += fn
	end
	for i, v in n do
		n[i] = if v.Magnitude > 1e-6 then v.Unit else Vector3.yAxis
	end
	return n
end

return BodyMesh
