-- EmoteClient: the Poses tile and its Emotes window (the six bodybuilding poses, the high five and the victory wave). The bodybuilding poses
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
local Kit = require(Shared.UI.Kit)
local Icons = require(Shared.UI.Icons)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New = Theme.New

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
	RWrist = { "RightHand", "RightWrist" },
	Neck = { "Head", "Neck" },
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

-- w = 0..1 (ease in/out), p = 0..1 how far through the emote
local POSES = {}
local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

POSES.HighFive = function(character, w)
	sideArm(character, SIDES[1], -rad(15) * w, rad(160) * w, rad(15) * w)
end
-- (prompt 28b, owner: "it looked like throwing") a real drink: the elbow comes up in front of the chest and the bottle to
-- the mouth (first quarter), then it tips up further and the head goes back with a few small gulps, then it comes down
-- (last 15%). Angles checked on a character in Studio (front, side, behind): shoulder in front + across, the wrist tips
-- the bottle's bottom up and out, Neck + = looking up.
POSES.Chug = function(character, _w, p)
	p = p or 0.5
	local up = smooth(p / 0.25) * smooth((1 - p) / 0.15) -- the arm: up to the mouth, hold, down
	local tip = smooth((p - 0.2) / 0.45)                  -- the bottle empties: tips up, head back
	local gulp = (math.sin(p * math.pi * 8) * 0.5 + 0.5) * tip
	setJoint(character, "RShoulder", Angles(rad(85) * up, 0, -rad(50) * up))
	setJoint(character, "RElbow", Angles(rad(115) * up, 0, 0))
	setJoint(character, "RWrist", Angles(-rad(20 + 35 * tip) * up, 0, rad(25 + 20 * tip) * up))
	setJoint(character, "Neck", Angles(rad(8 + 20 * tip + 4 * gulp) * up, 0, 0))
end

-- the victory wave: waving to a crowd, the right arm high over the head and the hand swinging side to side (about 2
-- waves a second; the whole arm sways a little with it), the other arm relaxed, chest up a little
POSES.VictoryWave = function(character, w)
	local wave = math.sin(os.clock() * math.pi * 4)
	sideArm(character, SIDES[1], 0, rad(158 + 8 * wave) * w, rad(18 + 16 * wave) * w)
	setJoint(character, "Waist", Angles(-rad(5) * w, 0, 0))
end

-- the joints each small pose writes (only those are reset when it ends, so it never wipes a machine or skate pose)
local POSE_JOINTS = {
	HighFive = { "RShoulder", "RElbow" }, Chug = { "RShoulder", "RElbow", "RWrist", "Neck" },
	VictoryWave = { "RShoulder", "RElbow", "Waist" },
}

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
			state.pose(character, w, t / state.seconds)
		end
	end
end)

------------------------------------------------------------------------
-- The Poses tile and the Emotes window (owner's UI v2: the same window style as the other menus): a grid of cards, each
-- a pink icon tile and the pose's name; tap one to do it (the window closes).
------------------------------------------------------------------------
local ICON = { HighFive = "hand", VictoryWave = "smile" } -- (the bodybuilding poses: a flexed arm)
local menuButton = SideMenu.Add("Emotes", "Poses", Icons.Pose, 4)
local modal = Kit.Modal({ name = "Emotes", title = "Emotes", icon = "smile", width = 540, height = 262, displayOrder = 24,
	tabs = { { id = "Poses", text = "Poses", icon = "biceps-flexed" } } })
local grid = New("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = modal.body }, {
	New("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 94), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function close()
	if modal.isOpen() then modal.close() end
end
local function open()
	if modal.isOpen() then return end
	menuButton:SetActive(true)
	modal.open()
	Audio.PlayUI("Whoosh")
end
modal.gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if not modal.isOpen() then menuButton:SetActive(false) end
end)
UIBus.RegisterPanel("Poses", close)
menuButton.Activated:Connect(function()
	if modal.isOpen() then close() else UIBus.PanelOpened("Poses") open() end
end)

for order, emote in ipairs(ShowOff.Emotes) do
	local card = Kit.Card({ Name = emote.id, LayoutOrder = order, Clickable = true, Parent = grid }, {})
	Kit.IconTile(ICON[emote.id] or "biceps-flexed", Color3.fromHex("#E2559A"), 48, { Name = "Tile", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = card })
	Kit.Text({ Name = "Name", Text = emote.name, Font = "Title", TextSize = 13, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 32), Parent = card })
	card.Activated:Connect(function()
		remote:FireServer(emote.id)
		close()
	end)
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "HighFived" and type(info) == "table" then
		Notify.Toast("High five!", "With " .. tostring(info.name), "hand", Color3.fromHex("#E2559A"))
		Audio.PlayUI("SetComplete")
	elseif kind == "OpenEmotes" then -- the posing stage's Pose prompt
		if not modal.isOpen() then open() end
	end
end)

