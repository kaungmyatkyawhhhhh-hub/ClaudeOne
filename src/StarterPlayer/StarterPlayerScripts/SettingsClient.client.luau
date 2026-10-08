-- SettingsClient: the Settings side button and panel (Music and Effects volume, Gain numbers On/Minimal/Off) and
-- background music. Volumes apply instantly while dragging and are saved with the player's data when the slider is
-- released; the choice saves on tap (MachineClient reads Gain numbers for every rep).
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Icons = require(Shared.UI.Icons)
local TopBar = require(Shared.UI.TopBar)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors, Spacing = Theme.New, Theme.Colors, Theme.Spacing
local Vertical, Horizontal = Enum.FillDirection.Vertical, Enum.FillDirection.Horizontal

local PANEL_WIDTH = 300
local KNOB = 18

local menuButton = TopBar.AddPill("Settings", "Settings", Icons.Gear, 3) -- a pill at the top right (UI v7)

local gui = Theme.ScreenGui({ Name = "Settings", Enabled = false, DisplayOrder = 24, Parent = player:WaitForChild("PlayerGui") })
-- right side, vertically centered, under the Settings pill
local panel = Theme.Panel({
	Name = "Panel",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -TopBar.Edge(), 0.5, 0),
	Size = UDim2.fromOffset(PANEL_WIDTH, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Active = true, -- taps on the panel never count as lifts
	Parent = gui,
}, { Theme.Pad("L"), Theme.List(Vertical, "M", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
Theme.Text({ LayoutOrder = 1, Text = "Settings", Font = "SemiBold", TextSize = "Large", Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })

local values = { music = 1, effects = 1, gainNumbers = "On", repFlash = "On", expPopups = "On" }
local dragging = nil -- the slider being dragged

local function save()
	Remotes.PlayerAction:FireServer("SetSettings", {
		music = values.music,
		effects = values.effects,
		gainNumbers = values.gainNumbers,
		repFlash = values.repFlash,
		expPopups = values.expPopups,
	})
end

-- A labeled slider: name and percent on top, a thin track with a white fill and a round knob.
local sliders = {}
-- Music and Effects side by side, so the whole panel fits a phone screen
local volumes = New("Frame", { Name = "Volumes", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = panel },
	{ Theme.List(Horizontal, "L", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
local function slider(order, key, labelText)
	local row = New("Frame", { LayoutOrder = order, Size = UDim2.new(0.5, -Spacing.L / 2, 0, 52), BackgroundTransparency = 1, Parent = volumes },
		{ Theme.List(Vertical, "S", Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local top = New("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = row })
	Theme.Text({ Text = labelText, Font = "Regular", TextSize = "Body", Size = UDim2.fromScale(0.6, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
	local percent = Theme.Text({ Font = "Regular", TextSize = "Small", TextColor3 = Colors.Muted, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.4, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = top })
	-- tall invisible hit area so the thin track is easy to grab on phones
	local hit = New("TextButton", { Name = key, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = row })
	local track = New("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Colors.Text, BackgroundTransparency = 0.82, Parent = hit }, { Theme.Round("Round") })
	local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Colors.Text, Parent = track }, { Theme.Round("Round") })
	local knob = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(KNOB, KNOB), BackgroundColor3 = Colors.Text, ZIndex = 2, Parent = track }, { Theme.Round("Round") })
	Theme.AddDepth(knob, "Round")

	local entry = { key = key, track = track }
	function entry.show(value)
		fill.Size = UDim2.fromScale(value, 1)
		knob.Position = UDim2.fromScale(value, 0.5)
		percent.Text = math.floor(value * 100 + 0.5) .. "%"
	end
	function entry.setFromX(x)
		local value = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		values[key] = math.floor(value * 20 + 0.5) / 20 -- 5% steps
		entry.show(values[key])
		Audio.SetVolumes(values.music, values.effects)
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = entry
			entry.setFromX(input.Position.X)
		end
	end)
	sliders[key] = entry
	return entry
end
slider(1, "music", "Music")
slider(2, "effects", "Effects")

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		dragging.setFromX(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragging = nil
		Audio.PlayUI("Click") -- a soft click at the new effects volume
		save()
	end
end)

-- A row of choices (the chosen one lit): Gain numbers On / Minimal / Off. `inline` puts the title and the choices on one
-- line (the short On / Off rows), so the whole panel still fits a phone screen.
local choiceRows = {}
local function choiceRow(order, key, title, modes, labels, inline)
	local row = New("Frame", { Name = key, LayoutOrder = order, Size = UDim2.new(1, 0, 0, if inline then Theme.MinTouch else 20 + Spacing.S + Theme.MinTouch), BackgroundTransparency = 1, Parent = panel },
		{ Theme.List(if inline then Horizontal else Vertical, "S", Enum.HorizontalAlignment.Left, if inline then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top) })
	Theme.Text({ LayoutOrder = 1, Text = title, Font = "Regular", TextSize = "Body", Size = if inline then UDim2.new(0.4, -Spacing.S, 0, 20) else UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local choices = New("Frame", { Name = "Choices", LayoutOrder = 2, Size = if inline then UDim2.new(0.6, 0, 0, Theme.MinTouch) else UDim2.new(1, 0, 0, Theme.MinTouch), BackgroundTransparency = 1, Parent = row },
		{ Theme.List(Horizontal, "S", Enum.HorizontalAlignment.Left) })
	local buttons = {}
	local function show()
		for mode, entry in pairs(buttons) do
			local chosen = values[key] == mode
			entry.button.BackgroundColor3 = chosen and Colors.Text or Colors.Panel
			entry.button.BackgroundTransparency = chosen and Theme.Alpha.Primary or Theme.Alpha.Panel
			entry.stroke.Transparency = chosen and 0.6 or Theme.Alpha.ButtonBorder
			entry.label.TextColor3 = chosen and Colors.Text or Colors.Muted
		end
	end
	for index, mode in ipairs(modes) do
		local label = Theme.Text({ Text = labels and labels[index] or mode, Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) })
		local button = Theme.Button("Secondary", { Name = key .. mode, LayoutOrder = index, Size = UDim2.fromScale(0, 1) }, {
			label,
			New("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		})
		button.Parent = choices
		buttons[mode] = { button = button, label = label, stroke = button:FindFirstChildOfClass("UIStroke") }
		button.Activated:Connect(function()
			if values[key] == mode then return end
			values[key] = mode
			show()
			Audio.PlayUI("Click")
			save()
		end)
	end
	choiceRows[key] = show
end
-- Gain numbers: On (rep + set popups) / Minimal (set popups only) / Off
choiceRow(4, "gainNumbers", "Gain numbers", { "On", "Minimal", "Off" })
-- Rep flash: the trained muscles glow warm for a moment on each rep
choiceRow(5, "repFlash", "Rep flash", { "On", "Off" }, nil, true)
-- Show EXP popups: every rep, a small "+EXP" per trained muscle around you (MachineClient)
choiceRow(6, "expPopups", "Show EXP popups", { "On", "Off" }, nil, true)

local closeButton = Theme.Button("Secondary", { Name = "Close", LayoutOrder = 7, Size = UDim2.new(1, 0, 0, Theme.MinTouch), Parent = panel }, {
	Theme.Text({ Text = "Close", Font = "SemiBold", TextSize = "Body", Size = UDim2.fromScale(1, 1) }),
})

local isOpen = false
local function open()
	isOpen = true
	menuButton:SetActive(true)
	UIBus.MenuPanelVisible:Fire(true)
	for key, entry in pairs(sliders) do entry.show(values[key]) end
	gui.Enabled = true
	Audio.PlayUI("Whoosh")
	panel.Position = UDim2.new(1, -TopBar.Edge() + Spacing.L, 0.5, 0)
	Theme.Tween(panel, { Position = UDim2.new(1, -TopBar.Edge(), 0.5, 0) })
	Theme.Fade(panel, true)
end
local function close()
	if not isOpen then return end
	isOpen = false
	dragging = nil
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
	local tween = Theme.Fade(panel, false)
	if tween then
		tween.Completed:Connect(function()
			if not isOpen then gui.Enabled = false end
		end)
	end
end
UIBus.RegisterPanel("Settings", close)
menuButton.Activated:Connect(function()
	if isOpen then close() else UIBus.PanelOpened("Settings") open() end
end)
closeButton.Activated:Connect(close)
UIBus.OpenSettings.Event:Connect(function()
	if not isOpen then UIBus.PanelOpened("Settings") open() end
end)

-- saved volumes, then music
task.spawn(function()
	local settings = ClientData.Get().settings or {}
	values.music = settings.music or 1
	values.effects = settings.effects or 1
	values.gainNumbers = settings.gainNumbers or "On"
	values.repFlash = if settings.repFlash == "Off" then "Off" else "On"
	values.expPopups = if settings.expPopups == "Off" then "Off" else "On"
	for _, show in pairs(choiceRows) do show() end
	Audio.SetVolumes(values.music, values.effects)
	Audio.StartMusic()
	-- area music: the pro gym is the room east of the starter gym (x 37..93, z -73.5..-4, see the Gyms builder)
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local p = root.Position
			local inPro = p.X > 37 and p.X < 93 and p.Z > -73.5 and p.Z < -4 and p.Y < 20
			Audio.SetArea(inPro and "Pro" or "Starter")
		end
		task.wait(2)
	end
end)
