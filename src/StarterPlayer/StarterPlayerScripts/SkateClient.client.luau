-- SkateClient: the Skate button in the right column, shown only outdoors in the town hub (Config.Town). Tapping it
-- asks the server for the board (SkateService validates and welds it); steering is the normal movement controls, so
-- phones use the usual thumbstick. While skating the character leans a little into turns.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared.Config.Town)
local Theme = require(Shared.UI.Theme)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Horizontal = Enum.FillDirection.Horizontal

local button = Theme.Button("Secondary", {
	Name = "Skate",
	Size = UDim2.fromOffset(132, Theme.MinTouch), -- a small button at the top of the column (not a full-width panel)
	Visible = false,
}, {
	Theme.Pad("S"),
	Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center),
})
button:SetAttribute("KeepWidth", true)
RightColumn.Add(button, 0, true) -- top of the idle group: hidden while lifting
local label = Theme.Text({ LayoutOrder = 1, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 1, 0), Parent = button })

local function skating()
	return player:GetAttribute("Skating") == true
end

local function refresh()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local outdoors = root ~= nil and not UIBus.MenuOpen and Town.IsOutdoors(root.Position)
	button.Visible = outdoors or skating()
	label.Text = skating() and "Stop skating" or "Skate"
end

button.Activated:Connect(function()
	Remotes.PlayerAction:FireServer("Skate", not skating())
	Audio.PlayUI("Click")
end)
player:GetAttributeChangedSignal("Skating"):Connect(refresh)

task.spawn(function()
	while true do
		task.wait(0.5)
		refresh()
	end
end)

-- The skating pose, for EVERY player you can see on a board (the "Skating" attribute is replicated): a real skater's side-on
-- stance instead of running on the spot. The body turns sideways on the board, knees bent, front arm out for balance, a
-- lean into turns and a lean back when speeding up. It is set on the joints' Transforms after the walk animation (same
-- way as the emote poses), only on this client.
local rad, Angles = math.rad, CFrame.Angles
local JOINTS = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	RHip = { "RightUpperLeg", "RightHip" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	Neck = { "Head", "Neck" },
}
local function joint(character, key)
	local spec = JOINTS[key]
	local part = character:FindFirstChild(spec[1])
	local motor = part and part:FindFirstChild(spec[2])
	if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then return motor end
	return nil
end
local function set(character, key, cframe)
	local motor = joint(character, key)
	if motor then motor.Transform = cframe end
end

local states = {} -- [character] = { lean, speedLean, crouch, t }
local function pose(character, root, dt)
	local state = states[character]
	if not state then
		state = { lean = 0, back = 0, crouch = 0, speed = 0, t = 0 }
		states[character] = state
	end
	local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local speed = velocity.Magnitude
	local forward = velocity:Dot(root.CFrame.LookVector)
	local accel = (speed - state.speed) / math.max(dt, 1 / 120)
	state.speed = speed
	local turn = root.AssemblyAngularVelocity.Y
	local k = math.min(1, dt * 8)
	state.lean += (math.clamp(-turn * 0.06, -0.3, 0.3) - state.lean) * k
	state.back += (math.clamp(accel * 0.004, -0.15, 0.2) - state.back) * k
	-- crouch deeper at speed
	state.crouch += (math.clamp(speed / 30, 0, 1) - state.crouch) * k
	state.t += dt * (1 + speed * 0.05)
	local sway = math.sin(state.t * 2.2) * 0.04 * math.min(1, speed / 10)
	local bend = rad(18) + rad(14) * state.crouch
	-- side-on stance: the body faces to the skater's right of the board (left foot forward)
	set(character, "Root", Angles(0, rad(-90), state.lean * 0.6))
	set(character, "Waist", Angles(rad(6) + state.back, rad(90) * 0, sway))
	set(character, "LHip", Angles(-rad(8) * 0 , 0, rad(14)) * Angles(-bend * 0.5, 0, 0))
	set(character, "RHip", Angles(-rad(8) * 0, 0, -rad(14)) * Angles(-bend * 0.5, 0, 0))
	set(character, "LKnee", Angles(bend, 0, 0))
	set(character, "RKnee", Angles(bend * 1.1, 0, 0))
	-- arms out for balance, the front one a little higher
	set(character, "LShoulder", Angles(0, 0, rad(-48) - sway * 2))
	set(character, "RShoulder", Angles(0, 0, rad(40) + sway * 2))
	set(character, "LElbow", Angles(rad(12), 0, 0))
	set(character, "RElbow", Angles(rad(12), 0, 0))
	set(character, "Neck", Angles(0, rad(90), 0)) -- the head still looks where the board goes
end

local FOV_BASE, camera = nil, workspace.CurrentCamera
RunService.Stepped:Connect(function(_, dt)
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if other:GetAttribute("Skating") == true and character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root then pose(character, root, dt) end
		elseif character and states[character] then
			states[character] = nil
			for key in pairs(JOINTS) do set(character, key, CFrame.identity) end
		end
	end
	-- a little more field of view at speed for me
	camera = workspace.CurrentCamera
	local mine = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if camera and mine then
		FOV_BASE = FOV_BASE or camera.FieldOfView
		local speed = (mine.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local want = skating() and FOV_BASE + math.clamp((speed - 16) * 0.5, 0, 8) or FOV_BASE
		if math.abs(camera.FieldOfView - want) > 0.05 and (skating() or camera.FieldOfView ~= FOV_BASE) then
			camera.FieldOfView += (want - camera.FieldOfView) * math.min(1, dt * 4)
		end
	end
end)
