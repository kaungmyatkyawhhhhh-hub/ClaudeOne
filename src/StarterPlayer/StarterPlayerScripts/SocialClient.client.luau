-- SocialClient: arm wrestling (bottom panel: pick an NPC opponent or wait for a player, the 3-2-1, a big TAP button
-- (or tap anywhere / Space / gamepad A), the push bar, the result) and the corner note for lifting together
-- (spotting: SpotClient). Matches run on the server (ArmWrestleService); the arms move in ArmWrestleClient.
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
-- Lifting-together note (spotting has its own client: SpotClient)
------------------------------------------------------------------------
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "TogetherStarted" then
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
-- alone at the table: pick an NPC opponent (or wait for a player to sit down)
local npcRow = New("Frame", { Name = "Npcs", LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, Parent = panel },
	{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
-- one button per opponent the server offers (Social.ArmWrestle.Npcs, plus an NPC rival whose challenge you accepted)
local npcButtons = {}
local shownChoices = ""
local function buildChoices(list)
	local key = ""
	for _, npc in ipairs(list) do key ..= tostring(npc.id) .. "," end
	if key == shownChoices then return end
	shownChoices = key
	for _, button in pairs(npcButtons) do button:Destroy() end
	npcButtons = {}
	for order, npc in ipairs(list) do
		local sub = npc.coins and (tostring(npc.label) .. " · " .. npc.coins .. " coins") or tostring(npc.label)
		local button = Theme.Button("Secondary", { Name = tostring(npc.id), LayoutOrder = order, Size = UDim2.new(1 / #list, -Spacing.S, 0, 56), Parent = npcRow }, {
			Theme.List(Vertical, "XS", Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
			Theme.Text({ LayoutOrder = 1, Text = tostring(npc.name), Font = "SemiBold", TextSize = "Body", Size = UDim2.new(1, 0, 0, 20) }),
			Theme.Text({ LayoutOrder = 2, Text = sub, Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, Size = UDim2.new(1, 0, 0, 16), Upper = false }),
		})
		button.Activated:Connect(function()
			remote:FireServer("Npc", npc.id)
			npcRow.Visible = false
		end)
		npcButtons[npc.id] = button
	end
end
buildChoices(Social.ArmWrestle.Npcs)
-- the big TAP button (tapping anywhere works too)
local tapButton = Theme.Button("Primary", { Name = "Tap", LayoutOrder = 7, Size = UDim2.fromOffset(150, 72), Visible = false, Parent = panel }, {
	Theme.Text({ Text = "Tap!", Font = "SemiBold", TextSize = "Huge", Size = UDim2.fromScale(1, 1) }),
})
local leaveButton = Theme.Button("Secondary", { Name = "Leave", LayoutOrder = 8, Size = UDim2.new(0, 160, 0, Theme.MinTouch), Parent = panel }, {
	Theme.Text({ Text = "Stand up", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})
leaveButton.Activated:Connect(function() remote:FireServer("Leave") end)

-- phones (short screens): a narrower, lower panel so the wrestlers stay in view
Theme.OnCompactChanged(function(compact)
	panel.Size = UDim2.fromOffset(compact and 340 or 420, 0)
	panel.Position = UDim2.new(0.5, 0, 1, compact and -Spacing.S or -Spacing.XL)
	tapButton.Size = compact and UDim2.fromOffset(130, 56) or UDim2.fromOffset(150, 72)
	big.Size = UDim2.new(1, 0, 0, compact and 34 or 44)
end)

local live = false
local mySide = 1

-- is this press on the TAP button? (then the button's own Activated counts it, not the tap-anywhere input)
local function overTapButton(input)
	if not tapButton.Visible then return false end
	local p, s = tapButton.AbsolutePosition, tapButton.AbsoluteSize
	local x, y = input.Position.X, input.Position.Y + game:GetService("GuiService"):GetGuiInset().Y
	return x >= p.X and x <= p.X + s.X and y >= p.Y and y <= p.Y + s.Y
end

local function sendTap()
	if not live then return end
	remote:FireServer("Tap")
	Audio.PlayUI("ArmTap")
end
tapButton.Activated:Connect(sendTap)

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
		-- (a press on the TAP button is already counted by its Activated)
		local over = overTapButton(input)
		if not over then sendTap() end
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
local resultUntil = 0 -- the result stays readable this long, even after the server stands you up
remote.OnClientEvent:Connect(function(kind, info)
	if kind ~= "State" or type(info) ~= "table" then return end
	local state = info.state
	if state == "idle" then
		setLive(false)
		tapButton.Visible = false
		npcRow.Visible = false
		if os.clock() >= resultUntil then gui.Enabled = false end
		return
	end
	gui.Enabled = true
	mySide = info.side or mySide
	themLabel.Text = info.opponent or "..."
	tapButton.Visible = state == "live"
	if state ~= "waiting" then npcRow.Visible = false end
	if state == "waiting" then
		setLive(false)
		title.Text = "Arm wrestling"
		big.Text = ""
		local choices = type(info.npcs) == "table" and #info.npcs > 0
		if choices then buildChoices(info.npcs) end
		npcRow.Visible = choices
		hint.Text = choices and "Pick an opponent, or wait for a player to sit down" or "Waiting for an opponent..."
		leaveButton.Visible = true
		showMeter(0)
	elseif state == "countdown" then
		setLive(false)
		title.Text = "vs " .. (info.opponent or "...")
		big.Text = tostring(info.countdown or "")
		hint.Text = "Get ready to tap fast"
		leaveButton.Visible = false
		showMeter(0)
		Audio.PlayUI("ArmCountdown")
	elseif state == "live" then
		if info.countdown == 0 then
			big.Text = "Go!"
			Audio.PlayUI("ArmGo")
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
		if info.king then hint.Text ..= " · you beat the champion!" end
		if info.won then Audio.PlayUI("SetComplete") end
		resultToken += 1
		local token = resultToken
		resultUntil = os.clock() + 4
		task.delay(4, function()
			if token == resultToken and not live then gui.Enabled = false end
		end)
	end
end)
