-- SettingsClient: the Settings window (owner's UI v2, mockup 10_settings), opened by the gear in the top bar (and from the
-- main menu), and the background music.
-- Two columns of rows: a gold icon, the setting's name and an ON (green) / OFF (gray) button. Every change saves at once
-- (SetSettings). Rows:
--   Music, Sound Effects        On = full volume, Off = silent (Audio.SetVolumes)
--   Others' Sounds              Off = sounds on other players and their machines stay quiet here (Audio.OthersMuted);
--                               (the mockup's "Other Screams": the game has no screams)
--   Low Graphics                On = no shadows and no bloom / depth of field / sun rays on this device
--   Tutorial Hints              the hints and coach lines in the top band (Notify.Hint; the tutorial itself always shows)
--   Gain Numbers                On / Minimal / Off (tap cycles; MachineClient reads it every rep)
--   Rep Flash, EXP Popups, Spot Requests   On / Off
-- (The mockup's "Other Auras" row is left out: the game has no auras yet, so it would switch nothing.)
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Icons = require(Shared.UI.Icons)
local TopBar = require(Shared.UI.TopBar)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

local ROW_H, COLUMNS = 38, 2

local menuButton = TopBar.AddPill("Settings", "Settings", Icons.Gear, 3)

local modal = Kit.Modal({ name = "Settings", title = "Settings", icon = "settings", width = 510, height = 262, displayOrder = 24,
	tabs = { { id = "Settings", text = "Settings", icon = "settings" } } })
local grid = New("Frame", { Name = "Grid", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = modal.body }, {
	New("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, ROW_H), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local values = { music = 1, effects = 1, gainNumbers = "On", repFlash = "On", expPopups = "On", spotRequests = "On",
	hints = "On", otherScreams = "On", lowGraphics = "Off" }

local function save(changes)
	Remotes.PlayerAction:FireServer("SetSettings", changes)
end

-- Low Graphics: shadows and the heavy post effects off on this device (restored when turned off)
local saved = {}
local function applyLowGraphics(on: boolean)
	if on then
		saved.shadows = saved.shadows == nil and Lighting.GlobalShadows or saved.shadows
		Lighting.GlobalShadows = false
	elseif saved.shadows ~= nil then
		Lighting.GlobalShadows = saved.shadows
	end
	for _, effect in ipairs(Lighting:GetChildren()) do
		if effect:IsA("BloomEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") then
			if on then
				if effect:GetAttribute("LowGraphicsWas") == nil then effect:SetAttribute("LowGraphicsWas", effect.Enabled) end
				effect.Enabled = false
			elseif effect:GetAttribute("LowGraphicsWas") ~= nil then
				effect.Enabled = effect:GetAttribute("LowGraphicsWas")
				effect:SetAttribute("LowGraphicsWas", nil)
			end
		end
	end
end

-- A row: a card with a gold icon, the name, and a choice button on the right.
local rows = {}
local function row(order, key, labelText, icon, modes)
	local card = Kit.Card({ Name = key, LayoutOrder = order, Parent = grid }, {})
	Pieces.Icon(icon, Colors.Gold, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(20, 20), Parent = card })
		:SetAttribute("KeepColor", true)
	Kit.Text({ Name = "Label", Text = labelText, Font = "Title", TextSize = 15, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 38, 0.5, 0),
		Size = UDim2.new(1, -112, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
	local button = Kit.Button("Green", "On", { Name = "Choice", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Parent = card },
		{ width = 64, height = 28, textSize = 14 })
	local function show()
		local value = values[key]
		local on = value ~= "Off" and value ~= 0
		local text = if type(value) == "number" then (on and "On" or "Off") else value
		Kit.SetButton(button, if text == "Minimal" then "Gold" elseif on then "Green" else "Gray", text)
	end
	button.Activated:Connect(function()
		local value = values[key]
		local nextValue
		if type(value) == "number" then
			nextValue = value > 0 and 0 or 1
		else
			local index = table.find(modes, value) or 1
			nextValue = modes[index % #modes + 1]
		end
		values[key] = nextValue
		show()
		if key == "music" or key == "effects" then
			Audio.SetVolumes(values.music, values.effects)
		elseif key == "otherScreams" then
			Audio.OthersMuted = nextValue == "Off"
		elseif key == "lowGraphics" then
			applyLowGraphics(nextValue == "On")
		end
		save({ [key] = nextValue })
	end)
	rows[key] = show
end
local ONOFF = { "On", "Off" }
row(1, "music", "Music", "music", ONOFF)
row(2, "effects", "Sound Effects", "volume-2", ONOFF)
row(3, "otherScreams", "Others' Sounds", "users", ONOFF)
row(4, "lowGraphics", "Low Graphics", "eye", { "Off", "On" })
row(5, "hints", "Tutorial Hints", "bell", ONOFF)
row(6, "gainNumbers", "Gain Numbers", "zap", { "On", "Minimal", "Off" })
row(7, "repFlash", "Rep Flash", "heart-pulse", ONOFF)
row(8, "expPopups", "EXP Popups", "sparkles", ONOFF)
row(9, "spotRequests", "Spot Requests", "hand", ONOFF)

local function refreshAll()
	for _, show in pairs(rows) do show() end
end

local function open()
	refreshAll()
	menuButton:SetActive(true)
	UIBus.MenuPanelVisible:Fire(true)
	modal.open()
	Audio.PlayUI("Whoosh")
end
local function close()
	if not modal.isOpen() then return end
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
	modal.close()
end
UIBus.RegisterPanel("Settings", close)
menuButton.Activated:Connect(function()
	if modal.isOpen() then close() else UIBus.PanelOpened("Settings") open() end
end)
modal.closeButton.Activated:Connect(function()
	menuButton:SetActive(false)
	UIBus.MenuPanelVisible:Fire(false)
end)
UIBus.OpenSettings.Event:Connect(function()
	if not modal.isOpen() then UIBus.PanelOpened("Settings") open() end
end)

-- saved settings, then music
task.spawn(function()
	local settings = ClientData.Get().settings or {}
	values.music = settings.music or 1
	values.effects = settings.effects or 1
	values.gainNumbers = settings.gainNumbers or "On"
	values.repFlash = if settings.repFlash == "Off" then "Off" else "On"
	values.expPopups = if settings.expPopups == "Off" then "Off" else "On"
	values.spotRequests = if settings.spotRequests == "Off" then "Off" else "On"
	values.hints = if settings.hints == "Off" then "Off" else "On"
	values.otherScreams = if settings.otherScreams == "Off" then "Off" else "On"
	values.lowGraphics = if settings.lowGraphics == "On" then "On" else "Off"
	refreshAll()
	Audio.SetVolumes(values.music, values.effects)
	Audio.OthersMuted = values.otherScreams == "Off"
	if values.lowGraphics == "On" then applyLowGraphics(true) end
	Audio.StartMusic()
	-- area music: the pro gym is the room east of the starter gym (x 44.5..114, z -90..-4; the starter gym with its hall is
	-- x -45..44.5 up to z 13.5, see the Gyms builder), the beach is north of Beach Road (z > 162), the town everywhere else
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local p = root.Position
			local area = "Town"
			if p.Y > 60 then
				area = "Starter" -- (the genetics stage high above the town)
			elseif p.X > 44.5 and p.X < 114 and p.Z > -90 and p.Z < -4 then
				area = "Pro"
			elseif p.X > -45 and p.X < 44.5 and p.Z > -90 and p.Z < 13.5 then
				area = "Starter"
			elseif p.Z > 162 then
				area = "Beach"
			end
			Audio.SetArea(area)
		end
		task.wait(2)
	end
end)
