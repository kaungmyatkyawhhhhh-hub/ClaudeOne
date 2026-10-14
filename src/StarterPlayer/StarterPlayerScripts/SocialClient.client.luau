-- SocialClient: arm wrestling (pick an NPC opponent or wait for a player, the 3-2-1, a big round TAP button (or tap
-- anywhere / Space / gamepad A), the tug bar, the result) and the note for lifting together (spotting: SpotClient).
-- Matches run on the server (ArmWrestleService); the arms move in ArmWrestleClient.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Social = require(Shared.Config.Social)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Notify = require(Shared.UI.Notify)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors
local Horizontal = Enum.FillDirection.Horizontal

------------------------------------------------------------------------
-- Lifting-together note (spotting has its own client: SpotClient)
------------------------------------------------------------------------
Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	if kind == "TogetherStarted" then
		Notify.Toast("Lifting together", "+" .. math.floor((Social.Together.GainsBoost - 1) * 100 + 0.5) .. "% gains", "users", Colors.Green, "together")
	end
end)

------------------------------------------------------------------------
-- Arm wrestling
------------------------------------------------------------------------
local remote = Remotes:WaitForChild("ArmWrestle", 30)
if not remote then return end -- the arm wrestling service didn't start

-- Owner's UI v2 (mockup 13_arm_wrestle): at the top "YOU" (left) and the opponent's name (right) over one long bar, red
-- from the left (you) and blue from the right (them), split where the match stands; the gold timer between the names (the
-- 3-2-1 and "GO!" there too); a big round red "TAP!" button ("as fast as you can") at the bottom. Waiting at the table: the
-- opponent buttons (NPCs: name + Easy / Medium / Hard · coins) and STAND UP in a small panel at the bottom. The result
-- shows big in the middle ("YOU WIN!" gold, "YOU LOSE" red, "DRAW") with the coins under it.
local gui = Theme.ScreenGui({ Name = "ArmWrestle", DisplayOrder = 7, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local root = Kit.Root(gui)
local BAR_W = 480

local top = New("Frame", { Name = "Top", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(BAR_W, 64), Parent = root })
-- (just under Roblox's top bar, Kit.UnderTopbar)
local function placeTop() top.Position = UDim2.new(0.5, 0, 0, Kit.UnderTopbar(root)) end
Kit.OnTopbar(placeTop)
gui:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(placeTop) end)
Kit.Text({ Name = "You", Text = "YOU", Font = "Title", TextSize = 20, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0.35, 0, 0, 26),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
local themLabel = Kit.Text({ Name = "Them", Text = "", Font = "Title", TextSize = 20, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.35, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Right, Parent = top })
local big = Kit.Text({ Name = "Timer", Text = "", Font = "Title", TextSize = 30, TextColor3 = Colors.Gold, AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -6), Size = UDim2.new(0.3, 0, 0, 34), Parent = top })
-- the tug bar: blue track (them) with a red fill (you) from the left
local bar = New("Frame", { Name = "Bar", Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = Color3.new(1, 1, 1), Parent = top }, {
	New("UICorner", { CornerRadius = UDim.new(0, 8) }),
	New("UIStroke", { Color = Colors.Outline, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Colors.Blue:Lerp(Color3.new(1, 1, 1), 0.2), Colors.Blue:Lerp(Color3.new(0, 0, 0), 0.2)) }),
})
local fill = New("Frame", { Name = "You", Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar }, {
	New("UICorner", { CornerRadius = UDim.new(0, 8) }),
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Colors.Red:Lerp(Color3.new(1, 1, 1), 0.2), Colors.Red:Lerp(Color3.new(0, 0, 0), 0.2)) }),
})

-- the result, big in the middle
local result = New("Frame", { Name = "Result", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
	Size = UDim2.fromOffset(460, 80), Visible = false, Parent = root })
local resultText = Kit.Text({ Name = "Text", Text = "", Font = "Title", TextSize = 46, Size = UDim2.new(1, 0, 0, 52), Parent = result })
local resultSub = Kit.Text({ Name = "Sub", Text = "", Font = "Title", TextSize = 17, Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 22), Parent = result })

-- waiting at the table: pick an NPC opponent (or wait for a player to sit down), or stand up
local waitPanel = Theme.Panel({ Name = "Waiting", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(470, 132),
	Active = true, Parent = root }, {})
local hint = Kit.Text({ Name = "Hint", Text = "", Font = "Title", TextSize = 15, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 20), Parent = waitPanel })
local npcRow = New("Frame", { Name = "Npcs", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 48), Parent = waitPanel },
	{ Theme.List(Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
local leaveButton = Kit.Button("Gray", "Stand up", { Name = "Leave", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Parent = waitPanel },
	{ width = 150, height = 32, textSize = 14 })
leaveButton.Activated:Connect(function() remote:FireServer("Leave") end)

-- one button per opponent the server offers (Social.ArmWrestle.Npcs, plus an NPC rival whose challenge you accepted)
local npcButtons = {}
local shownChoices = ""
-- every opponent (a rival too) is the same dark card, the same size; the difficulty line under the name carries the color
-- (owner, 14 Oct: no glow rings on cards that come in a row)
local NPC_COLOR = { Easy = Colors.Green, Medium = Colors.Gold, Hard = Colors.Red }
local function buildChoices(list)
	local key = ""
	for _, npc in ipairs(list) do key ..= tostring(npc.id) .. "," end
	if key == shownChoices then return end
	shownChoices = key
	for _, button in pairs(npcButtons) do button:Destroy() end
	npcButtons = {}
	for order, npc in ipairs(list) do
		local sub = npc.coins and (tostring(npc.label) .. " · " .. npc.coins .. " coins") or tostring(npc.label)
		local button = Kit.Button("Quiet", tostring(npc.name), { Name = tostring(npc.id), LayoutOrder = order, Parent = npcRow },
			{ width = math.floor((470 - 24 - 8 * (#list - 1)) / #list), height = 46, textSize = 15, upper = false })
		-- the difficulty and the coins under the name (the button's row stacks them)
		local list = button:FindFirstChildOfClass("UIListLayout")
		if list then
			list.FillDirection = Enum.FillDirection.Vertical
			list.Padding = UDim.new(0, 0)
		end
		local label = button:FindFirstChild("Label")
		if label then label.Size = UDim2.fromOffset(0, 20) end
		local subLabel = Kit.Text({ Name = "Sub", LayoutOrder = 3, Text = sub, Font = "Body", TextSize = 11, Size = UDim2.new(1, 0, 0, 13), Parent = button })
		subLabel.TextColor3 = NPC_COLOR[npc.label] or Theme.RankColors.S -- (a rival: coral)
		subLabel:SetAttribute("KeepColor", true)
		button.Activated:Connect(function()
			remote:FireServer("Npc", npc.id)
		end)
		npcButtons[npc.id] = button
	end
end
buildChoices(Social.ArmWrestle.Npcs)

-- the big round TAP button (tapping anywhere works too)
local tapButton = New("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(136, 136), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = root }, {
	New("UICorner", { CornerRadius = UDim.new(1, 0) }),
	New("UIStroke", { Color = Colors.Outline, Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Colors.Red:Lerp(Color3.new(1, 1, 1), 0.25), Colors.Red:Lerp(Color3.new(0, 0, 0), 0.15)) }),
})
local tapScale = New("UIScale", { Parent = tapButton })
Kit.Text({ Name = "Big", Text = "TAP!", Font = "Title", TextSize = 42, Position = UDim2.new(0, 0, 0.18, 0), Size = UDim2.new(1, 0, 0, 46), Parent = tapButton })
Kit.Text({ Name = "Small", Text = "as fast as you can", Font = "Title", TextSize = 12, Position = UDim2.new(0, 0, 0.58, 0), Size = UDim2.new(1, 0, 0, 16), Parent = tapButton })

local live = false
local mySide = 1
local liveEnds = 0 -- os.clock() when the match runs out (Social.ArmWrestle.MaxTime after GO)

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
	tapScale.Scale = 0.92
	Theme.Tween(tapScale, { Scale = 1 }, 0.12)
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
	-- meter is +1 when seat 1 wins; turn it into "you" (left, red) vs "them" (right, blue)
	local mine = math.clamp(meter * mySide, -1, 1) -- +1 = you are winning
	Theme.Tween(fill, { Size = UDim2.fromScale(0.5 + mine * 0.5, 1) }, 0.12)
end

-- the timer while the match runs
task.spawn(function()
	while true do
		task.wait(0.1)
		if live then big.Text = string.format("0:%02d", math.max(0, math.ceil(liveEnds - os.clock()))) end
	end
end)

local resultToken = 0
local resultUntil = 0 -- the result stays readable this long, even after the server stands you up
remote.OnClientEvent:Connect(function(kind, info)
	if kind ~= "State" or type(info) ~= "table" then return end
	local state = info.state
	if state == "idle" then
		setLive(false)
		tapButton.Visible = false
		waitPanel.Visible = false
		if os.clock() >= resultUntil then gui.Enabled = false end
		return
	end
	gui.Enabled = true
	mySide = info.side or mySide
	themLabel.Text = string.upper(tostring(info.opponent or "..."))
	tapButton.Visible = state == "live" or state == "countdown"
	waitPanel.Visible = state == "waiting"
	top.Visible = state ~= "waiting"
	result.Visible = state == "result"
	if state == "waiting" then
		setLive(false)
		big.Text = ""
		local choices = type(info.npcs) == "table" and #info.npcs > 0
		if choices then buildChoices(info.npcs) end
		npcRow.Visible = choices
		hint.Text = choices and "Pick an opponent, or wait for a player to sit down" or "Waiting for an opponent..."
		showMeter(0)
	elseif state == "countdown" then
		setLive(false)
		big.Text = tostring(info.countdown or "")
		showMeter(0)
		Audio.PlayUI("ArmCountdown")
	elseif state == "live" then
		if info.countdown == 0 then
			big.Text = "GO!"
			liveEnds = os.clock() + (Social.ArmWrestle.MaxTime or 8)
			Audio.PlayUI("ArmGo")
		end
		setLive(true)
		showMeter(info.meter or 0)
	elseif state == "result" then
		setLive(false)
		tapButton.Visible = false
		showMeter(info.won and mySide or -mySide)
		big.Text = ""
		resultText.Text = info.draw and "DRAW" or (info.won and "YOU WIN!" or "YOU LOSE")
		resultText.TextColor3 = info.draw and Colors.Text or (info.won and Colors.Gold or Colors.Red)
		local sub = info.coins and ("+" .. info.coins .. " coins") or tostring(info.reason or "")
		if info.king then sub ..= " · you beat the champion!" end
		resultSub.Text = sub
		if info.won then Audio.PlayUI("SetComplete") end
		resultToken += 1
		local token = resultToken
		resultUntil = os.clock() + 4
		task.delay(4, function()
			if token == resultToken and not live then gui.Enabled = false end
		end)
	end
end)
