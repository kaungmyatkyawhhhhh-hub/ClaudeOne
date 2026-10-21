-- ShakeClient: the shake boost countdown chip, notes for buying/drinking shakes and petting the cat, and the gym cat's
-- tail wag (local only). (Prompt 28: the DRINK SHAKE button left of the stamina bar is gone: the shake sits in hotbar slot 1,
-- ItemService puts it there.)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Stamina = require(Shared.Config.Stamina)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local UIBus = require(Shared.UI.UIBus)
local RightColumn = require(Shared.UI.RightColumn)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Colors = Theme.Colors

------------------------------------------------------------------------
-- The shake boost's chip (time left)
------------------------------------------------------------------------
local chip = RightColumn.Chip("sparkles", Colors.Purple, 10)

local started = false

local function boostLeft()
	local ends = player:GetAttribute("ShakeEnds")
	if type(ends) ~= "number" then return 0 end
	return math.max(0, ends - Workspace:GetServerTimeNow())
end

local function refresh()
	if not started then return end
	local left = boostLeft()
	chip:SetVisible(left > 0)
	if left > 0 then
		local s = math.ceil(left)
		chip:SetText(string.format("+%d%%", math.floor((Stamina.Shake.GainsBoost - 1) * 100 + 0.5)), string.format("%d:%02d", s // 60, s % 60))
	end
end

player:GetAttributeChangedSignal("ShakeEnds"):Connect(refresh)

-- countdown
task.spawn(function()
	while true do
		task.wait(0.5)
		if started and boostLeft() > 0 then refresh() end
	end
end)

------------------------------------------------------------------------
-- Notes
------------------------------------------------------------------------
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "ShakeResult" then
		Notify.Show(info.text, nil, "shake")
		if info.bought then Audio.PlayUI("Click") end
	elseif kind == "ShakeDrunk" then
		Notify.Show(tostring(info.flavor) .. " shake. Stamina full, +" .. math.floor((Stamina.Shake.GainsBoost - 1) * 100 + 0.5) .. "% gains.")
		Audio.PlayUI("LevelUp")
	elseif kind == "CatPet" then
		if (info.refill or 0) > 0 then
			Notify.Show(Stamina.Cat.Name .. " purrs. +" .. info.refill .. " stamina.", nil, "cat")
		else
			Notify.Show(Stamina.Cat.Name .. " is napping. Try again soon.", nil, "cat")
		end
	end
end)

-- Recovery stations (sauna, stretching area, cardio): one small note under the top bar when you step in, gone after 3 s
-- (BoostService sets the player attribute Recovery to the station you stand in). Once per visit: walking along the
-- edge of a station doesn't repeat it (owner, 14 Oct: no permanent banners).
local NOTE_AGAIN = 60 -- seconds before the same station's note can show again
local lastStation, noteShownAt = nil, {}
player:GetAttributeChangedSignal("Recovery"):Connect(function()
	local station = player:GetAttribute("Recovery")
	if station and station ~= lastStation and Stamina.RecoveryNotes[station] and os.clock() - (noteShownAt[station] or -math.huge) > NOTE_AGAIN then
		noteShownAt[station] = os.clock()
		Notify.Show(Stamina.RecoveryNotes[station], nil, "recovery")
	end
	lastStation = station
end)

------------------------------------------------------------------------
-- Plates the cat's idle (local, so it costs no network): the tail wags, and the head slowly looks around (a soft turn
-- now and then, a small tilt)
------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for _, cat in ipairs(CollectionService:GetTagged("GymCat")) do
		local tail = cat:FindFirstChild("Tail")
		local base = tail and tail:GetAttribute("BaseCFrame")
		-- (only near the camera: nobody sees a tail wag from across the town)
		if base and camera and (camera.CFrame.Position - base.Position).Magnitude < 60 then
			local swing = math.sin(now * 2.2) * math.rad(18)
			-- pivot at the tail's root (the end touching the body)
			local root = base * CFrame.new(-tail.Size.X / 2, 0, 0)
			tail.CFrame = root * CFrame.Angles(0, swing, 0) * CFrame.new(tail.Size.X / 2, 0, 0) -- side to side
			local head = cat:FindFirstChild("HeadGroup")
			local neck = head and head:GetAttribute("BaseCFrame")
			if neck then
				-- a slow look left / right (two slow waves so it never repeats exactly) and a small tilt
				local look = math.sin(now * 0.35) * 0.7 + math.sin(now * 0.13 + 1.7) * 0.3
				head:PivotTo(neck * CFrame.Angles(0, look * math.rad(28), math.sin(now * 0.5) * math.rad(5)))
			end
		end
	end
end)

------------------------------------------------------------------------
task.spawn(function()
	ClientData.Get()
	UIBus.WaitForMenu()
	started = true
	refresh()
end)
