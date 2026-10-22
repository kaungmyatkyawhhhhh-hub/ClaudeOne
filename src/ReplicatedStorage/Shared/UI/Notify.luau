-- Toasts and hints (owner's UI v2, 13 Oct; prompt 53, 23 Oct: one toast lane):
--   Notify.Show(text, color?, key?)               a toast with one line
--   Notify.Toast(title, sub?, icon?, color?, key?) a toast with a second line and an icon (Config/UI.Icons)
--   Notify.Reward(title, sub?, icon?, color?, sound?, key?) the same toast for the moments that matter (a new weight, a
--                                                  quest done, LVL up, a new title), with a sound (a Config/Sounds name)
--   Notify.Hint(text, key?)                        a HINT in the top band: only one at a time (a new one replaces the old),
--                                                  hidden after Notify.HintSeconds. Off when the player turned "Tutorial
--                                                  Hints" off in Settings (settings.hints == "Off").
--   Notify.SetBand(text?)                          the tutorial step's line in the band (TutorialClient): shown like a
--                                                  hint (also gone after HintSeconds; the coach dialog keeps the words)
--   Notify.BandBottom()                            mockup px from the top to the bottom of the band (0 when empty)
--   Notify.Reserve(px)                             keeps px free under the band (toasts sit below it)
-- (prompt 53) ONE toast lane at the top centre, just under the top bar (under the band when it shows), never in the middle
-- of the screen: toasts and rewards wait in one line and show one at a time (Notify.Seconds each, shorter when more are
-- waiting), sliding down in and fading out. The card (every toast in the game): dark graphite with the hex mesh, a thin
-- gold outline, a dark bottom edge, the icon on its own (no box) in the toast's color, the title in white chunky with a
-- dark stroke, the second line small and light grey. key throttles repeats (a reward with the same key still waiting is
-- replaced by the newer one: LVL 4, 5, 6 in a row show once). While the genetics screen is up they wait.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Pieces = require(script.Parent.Pieces)
local UIBus = require(script.Parent.UIBus)

local New, Colors = Theme.New, Theme.Colors

local Notify = {}

Notify.Seconds = 2.5       -- each toast's time on screen
Notify.QuickSeconds = 1.4  -- ... when more are waiting
Notify.MaxWaiting = 6      -- older plain toasts drop off a longer line
Notify.Top = 48            -- mockup px from the top: just under Roblox's top bar (set from Kit.UnderTopbar)
Notify.HintSeconds = 4
Notify.BandHeight = 30
Notify.BandMaxWidth = 320  -- (prompt 53: the band stays in the top centre, clear of SKIP on the right)
Notify.CardMaxWidth = 420
local LIP = 4               -- the card's dark bottom edge (px)
local SUB = Color3.fromHex("#C9C2C4")

local gui, root, lane, band, bandText
local lastShown = {}
local held = false -- the genetics screen is up: toasts wait
local hintToken = 0
local tutorialLine = nil

local applyBand -- (below)
local function bandVisible()
	return band ~= nil and band.Visible
end

local reserved = 0 -- mockup px kept free under the band
local function placeLane()
	if not lane then return end
	lane.Position = UDim2.new(0.5, 0, 0, Notify.Top + (if bandVisible() then band.Size.Y.Offset + 6 else 0) + reserved)
end

local function ensure()
	if lane then return end
	gui = Theme.ScreenGui({ Name = "Notifications", DisplayOrder = 50, Parent = Players.LocalPlayer:WaitForChild("PlayerGui") })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	root = Kit.Root(gui)
	-- the band (prompt 53a): a dark pill as wide as its line (up to BandMaxWidth, then two lines), white chunky text
	band = Theme.Panel({ Name = "Band", Piece = "pill", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, Notify.Top),
		Size = UDim2.fromOffset(120, Notify.BandHeight), Visible = false, Parent = root }, {})
	band.BackgroundTransparency = 0.12
	bandText = Kit.Text({ Name = "Text", Text = "", Font = "Chunky", TextSize = 14, TextWrapped = true, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -28, 1, -6), Parent = band })
	lane = New("Frame", { Name = "Lane", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(Notify.CardMaxWidth, 60), BackgroundTransparency = 1,
		Parent = root })
	placeLane()
	Kit.OnTopbar(function()
		Notify.Top = Kit.UnderTopbar(root)
		band.Position = UDim2.new(0.5, 0, 0, Notify.Top)
		placeLane()
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("WindowOpen"):Connect(applyBand)
end

-- (the band steps aside while a menu window is open, Kit.Modal sets the player's WindowOpen attribute, and comes back
-- after it closes if its line is still current)
function applyBand()
	band.Visible = bandText.Text ~= "" and not Players.LocalPlayer:GetAttribute("WindowOpen")
	placeLane()
end

-- the band's size from its line: one line up to BandMaxWidth, else two lines at that width
local function sizeBand(text: string)
	local params = Instance.new("GetTextBoundsParams")
	params.Text, params.Font, params.Size = text, bandText.FontFace, bandText.TextSize
	params.Width = Notify.BandMaxWidth - 28
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	if not ok then bounds = Vector2.new(Notify.BandMaxWidth - 28, bandText.TextSize) end
	local twoLines = bounds.Y > bandText.TextSize * 1.6
	band.Size = UDim2.fromOffset(math.min(bounds.X + 30, Notify.BandMaxWidth), if twoLines then Notify.BandHeight + 16 else Notify.BandHeight)
end

local function setBandText(text)
	ensure()
	bandText.Text = text or ""
	if text and text ~= "" then task.spawn(function()
		sizeBand(text)
		placeLane()
	end) end
	applyBand()
end

------------------------------------------------------------------------
-- The card
------------------------------------------------------------------------
-- a one-line toast too long for the card wraps onto two lines (smaller), never cut off
local TITLE_ROOM = Notify.CardMaxWidth - 70 -- the card minus its padding and icon
local function needsTwoLines(text: string): boolean
	local params = Instance.new("GetTextBoundsParams")
	params.Text, params.Font, params.Size, params.Width = string.upper(text), Theme.Fonts.Chunky, 15, 1e5
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	return ok and bounds.X > TITLE_ROOM
end

local function card(entry)
	local tint = entry.color or Colors.Gold
	local wrap = not entry.sub and needsTwoLines(entry.title)
	local height = if entry.sub then 46 elseif wrap then 50 else 36
	local holder = New("Frame", { Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -12), Size = UDim2.fromOffset(0, height + LIP),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = lane })
	New("Frame", { Name = "Lip", Position = UDim2.fromOffset(0, LIP), Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Color3.fromHex("#0B090C"), Parent = holder }, {
		New("UICorner", { CornerRadius = UDim.new(0, 12) }),
		New("UIStroke", { Color = Colors.Outline, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local face = Theme.Panel({ Name = "Face", Size = UDim2.fromOffset(0, height), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 2, Parent = holder }, {
		New("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 16) }),
		Theme.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		New("UISizeConstraint", { MaxSize = Vector2.new(Notify.CardMaxWidth, height) }),
	})
	face.BackgroundTransparency = 0.04
	local border = face:FindFirstChild("Border") :: UIStroke
	if border then border.Color, border.Thickness, border.Transparency = Colors.Gold, 1.5, 0 end
	Theme.SetHex(face, Theme.HexAlpha, 12)
	local icon = Pieces.Icon(entry.icon or "bell", tint, { Name = "Icon", LayoutOrder = 1, Size = UDim2.fromOffset(if entry.sub then 28 else 22, if entry.sub then 28 else 22),
		Parent = face })
	icon:SetAttribute("KeepColor", true)
	local texts = New("Frame", { Name = "Texts", LayoutOrder = 2, Size = UDim2.fromOffset(0, height - 8), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Parent = face }, { Theme.List(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	if wrap then
		Kit.Text({ Name = "Title", LayoutOrder = 1, Text = entry.title, Font = "Chunky", Upper = true, TextSize = 14, TextWrapped = true,
			Size = UDim2.fromOffset(TITLE_ROOM, 38), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = texts })
	else
		Kit.Text({ Name = "Title", LayoutOrder = 1, Text = entry.title, Font = "Chunky", Upper = true, TextSize = if entry.sub then 16 else 15, Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.AtEnd, Parent = texts })
	end
	if entry.sub and entry.sub ~= "" then
		Kit.Text({ Name = "Sub", LayoutOrder = 2, Text = entry.sub, Font = "Strong", TextSize = 11, TextColor3 = SUB, Size = UDim2.fromOffset(0, 15),
			AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.AtEnd, Parent = texts })
	end
	-- the lip follows the face's width (AutomaticSize sizes the holder from the face)
	return holder
end

------------------------------------------------------------------------
-- The lane: one at a time
------------------------------------------------------------------------
local waiting = {}
local running = false

local function run()
	if running then return end
	running = true
	task.spawn(function()
		while #waiting > 0 do
			if held then task.wait(0.3) continue end
			local entry = table.remove(waiting, 1)
			ensure()
			local holder = card(entry)
			if entry.sound then
				local ok, Audio = pcall(function() return require(script.Parent.Parent.Audio) end)
				if ok then pcall(Audio.Play2D, entry.sound) end
			end
			-- slide down into place while fading in
			Theme.Fade(holder, true, 0.18)
			Theme.Tween(holder, { Position = UDim2.new(0.5, 0, 0, 0) }, 0.22, Enum.EasingStyle.Back)
			local started = os.clock()
			while os.clock() - started < (if #waiting > 0 then Notify.QuickSeconds else Notify.Seconds) do
				task.wait(0.1)
			end
			-- slide on down a little and fade out
			Theme.Tween(holder, { Position = UDim2.new(0.5, 0, 0, 8) }, 0.25)
			local tween = Theme.Fade(holder, false, 0.25)
			if tween then tween.Completed:Wait() end
			holder:Destroy()
		end
		running = false
	end)
end

local function push(entry)
	if entry.key then
		-- a newer reward with the same key replaces one still waiting (LVL 4, 5, 6 in a row show once, as the latest)
		for i, other in ipairs(waiting) do
			if other.key == entry.key then
				waiting[i] = entry
				return
			end
		end
		if not entry.reward then
			if lastShown[entry.key] and os.clock() - lastShown[entry.key] < 2 then return end
			lastShown[entry.key] = os.clock()
		end
	end
	table.insert(waiting, entry)
	-- a long line: the oldest plain toasts drop off (rewards always show)
	while #waiting > Notify.MaxWaiting do
		local dropped = false
		for i, other in ipairs(waiting) do
			if not other.reward then table.remove(waiting, i) dropped = true break end
		end
		if not dropped then break end
	end
	run()
end

function Notify.Show(text, color, key)
	push({ title = tostring(text), color = color, key = key })
end

function Notify.Toast(title, sub, icon, color, key)
	push({ title = tostring(title), sub = sub, icon = icon, color = color, key = key })
end

function Notify.Reward(title: string, sub: string?, icon: string?, color: Color3?, sound: string?, key: string?)
	push({ title = tostring(title), sub = sub, icon = icon or "sparkles", color = color, sound = sound, key = key, reward = true })
end

------------------------------------------------------------------------
-- Hints and the tutorial band
------------------------------------------------------------------------
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

-- Keeps `px` (mockup px) free under the band for something else (0 = nothing): toasts sit below it.
function Notify.Reserve(px: number)
	reserved = math.max(0, px or 0)
	placeLane()
end

function Notify.BandBottom()
	ensure()
	return if bandVisible() then Notify.Top + band.Size.Y.Offset else 0
end

UIBus.GeneticsVisible.Event:Connect(function(visible)
	if gui then gui.Enabled = not visible end
	held = visible == true
end)

return Notify
