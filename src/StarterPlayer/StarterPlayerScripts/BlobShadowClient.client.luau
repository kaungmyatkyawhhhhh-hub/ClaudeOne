-- BlobShadowClient: a soft dark round shadow under every body (owner, 20 Oct: the body stage meshes cast no shadow, so a
-- cheap blob instead). One flat part per body with a Decal (a black radial fade) on its top, raycast straight down from the
-- body to the floor, sized to the body's width (torso + both upper arms), lighter and a little bigger the higher the body is
-- above the floor (a jump), gone past FADE_HEIGHT or further than RANGE studs from the camera. Bodies: players, the gym
-- regulars (Workspace.NPCs), personal trainers (Workspace.LocalTrainers) and the statue. Client side only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TEXTURE = "rbxassetid://76083127218780" -- gymarc_blob_shadow.png (black, alpha fades out to the edge)
local DARKNESS = 0.2       -- the decal's Transparency right under the body (0 = black; the gym floors are dark)
local WIDTH = 1.25         -- x the body's width
local RAY = 14             -- studs looked down from the body's root
local FADE_HEIGHT = 8      -- studs above the floor where the shadow is gone
local RANGE = 120          -- studs from the camera
local REFRESH = 1          -- seconds between body list / width checks

local folder = Instance.new("Folder")
folder.Name = "BlobShadows"
folder.Parent = Workspace

local shadows = {} -- [model] = { part, decal, width }
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
params.IgnoreWater = true

local function bodies(): { Model }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(list, player.Character) end
	end
	for _, name in ipairs({ "NPCs", "LocalTrainers" }) do
		local holder = Workspace:FindFirstChild(name)
		if holder then
			for _, model in ipairs(holder:GetChildren()) do
				if model:IsA("Model") then table.insert(list, model) end
			end
		end
	end
	local statue = Workspace:FindFirstChild("Statue")
	if statue and statue:IsA("Model") then table.insert(list, statue) end
	return list
end

local function widthOf(model: Model): number?
	local torso = model:FindFirstChild("UpperTorso")
	if not (torso and torso:IsA("BasePart")) then return nil end
	local width = torso.Size.X
	for _, name in ipairs({ "LeftUpperArm", "RightUpperArm" }) do
		local arm = model:FindFirstChild(name)
		if arm and arm:IsA("BasePart") then width += arm.Size.X end
	end
	return width * WIDTH
end

local function make(): any
	local part = Instance.new("Part")
	part.Name = "BlobShadow"
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = false, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(2, 0.05, 2)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = TEXTURE
	decal.Transparency = 1
	decal.Parent = part
	part.Parent = folder
	return { part = part, decal = decal, width = nil }
end

local function refresh()
	local seen, exclude = {}, { folder }
	for _, model in ipairs(bodies()) do
		seen[model] = true
		table.insert(exclude, model)
		local shadow = shadows[model] or make()
		shadows[model] = shadow
		shadow.width = widthOf(model)
	end
	for model, shadow in pairs(shadows) do
		if not seen[model] then
			shadow.part:Destroy()
			shadows[model] = nil
		end
	end
	params.FilterDescendantsInstances = exclude
end

local function hide(shadow)
	if shadow.decal.Transparency ~= 1 then shadow.decal.Transparency = 1 end
end

local lastRefresh = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastRefresh > REFRESH then
		lastRefresh = now
		refresh()
	end
	local camera = Workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
	for model, shadow in pairs(shadows) do
		local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("LowerTorso")
		if not (shadow.width and root and root:IsA("BasePart")) or (root.Position - cameraPosition).Magnitude > RANGE then
			hide(shadow)
			continue
		end
		local hit = Workspace:Raycast(root.Position, Vector3.new(0, -RAY, 0), params)
		if not hit then
			hide(shadow)
			continue
		end
		-- (the root sits about a leg's length above the floor while standing: height = how much further up than that)
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local standing = if humanoid then humanoid.HipHeight + root.Size.Y / 2 else 0
		local height = math.max(0, root.Position.Y - hit.Position.Y - standing)
		local fade = math.clamp(height / FADE_HEIGHT, 0, 1)
		if fade >= 1 then
			hide(shadow)
			continue
		end
		local size = shadow.width * (1 + 0.4 * fade)
		local up = hit.Normal
		local right = if math.abs(up.Y) > 0.99 then Vector3.xAxis else up:Cross(Vector3.yAxis).Unit
		local cf = CFrame.fromMatrix(hit.Position + up * 0.03, right, up)
		local part = shadow.part
		if (part.Position - cf.Position).Magnitude > 0.01 or math.abs(part.Size.X - size) > 0.01 then
			part.Size = Vector3.new(size, 0.05, size)
			part.CFrame = cf
		end
		local transparency = DARKNESS + (1 - DARKNESS) * fade
		if math.abs(shadow.decal.Transparency - transparency) > 0.01 then shadow.decal.Transparency = transparency end
	end
end)
