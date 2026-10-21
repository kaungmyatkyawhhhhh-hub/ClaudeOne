-- Trainer photos (prompt 25): the portraits / reveal pictures of the 8 trainers, rendered in Studio from a fixed camera.
-- Run in a PLAY test, in the CLIENT (execute_luau Client, or the client command bar), after the trainer models exist
-- (ReplicatedStorage.TrainerModels). It builds a chroma-key stage at y = 400 (an unlit green backdrop; spotlights without
-- shadows), puts a clone of every trainer in Workspace.LocalTrainers (so MuscleClient gives them their muscles) and hides
-- the HUD while the photo camera is on. Then:
--   _G.Shoot("AtlasCoach", "bust" | "full", "Relaxed" | a PoseData pose | "Crossed")   -- frames one trainer
--   _G.SetKey(Color3)   -- the backdrop color
-- and take a screen capture. tools/trainer_icons.py keys out the backdrop and makes the icons (Black + Gold frame in the
-- rarity color), the reveal pictures and the Secret silhouette; upload them and put the ids in Config/Trainers icon / art.
-- _G.PhotoCam = nil ends the photo camera. (A raised pose: wait a frame, then frame it from the posed bounding box.)
-- Key colors used: green for most, blue for Coach Nia (green clothes, pink hair).
-- (prompt 34) _G.Shoot(id, shot, pose, yaw): yaw = the camera's angle round him (90 = his right side). The light is soft
-- and even (no shadows, no bloom, little shine; client only, gone when the test stops). It can also run as a ModuleScript
-- (require it once in the client).
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Trainers = require(RS.Shared.Config.Trainers)
local PoseApply = require(RS.Shared.PoseApply)
local PoseData = require(RS.PoseData)

local old = workspace:FindFirstChild("PhotoStage")
if old then old:Destroy() end
for _, m in ipairs(workspace.LocalTrainers:GetChildren()) do
	if m:GetAttribute("Lineup") then m:Destroy() end
end
local stage = Instance.new("Model")
stage.Name = "PhotoStage"
local backdrop = Instance.new("Part")
backdrop.Anchored, backdrop.Size, backdrop.Position = true, Vector3.new(200, 120, 1), Vector3.new(0, 420, -30)
backdrop.Parent = stage
for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
	local sg = Instance.new("SurfaceGui")
	sg.Face, sg.LightInfluence = face, 0
	local f = Instance.new("Frame")
	f.Name, f.Size, f.BorderSizePixel, f.BackgroundColor3 = "F", UDim2.fromScale(1, 1), 0, Color3.fromRGB(0, 255, 0)
	f.Parent = sg
	sg.Parent = backdrop
end
for _, x in ipairs({ -30, 0, 30 }) do
	local lamp = Instance.new("Part")
	lamp.Anchored, lamp.Transparency, lamp.CanCollide, lamp.Size = true, 1, false, Vector3.one
	lamp.CFrame = CFrame.lookAt(Vector3.new(x, 418, 22), Vector3.new(x, 404, 0))
	local s = Instance.new("SpotLight")
	s.Brightness, s.Range, s.Angle, s.Shadows, s.Color = 3, 45, 80, false, Color3.fromRGB(255, 246, 232)
	s.Parent = lamp
	lamp.Parent = stage
end
stage.Parent = workspace
local Lighting = game:GetService("Lighting")
Lighting.GlobalShadows = false
Lighting.EnvironmentSpecularScale = 0.15
for _, effect in ipairs(Lighting:GetChildren()) do
	if effect:IsA("BloomEffect") then effect.Enabled = false end
end

local models = {}
for i, t in ipairs(Trainers.List) do
	local m = RS.TrainerModels:FindFirstChild(t.id):Clone()
	m:SetAttribute("Lineup", true)
	local root = m:FindFirstChild("HumanoidRootPart")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = d == root end
	end
	local h = m:FindFirstChildOfClass("Humanoid").HipHeight + root.Size.Y / 2
	m:SetAttribute("H", h)
	-- facing the camera (+Z), parked apart
	local pivot = m:GetPivot()
	m:PivotTo(CFrame.new(-200 - i * 12, 400 + h, 0) * CFrame.Angles(0, math.pi, 0) * (CFrame.new(root.Position):Inverse() * pivot))
	m.Parent = workspace.LocalTrainers
	models[t.id] = m
end
_G.PhotoModels = models

-- the muscle stages' skin layer under clothes is hidden on every trainer (as TrainerFollowClient does)
_G.HideSkin = function()
	for _, m in pairs(models) do
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Skin" and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == "MuscleMeshes" then
				d.LocalTransparencyModifier = 1
			end
		end
	end
end
_G.SetKey = function(c: Color3)
	for _, d in ipairs(stage:GetDescendants()) do
		if d:IsA("Frame") and d.Name == "F" then d.BackgroundColor3 = c end
	end
end

-- poses that aren't in PoseData: The Shadow's crossed arms (as TrainerFollowClient's idle), Volta's boxing guard
local CUSTOM = {
	Crossed = { RightShoulder = { 65, 30, -60 }, LeftShoulder = { 55, -30, 60 }, RightElbow = { 40, 60, 0 }, LeftElbow = { 40, 0, 0 } },
	Guard = { RightShoulder = { 55, 0, -28 }, LeftShoulder = { 70, 0, 22 }, RightElbow = { 115, 0, 0 }, LeftElbow = { 100, 0, 0 }, Waist = { -4, -12, 0 },
		RightHip = { 0, 0, 6 }, LeftHip = { 0, 0, -6 } },
}
_G.Shoot = function(id: string, shot: string, poseName: string?, yaw: number?)
	for n, m in pairs(models) do
		local root = m:FindFirstChild("HumanoidRootPart")
		local x = if n == id then 0 else -200 - #n * 7
		m:PivotTo(m:GetPivot() + (Vector3.new(x, 400 + m:GetAttribute("H"), 0) - root.Position))
	end
	local m = models[id]
	PoseApply.Clear(m)
	if CUSTOM[poseName] then
		for _, joint in ipairs(m:GetDescendants()) do
			local a = (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and CUSTOM[poseName][joint.Name]
			if a then joint.Transform = CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3])) end
		end
	else
		PoseApply.Apply(m, PoseData[poseName or "Relaxed"], 1)
	end
	_G.HideSkin()
	task.wait()
	local cf, size = m:GetBoundingBox()
	local top = cf.Position.Y + size.Y / 2 + 0.1
	local waist = m:FindFirstChild("LowerTorso")
	local bottom = if shot == "bust" then waist.Position.Y - 1.2 else 400 - 0.1
	local mid, span, fov = (top + bottom) / 2, (top - bottom) * 1.04, 18
	local dist = (span / 2) / math.tan(math.rad(fov / 2))
	local a = math.rad(yaw or 0)
	_G.PhotoFov = fov
	_G.PhotoCam = CFrame.lookAt(Vector3.new(math.sin(a) * dist, mid, math.cos(a) * dist), Vector3.new(0, mid, 0))
	return string.format("%s %s top %.1f bottom %.1f", id, shot, top, bottom)
end

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
pcall(function() RunService:UnbindFromRenderStep("PhotoCam") end)
RunService:BindToRenderStep("PhotoCam", Enum.RenderPriority.Last.Value + 5, function()
	local camera = workspace.CurrentCamera
	if _G.PhotoCam then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = _G.PhotoCam
		camera.FieldOfView = _G.PhotoFov or 70
		for _, g in ipairs(playerGui:GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled then g.Enabled = false end
		end
	end
end)
return "photo stage ready"
