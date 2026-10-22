-- ProGymLights (prompt 58, 23 Oct): finishes the Pro Gym after the prompt 50 makeover.
-- Run once in Studio: require(this).Run(). The whole Pro Gym was copied to ServerStorage.ProGymBackup_23Oct_b first;
-- what this takes out goes to ServerStorage.ProGymRemoved_23Oct_b, what it adds is in ProGym.Lights58 (and the outside
-- pieces in Town.GymFront.ProFront58).
--   1) WHITE LIGHT: every yellow / gold glow becomes clean white (~6000K): the LED strips and seams, the lamps' glow, the
--      sign frames, every warm light. Gold stays only as a material: the lamp rims, the mat lines and wall trims are gold
--      metal inlays now (no glow), the machines' gold stitching is plain gold. The gold floor glow under each Pro machine
--      (prompt 47) is a soft, faint white glow.
--   2) The reception desk (FrontDesk / FrontDeskTop / FrontDeskLine) is gone: a bench and two plants fill its spot in
--      front of the PRO GYM sign wall. Nothing depended on the desk (no prompt, NPC spot, GO TO or GuidePath target).
--   3) LIGHTING: the ceiling light bars are proper white linear fixtures (black housing, wide diffuser, brighter
--      SurfaceLights) in rows over every zone; a white LED strip under the long mirror; soft white spotlights on the
--      ELITE corner and the stretch / posing mat; the old wall washers left on the removed middle wall (x 112) and on the
--      east wall (glass now) are gone; the fill lights a bit stronger. Still only the 4 lamps cast shadows.
--   4) WINDOWS: the east wall is floor-to-ceiling glass (black mullions) looking down on the valley city
--      (tools/builders/ProGymValley + ProGymCity); the front (cardio) wall's glass goes up to the ceiling. The east
--      mirrors go (the long mirror on the back wall stays) and the GYM ARC PRO neon sign moves to the header over the
--      glass wall to the starter gym. The wall TVs hang from the ceiling on rods.
--      OUTSIDE: a black canopy along the whole front with white downlights (night lights), a white-lit PRO GYM sign on the
--      solid front wall, the roof parapet carried round the east hall; the old wall lamps and the small sign on the
--      front spandrel go. An invisible guard stops anyone walking off the new cliff east of the gym.
local ProGymLights = {}

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local N, S, E, W = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0)
local WHITE = Color3.fromHex("#F4F7FF")      -- neon (cool white)
local LIGHT = Color3.fromHex("#EEF3FF")      -- light colour (~6000K)
local SOFT = Color3.fromHex("#DDE6F2")       -- the machines' faint floor glow
local GOLD = Color3.fromHex("#F6C75A")
local GOLD_DARK = Color3.fromHex("#C9A13A")
local INK = Color3.fromHex("#0B0B0D")
local GLASS = Color3.fromHex("#BFD6E6")
local GLASS_T = 0.82

local made, removed
local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	p.Parent = p.Parent or made
	return p
end
local function stash(inst: Instance?)
	if inst then inst.Parent = removed end
end
local function warm(c: Color3): boolean
	local h, s = c:ToHSV()
	return s > 0.1 and h > 0.05 and h < 0.18
end

-- moves a model so its bounding box centre is at (x, z) (height kept) and its front (pivot look) faces `face`
local function place(model: Model, x: number, z: number, face: Vector3)
	local pivot = model:GetPivot()
	local box = model:GetBoundingBox()
	local o = pivot:PointToObjectSpace(box.Position)
	local rot = CFrame.lookAt(Vector3.zero, face)
	local d = rot:VectorToWorldSpace(Vector3.new(o.X, 0, o.Z))
	model:PivotTo(CFrame.new(x - d.X, pivot.Y, z - d.Z) * rot)
end

-- a ceiling spotlight: a small black can with a white lens, aimed straight down
local function spot(x: number, z: number, angle: number, brightness: number)
	part({ Name = "SpotCan", Size = Vector3.new(0.9, 0.6, 0.9), CFrame = CFrame.new(x, 17.65, z), Material = Enum.Material.Metal, Color = INK })
	local lens = part({ Name = "SpotLens", Size = Vector3.new(0.6, 0.05, 0.6), CFrame = CFrame.new(x, 17.33, z), Material = Enum.Material.Neon, Color = WHITE })
	local light = Instance.new("SpotLight")
	light.Face, light.Angle, light.Range, light.Brightness, light.Color, light.Shadows = Enum.NormalId.Bottom, angle, 22, brightness, LIGHT, false
	light.Parent = lens
end

local SIGN_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

function ProGymLights.Run()
	local pg = workspace.ProGym
	assert(SS:FindFirstChild("ProGymBackup_23Oct_b"), "copy the Pro Gym to ServerStorage.ProGymBackup_23Oct_b first")
	assert(not pg:FindFirstChild("Lights58"), "already done")
	made = Instance.new("Folder")
	made.Name = "Lights58"
	made.Parent = pg
	removed = SS:FindFirstChild("ProGymRemoved_23Oct_b") or Instance.new("Folder")
	removed.Name = "ProGymRemoved_23Oct_b"
	removed.Parent = SS
	local mk, props = pg.Makeover, pg.Props

	-- 1) white light; gold only as a material
	for _, d in ipairs(pg:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon and warm(d.Color) then
			local name = d.Name
			if name == "LampRim" or name:find("Line$") or name:find("^Trim") then
				d.Material, d.Color = Enum.Material.Metal, GOLD_DARK
			elseif name == "ProStitch" then
				d.Material = Enum.Material.SmoothPlastic
			elseif name == "ProGlow" then
				d.Color, d.Transparency = SOFT, 0.6
			else
				d.Color = WHITE
			end
		elseif d:IsA("Light") and warm(d.Color) then
			d.Color = LIGHT
			if d.Parent and d.Parent.Name == "ProGlow" then d.Brightness, d.Range = 0.3, 6 end
		end
	end

	-- 2) the reception desk out; a bench and two plants in its spot
	for _, name in ipairs({ "FrontDesk", "FrontDeskTop", "FrontDeskLine" }) do stash(mk:FindFirstChild(name)) end
	local bench = props:FindFirstChild("Bench")
	if bench then
		local b = bench:Clone()
		b.Parent = props
		place(b, 56, -25.2, S)
	end
	local plant = props:FindFirstChild("Plant")
	if plant then
		for _, x in ipairs({ 50.5, 61.5 }) do
			local p = plant:Clone()
			p.Parent = props
			place(p, x, -27, S)
		end
	end

	-- 3) lighting
	-- the ceiling bars: white linear fixtures in rows over every zone
	for _, shell in ipairs({ pg.Shell, pg.ShellEast }) do
		for _, bar in ipairs(shell:GetChildren()) do
			if bar:IsA("BasePart") and (bar.Name == "LightBar" or bar.Name == "LightBarJoin") then
				bar.Size = Vector3.new(bar.Size.X, 0.12, 0.7)
				bar.Color, bar.Material = WHITE, Enum.Material.Neon
				part({ Name = "LightHousing", Size = Vector3.new(bar.Size.X + 0.3, 0.25, 1.05), CFrame = bar.CFrame + Vector3.new(0, 0.18, 0),
					Material = Enum.Material.Metal, Color = INK })
				for _, light in ipairs(bar:GetChildren()) do
					if light:IsA("SurfaceLight") then
						light.Brightness, light.Range, light.Angle, light.Color, light.Shadows = 1.4, 18, 120, LIGHT, false
					end
				end
			end
		end
	end
	for _, folder in ipairs({ pg.FillLights, pg.FillLightsEast }) do
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("PointLight") then d.Brightness, d.Color, d.Shadows = 0.7, LIGHT, false end
		end
	end
	-- a white LED strip under the long mirror on the back wall
	for _, panel in ipairs(props:GetChildren()) do
		local mirror = panel.Name == "MirrorPanel" and panel:FindFirstChild("Mirror")
		if mirror and mirror.Position.Z < -80 then
			part({ Name = "MirrorLed", Size = Vector3.new(mirror.Size.X, 0.1, 0.1),
				CFrame = CFrame.new(mirror.Position.X, mirror.Position.Y - mirror.Size.Y / 2 - 0.1, mirror.Position.Z + 0.12), Material = Enum.Material.Neon, Color = WHITE })
		end
	end
	-- soft spotlights on the ELITE corner and the stretch / posing mat
	for _, xz in ipairs({ { 116, -55 }, { 131, -55 }, { 116, -70 }, { 131, -70 }, { 123.5, -83 } }) do spot(xz[1], xz[2], 60, 1.3) end
	for _, z in ipairs({ -56, -68 }) do spot(147.5, z, 55, 1.5) end
	-- the wall washers left on the removed middle wall (x 112) and on the east wall (glass now)
	for _, folder in ipairs({ pg.LightingPass, pg.LightingPassEast }) do
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") and ((d.Position.X > 110 and d.Position.X < 114.5) or d.Position.X > 150) then stash(d) end
		end
	end

	-- 4a) the east wall: floor-to-ceiling glass
	local east = pg.ShellEast
	stash(east:FindFirstChild("EastWall"))
	for _, d in ipairs(east:GetChildren()) do
		if d:IsA("BasePart") and d.Position.X > 152 and (d.Name == "Panel" or d.Name == "LedSeam") then stash(d) end
	end
	stash(props:FindFirstChild("MirrorPanel") and (function()
		for _, m in ipairs(props:GetChildren()) do
			if m.Name == "MirrorPanel" and m:GetPivot().Position.X > 150 then return m end
		end
		return nil
	end)())
	for _, m in ipairs(pg.ZoneSignsEast:GetChildren()) do
		if m.Name == "MirrorPanelEast" then stash(m) end
	end
	-- the GYM ARC PRO neon sign moves to the header over the glass wall to the starter gym, facing into the hall
	local oldAnchor, newAnchor = nil, Vector3.new(45.32, 14.4, -52)
	for _, m in ipairs(props:GetChildren()) do
		if m.Name == "NeonSignBack" and m:IsA("BasePart") and m.Position.X > 150 then oldAnchor = m.Position end
	end
	if oldAnchor then
		local move = CFrame.new(newAnchor) * CFrame.Angles(0, math.pi, 0) * CFrame.new(-oldAnchor)
		for _, m in ipairs(props:GetChildren()) do
			if (m.Name == "NeonSignBack" or m.Name == "NeonSignFrame") and m:IsA("BasePart") and m.Position.X > 150 then m.CFrame = move * m.CFrame end
		end
	end
	local z0, z1, x = -88.95, -4.05, 153.6
	part({ Name = "EastGlass", Size = Vector3.new(0.25, 17.6, z1 - z0), CFrame = CFrame.new(x, 8.95, (z0 + z1) / 2), Material = Enum.Material.SmoothPlastic,
		Color = GLASS, Transparency = GLASS_T, Reflectance = 0.05, CanCollide = true, CanQuery = true })
	part({ Name = "EastBase", Size = Vector3.new(0.8, 0.5, z1 - z0), CFrame = CFrame.new(x, 0.25, (z0 + z1) / 2), Material = Enum.Material.Metal, Color = INK, CanCollide = true })
	part({ Name = "EastHeader", Size = Vector3.new(0.8, 0.5, z1 - z0), CFrame = CFrame.new(x, 17.75, (z0 + z1) / 2), Material = Enum.Material.Metal, Color = INK })
	local panes = 12
	for i = 0, panes do
		local z = z0 + (z1 - z0) * i / panes
		part({ Name = "EastMullion", Size = Vector3.new(0.45, 17.6, 0.3), CFrame = CFrame.new(x, 8.95, z), Material = Enum.Material.Metal, Color = INK, CanCollide = true })
	end

	-- 4b) the front (cardio) wall: glass up to the ceiling
	for _, shell in ipairs({ pg.Shell, east }) do
		local spandrel = shell:FindFirstChild("FrontSpandrel")
		if spandrel then
			local sx, sz = spandrel.Position.X, spandrel.Position.Z
			part({ Name = "FrontGlassUpper", Size = Vector3.new(spandrel.Size.X, 6.8, 0.2), CFrame = CFrame.new(sx, 14.55, sz), Material = Enum.Material.SmoothPlastic,
				Color = GLASS, Transparency = GLASS_T, Reflectance = 0.05, CanCollide = true, CanQuery = true })
			part({ Name = "FrontHeader", Size = Vector3.new(spandrel.Size.X, 0.5, 0.6), CFrame = CFrame.new(sx, 17.75, sz), Material = Enum.Material.Metal, Color = INK })
			stash(spandrel)
		end
		for _, d in ipairs(shell:GetChildren()) do
			if d:IsA("BasePart") then
				if d.Name == "CurtainMullion" then
					d.Size = Vector3.new(d.Size.X, 17.2, d.Size.Z)
					d.Position = Vector3.new(d.Position.X, 9.4, d.Position.Z)
				elseif d.Name == "CurtainGlass" then
					d.Transparency, d.Color, d.Reflectance = GLASS_T, GLASS, 0.05
				end
			end
		end
	end
	-- the wall TVs hang from the ceiling now (the wall behind them is glass)
	for _, tv in ipairs(pg.Decor:GetChildren()) do
		if tv.Name == "WallTV" then
			local cf, size = tv:GetBoundingBox()
			local top = cf.Position.Y + size.Y / 2
			for _, dx in ipairs({ -size.X / 2 + 0.5, size.X / 2 - 0.5 }) do
				local p = cf.Position + cf.RightVector * dx
				part({ Name = "TvRod", Size = Vector3.new(0.08, 18 - top, 0.08), CFrame = CFrame.new(p.X, (top + 18) / 2, p.Z), Material = Enum.Material.Metal, Color = INK })
			end
		end
	end

	-- 4c) outside: canopy, the white-lit PRO GYM sign, the parapet round the east hall, a guard at the new cliff
	local front = workspace.Town.GymFront
	local outside = Instance.new("Folder")
	outside.Name = "ProFront58"
	outside.Parent = front
	for _, d in ipairs(front:GetChildren()) do
		if d:IsA("BasePart") and d.Position.X > 45 and (d.Name == "WallLight" or d.Name == "WallLightArm" or d.Name == "ProSign") then stash(d) end
	end
	local x0, x1 = 45.5, 149.5 -- (the tall building at the corner starts at x 150)
	local cx, w = (x0 + x1) / 2, x1 - x0
	part({ Name = "Canopy", Size = Vector3.new(w, 0.5, 5), CFrame = CFrame.new(cx, 11.55, -0.75), Material = Enum.Material.Metal, Color = INK, Parent = outside })
	part({ Name = "CanopyFascia", Size = Vector3.new(w, 1.1, 0.3), CFrame = CFrame.new(cx, 11.45, 1.75), Material = Enum.Material.Metal, Color = INK, Parent = outside })
	local edge = part({ Name = "CanopyLed", Size = Vector3.new(w - 0.4, 0.08, 0.2), CFrame = CFrame.new(cx, 11.25, 1.45), Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromHex("#2A2C30"), Parent = outside })
	edge:SetAttribute("NightColor", WHITE)
	edge:SetAttribute("DayColor", Color3.fromHex("#2A2C30"))
	CS:AddTag(edge, "NightLight")
	for i = 0, 6 do
		local lx = x0 + 6 + i * (w - 12) / 6
		local disc = part({ Name = "CanopyDownlight", Size = Vector3.new(0.8, 0.06, 0.8), CFrame = CFrame.new(lx, 11.27, -0.9), Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromHex("#D9DEE6"), Parent = outside })
		disc:SetAttribute("NightColor", WHITE)
		disc:SetAttribute("DayColor", Color3.fromHex("#D9DEE6"))
		CS:AddTag(disc, "NightLight")
		local light = Instance.new("SpotLight")
		light.Face, light.Angle, light.Range, light.Brightness, light.Color, light.Shadows, light.Enabled = Enum.NormalId.Bottom, 90, 14, 1.2, LIGHT, false, false
		light.Parent = disc
	end
	-- the sign on the solid front wall (x 92.4 .. 114), above the canopy
	local signPos = Vector3.new(103.2, 15, -2.75)
	local sign = part({ Name = "ProGymSign", Size = Vector3.new(19, 4.6, 0.4), CFrame = CFrame.lookAt(signPos, signPos + S), Material = Enum.Material.Metal,
		Color = INK, Parent = outside })
	CS:AddTag(sign, "NightSign")
	for _, e in ipairs({ { 0, 2.25, 18.8, 0.1 }, { 0, -2.25, 18.8, 0.1 } }) do
		part({ Name = "ProGymSignTrim", Size = Vector3.new(e[3], e[4], 0.05), CFrame = sign.CFrame * CFrame.new(e[1], e[2], -0.22), Material = Enum.Material.Metal, Color = GOLD_DARK, Parent = outside })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.SizingMode, gui.PixelsPerStud, gui.LightInfluence, gui.Brightness = Enum.NormalId.Front, Enum.SurfaceGuiSizingMode.PixelsPerStud, 30, 0, 1.6
	gui.Parent = sign
	local function label(props)
		local l = Instance.new(props.Image and "ImageLabel" or "TextLabel")
		l.BackgroundTransparency, l.AnchorPoint = 1, Vector2.new(0.5, 0.5)
		for k, v in pairs(props) do l[k] = v end
		l.Parent = gui
		return l
	end
	label({ Image = "rbxassetid://97319043121415", ImageColor3 = GOLD, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromScale(0.13, 0.5), Size = UDim2.fromScale(0.16, 0.8) })
	local title = label({ Text = "PRO GYM", TextColor3 = WHITE, TextScaled = true, FontFace = SIGN_FONT, Position = UDim2.fromScale(0.56, 0.44), Size = UDim2.fromScale(0.72, 0.62) })
	local glow = Instance.new("UIStroke")
	glow.Color, glow.Thickness, glow.Transparency = Color3.fromHex("#BFD3FF"), 3, 0.55
	glow.Parent = title
	label({ Text = "GYM ARC", TextColor3 = GOLD, TextScaled = true, FontFace = SIGN_FONT, Position = UDim2.fromScale(0.56, 0.86), Size = UDim2.fromScale(0.3, 0.16) })
	local wash = Instance.new("SurfaceLight")
	wash.Face, wash.Angle, wash.Range, wash.Brightness, wash.Color, wash.Shadows = Enum.NormalId.Front, 80, 7, 0.8, LIGHT, false
	wash.Parent = sign
	-- the roof parapet round the east hall (the old one stopped at x 115)
	local parapetFront, parapetSide = nil, nil
	for _, d in ipairs(front:GetChildren()) do
		if d.Name == "Parapet" and d:IsA("BasePart") and d.Position.Y > 19 then
			if d.Size.X > 60 and d.Position.Z > -10 then parapetFront = d elseif d.Size.Z > 60 then parapetSide = d end
		end
	end
	if parapetFront then
		local p = parapetFront:Clone()
		p.Size = Vector3.new(39.5, p.Size.Y, p.Size.Z)
		p.Position = Vector3.new(134.5, p.Position.Y, p.Position.Z)
		p.Parent = outside
		local back = parapetFront:Clone()
		back.Size = Vector3.new(39.5, back.Size.Y, back.Size.Z)
		back.Position = Vector3.new(134.5, back.Position.Y, -89.9)
		back.Parent = outside
	end
	if parapetSide then
		local p = parapetSide:Clone()
		p.Position = Vector3.new(154, p.Position.Y, p.Position.Z)
		p.Parent = outside
	end
	-- the guard: nobody walks off the cliff east of the gym (the town boundary is at x 200 / z -98)
	part({ Name = "ValleyGuard", Size = Vector3.new(50, 60, 1), CFrame = CFrame.new(177, 30, -5.5), Transparency = 1, CanCollide = true, Parent = outside })
	return "done"
end

return ProGymLights
