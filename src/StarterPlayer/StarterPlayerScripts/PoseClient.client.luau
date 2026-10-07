-- PoseClient: the game side of the bodybuilding poses. PoseController (from the poses package) does the posing itself: every
-- character whose "Pose" attribute is set (the server sets it, see ShowOffService.SetPose) is posed on every client.
-- This script adds, around that:
--   * for YOUR pose: the pose name on screen, turning to face the camera, and letting go when you move or jump
--     (the server froze your walk speed and jump while you pose; a move or jump request asks it to release);
--   * the pose hit for EVERY posing character, a moment after the pose settles: the shown muscles pump up 4%, a crowd
--     "ooh" and, for your own pose, a tiny camera punch and a soft flash;
--   * the judges' score on the posing stage (the server sends it).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShowOff = require(Shared.Config.ShowOff)
local MuscleRig = require(Shared.MuscleRig)
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Vertical = Enum.FillDirection.Vertical
local Colors = Theme.Colors

local remote = Remotes:WaitForChild("Emote", 30)
if not remote then return end -- the show-off service didn't start

local BLEND_IN = 0.35  -- PoseController's blend; the hit lands when the pose has settled
local GRACE = 0.6      -- seconds after the pose starts before moving cancels it (so the button press itself doesn't)
local PUMP = 0.04      -- the muscles shown off get this much bigger at the peak of the hit
local punchBase, punchToken = nil, 0 -- field of view before the current camera punch

local emoteByPose = {}
for _, emote in ipairs(ShowOff.Emotes) do
	if emote.poseData then emoteByPose[emote.poseData] = emote end
end

------------------------------------------------------------------------
-- On-screen name (your pose only) and the flash
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "PoseName", Enabled = false, DisplayOrder = 23, Parent = player:WaitForChild("PlayerGui") })
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24), -- low, under the character (nothing else sits at the bottom centre while posing)
	Size = UDim2.fromOffset(260, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = gui,
}, {
	Theme.Pad("S"),
	Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
local nameLabel = Theme.Text({ LayoutOrder = 1, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), Parent = panel })
Theme.Text({
	LayoutOrder = 2, Text = "Move or jump to stop", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted,
	Size = UDim2.new(1, 0, 0, 18), Parent = panel,
})

local flashGui = Theme.ScreenGui({ Name = "PoseFlash", DisplayOrder = 40, IgnoreGuiInset = true, Parent = player.PlayerGui })
local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Colors.Text
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = flashGui

------------------------------------------------------------------------
-- The pose hit
------------------------------------------------------------------------
local function hit(character: Model, emote)
	MuscleRig.PulseModel(character, emote.muscles, PUMP)
	local root = character:FindFirstChild("HumanoidRootPart")
	if character == player.Character then
		Audio.Play2D("CrowdOoh")
		-- a tiny camera punch (field of view in and back out) and a soft flash
		local camera = workspace.CurrentCamera
		if camera then
			-- (the field of view to return to is remembered while a punch is running, so quick back-to-back hits can't ratchet it down)
			punchToken += 1
			local token = punchToken
			punchBase = punchBase or camera.FieldOfView
			Theme.Tween(camera, { FieldOfView = punchBase - 4 }, 0.08)
			task.delay(0.09, function()
				if camera.Parent then Theme.Tween(camera, { FieldOfView = punchBase }, 0.3) end
			end)
			task.delay(0.5, function()
				if token == punchToken then punchBase = nil end
			end)
		end
		flash.BackgroundTransparency = 0.82
		Theme.Tween(flash, { BackgroundTransparency = 1 }, 0.45)
	elseif root then
		Audio.PlayAt("CrowdOoh", root.Position)
	end
end

------------------------------------------------------------------------
-- Your pose: the name, facing the camera, letting go
------------------------------------------------------------------------
local posingSince = nil -- os.clock() when my current pose started (nil = not posing)

local function faceCamera(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then return end
	local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then return end
	-- the character's front toward the camera
	root.CFrame = CFrame.lookAt(root.Position, root.Position - look.Unit)
end

local function release()
	if not posingSince then return end
	posingSince = nil
	remote:FireServer("")
end

UserInputService.JumpRequest:Connect(function()
	if posingSince and os.clock() - posingSince > GRACE then release() end
end)

RunService.Heartbeat:Connect(function()
	if not posingSince or os.clock() - posingSince <= GRACE then return end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then release() end
end)

------------------------------------------------------------------------
-- Watch every character that can pose (players and the NPCs tagged "Poser")
------------------------------------------------------------------------
local watched = setmetatable({}, { __mode = "k" })

local function watch(character: Instance)
	if not character:IsA("Model") or watched[character] then return end
	watched[character] = true
	local lastName = ""
	local function changed()
		local name = character:GetAttribute("Pose")
		name = if type(name) == "string" then name else ""
		local emote = emoteByPose[name]
		if name ~= "" and name ~= lastName and emote then
			task.delay(BLEND_IN, function()
				if character.Parent and character:GetAttribute("Pose") == name then hit(character, emote) end
			end)
		end
		lastName = name
		if character == player.Character then
			if emote then
				if not posingSince then faceCamera(character) end
				posingSince = os.clock()
				nameLabel.Text = emote.name
				gui.Enabled = true
				Theme.Fade(panel, true)
			else
				posingSince = nil
				local tween = Theme.Fade(panel, false)
				if tween then
					tween.Completed:Connect(function() if not posingSince then gui.Enabled = false end end)
				else
					gui.Enabled = false
				end
			end
		end
	end
	character:GetAttributeChangedSignal("Pose"):Connect(changed)
	changed()
end

local function onPlayer(other: Player)
	if other.Character then watch(other.Character) end
	other.CharacterAdded:Connect(watch)
end
for _, other in ipairs(Players:GetPlayers()) do onPlayer(other) end
Players.PlayerAdded:Connect(onPlayer)
for _, npc in ipairs(CollectionService:GetTagged("Poser")) do watch(npc) end
CollectionService:GetInstanceAddedSignal("Poser"):Connect(watch)

------------------------------------------------------------------------
-- The judges' score
------------------------------------------------------------------------
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "PoseScore" and type(info) == "table" and type(info.score) == "number" then
		Notify.Show(string.format("Judges: %s / 10 for your %s", tostring(info.score), string.lower(tostring(info.name))))
		Audio.PlayUI("SetComplete")
	end
end)
