-- Toasts and hints (owner's UI v2, 13 Oct):
--   Notify.Show(text, color?, key?)               a toast: one line on a small dark card with a colored icon tile
--   Notify.Toast(title, sub?, icon?, color?, key?) a toast with a second line and an icon (Config/UI.Icons)
--   Notify.Hint(text, key?)                        a HINT in the top tutorial band: only one at a time (a new one replaces
--                                                  the old), hidden after Notify.HintSeconds. Off when the player turned
--                                                  "Tutorial Hints" off in Settings (settings.hints == "Off").
--   Notify.SetBand(text?)                          the tutorial step's line in the band (TutorialClient): shown like a
--                                                  hint (also gone after HintSeconds; the coach dialog keeps the words)
--   Notify.BandBottom()                            mockup px from the top to the bottom of the band (0 when empty)
--   Notify.Reserve(px)                             keeps px free under the band (toasts stack below it)
--   Notify.Reward(title, sub?, icon?, color?, sound?, key?) a big reward popup, queued (see below)
-- Toasts stack under the top bar at the top center (newest on top, at most Notify.MaxVisible), below the band, so they
-- never cover each other, the band or the machine panel (which sits on the right). key throttles repeats of a message.
-- While the genetics screen is up they wait.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local UIBus = require(script.Parent.UIBus)

local New, Colors = Theme.New, Theme.Colors

local Notify = {}

Notify.Lifetime = 3
Notify.MaxVisible = 3
Notify.Top = 48           -- mockup px from the top: just under Roblox's top bar (set from Kit.UnderTopbar)
Notify.HintSeconds = 4
Notify.BandHeight = 30

local gui, root, list, band, bandText
local order = 0
local lastShown = {}
local held = nil -- toasts waiting while the genetics screen is up
local hintToken = 0
local tutorialLine = nil

local applyBand -- (below)
local function bandVisible()
	return band ~= nil and band.Visible
end

local reserved = 0 -- mockup px kept free under the band (the tutorial's SKIP TUTORIAL button)
local function placeList()
	if not list then return end
	list.Position = UDim2.new(0.5, 0, 0, Notify.Top + (bandVisible() and (Notify.BandHeight + 4) or 0) + reserved)
end

local function ensure()
	if list then return end
	gui = Theme.ScreenGui({ Name = "Notifications", DisplayOrder = 50, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	root = Kit.Root(gui)
	-- the band: dark, fading out to both sides, the line in big outlined text (mockup 11)
	band = New("Frame", { Name = "Band", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, Notify.Top),
		Size = UDim2.fromOffset(560, Notify.BandHeight), BackgroundColor3 = Colors.Shadow, BackgroundTransparency = 0.45, Visible = false, Parent = root }, {
		New("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0),
			NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	bandText = Kit.Text({ Name = "Text", Text = "", Font = "Title", TextSize = 17, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(20, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = band })
	list = New("Frame", { Name = "List", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(420, 200), BackgroundTransparency = 1, Parent = root }, {
		New("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top }),
	})
	placeList()
	Kit.OnTopbar(function()
		Notify.Top = Kit.UnderTopbar(root)
		band.Position = UDim2.new(0.5, 0, 0, Notify.Top)
		placeList()
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("WindowOpen"):Connect(applyBand)
end

-- (the band steps aside while a menu window is open, Kit.Modal sets the player's WindowOpen attribute, and comes back
-- after it closes if its line is still current)
function applyBand()
	band.Visible = bandText.Text ~= "" and not Players.LocalPlayer:GetAttribute("WindowOpen")
	placeList()
end

local function setBandText(text)
	ensure()
	bandText.Text = text or ""
	applyBand()
end

local function show(title, sub, icon, color)
	ensure()
	local toasts = {}
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") and child.Name == "Toast" then table.insert(toasts, child) end
	end
	table.sort(toasts, function(a, b) return a.LayoutOrder > b.LayoutOrder end)
	for i = Notify.MaxVisible, #toasts do toasts[i]:Destroy() end

	order -= 1 -- (newest on top)
	local tint = color or Colors.Gold
	local toast = Theme.Panel({ Name = "Toast", LayoutOrder = order, Piece = "hud_box", Size = UDim2.fromOffset(0, sub and 42 or 34),
		AutomaticSize = Enum.AutomaticSize.X, Parent = list }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 14) }),
		Theme.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(440, 80), Parent = toast })
	Kit.IconTile(icon or "bell", tint, sub and 30 or 25, { LayoutOrder = 1, Parent = toast })
	local texts = New("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(0, sub and 34 or 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = toast },
		{ Theme.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	if sub then
		Kit.Text({ LayoutOrder = 1, Text = title, Font = "Title", TextSize = 14, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Parent = texts })
		Kit.Text({ LayoutOrder = 2, Text = sub, Font = "Body", TextSize = 11, TextColor3 = Colors.Muted, Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X, Parent = texts })
	else
		Kit.Text({ LayoutOrder = 1, Text = title, Font = "Title", TextSize = 14, Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X,
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = texts })
	end
	local pop = New("UIScale", { Scale = 0.9, Parent = toast })
	Theme.Tween(pop, { Scale = 1 }, 0.2, Enum.EasingStyle.Back)
	Theme.Fade(toast, true, 0.18)
	task.delay(Notify.Lifetime, function()
		if toast.Parent then
			local tween = Theme.Fade(toast, false, 0.35)
			if tween then tween.Completed:Wait() end
			toast:Destroy()
		end
	end)
end

local function queue(title, sub, icon, color, key)
	if key then
		if lastShown[key] and os.clock() - lastShown[key] < 2 then return end
		lastShown[key] = os.clock()
	end
	if held then
		table.insert(held, { title, sub, icon, color })
		return
	end
	show(title, sub, icon, color)
end

function Notify.Show(text, color, key)
	queue(tostring(text), nil, nil, color, key)
end

function Notify.Toast(title, sub, icon, color, key)
	queue(tostring(title), sub, icon, color, key)
end

local function hintsOn()
	local ok, ClientData = pcall(function() return require(ReplicatedStorage.Shared.ClientData) end)
	local data = ok and ClientData.Get and ClientData.Get() or nil
	local settings = data and data.settings
	return not (settings and settings.hints == "Off")
end

local function showBand(text)
	hintToken += 1
	local token = hintToken
	setBandText(text)
	task.delay(Notify.HintSeconds, function()
		if token == hintToken then setBandText(nil) end
	end)
end

-- One hint at a time in the band (a new one replaces the old), hidden after HintSeconds.
function Notify.Hint(text, key)
	if not text or text == "" or not hintsOn() then return end
	if key then
		if lastShown[key] and os.clock() - lastShown[key] < 6 then return end
		lastShown[key] = os.clock()
	end
	showBand(text)
end

-- A tutorial step's line (the tutorial always shows, even with hints off).
function Notify.SetBand(text)
	if text == tutorialLine then return end
	tutorialLine = text
	if text and text ~= "" then showBand(text) else hintToken += 1; setBandText(nil) end
end

-- Keeps `px` (mockup px) free under the band for something else (0 = nothing): toasts stack below it.
function Notify.Reserve(px: number)
	reserved = math.max(0, px or 0)
	placeList()
end

function Notify.BandBottom()
	ensure()
	return bandVisible() and (Notify.Top + Notify.BandHeight) or 0
end

-- Reward popups (prompt 20, 21 Oct: rewards were easy to miss): a bigger card with a gold edge in the upper middle of the
-- screen, over the machine HUD too, for the moments that matter (a new weight, a quest done, LVL up, a new title). One at
-- a time: when several come at once they wait in line, RewardGap seconds apart. sound = a Config/Sounds name (optional).
Notify.RewardGap = 1.5
Notify.RewardSeconds = 2.6
Notify.RewardY = 0.6 -- the card's centre, as a share of the screen height (under the PR banner and hints, above the stamina bar)
local rewardQueue, rewardBusy = {}, false
local rewardHolder = nil

local function showReward(entry)
	ensure()
	if not rewardHolder then
		rewardHolder = New("Frame", { Name = "Rewards", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })
	end
	local tint = entry.color or Colors.Gold
	local card = Theme.Panel({ Name = "Reward", Piece = "hud_box", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, Notify.RewardY),
		Size = UDim2.fromOffset(0, 58), AutomaticSize = Enum.AutomaticSize.X, Parent = rewardHolder }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 18) }),
		Theme.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		New("UIStroke", { Color = tint, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	New("UISizeConstraint", { MaxSize = Vector2.new(520, 80), Parent = card })
	Kit.IconTile(entry.icon or "sparkles", tint, 40, { LayoutOrder = 1, Parent = card })
	local texts = New("Frame", { LayoutOrder = 2, Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = card },
		{ Theme.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	Kit.Text({ LayoutOrder = 1, Text = entry.title, Font = "Title", TextSize = 20, TextColor3 = tint, Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X, Parent = texts })
	if entry.sub and entry.sub ~= "" then
		Kit.Text({ LayoutOrder = 2, Text = entry.sub, Font = "Strong", TextSize = 13, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Parent = texts })
	end
	local pop = New("UIScale", { Scale = 0.6, Parent = card })
	Theme.Tween(pop, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)
	Theme.Fade(card, true, 0.15)
	if entry.sound then
		local ok, Audio = pcall(function() return require(script.Parent.Parent.Audio) end)
		if ok then pcall(Audio.Play2D, entry.sound) end
	end
	return card
end

local function runRewards()
	if rewardBusy then return end
	rewardBusy = true
	task.spawn(function()
		while #rewardQueue > 0 do
			if held then task.wait(0.3) continue end -- (the genetics screen is up)
			local card = showReward(table.remove(rewardQueue, 1))
			local started = os.clock()
			-- stay up RewardSeconds, or only RewardGap when the next one is waiting
			while os.clock() - started < Notify.RewardSeconds and not (#rewardQueue > 0 and os.clock() - started >= Notify.RewardGap) do
				task.wait(0.1)
			end
			local tween = Theme.Fade(card, false, 0.2)
			task.delay(0.25, function() card:Destroy() end)
			if tween and #rewardQueue == 0 then tween.Completed:Wait() end
		end
		rewardBusy = false
	end)
end

-- key (optional): a newer reward with the same key replaces one still waiting in line (LVL 4, LVL 5, LVL 6 in a row
-- show once, as the latest), so fast early levels and weights don't pile up.
function Notify.Reward(title: string, sub: string?, icon: string?, color: Color3?, sound: string?, key: string?)
	local entry = { title = tostring(title), sub = sub, icon = icon, color = color, sound = sound, key = key }
	if key then
		for i, waiting in ipairs(rewardQueue) do
			if waiting.key == key then
				rewardQueue[i] = entry
				return
			end
		end
	end
	table.insert(rewardQueue, entry)
	runRewards()
end

UIBus.GeneticsVisible.Event:Connect(function(visible)
	if gui then gui.Enabled = not visible end
	if visible then
		held = held or {}
		return
	end
	local waiting = held or {}
	held = nil
	for index, toast in ipairs(waiting) do
		task.delay(0.4 + (index - 1) * 0.3, show, toast[1], toast[2], toast[3], toast[4])
	end
end)

return Notify
