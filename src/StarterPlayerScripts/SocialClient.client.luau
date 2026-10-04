-- SocialClient: arm wrestling (bottom panel with the push meter, countdown, tap input, result) and corner notes
-- for spotting and lifting together.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Social = require(Shared.Config.Social)
local Theme = require(Shared.UI.Theme)
local Notify = require(Shared.UI.Notify)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

------------------------------------------------------------------------
-- Spotting / together notes
------------------------------------------------------------------------
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "SpotStarted" then
		if info.spotter then
			Notify.Show("Spotting " .. tostring(info.name) .. ". You earn coins for every rep.")
		else
			Notify.Show(tostring(info.name) .. " is spotting you. +" .. math.floor((Social.Spot.GainsBoost - 1) * 100 + 0.5) .. "% gains.")
		end
		Audio.PlayUI("Click")
	elseif kind == "SpotEnded" then
		Notify.Show(info.spotter and "Spot ended." or (tostring(info.name) .. " stopped spotting."), nil, "spot")
	elseif kind == "TogetherStarted" then
		Notify.Show("Lifting together: +" .. math.floor((Social.Together.GainsBoost - 1) * 100 + 0.5) .. "% gains.", nil, "together")
	end
end)

------------------------------------------------------------------------
-- Arm wrestling
------------------------------------------------------------------------
local remote = Remotes:WaitForChild("ArmWrestle", 30)
if not remote then return end -- the arm wrestling service didn't start

local gui = Theme.ScreenGui({ Name = "ArmWrestle", DisplayOrder = 7, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -Spacing.XL),
	Size = UDim2.fromOffset(420, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Parent = gui,
}, {
	Theme.Pad("L"),
	Theme.List(Vertical, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top),
})
local title = Theme.Text({ LayoutOrder = 1, Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 22), Parent = panel })
local big = Theme.Text({ LayoutOrder = 2, Font = "SemiBold", TextSize = "Huge", Size = UDim2.new(1, 0, 0, 44), Parent = panel })

-- meter: your side on the left; the white fill grows from the middle toward whoever is winning
local meterRow = New("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = panel })
local track = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.85, Parent = meterRow }, { Theme.Round("Segment") })
local fill = New("Frame", { AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0, 1), BackgroundColor3 = Colors.Text, Parent = track }, { Theme.Round("Segment") })
New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 8), BackgroundColor3 = Colors.Text, Parent = meterRow })
local labels = New("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = panel })
Theme.Text({ Text = "You", Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = labels })
local themLabel = Theme.Text({ Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = labels })
local hint = Theme.Text({ LayoutOrder = 5, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 18), Parent = panel })
local leaveButton = Theme.Button("Secondary", { Name = "Leave", LayoutOrder = 6, Size = UDim2.new(0, 160, 0, Theme.MinTouch), Parent = panel }, {
	Theme.Text({ Text = "Stand up", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
leaveButton.Activated:Connect(function() remote:FireServer("Leave") end)

local live = false
local mySide = 1

local function sendTap()
	if live then remote:FireServer("Tap") end
end

local function setLive(on)
	if live == on then return end
	live = on
	if on then
		ContextActionService:BindActionAtPriority("ArmWrestleTap", function(_, state)
			if state == Enum.UserInputState.Begin then sendTap() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	else
		ContextActionService:UnbindAction("ArmWrestleTap")
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not live then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		sendTap()
	end
end)

local function showMeter(meter)
	-- meter is +1 when seat 1 wins; turn it into "you" (left) vs "them" (right)
	local mine = meter * mySide -- +1 = you are winning
	local width = math.abs(mine) * 0.5
	fill.Size = UDim2.fromScale(width, 1)
	fill.Position = UDim2.fromScale(mine >= 0 and 0.5 - width or 0.5, 0)
	fill.BackgroundColor3 = mine >= 0 and Colors.Text or Colors.NeedsWork
end

local resultToken = 0
remote.OnClientEvent:Connect(function(kind, info)
	if kind ~= "State" or type(info) ~= "table" then return end
	local state = info.state
	if state == "idle" then
		setLive(false)
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	mySide = info.side or mySide
	themLabel.Text = info.opponent or "..."
	if state == "waiting" then
		setLive(false)
		title.Text = "Arm wrestling"
		big.Text = ""
		hint.Text = "Waiting for an opponent..."
		leaveButton.Visible = true
		showMeter(0)
	elseif state == "countdown" then
		setLive(false)
		title.Text = "vs " .. (info.opponent or "...")
		big.Text = tostring(info.countdown or "")
		hint.Text = "Get ready to tap fast"
		leaveButton.Visible = false
		showMeter(0)
		Audio.PlayUI("Click")
	elseif state == "live" then
		if info.countdown == 0 then
			big.Text = "Tap!"
			Audio.PlayUI("SetComplete")
		end
		setLive(true)
		hint.Text = "Tap anywhere as fast as you can"
		leaveButton.Visible = false
		showMeter(info.meter or 0)
	elseif state == "result" then
		setLive(false)
		leaveButton.Visible = false
		showMeter(info.won and mySide or -mySide)
		title.Text = tostring(info.reason or "")
		big.Text = info.draw and "Draw" or (info.won and "You win" or "You lose")
		hint.Text = info.coins and ("+" .. info.coins .. " coins") or ""
		if info.won then Audio.PlayUI("TitleUnlocked") end
		resultToken += 1
		local token = resultToken
		task.delay(3, function()
			if token == resultToken and not live then gui.Enabled = false end
		end)
	end
end)
