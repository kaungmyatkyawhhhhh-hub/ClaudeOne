-- TrainerPortrait (prompt 24, 21 Oct): a trainer in 3D in a ViewportFrame (the Agency odds list, the roll reveal, the
-- Inventory's Trainers tab). A clone of his template (ReplicatedStorage.TrainerModels, TrainerService) struck in a pose
-- (PoseData via PoseApply + BodyShape.SolveJoints, like the progress mirror), framed from his size.
--   TrainerPortrait.New(id, opts) -> ViewportFrame
--     opts: Size / Position / AnchorPoint / ZIndex / Parent, pose ("FrontDoubleBiceps"; "Relaxed"), shot ("full" | "bust"),
--           silhouette (a black shape: Secret before you own him), golden (a gold light), background (Color3; nil = clear)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent
local PoseApply = require(Shared.PoseApply)
local BodyShape = require(Shared.BodyShape)

local TrainerPortrait = {}

local templates = nil
local function template(id)
	templates = templates or ReplicatedStorage:FindFirstChild("TrainerModels") or ReplicatedStorage:WaitForChild("TrainerModels", 10)
	return templates and templates:FindFirstChild(id)
end

function TrainerPortrait.New(id: string, opts)
	opts = opts or {}
	local frame = Instance.new("ViewportFrame")
	frame.Name = "Portrait"
	frame.BackgroundTransparency = if opts.background then 0 else 1
	frame.BackgroundColor3 = opts.background or Color3.new(0, 0, 0)
	frame.Size = opts.Size or UDim2.fromOffset(80, 80)
	frame.Position = opts.Position or UDim2.new()
	frame.AnchorPoint = opts.AnchorPoint or Vector2.zero
	frame.ZIndex = opts.ZIndex or 1
	frame.Ambient = if opts.silhouette then Color3.new(0, 0, 0) else Color3.fromRGB(150, 145, 140)
	frame.LightColor = if opts.silhouette then Color3.new(0, 0, 0) elseif opts.golden then Color3.fromHex("#FFE6A0") else Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-0.6, -0.8, -0.8)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = frame
	frame.CurrentCamera = camera
	local source = template(id)
	if source then
		local ok = pcall(function()
			local model = source:Clone()
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					if opts.silhouette then
						d.Color = Color3.new(0, 0, 0)
						d.Material = Enum.Material.SmoothPlastic
					end
				elseif d:IsA("Decal") and opts.silhouette then
					d.Transparency = 1
				elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Sound") then
					d:Destroy()
				end
			end
			if opts.silhouette then
				for _, d in ipairs(model:GetChildren()) do
					if d:IsA("Shirt") or d:IsA("Pants") then d:Destroy() end
				end
			end
			local root = model:FindFirstChild("HumanoidRootPart")
			if root then model.PrimaryPart = root end
			model:PivotTo(CFrame.new(0, 0, 0))
			local poseData = require(ReplicatedStorage:WaitForChild("PoseData"))
			local pose = poseData[opts.pose or "FrontDoubleBiceps"]
			if pose then
				PoseApply.Apply(model, pose, 1)
				BodyShape.SolveJoints(model)
			end
			model.Parent = frame
			-- the camera: in front of him, looking at his middle (full body) or chest up (bust)
			local cf, size = model:GetBoundingBox()
			local height = size.Y
			local focus = cf.Position + Vector3.new(0, if opts.shot == "bust" then height * 0.22 else 0, 0)
			local span = if opts.shot == "bust" then height * 0.6 else height * 1.05
			local distance = (span / 2) / math.tan(math.rad(camera.FieldOfView / 2))
			local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1) -- (the way he faces: the camera stands there)
			camera.CFrame = CFrame.lookAt(focus + look * distance + Vector3.new(distance * 0.12, 0, 0), focus)
		end)
		if not ok then frame.BackgroundTransparency = 1 end
	end
	if opts.Parent then frame.Parent = opts.Parent end
	return frame
end

return TrainerPortrait
