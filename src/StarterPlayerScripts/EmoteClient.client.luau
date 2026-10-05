-- EmoteClient: the Emotes side button and its small panel (double biceps, lat spread, high five), and the poses
-- themselves. The server tells every client who emotes; each client poses that character locally (R15 joint
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
}
local SIDES = { { "R", 1 }, { "L", -1 } }

local function setJoint(character, key, cframe)
	local spec = JOINTS[key]
	local part = character:FindFirstChild(spec[1])
	local motor = part and part:FindFirstChild(spec[2])
	if motor and motor:IsA("Motor6D") then motor.Transform = cframe end
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
POSES.DoubleBiceps = function(character, w)
	for _, side in ipairs(SIDES) do sideArm(character, side, -rad(5) * w, rad(88) * w, rad(125) * w) end
	setJoint(character, "Waist", Angles(rad(4) * w, 0, 0))
end
POSES.LatSpread = function(character, w)
	-- fists at the waist, elbows flared forward and out
	for _, side in ipairs(SIDES) do frontArm(character, side, rad(25) * w, rad(45) * w, rad(100) * w) end
	setJoint(character, "Waist", Angles(rad(6) * w, 0, 0))
end
POSES.HighFive = function(character, w)
	sideArm(character, SIDES[1], -rad(15) * w, rad(160) * w, rad(15) * w)
end
POSES.Chug = function(character, w)
	-- shaker to the mouth, head back a little
	frontArm(character, SIDES[1], rad(80) * w, rad(15) * w, rad(140) * w)
	setJoint(character, "Waist", Angles(rad(8) * w, 0, 0))
end

local function resetPose(character)
	for key in pairs(JOINTS) do setJoint(character, key, CFrame.identity) end
end

local active = {} -- [character] = { pose, start, seconds }
local EASE = 0.2

remote.OnClientEvent:Connect(function(who, emoteId, seconds)
	local emote = ShowOff.EmoteById[emoteId]
	local character = typeof(who) == "Instance" and who:IsA("Player") and who.Character
	if not emote or not character or not POSES[emote.pose] then return end
	active[character] = { pose = POSES[emote.pose], start = os.clock(), seconds = tonumber(seconds) or emote.seconds }
end)

-- before physics, so the pose wins over the walk/idle animation (same as MachineClient)
RunService.Stepped:Connect(function()
	local now = os.clock()
	for character, state in pairs(active) do
		local t = now - state.start
		if not character.Parent or t >= state.seconds then
			active[character] = nil
			if character.Parent then resetPose(character) end
		else
			local w = math.min(1, t / EASE, (state.seconds - t) / EASE)
			w = w * w * (3 - 2 * w) -- smoothstep
			state.pose(character, w)
		end
	end
end)

------------------------------------------------------------------------
-- NPC gym-goers (GymGoerService): a loop of alternating curls, a double-biceps flex, then a short rest
------------------------------------------------------------------------
local CollectionService = game:GetService("CollectionService")
local GOER_CYCLE = { curl = 9, flex = 3, rest = 4 } -- seconds
local CURL_PERIOD = 2.4

local function goerPose(character, t)
	local cycle = GOER_CYCLE.curl + GOER_CYCLE.flex + GOER_CYCLE.rest
	local c = t % cycle
	if c < GOER_CYCLE.curl then
		local wave = (t % CURL_PERIOD) / CURL_PERIOD * math.pi * 2
		frontArm(character, SIDES[1], rad(5), rad(10), rad(25 + 115 * (0.5 + 0.5 * math.sin(wave))))
		frontArm(character, SIDES[2], rad(5), rad(10), rad(25 + 115 * (0.5 + 0.5 * math.sin(wave + math.pi))))
	elseif c < GOER_CYCLE.curl + GOER_CYCLE.flex then
		local into = c - GOER_CYCLE.curl
		local w = math.min(1, into / EASE, (GOER_CYCLE.flex - into) / EASE)
		POSES.DoubleBiceps(character, w * w * (3 - 2 * w))
	else
		frontArm(character, SIDES[1], rad(3), rad(8), rad(15))
		frontArm(character, SIDES[2], rad(3), rad(8), rad(15))
		setJoint(character, "Waist", CFrame.identity)
	end
end

RunService.Stepped:Connect(function()
	local now = os.clock()
	local cameraAt = workspace.CurrentCamera.CFrame.Position
	for _, goer in ipairs(CollectionService:GetTagged("GymGoer")) do
		-- (performance: nobody sees a curl from across the map, so far-away regulars aren't posed)
		if goer:IsDescendantOf(workspace) and (goer:GetPivot().Position - cameraAt).Magnitude < 90 then
			goerPose(goer, now + (goer:GetAttribute("Phase") or 0))
		end
	end
end)

------------------------------------------------------------------------
-- Side button + panel
------------------------------------------------------------------------
local menuButton = SideMenu.Add("Emotes", "Emotes", Icons.Pose, 4)
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
Theme.Text({ LayoutOrder = 0, Text = "Emotes", Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

local isOpen = false
local function close()
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
menuButton.Activated:Connect(function()
	if isOpen then close() else open() end
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
	end
end)

