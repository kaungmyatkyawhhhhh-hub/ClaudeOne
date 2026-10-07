-- EmoteClient: the Emotes side button and its small panel (the six bodybuilding poses and the high five). The bodybuilding poses
-- are PoseData poses (PoseController poses any character whose "Pose" attribute is set; PoseClient adds the pose name, the
-- pose hit and letting go). The high five and the shake chug are small timed poses done here: the server tells every client
-- who emotes and each client poses that character locally (R15 joint
-- Transforms, same angle conventions as MachineClient), easing in and out. The shake chug plays on its own.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShowOff = require(Shared.Config.ShowOff)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Spacing = Theme.Spacing
local Vertical = Enum.FillDirection.Vertical

local remote = Remotes:WaitForChild("Emote", 30)
if not remote then return end -- the show-off service didn't start

------------------------------------------------------------------------
-- Poses (angles in the same R15 conventions as MachineClient)
------------------------------------------------------------------------
local rad, Angles = math.rad, CFrame.Angles
local TWIST = math.rad(-90) -- turns the upper arm so the elbow bends up (measured for the overhead press)
local JOINTS = {
	Waist = { "UpperTorso", "Waist" },
	RShoulder = { "RightUpperArm", "RightShoulder" },
	LShoulder = { "LeftUpperArm", "LeftShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	Root = { "LowerTorso", "Root" },
	RHip = { "RightUpperLeg", "RightHip" },
	LHip = { "LeftUpperLeg", "LeftHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
}
local SIDES = { { "R", 1 }, { "L", -1 } }

local function setJoint(character, key, cframe)
	local spec = JOINTS[key]
	local part = character:FindFirstChild(spec[1])
	local motor = part and part:FindFirstChild(spec[2])
	if motor and (motor:IsA("Motor6D") or motor:IsA("AnimationConstraint")) then motor.Transform = cframe end
end

local function sideArm(character, side, forward, raise, bend)
	setJoint(character, side[1] .. "Shoulder", Angles(forward, 0, 0) * Angles(0, 0, side[2] * raise) * Angles(0, side[2] * TWIST, 0))
	setJoint(character, side[1] .. "Elbow", Angles(bend, 0, 0))
end

local function frontArm(character, side, flex, flare, bend)
	setJoint(character, side[1] .. "Shoulder", Angles(flex, 0, side[2] * flare))
	setJoint(character, side[1] .. "Elbow", Angles(bend, 0, 0))
end

-- w = 0..1 (ease in/out)
local POSES = {}

POSES.HighFive = function(character, w)
	sideArm(character, SIDES[1], -rad(15) * w, rad(160) * w, rad(15) * w)
end
POSES.Chug = function(character, w)
	-- shaker to the mouth, head back a little
	frontArm(character, SIDES[1], rad(80) * w, rad(15) * w, rad(140) * w)
	setJoint(character, "Waist", Angles(rad(8) * w, 0, 0))
end

-- the joints each small pose writes (only those are reset when it ends, so it never wipes a machine or skate pose)
local POSE_JOINTS = { HighFive = { "RShoulder", "RElbow" }, Chug = { "RShoulder", "RElbow", "Waist" } }

local function resetPose(character, keys)
	for _, key in ipairs(keys) do setJoint(character, key, CFrame.identity) end
end

local active = {} -- [character] = { pose, start, seconds }
local EASE = 0.2

remote.OnClientEvent:Connect(function(who, emoteId, seconds)
	local emote = ShowOff.EmoteById[emoteId]
	local character = typeof(who) == "Instance" and who:IsA("Player") and who.Character
	if not emote or not character or not POSES[emote.pose] then return end
	active[character] = { pose = POSES[emote.pose], joints = POSE_JOINTS[emote.pose] or {}, start = os.clock(), seconds = tonumber(seconds) or emote.seconds }
end)

-- before physics, so the pose wins over the walk/idle animation (same as MachineClient)
RunService.Stepped:Connect(function()
	local now = os.clock()
	for character, state in pairs(active) do
		local t = now - state.start
		-- a character that got on a machine or a skateboard meanwhile belongs to that pose now: let this one go
		local root = character.Parent and character:FindFirstChild("HumanoidRootPart")
		local who = Players:GetPlayerFromCharacter(character)
		local taken = root ~= nil and (root.Anchored or (who ~= nil and who:GetAttribute("Skating") == true))
		if not character.Parent or t >= state.seconds or taken then
			active[character] = nil
			if character.Parent and not taken then resetPose(character, state.joints) end
		else
			local w = math.min(1, t / EASE, (state.seconds - t) / EASE)
			w = w * w * (3 - 2 * w) -- smoothstep
			state.pose(character, w)
		end
	end
end)

------------------------------------------------------------------------
-- Side button + panel
------------------------------------------------------------------------
local menuButton = SideMenu.Add("Emotes", "Poses", Icons.Pose, 4)
local gui = Theme.ScreenGui({ Name = "Emotes", Enabled = false, DisplayOrder = 24, Parent = player:WaitForChild("PlayerGui") })
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, SideMenu.Right() + Spacing.M, 0.5, 0),
	Size = UDim2.fromOffset(220, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = gui,
}, {
	Theme.Pad("M"),
	Theme.List(Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
Theme.Text({ LayoutOrder = 0, Text = "Poses", Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

local isOpen = false
local function close()
	if not isOpen then return end
	isOpen = false
	menuButton:SetActive(false)
	local tween = Theme.Fade(panel, false)
	if tween then
		tween.Completed:Connect(function() if not isOpen then gui.Enabled = false end end)
	else
		gui.Enabled = false
	end
end
local function open()
	isOpen = true
	panel.Position = UDim2.new(0, SideMenu.Right() + Spacing.M, 0.5, 0) -- beside the side menu (one or two columns)
	menuButton:SetActive(true)
	gui.Enabled = true
	Audio.PlayUI("Whoosh")
	Theme.Fade(panel, true)
end
UIBus.RegisterPanel("Poses", close)
menuButton.Activated:Connect(function()
	if isOpen then close() else UIBus.PanelOpened("Poses") open() end
end)

for order, emote in ipairs(ShowOff.Emotes) do
	local button = Theme.Button("Secondary", { Name = emote.id, LayoutOrder = order, Size = UDim2.new(1, 0, 0, Theme.MinTouch), Parent = panel }, {
		Theme.Text({ Text = emote.name, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
	})
	button.Activated:Connect(function()
		remote:FireServer(emote.id)
		close()
	end)
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "HighFived" and type(info) == "table" then
		Notify.Show("High five with " .. tostring(info.name) .. "!")
		Audio.PlayUI("SetComplete")
	elseif kind == "OpenEmotes" then -- the posing stage's Pose prompt
		if not isOpen then open() end
	end
end)

