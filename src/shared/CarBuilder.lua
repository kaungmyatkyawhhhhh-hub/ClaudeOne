--[[
	CarBuilder
	Builds every car in the game out of parts, procedurally:
	  * five body styles (Sedan, Coupe, SUV, Supercar, Hypercar)
	  * glass cabin, pillars, lights, mirrors, spoilers, intakes, exhausts
	  * optional full interior: dashboard, gauges, seats, console, ambient lighting
	  * optional driver with a steering wheel rig: the gloves are welded to the
	    wheel rim and the arms are solved every frame with 2-bone IK, so the
	    hands really turn the wheel.

	Coordinates while building: origin at the centre of the car on the ground,
	-Z is forward, +X is right, +Y is up. The "Chassis" part is the collision
	hitbox and PrimaryPart.
]]

local Cars = require(script.Parent.Cars)
local Config = require(script.Parent.Config)

local CarBuilder = {}

export type BuildOptions = {
	interior: boolean?, -- full cockpit + animated driver arms
	driver: boolean?, -- simple driver silhouette (NPCs)
	lights: boolean?, -- real SpotLights on the headlights
	anchored: boolean?,
	color: Color3?,
	underglow: Color3?,
	simpleWheels: boolean?,
	lite: boolean?, -- skip small details (used for NPC traffic)
}

type Dims = {
	L: number,
	W: number,
	H: number,
	clr: number,
	belt: number,
	wheelR: number,
	wheelW: number,
	wb: number,
	hood: number,
	ws: number,
	roof: number,
	rear: number,
	inset: number,
	slope: number,
	nose: number,
	doors: number,
}

local DIMS: { [string]: Dims } = {
	Sedan = { L = 14, W = 6.0, H = 4.5, clr = 0.65, belt = 2.72, wheelR = 1.08, wheelW = 0.85, wb = 8.6, hood = 4.0, ws = 2.3, roof = 3.8, rear = 2.1, inset = 0.45, slope = 0.4, nose = 0.55, doors = 4 },
	Coupe = { L = 13.6, W = 6.1, H = 4.15, clr = 0.55, belt = 2.5, wheelR = 1.08, wheelW = 0.9, wb = 8.3, hood = 4.2, ws = 2.6, roof = 2.4, rear = 3.0, inset = 0.5, slope = 0.5, nose = 0.5, doors = 2 },
	SUV = { L = 15.2, W = 6.5, H = 5.9, clr = 0.95, belt = 3.7, wheelR = 1.35, wheelW = 1.0, wb = 9.2, hood = 3.8, ws = 1.8, roof = 7.6, rear = 0.8, inset = 0.35, slope = 0.3, nose = 0.6, doors = 4 },
	Supercar = { L = 14.2, W = 6.5, H = 3.65, clr = 0.4, belt = 2.15, wheelR = 1.12, wheelW = 1.05, wb = 8.6, hood = 3.7, ws = 2.9, roof = 2.0, rear = 3.4, inset = 0.7, slope = 0.85, nose = 0.42, doors = 2 },
	Hypercar = { L = 14.8, W = 6.7, H = 3.45, clr = 0.35, belt = 2.0, wheelR = 1.12, wheelW = 1.1, wb = 8.9, hood = 3.4, ws = 3.1, roof = 1.8, rear = 3.8, inset = 0.75, slope = 0.95, nose = 0.4, doors = 2 },
}

function CarBuilder.getDims(class: string): Dims
	return DIMS[class] or DIMS.Sedan
end

---------------------------------------------------------------------
-- Styles
---------------------------------------------------------------------
type Style = {
	Color: Color3,
	Material: Enum.Material,
	Reflectance: number?,
	Transparency: number?,
}

local function makeStyles(body: Color3, accent: Color3, ambient: Color3): { [string]: Style }
	return {
		Body = { Color = body, Material = Enum.Material.SmoothPlastic, Reflectance = 0.14 },
		Accent = { Color = accent, Material = Enum.Material.SmoothPlastic, Reflectance = 0.1 },
		Glass = { Color = Color3.fromRGB(18, 22, 28), Material = Enum.Material.Glass, Transparency = 0.45, Reflectance = 0.2 },
		Trim = { Color = Color3.fromRGB(14, 14, 16), Material = Enum.Material.SmoothPlastic },
		Carbon = { Color = Color3.fromRGB(26, 26, 29), Material = Enum.Material.Fabric },
		Chrome = { Color = Color3.fromRGB(205, 208, 214), Material = Enum.Material.Metal, Reflectance = 0.35 },
		Rubber = { Color = Color3.fromRGB(20, 20, 22), Material = Enum.Material.Rubber },
		Rim = { Color = Color3.fromRGB(70, 72, 78), Material = Enum.Material.Metal, Reflectance = 0.3 },
		Head = { Color = Color3.fromRGB(235, 242, 255), Material = Enum.Material.Neon },
		Tail = { Color = Color3.fromRGB(150, 0, 6), Material = Enum.Material.Neon },
		Amber = { Color = Color3.fromRGB(255, 140, 0), Material = Enum.Material.Neon },
		Plate = { Color = Color3.fromRGB(232, 232, 228), Material = Enum.Material.SmoothPlastic },
		Interior = { Color = Color3.fromRGB(24, 24, 28), Material = Enum.Material.Leather },
		Interior2 = { Color = Color3.fromRGB(44, 44, 50), Material = Enum.Material.Fabric },
		Stitch = { Color = accent, Material = Enum.Material.Leather },
		Ambient = { Color = ambient, Material = Enum.Material.Neon, Transparency = 0.15 },
		Screen = { Color = Color3.fromRGB(8, 10, 14), Material = Enum.Material.SmoothPlastic },
		Skin = { Color = Color3.fromRGB(226, 182, 145), Material = Enum.Material.SmoothPlastic },
		Hair = { Color = Color3.fromRGB(22, 18, 16), Material = Enum.Material.Fabric },
		Jacket = { Color = Color3.fromRGB(22, 22, 26), Material = Enum.Material.Fabric },
		Jeans = { Color = Color3.fromRGB(30, 36, 52), Material = Enum.Material.Fabric },
		Glove = { Color = Color3.fromRGB(12, 12, 12), Material = Enum.Material.Leather },
		Underglow = { Color = ambient, Material = Enum.Material.Neon, Transparency = 0.1 },
		Hitbox = { Color = Color3.new(1, 0, 0), Material = Enum.Material.SmoothPlastic, Transparency = 1 },
	}
end

---------------------------------------------------------------------
-- IK helper (shared with the client driving script)
---------------------------------------------------------------------
-- Returns the CFrames (in the same space as the inputs) of an upper and a lower
-- bone whose length runs along their local Z axis.
function CarBuilder.solveArm(shoulder: Vector3, target: Vector3, upperLen: number, foreLen: number, pole: Vector3): (CFrame, CFrame)
	local toTarget = target - shoulder
	local dist = math.clamp(toTarget.Magnitude, 0.05, upperLen + foreLen - 0.01)
	local dir = toTarget.Unit
	-- law of cosines: distance along dir to the elbow projection
	local x = (upperLen * upperLen - foreLen * foreLen + dist * dist) / (2 * dist)
	local h = math.sqrt(math.max(upperLen * upperLen - x * x, 0))
	local perp = pole - dir * pole:Dot(dir)
	if perp.Magnitude < 1e-3 then
		perp = Vector3.new(0, -1, 0)
	end
	perp = perp.Unit
	local elbow = shoulder + dir * x + perp * h
	local hand = shoulder + dir * dist

	local upperCF = CFrame.lookAt((shoulder + elbow) / 2, elbow, Vector3.yAxis)
	local foreCF = CFrame.lookAt((elbow + hand) / 2, hand, Vector3.yAxis)
	return upperCF, foreCF
end

---------------------------------------------------------------------
-- Builder
---------------------------------------------------------------------
function CarBuilder.build(spec: Cars.CarSpec, options: BuildOptions?): Model
	local opts: BuildOptions = options or {}
	local d = CarBuilder.getDims(spec.Class)
	local L, W, H = d.L, d.W, d.H
	local clr, belt = d.clr, d.belt
	local class = spec.Class
	local isSuper = class == "Supercar" or class == "Hypercar"

	local bodyColor = opts.color or spec.Color
	local accent = spec.Accent or bodyColor
	local ambientColor = opts.underglow or Color3.fromRGB(150, 70, 255)
	local styles = makeStyles(bodyColor, accent, ambientColor)
	local lite = opts.lite == true

	local model = Instance.new("Model")
	model.Name = spec.Name

	local parts: { BasePart } = {}
	local welds: { { BasePart } } = {} -- {part, weldTo}

	-- Root hitbox
	local root = Instance.new("Part")
	root.Name = "Chassis"
	root.Size = Vector3.new(W - 0.1, H - 0.05, L - 0.1)
	root.CFrame = CFrame.new(0, H / 2, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.CanQuery = true
	root.CanTouch = true
	root.Anchored = true
	root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	-- parts built while this is true are bodywork that the smooth mesh skin replaces
	local exterior = true
	local function finishPart(p: BasePart, name: string, styleName: string, cf: CFrame, size: Vector3, weldTo: any)
		local st = styles[styleName] or styles.Body
		if exterior then
			p:SetAttribute("Ext", true)
		end
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = st.Color
		p.Material = st.Material
		p.Reflectance = st.Reflectance or 0
		p.Transparency = st.Transparency or 0
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = styleName ~= "Glass" and styleName ~= "Head" and styleName ~= "Tail"
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		table.insert(parts, p)
		-- weldTo == false means "do not weld" (part is driven by a Motor6D)
		if weldTo ~= false then
			table.insert(welds, { p, weldTo or root })
		end
	end

	local function block(name: string, size: Vector3, cf: CFrame, styleName: string, weldTo: any): Part
		local p = Instance.new("Part")
		finishPart(p, name, styleName, cf, size, weldTo)
		return p
	end

	local function wedge(name: string, size: Vector3, cf: CFrame, styleName: string, weldTo: any): WedgePart
		local p = Instance.new("WedgePart")
		finishPart(p, name, styleName, cf, size, weldTo)
		return p
	end

	local function cyl(name: string, size: Vector3, cf: CFrame, styleName: string, weldTo: any): Part
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		finishPart(p, name, styleName, cf, size, weldTo)
		return p
	end

	local function ball(name: string, diameter: number, cf: CFrame, styleName: string, weldTo: any): Part
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		finishPart(p, name, styleName, cf, Vector3.one * diameter, weldTo)
		return p
	end

	local function beam(name: string, a: Vector3, b: Vector3, thickness: number, styleName: string, weldTo: any): Part
		local len = (b - a).Magnitude
		return block(name, Vector3.new(thickness, thickness, len), CFrame.lookAt((a + b) / 2, b), styleName, weldTo)
	end

	-- Box from min/max corners
	local function box(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, styleName: string): Part
		return block(
			name,
			Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
			CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
			styleName
		)
	end

	-- Wedge from min/max corners. flip = slope descends toward +Z instead of -Z
	local function wedgeBox(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, styleName: string, flip: boolean?): WedgePart
		local cf = CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		if flip then
			cf *= CFrame.Angles(0, math.pi, 0)
		end
		return wedge(name, Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)), cf, styleName)
	end

	-----------------------------------------------------------------
	-- Key stations along the car
	-----------------------------------------------------------------
	local zFront = -L / 2
	local zWs = zFront + d.hood
	local zWsTop = zWs + d.ws
	local zRoofEnd = zWsTop + d.roof
	local zRearEnd = zRoofEnd + d.rear
	local zBack = L / 2
	local Wc = W - d.inset * 2
	local noseTop = clr + (belt - clr) * d.nose
	local hw = W / 2

	-----------------------------------------------------------------
	-- Lower body
	-----------------------------------------------------------------
	-- Hood section: bumper block + sloped hood
	local slopeLen = d.hood * d.slope
	box("FrontBumper", -hw, clr, zFront, hw, noseTop, zWs, "Body")
	wedgeBox("HoodSlope", -hw, noseTop, zFront, hw, belt, zFront + slopeLen, "Body")
	if slopeLen < d.hood - 0.01 then
		box("Hood", -hw, noseTop, zFront + slopeLen, hw, belt, zWs, "Body")
	end

	-- Cabin section: hollow (doors + floor) so the interior is visible
	local doorT = 0.35
	box("DoorL", -hw, clr, zWs, -hw + doorT, belt, zRearEnd, "Body")
	box("DoorR", hw - doorT, clr, zWs, hw, belt, zRearEnd, "Body")
	box("Floor", -hw + doorT, clr, zWs, hw - doorT, clr + 0.25, zRearEnd, "Interior2")
	box("Firewall", -hw + doorT, clr + 0.25, zWs, hw - doorT, belt, zWs + 0.3, "Interior")

	-- Tail section
	local tailTop = belt
	box("Tail", -hw, clr, zRearEnd, hw, tailTop, zBack, "Body")
	if class == "Coupe" or class == "Sedan" then
		-- small duck-tail lip on the boot
		wedgeBox("Ducktail", -hw + 0.4, tailTop, zBack - 0.9, hw - 0.4, tailTop + 0.18, zBack - 0.1, "Body", true)
	end

	-- Side skirts + door seams
	box("SkirtL", -hw - 0.04, clr - 0.05, zWs - 0.4, -hw + 0.2, clr + 0.35, zRearEnd + 0.2, isSuper and "Carbon" or "Trim")
	box("SkirtR", hw - 0.2, clr - 0.05, zWs - 0.4, hw + 0.04, clr + 0.35, zRearEnd + 0.2, isSuper and "Carbon" or "Trim")
	local doorEnd = if d.doors == 4 then zWsTop + d.roof * 0.48 else zRoofEnd - 0.2
	for _, sx in (if lite then {} else { -1, 1 }) :: { number } do
		local x = sx * (hw + 0.01)
		block("Seam", Vector3.new(0.04, belt - clr - 0.45, 0.05), CFrame.new(x, (clr + 0.35 + belt) / 2, zWs + 0.15), "Trim")
		block("Seam", Vector3.new(0.04, belt - clr - 0.45, 0.05), CFrame.new(x, (clr + 0.35 + belt) / 2, doorEnd), "Trim")
		block("Handle", Vector3.new(0.06, 0.14, 0.55), CFrame.new(x + sx * 0.02, belt - 0.35, doorEnd - 0.6), "Chrome")
		if d.doors == 4 then
			block("Seam", Vector3.new(0.04, belt - clr - 0.45, 0.05), CFrame.new(x, (clr + 0.35 + belt) / 2, zRoofEnd - 0.1), "Trim")
			block("Handle", Vector3.new(0.06, 0.14, 0.55), CFrame.new(x + sx * 0.02, belt - 0.35, zRoofEnd - 0.7), "Chrome")
		end
	end

	-----------------------------------------------------------------
	-- Greenhouse
	-----------------------------------------------------------------
	local glassTop = H - 0.3
	wedgeBox("Windshield", -Wc / 2, belt, zWs, Wc / 2, glassTop, zWsTop, "Glass")
	box("SideGlassL", -Wc / 2, belt, zWsTop, -Wc / 2 + 0.12, glassTop, zRoofEnd, "Glass")
	box("SideGlassR", Wc / 2 - 0.12, belt, zWsTop, Wc / 2, glassTop, zRoofEnd, "Glass")
	if d.rear > 0.05 then
		wedgeBox("RearGlass", -Wc / 2, belt, zRoofEnd, Wc / 2, glassTop, zRearEnd, "Glass", true)
	end
	local roofStyle = if spec.Accent then "Accent" else "Body"
	box("Roof", -Wc / 2 - 0.02, glassTop, zWsTop - 0.05, Wc / 2 + 0.02, H, zRoofEnd + 0.05, roofStyle)
	-- Window sill (gives the cabin a "sitting on the body" look)
	box("SillL", -hw, belt, zWs, -Wc / 2, belt + 0.06, zRearEnd, "Body")
	box("SillR", Wc / 2, belt, zWs, hw, belt + 0.06, zRearEnd, "Body")

	-- Pillars
	local pillarStyle = if isSuper then "Trim" else roofStyle
	for _, sx in { -1, 1 } do
		local x = sx * (Wc / 2 - 0.05)
		beam("APillar", Vector3.new(x, belt, zWs), Vector3.new(x, glassTop + 0.05, zWsTop), 0.22, pillarStyle)
		if d.rear > 0.05 then
			beam("CPillar", Vector3.new(x, glassTop + 0.05, zRoofEnd), Vector3.new(x, belt, zRearEnd), 0.26, pillarStyle)
		else
			block("DPillar", Vector3.new(0.24, glassTop - belt, 0.3), CFrame.new(x, (glassTop + belt) / 2, zRoofEnd - 0.1), pillarStyle)
		end
		if d.doors == 4 then
			block("BPillar", Vector3.new(0.2, glassTop - belt, 0.3), CFrame.new(x, (glassTop + belt) / 2, doorEnd), "Trim")
		end
		-- Chrome belt-line trim on the classier cars
		if (class == "Sedan" or class == "SUV") and not lite then
			block("BeltTrim", Vector3.new(0.05, 0.06, zRoofEnd - zWsTop), CFrame.new(sx * (Wc / 2 + 0.03), belt + 0.08, (zWsTop + zRoofEnd) / 2), "Chrome")
		end
		-- Mirrors
		local mBase = Vector3.new(sx * (Wc / 2 + 0.05), belt + 0.25, zWs + 0.55)
		local mHead = mBase + Vector3.new(sx * 0.45, 0.12, 0.05)
		beam("MirrorArm", mBase, mHead, 0.1, "Trim")
		block("Mirror", Vector3.new(0.45, 0.32, 0.22), CFrame.new(mHead + Vector3.new(sx * 0.12, 0, 0)), roofStyle)
		if not lite then
			block("MirrorGlass", Vector3.new(0.38, 0.25, 0.02), CFrame.new(mHead + Vector3.new(sx * 0.12, 0, 0.12)), "Chrome")
		end
	end

	-- Roof extras
	if class == "SUV" then
		for _, sx in { -1, 1 } do
			box("RoofRail", sx * (Wc / 2 - 0.35), H, zWsTop + 0.3, sx * (Wc / 2 - 0.15), H + 0.15, zRoofEnd - 0.3, "Chrome")
		end
		box("RoofSpoiler", -Wc / 2, H - 0.1, zRoofEnd - 0.1, Wc / 2, H + 0.05, zRoofEnd + 0.45, roofStyle)
	end

	-----------------------------------------------------------------
	-- Front details
	-----------------------------------------------------------------
	local front = zFront - 0.02
	local headY = noseTop - (if isSuper then 0.05 else 0.25)
	local headW = if isSuper then W * 0.2 else W * 0.22
	local headH = if isSuper then 0.16 else 0.3
	local headLights: { BasePart } = {}
	for _, sx in { -1, 1 } do
		local hx = sx * (hw - headW / 2 - 0.25)
		block("HeadHousing", Vector3.new(headW + 0.12, headH + 0.12, 0.1), CFrame.new(hx, headY, front + 0.02), "Trim")
		local hl = block("Headlight", Vector3.new(headW, headH, 0.12), CFrame.new(hx, headY, front - 0.01), "Head")
		table.insert(headLights, hl)
		if lite then
			continue
		end
		-- LED daytime running light under the lamp
		block("DRL", Vector3.new(headW * 0.9, 0.06, 0.08), CFrame.new(hx, headY - headH / 2 - 0.14, front), "Head")
		-- Indicator
		block("Indicator", Vector3.new(0.25, 0.1, 0.08), CFrame.new(sx * (hw - 0.2), headY - 0.02, front + 0.05), "Amber")
	end

	-- Grille / intakes
	if isSuper then
		box("IntakeL", -hw + 0.35, clr + 0.15, front - 0.04, -0.9, clr + 0.6, front + 0.15, "Trim")
		box("IntakeR", 0.9, clr + 0.15, front - 0.04, hw - 0.35, clr + 0.6, front + 0.15, "Trim")
		box("Splitter", -hw + 0.1, clr - 0.08, zFront - 0.25, hw - 0.1, clr + 0.02, zFront + 0.6, "Carbon")
	else
		local gw = if class == "SUV" then W * 0.55 else W * 0.42
		local gh = if class == "SUV" then (noseTop - clr) * 0.75 else (noseTop - clr) * 0.55
		local gy = clr + (noseTop - clr) * 0.55
		block("Grille", Vector3.new(gw, gh, 0.1), CFrame.new(0, gy, front - 0.02), "Trim")
		for i = 1, (if lite then 0 else 3) do
			block("GrilleBar", Vector3.new(gw - 0.1, 0.05, 0.06), CFrame.new(0, gy - gh / 2 + gh * i / 4, front - 0.06), "Chrome")
		end
		box("LowerIntake", -W * 0.3, clr + 0.05, front - 0.03, W * 0.3, clr + 0.3, front + 0.1, "Trim")
		if class == "Coupe" then
			box("Splitter", -hw + 0.2, clr - 0.06, zFront - 0.15, hw - 0.2, clr + 0.02, zFront + 0.5, "Carbon")
		end
	end
	block("PlateF", Vector3.new(1.15, 0.36, 0.05), CFrame.new(0, clr + 0.32, front - 0.08), "Plate")

	-----------------------------------------------------------------
	-- Rear details
	-----------------------------------------------------------------
	local back = zBack + 0.02
	local tailLights: { BasePart } = {}
	local tailY = tailTop - (if isSuper then 0.25 else 0.4)
	if class == "Hypercar" or class == "Supercar" then
		table.insert(tailLights, block("Taillight", Vector3.new(W - 0.6, 0.12, 0.1), CFrame.new(0, tailY, back), "Tail"))
	else
		for _, sx in { -1, 1 } do
			table.insert(tailLights, block("Taillight", Vector3.new(W * 0.24, 0.3, 0.1), CFrame.new(sx * (hw - W * 0.12 - 0.15), tailY, back), "Tail"))
		end
		if class == "SUV" or class == "Sedan" then
			table.insert(tailLights, block("Taillight", Vector3.new(W * 0.4, 0.06, 0.08), CFrame.new(0, tailY + 0.1, back), "Tail"))
		end
	end
	block("PlateR", Vector3.new(1.15, 0.36, 0.05), CFrame.new(0, clr + 0.7, back + 0.03), "Plate")
	box("Diffuser", -hw + 0.4, clr - 0.06, back - 0.6, hw - 0.4, clr + 0.3, back + 0.04, isSuper and "Carbon" or "Trim")
	if isSuper and not lite then
		for i = -2, 2 do
			block("DiffuserFin", Vector3.new(0.06, 0.32, 0.6), CFrame.new(i * 0.7, clr + 0.1, back - 0.25), "Carbon")
		end
	end

	-- Exhausts (cylinder axis is X, rotate to point backwards)
	local exhaustXs: { number } = if class == "Hypercar" then { -0.35, 0.35 } elseif isSuper then { -1.1, -0.7, 0.7, 1.1 } else { -hw + 0.9, hw - 0.9 }
	for _, ex in exhaustXs do
		cyl("Exhaust", Vector3.new(0.5, 0.36, 0.36), CFrame.new(ex, clr + 0.18, back) * CFrame.Angles(0, math.pi / 2, 0), "Chrome")
	end

	-- Supercar side intakes
	if isSuper then
		for _, sx in { -1, 1 } do
			block("SideIntake", Vector3.new(0.08, (belt - clr) * 0.5, 1.7), CFrame.new(sx * (hw + 0.01), clr + (belt - clr) * 0.5, zRoofEnd + 0.4), "Trim")
		end
		-- engine cover vents
		for i = 0, (if lite then -1 else 3) do
			block("EngineVent", Vector3.new(W * 0.45, 0.04, 0.12), CFrame.new(0, tailTop + 0.02, zRearEnd + 0.35 + i * 0.35), "Trim")
		end
	end

	-- Spoilers
	if class == "Hypercar" then
		local wingY = belt + 1.05
		local wingZ = zBack - 0.85
		block("Wing", Vector3.new(W - 0.5, 0.12, 1.2), CFrame.new(0, wingY, wingZ) * CFrame.Angles(math.rad(-6), 0, 0), "Carbon")
		for _, sx in { -1, 1 } do
			block("WingPlate", Vector3.new(0.08, 0.6, 1.3), CFrame.new(sx * (W / 2 - 0.25), wingY + 0.05, wingZ), "Carbon")
			beam("WingPost", Vector3.new(sx * 1.2, tailTop, wingZ + 0.3), Vector3.new(sx * 1.2, wingY - 0.05, wingZ), 0.14, "Carbon")
		end
	elseif class == "Supercar" then
		wedgeBox("Spoiler", -hw + 0.5, tailTop, zBack - 0.7, hw - 0.5, tailTop + 0.3, zBack + 0.05, "Carbon", true)
	end

	-----------------------------------------------------------------
	-- Wheels
	-----------------------------------------------------------------
	local wheelMotors: { Motor6D } = {}
	local wheelParts: { { part: any, front: boolean, name: string } } = {}
	local R = d.wheelR
	for _, info in { { "FL", -1, true }, { "FR", 1, true }, { "RL", -1, false }, { "RR", 1, false } } do
		local wname, sx, isFront = info[1] :: string, info[2] :: number, info[3] :: boolean
		local rr = if isSuper and not isFront then R * 1.04 else R
		local wz = if isFront then -d.wb / 2 else d.wb / 2
		local wx = sx * (hw - d.wheelW / 2 - 0.06)
		local tireCF = CFrame.new(wx, rr, wz)
		local tire = cyl("Wheel" .. wname, Vector3.new(d.wheelW, rr * 2, rr * 2), tireCF, "Rubber", false)
		-- the tyre is attached with a Motor6D so the client can spin & steer it
		local face = sx * (d.wheelW / 2 + 0.02)
		cyl("Rim", Vector3.new(0.08, rr * 1.42, rr * 1.42), tireCF * CFrame.new(face, 0, 0), "Rim", tire)
		cyl("Hub", Vector3.new(0.1, rr * 0.3, rr * 0.3), tireCF * CFrame.new(face + sx * 0.05, 0, 0), "Chrome", tire)
		if not opts.simpleWheels then
			local spokes = if isSuper then 10 else 5
			for k = 0, spokes - 1 do
				local cf = tireCF * CFrame.new(face + sx * 0.04, 0, 0) * CFrame.Angles(k * 2 * math.pi / spokes, 0, 0) * CFrame.new(0, 0, rr * 0.36)
				block("Spoke", Vector3.new(0.07, if isSuper then 0.09 else 0.17, rr * 0.62), cf, "Chrome", tire)
			end
			-- brake caliper (rides with the wheel for simplicity, tucked behind the rim)
			if isSuper then
				block("Caliper", Vector3.new(0.18, rr * 0.5, 0.3), tireCF * CFrame.new(face - sx * 0.12, rr * 0.45, 0), "Amber", tire)
			end
		end
		-- dark wheel-arch shadow above the tyre
		block("Arch", Vector3.new(d.wheelW + 0.1, 0.18, rr * 2.2), CFrame.new(wx, rr * 2 + 0.05, wz), "Trim")
		table.insert(wheelParts, { part = tire, front = isFront, name = wname })
	end

	-----------------------------------------------------------------
	-- Underglow
	-----------------------------------------------------------------
	if opts.underglow then
		local glow = block("Underglow", Vector3.new(W - 1.2, 0.08, L - 3), CFrame.new(0, clr - 0.12, 0), "Underglow")
		local pl = Instance.new("PointLight")
		pl.Color = opts.underglow
		pl.Range = 14
		pl.Brightness = 3
		pl.Shadows = false
		pl.Parent = glow
	end

	-----------------------------------------------------------------
	-- Driver / interior
	-----------------------------------------------------------------
	exterior = false
	local driverX = -W * 0.21
	local eyeY = math.min(H - 0.7, belt + 0.95)
	local eyeZ = zWsTop + 0.75
	local seatY = math.max(clr + 0.4, eyeY - 2.25)

	local function addSeat(x: number, z: number, name: string)
		box(name .. "Cushion", x - 0.8, seatY - 0.25, z - 0.85, x + 0.8, seatY + 0.2, z + 0.85, "Interior")
		local backCF = CFrame.new(x, seatY + 1.25, z + 0.95) * CFrame.Angles(math.rad(14), 0, 0)
		block(name .. "Back", Vector3.new(1.6, 2.4, 0.4), backCF, "Interior")
		block(name .. "Stripe", Vector3.new(0.3, 2.2, 0.05), backCF * CFrame.new(0, 0, -0.21), "Stitch")
		block(name .. "Headrest", Vector3.new(0.95, 0.65, 0.35), backCF * CFrame.new(0, 1.45, 0.05), "Interior")
	end

	local steerMount: CFrame? = nil
	local hub: Part? = nil
	if opts.interior then
		local innerX = hw - doorT
		local wheelCenter = Vector3.new(driverX, eyeY - 0.9, eyeZ - 1.65)
		local dashRear = wheelCenter.Z - 0.45
		local dashTop = belt + 0.22

		-- Dashboard
		-- the dash top sits above the belt, so keep it inside the glass
		local dashX = math.min(innerX, Wc / 2 - 0.2)
		box("Dashboard", -dashX, belt - 0.95, zWs + 0.3, dashX, dashTop, dashRear, "Interior")
		box("DashTop", -dashX, dashTop - 0.02, zWs + 0.3, dashX, dashTop + 0.04, dashRear + 0.08, "Interior2")
		block("AmbientDash", Vector3.new(innerX * 2 - 0.2, 0.05, 0.04), CFrame.new(0, belt - 0.3, dashRear + 0.02), "Ambient")
		-- Instrument cluster: the client renders live gauges on the "Cluster" screen
		local clusterCF = CFrame.new(driverX, dashTop + 0.2, dashRear - 0.15) * CFrame.Angles(math.rad(-12), 0, 0)
		block("ClusterHood", Vector3.new(1.5, 0.5, 0.55), clusterCF * CFrame.new(0, 0.05, -0.1), "Interior")
		local cluster = block("Cluster", Vector3.new(1.3, 0.38, 0.04), clusterCF * CFrame.new(0, -0.02, 0.18), "Screen")
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Gauges"
		gui.Face = Enum.NormalId.Back
		gui.LightInfluence = 0
		gui.Brightness = 1.6
		gui.CanvasSize = Vector2.new(340, 100)
		gui.Parent = cluster
		-- Centre infotainment screen
		local screen = block("Infotainment", Vector3.new(1.1, 0.65, 0.05), CFrame.new(0, belt + 0.02, dashRear + 0.04) * CFrame.Angles(math.rad(-15), 0, 0), "Screen")
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.LightInfluence = 0
		sg.Brightness = 1.2
		sg.CanvasSize = Vector2.new(220, 130)
		sg.Parent = screen
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
		bg.BorderSizePixel = 0
		bg.Parent = sg
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(Color3.fromRGB(40, 20, 80), Color3.fromRGB(0, 70, 90))
		grad.Rotation = 35
		grad.Parent = bg
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.GothamBlack
		t.Text = "CITY LEGENDS"
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextScaled = true
		t.Parent = bg
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.1, 0)
		pad.PaddingRight = UDim.new(0.1, 0)
		pad.PaddingTop = UDim.new(0.35, 0)
		pad.PaddingBottom = UDim.new(0.35, 0)
		pad.Parent = bg

		-- Vents
		for _, vx in { -innerX + 0.5, -0.45, 0.45, innerX - 0.5 } do
			block("Vent", Vector3.new(0.5, 0.22, 0.04), CFrame.new(vx, belt - 0.05, dashRear + 0.02), "Chrome")
		end

		-- Centre console + gear selector
		box("Console", -0.45, clr + 0.25, dashRear - 0.1, 0.45, belt - 0.75, eyeZ + 1.1, "Interior")
		block("ConsoleTrim", Vector3.new(0.92, 0.04, eyeZ + 1.2 - dashRear), CFrame.new(0, belt - 0.73, (dashRear + eyeZ + 1.1) / 2), "Carbon")
		block("Shifter", Vector3.new(0.18, 0.4, 0.18), CFrame.new(0, belt - 0.5, eyeZ - 0.4), "Chrome")
		block("ShifterKnob", Vector3.new(0.3, 0.16, 0.38), CFrame.new(0, belt - 0.28, eyeZ - 0.42), "Interior")

		-- Door cards with ambient LED strips
		for _, sx in { -1, 1 } do
			local x = sx * (innerX - 0.05)
			block("DoorCard", Vector3.new(0.1, belt - clr - 0.4, zRearEnd - zWs - 0.6), CFrame.new(x, (clr + 0.25 + belt - 0.1) / 2, (zWs + zRearEnd) / 2), "Interior")
			block("AmbientDoor", Vector3.new(0.04, 0.04, zRearEnd - zWs - 1.2), CFrame.new(x - sx * 0.06, belt - 0.25, (zWs + zRearEnd) / 2), "Ambient")
			block("Armrest", Vector3.new(0.3, 0.12, 1.4), CFrame.new(x - sx * 0.18, belt - 0.75, eyeZ + 0.1), "Interior2")
		end

		-- Seats
		addSeat(driverX, eyeZ + 0.35, "DriverSeat")
		addSeat(-driverX, eyeZ + 0.35, "PassengerSeat")
		if d.doors == 4 then
			local rz = math.min(eyeZ + 3.0, zRoofEnd - 0.2)
			box("RearBench", -innerX + 0.1, seatY - 0.2, rz - 0.8, innerX - 0.1, seatY + 0.2, rz + 0.8, "Interior")
			block("RearBack", Vector3.new(innerX * 2 - 0.2, 2.2, 0.4), CFrame.new(0, seatY + 1.2, rz + 0.95) * CFrame.Angles(math.rad(16), 0, 0), "Interior")
		end

		-- Headliner + rear view mirror
		-- the part headliner only suits the part body (the mesh cabin has its own)
		exterior = true
		box("Headliner", -Wc / 2 + 0.12, glassTop - 0.06, zWsTop, Wc / 2 - 0.12, glassTop, zRoofEnd, "Interior2")
		exterior = false
		block("RearViewMirror", Vector3.new(0.85, 0.22, 0.08), CFrame.new(0, glassTop - 0.3, zWsTop - 0.15), "Trim")
		block("RearViewGlass", Vector3.new(0.78, 0.16, 0.02), CFrame.new(0, glassTop - 0.3, zWsTop - 0.1), "Chrome")

		-- Pedals
		for i, px in { -0.35, 0, 0.35 } do
			block("Pedal", Vector3.new(0.22, 0.32, 0.06), CFrame.new(driverX + px, clr + 0.75, wheelCenter.Z - 0.9 - (if i == 3 then 0.05 else 0)) * CFrame.Angles(math.rad(25), 0, 0), "Chrome")
		end

		-- Steering wheel rig ------------------------------------------------
		local tilt = math.rad(24)
		local columnDir = Vector3.new(0, -math.sin(tilt), -math.cos(tilt))
		local mount = CFrame.lookAt(wheelCenter, wheelCenter + columnDir)
		steerMount = mount
		beam("SteeringColumn", wheelCenter + columnDir * 0.15, wheelCenter + columnDir * 1.1, 0.22, "Interior")

		local hubPart = block("SteerHub", Vector3.new(0.2, 0.2, 0.2), mount, "Trim", false)
		hubPart.Transparency = 1
		hub = hubPart
		local ringR = 0.62
		local segs = 18
		for i = 0, segs - 1 do
			local a = i / segs * math.pi * 2
			local cf = mount * CFrame.new(ringR * math.cos(a), ringR * math.sin(a), 0) * CFrame.Angles(0, 0, a)
			block("WheelRim", Vector3.new(0.15, 2 * math.pi * ringR / segs * 1.12, 0.17), cf, if i % 6 == 4 then "Stitch" else "Interior", hubPart)
		end
		for _, a in { 0, math.pi, -math.pi / 2 } do
			local cf = mount * CFrame.Angles(0, 0, a) * CFrame.new(ringR / 2, 0, 0.02)
			block("WheelSpoke", Vector3.new(ringR - 0.05, 0.14, 0.07), cf, "Carbon", hubPart)
		end
		cyl("WheelPad", Vector3.new(0.12, 0.42, 0.42), mount * CFrame.new(0, 0, 0.04) * CFrame.Angles(0, math.pi / 2, 0), "Interior", hubPart)
		block("WheelLogo", Vector3.new(0.16, 0.06, 0.02), mount * CFrame.new(0, 0, 0.11), "Ambient", hubPart)
		if isSuper then
			for _, sx in { -1, 1 } do
				block("Paddle", Vector3.new(0.25, 0.35, 0.04), mount * CFrame.new(sx * 0.42, 0.05, -0.12), "Carbon", hubPart)
			end
		end

		-- Gloves gripping the rim at roughly 10 and 2
		local gripAngles = { L = math.rad(160), R = math.rad(20) }
		for side, a in gripAngles do
			local cf = mount * CFrame.new(ringR * math.cos(a), ringR * math.sin(a), 0.03) * CFrame.Angles(0, 0, a)
			block("Glove" .. side, Vector3.new(0.3, 0.42, 0.34), cf, "Glove", hubPart)
			block("Thumb" .. side, Vector3.new(0.1, 0.18, 0.1), cf * CFrame.new(0, (if side == "L" then -0.18 else 0.18), 0.18), "Glove", hubPart)
			model:SetAttribute("Grip" .. side, Vector3.new(ringR * 0.9 * math.cos(a), ringR * 0.9 * math.sin(a), 0.24))
		end
		model:SetAttribute("SteerMaxRot", math.rad(115))
	end

	-- Driver body (both full and silhouette versions)
	local headPart: BasePart? = nil
	if opts.interior or opts.driver then
		local torsoCF = CFrame.new(driverX, eyeY - 1.4, eyeZ + 0.5) * CFrame.Angles(math.rad(12), 0, 0)
		block("DriverTorso", Vector3.new(1.35, 1.75, 0.7), torsoCF, "Jacket")
		local head = ball("DriverHead", 0.85, CFrame.new(driverX, eyeY + 0.05, eyeZ + 0.15), "Skin")
		headPart = head
		ball("DriverHair", 0.9, CFrame.new(driverX, eyeY + 0.17, eyeZ + 0.25), "Hair")
		cyl("DriverNeck", Vector3.new(0.45, 0.35, 0.35), CFrame.new(driverX, eyeY - 0.45, eyeZ + 0.3) * CFrame.Angles(0, 0, math.pi / 2), "Skin")
		if opts.interior then
			-- legs
			for _, sx in { -1, 1 } do
				local hip = Vector3.new(driverX + sx * 0.35, seatY + 0.4, eyeZ + 0.55)
				local knee = Vector3.new(driverX + sx * 0.38, seatY + 0.75, eyeZ - 1.25)
				local foot = Vector3.new(driverX + sx * 0.3, clr + 0.6, eyeZ - 2.15)
				beam("Thigh", hip, knee, 0.55, "Jeans")
				beam("Shin", knee, foot, 0.45, "Jeans")
				block("Shoe", Vector3.new(0.4, 0.3, 0.75), CFrame.new(foot + Vector3.new(0, -0.05, -0.2)), "Trim")
			end
		end
	end

	-----------------------------------------------------------------
	-- Lights
	-----------------------------------------------------------------
	if opts.lights then
		for _, hl in headLights do
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Range = 60
			spot.Angle = 70
			spot.Brightness = 5
			spot.Color = Color3.fromRGB(230, 238, 255)
			spot.Shadows = false
			spot.Parent = hl
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 20, 20)
		glow.Range = 9
		glow.Brightness = 1
		glow.Shadows = false
		glow.Name = "TailGlow"
		glow.Parent = tailLights[1]
	end
	for _, tl in tailLights do
		tl:SetAttribute("TailLight", true)
	end

	-----------------------------------------------------------------
	-- Weld everything
	-----------------------------------------------------------------
	for _, pair in welds do
		local w = Instance.new("WeldConstraint")
		w.Part0 = pair[2]
		w.Part1 = pair[1]
		w.Parent = pair[1]
	end

	for _, wp in wheelParts do
		local m = Instance.new("Motor6D")
		m.Name = "Wheel_" .. wp.name
		m.Part0 = root
		m.Part1 = wp.part
		m.C0 = root.CFrame:Inverse() * wp.part.CFrame
		m.C1 = CFrame.new()
		m:SetAttribute("Front", wp.front)
		m:SetAttribute("Radius", wp.part.Size.Y / 2)
		m.Parent = root
		table.insert(wheelMotors, m)
	end

	local rootInv = root.CFrame:Inverse()
	if hub and steerMount then
		local m = Instance.new("Motor6D")
		m.Name = "SteerMotor"
		m.Part0 = root
		m.Part1 = hub
		m.C0 = rootInv * steerMount
		m.C1 = CFrame.new()
		m.Parent = root
		model:SetAttribute("SteerMount", rootInv * steerMount)

		-- Arms: Motor6D with C0 = rest pose. The client writes Transform every
		-- frame from the IK solve so the arms follow the hands.
		local upperLen, foreLen = 1.12, 1.05
		model:SetAttribute("UpperLen", upperLen)
		model:SetAttribute("ForeLen", foreLen)
		for _, side in { "L", "R" } do
			local sx = if side == "L" then -1 else 1
			local shoulderG = Vector3.new(driverX + sx * 0.62, eyeY - 0.7, eyeZ + 0.38)
			local grip = model:GetAttribute("Grip" .. side) :: Vector3
			local handG = (steerMount * CFrame.new(grip)).Position
			local pole = Vector3.new(sx * 0.8, -1, 0.2)
			local upperCF, foreCF = CarBuilder.solveArm(shoulderG, handG, upperLen, foreLen, pole)
			local shoulderRoot = (rootInv * CFrame.new(shoulderG)).Position
			model:SetAttribute("Shoulder" .. side, shoulderRoot)

			for _, seg in { { "Upper", upperCF, upperLen, 0.36 }, { "Fore", foreCF, foreLen, 0.32 } } do
				local segName, cf, len, thick = seg[1] :: string, seg[2] :: CFrame, seg[3] :: number, seg[4] :: number
				local armPart = block(segName .. "Arm" .. side, Vector3.new(thick, thick, len + 0.12), cf, "Jacket", false)
				local am = Instance.new("Motor6D")
				am.Name = segName .. "Arm" .. side
				am.Part0 = root
				am.Part1 = armPart
				am.C0 = rootInv * cf
				am.C1 = CFrame.new()
				am.Parent = root
			end
		end
	end

	if headPart then
		model:SetAttribute("Eye", (rootInv * CFrame.new(driverX, eyeY, eyeZ - 0.05)).Position)
	else
		model:SetAttribute("Eye", (rootInv * CFrame.new(driverX, eyeY, eyeZ)).Position)
	end

	-- Final physical state
	local anchored = opts.anchored == true
	for _, p in parts do
		p.Anchored = false
	end
	root.Anchored = anchored

	model:SetAttribute("CarId", spec.Id)
	model:SetAttribute("Class", class)
	model:SetAttribute("Length", L)
	model:SetAttribute("Width", W)
	model:SetAttribute("Height", H)
	return model
end

-- Mass-produce a car spec for NPC traffic with a random realistic paint
function CarBuilder.randomTrafficSpec(rng: Random): Cars.CarSpec
	local weights = Config.Traffic.ClassWeights
	local total = 0
	for _, w in weights do
		total += w
	end
	local pick = rng:NextNumber() * total
	local chosenClass = "Sedan"
	for _, class in Cars.Classes do
		local w = weights[class] or 0
		if pick <= w then
			chosenClass = class
			break
		end
		pick -= w
	end
	local candidates = {}
	for _, spec in Cars.List do
		if spec.Class == chosenClass then
			table.insert(candidates, spec)
		end
	end
	return candidates[rng:NextInteger(1, #candidates)]
end

return CarBuilder
