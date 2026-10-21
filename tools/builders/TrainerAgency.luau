-- TrainerAgency builder (prompt 24, 21 Oct; run once in Studio, Edit mode): turns each Trainer Desk (tools/builders/
-- TrainerDesks; the desks themselves are not touched) into the TRAINER AGENCY: a big lit odds board on two tall posts behind
-- the desk, over its old sign, with a gold neon frame and two spotlights. The board part (tag "AgencyBoard") is filled by
-- TrainerClient from Config/Trainers (all 8 trainers, rarity colors, chances, boosts; Secret "???" until you own him), so the
-- odds on it always match the real ones.
-- Every desk is found from its TrainerPoint (tag "TrainerDesk"), so a desk moved by hand still gets its board. The board's
-- top stays under the ceiling (a ray up checks it).
-- Usage (command bar): require(game.ServerStorage._Builders.TrainerAgency).Build()   (or paste the body into the bar)
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Builder = {}

local D = 2.2 -- the desk's depth (TrainerDesks: the TrainerPoint is D / 2 + 0.8 in front of its middle, 3.2 up)
local GOLD = Color3.fromHex("#F6C75A")
local DARK = Color3.fromHex("#1E1E22")

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do p[k] = v end
	p.Parent = parent
	return p
end
local function deco(parent, name, size, cframe, color, material)
	return part(parent, name, size, cframe, color, material, { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false })
end

function Builder.Build()
	local built = {}
	for _, point in ipairs(CollectionService:GetTagged("TrainerDesk")) do
		local desk = point.Parent
		if point:IsA("BasePart") and desk and desk:IsDescendantOf(Workspace) then
			-- the desk's floor point (its -Z faces the customers)
			local base = point.CFrame * CFrame.new(0, -3.2, D / 2 + 0.8)
			local old = desk:FindFirstChild("AgencyBoard")
			if old then old:Destroy() end
			local model = Instance.new("Model")
			model.Name = "AgencyBoard"
			-- how high the board can go (under the ceiling)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { desk }
			local from = (base * CFrame.new(0, 7, D / 2 + 0.9)).Position
			local hit = Workspace:Raycast(from, Vector3.new(0, 30, 0), params)
			local ceiling = if hit then hit.Position.Y - base.Position.Y - 0.5 else 14
			local W, H = 7.2, 4.6
			local top = math.min(11.8, ceiling)
			local bottom = top - H
			if bottom < 6.7 then
				-- a low ceiling: a smaller board that still sits over the old sign
				H = math.max(2.6, top - 6.7)
				W = H * 7.2 / 4.6
				bottom = top - H
			end
			local cy = bottom + H / 2
			local z = D / 2 + 0.9
			for _, x in ipairs({ -W / 2 - 0.2, W / 2 + 0.2 }) do
				part(model, "Post", Vector3.new(0.26, top + 0.2, 0.26), base * CFrame.new(x, (top + 0.2) / 2, z + 0.15), DARK, Enum.Material.Metal)
			end
			local board = part(model, "Board", Vector3.new(W, H, 0.2), base * CFrame.new(0, cy, z), DARK, Enum.Material.SmoothPlastic, { CastShadow = false })
			CollectionService:AddTag(board, "AgencyBoard")
			-- a gold neon frame
			for _, spec in ipairs({ { 0, H / 2, W + 0.2, 0.14 }, { 0, -H / 2, W + 0.2, 0.14 }, { -W / 2, 0, 0.14, H }, { W / 2, 0, 0.14, H } }) do
				deco(model, "Frame", Vector3.new(spec[3], spec[4], 0.12), base * CFrame.new(spec[1], cy + spec[2], z - 0.12), GOLD, Enum.Material.Neon)
			end
			-- two small spotlights on arms, shining down onto the board
			for _, x in ipairs({ -W / 4, W / 4 }) do
				deco(model, "LampArm", Vector3.new(0.1, 0.1, 0.9), base * CFrame.new(x, top + 0.05, z - 0.45), DARK, Enum.Material.Metal)
				local shade = deco(model, "LampShade", Vector3.new(0.5, 0.3, 0.5), base * CFrame.new(x, top - 0.05, z - 0.95), DARK, Enum.Material.Metal)
				local light = Instance.new("SpotLight")
				light.Face = Enum.NormalId.Bottom
				light.Range = 7
				light.Brightness = 1.6
				light.Angle = 80
				light.Color = Color3.fromHex("#FFE9B8")
				light.Shadows = false
				light.Parent = shade
			end
			model.Parent = desk
			table.insert(built, string.format("%s (top %.1f, board %.1f x %.1f)", desk:GetFullName(), top, W, H))
		end
	end
	return "agency boards: " .. table.concat(built, "; ")
end

return Builder
