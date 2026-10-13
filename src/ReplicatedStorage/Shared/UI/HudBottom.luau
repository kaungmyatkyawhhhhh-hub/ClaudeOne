-- HudBottom (owner's final kit "BLACK + GOLD", mockups 01 / 02; owner's declutter, 14 Oct): the slim STAMINA bar at the
-- very bottom center, 10 px above the edge, at most 280 wide (a small dark panel: a teal lightning icon, "STAMINA",
-- "82 / 100" on the right, a thin teal bar under it; soft red when nearly empty), and the row of active boost icons above
-- it (a colored icon tile with its timer or value under it).
--   HudBottom.Chip(icon, color, order)   -> chip api { frame, SetText(main, sub?), SetVisible(on) } (sub = the timer)
--   HudBottom.SetTraining(on)            the bar reads "Stamina 60/100" and the row moves above STOP TRAINING
--   HudBottom.SetHidden(reason, on)      hide it while a screen needs the bottom (posing, arm wrestling)
--   HudBottom.BarTop()                   root-relative y (mockup px from the bottom) of the bar's top edge
-- Hidden on the main menu, the genetics screen and full-width screens. Stamina: ClientData.stamina against the player's
-- MaxStamina attribute (Iron Lungs, treadmill training) or Config/Stamina.Max.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local UIBus = require(script.Parent.UIBus)

local New, Colors = Theme.New, Theme.Colors

local HudBottom = {}

HudBottom.BarSize = Vector2.new(280, 34) -- the stamina panel
HudBottom.Bottom = 10         -- bar's gap to the screen bottom (mockup px)
HudBottom.ChipSize = 28
HudBottom.TrainingRowLift = 0 -- (owner's final kit: STOP sits bottom-left now, nothing above the stamina panel)
HudBottom.LowStamina = 0.15

local gui, root, row, setBar, barTrack, fill, staminaNow, staminaMaxText
local training = false
local hidden = {}

local function staminaMax()
	local max = Players.LocalPlayer:GetAttribute("MaxStamina")
	if type(max) == "number" and max > 0 then return max end
	local ok, Stamina = pcall(function() return require(ReplicatedStorage.Shared.Config.Stamina) end)
	return ok and Stamina.Max or 100
end

local function refresh()
	if not setBar then return end
	local ok, ClientData = pcall(function() return require(ReplicatedStorage.Shared.ClientData) end)
	local data = ok and ClientData.Get() or nil
	local stamina = data and data.stamina or 0
	local max = staminaMax()
	local ratio = math.clamp(stamina / max, 0, 1)
	setBar(ratio)
	staminaNow.Text = tostring(math.floor(stamina + 0.5))
	staminaMaxText.Text = "/ " .. math.floor(max + 0.5)
	local gloss = fill:FindFirstChild("Gloss")
	local color = ratio < HudBottom.LowStamina and Colors.NeedsWork or Colors.Teal
	if gloss then gloss.Color = Kit.Metal(color) end
end

local function placeRow()
	if not row then return end
	local lift = training and HudBottom.TrainingRowLift or 0
	row.Position = UDim2.new(0.5, 0, 1, -(HudBottom.Bottom + HudBottom.BarSize.Y + 8 + lift))
end

local function refreshVisible()
	if not gui then return end
	local anyHidden = next(hidden) ~= nil
	gui.Enabled = not anyHidden and not UIBus.MenuOpen and not UIBus.CoverOpen(gui.Parent)
end

local function ensure()
	if gui then return end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Theme.ScreenGui({ Name = "HudBottom", DisplayOrder = 4, Parent = playerGui })
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	root = Kit.Root(gui)
	-- the panel: header (icon, STAMINA, "82 / 100") over the teal bar
	barTrack = Theme.Panel({ Name = "Stamina", Piece = "hud_box", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -HudBottom.Bottom),
		Size = UDim2.fromOffset(HudBottom.BarSize.X, HudBottom.BarSize.Y), Parent = root })
	local zap = require(script.Parent.Pieces).Icon("zap", Colors.Teal, { Name = "Zap", Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(12, 12), Parent = barTrack })
	zap:SetAttribute("KeepColor", true)
	Kit.Text({ Name = "Title", Text = "STAMINA", Font = "Title", TextSize = 11, Position = UDim2.fromOffset(26, 2), Size = UDim2.fromOffset(100, 16),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = barTrack })
	local numbers = New("Frame", { Name = "Numbers", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 2),
		Size = UDim2.fromOffset(110, 16), Parent = barTrack }, { Theme.List(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	staminaNow = Kit.Text({ Name = "Now", LayoutOrder = 1, Text = "0", Font = "Number", TextSize = 12, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, Parent = numbers })
	staminaMaxText = Kit.Text({ Name = "Max", LayoutOrder = 2, Text = "/ 100", Font = "Number", TextSize = 12, TextColor3 = Colors.Muted, Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X, Parent = numbers })
	local _
	_, setBar, fill = Kit.Bar(Colors.Teal, { Name = "Bar", Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 8), Parent = barTrack }, { outline = 1 })
	row = New("Frame", { Name = "Boosts", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, HudBottom.ChipSize + 16),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = root }, {
		Theme.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
	})
	placeRow()
	task.spawn(function()
		local ClientData = require(ReplicatedStorage.Shared.ClientData)
		ClientData.Get()
		refresh()
		ClientData.Changed:Connect(function(path)
			if path[1] == "stamina" then refresh() end
		end)
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("MaxStamina"):Connect(refresh)
	UIBus.MenuClosed.Event:Connect(refreshVisible)
	UIBus.GeneticsVisible.Event:Connect(function(open) HudBottom.SetHidden("genetics", open) end)
	task.spawn(function()
		while true do
			task.wait(0.4)
			refreshVisible()
		end
	end)
	refreshVisible()
end

-- A boost icon: a 28px colored tile with a white icon, the timer (or the value) under it.
function HudBottom.Chip(icon: string, color: Color3, order: number?)
	ensure()
	local chip = New("Frame", { Name = "Boost_" .. icon, LayoutOrder = order or 1, Size = UDim2.fromOffset(40, HudBottom.ChipSize + 16),
		BackgroundTransparency = 1, Visible = false, Parent = row })
	Kit.IconTile(icon, color, HudBottom.ChipSize, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Parent = chip })
	local label = Kit.Text({ Name = "Value", Text = "", Font = "Number", TextSize = 12, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(2, 0, 0, 16), Parent = chip })
	local api = { frame = chip }
	function api.SetText(_, main, sub)
		-- the timer when there is one ("4:12"), else the value ("+5%")
		label.Text = (sub and sub ~= "") and sub or (main or "")
	end
	function api.SetVisible(_, on) chip.Visible = on end
	return api
end

function HudBottom.SetTraining(on: boolean)
	ensure()
	training = on
	placeRow()
	refresh()
end

function HudBottom.SetHidden(reason: string, on: boolean)
	ensure()
	hidden[reason] = on or nil
	refreshVisible()
end

-- mockup px from the screen bottom to the top of the stamina bar
function HudBottom.BarTop(): number
	return HudBottom.Bottom + HudBottom.BarSize.Y
end

function HudBottom.Refresh()
	ensure()
	refresh()
end

ensure()
return HudBottom
