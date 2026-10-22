-- TopBar (client): our icons on Roblox's own top bar, made with TopbarPlus (owner, 14 Oct: TopbarPlus v3.4.0 by
-- ForeverHD, ReplicatedStorage.Packages.Icon, the official Creator Store model 92368439343389, unedited so it can be
-- updated). TopbarPlus draws them like Roblox's buttons (same height, line and theme) and moves icons that don't fit
-- into its overflow menu.
--   left (TopBarClient): coins | height ("7'0"" + "MAX" when capped) | level ("LVL 60", caption: progress to the next)
--   right (TopBar.AddPill): Daily | Quests | Settings
-- Hidden on the main menu, the genetics screen and full-width screens (Icon.setTopbarEnabled; Roblox's own buttons
-- stay). Anything under the top bar starts at GuiService.TopbarInset.Max.Y + 8 (Kit.UnderTopbar).
-- TopBar.AddPill(id, text, iconFactory, order): (prompt 46, owner 22 Oct: the HUD mockup 05 again) "Daily" (calendar +
-- DAILY, a red "!" chip for a reward) and "Settings" (the gear) are right-hand icons; any other id ("Quests") gets an
-- inert stand-in (the Today's Quest card opens Quests). The icons keep TopbarPlus' own look (no outlines).
-- The POSING SHOW pill (PosingCompClient) sits in the same row, left of DAILY (TopBar.RightEdge). Returns { button, icon, SetActive(on), SetDot(on), SetBadge(n), SetText(text), Activated }.
-- TopBar.NewIcon(name, order): a left-hand icon (TopBarClient).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIBus = require(script.Parent.UIBus)
local SideMenu = require(script.Parent.SideMenu)
local UIConfig = require(script.Parent.Parent.Config.UI)
local Icon = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Icon"))

local TopBar = {}
TopBar.Icon = Icon

-- the right-hand icons: id -> look (left to right)
local PILLS = {
	Daily = { order = 2, text = "DAILY", icon = "calendar-days" },
	Settings = { order = 3, icon = "settings" },
}

-- (owner, 22 Oct: no outlines on the top bar; the icons keep Roblox's / TopbarPlus' own look) kept so callers still work
function TopBar.Style(icon)
	return icon
end

-- (prompt 46) the small red "!" chip in an icon's top-right corner (the side menu's badge)
local function chip(icon)
	local chipFrame = Instance.new("Frame")
	chipFrame.Name = "AlertChip"
	chipFrame.AnchorPoint = Vector2.new(1, 0)
	chipFrame.Position = UDim2.new(1, 3, 0, -3)
	chipFrame.Size = UDim2.fromOffset(16, 16)
	chipFrame.BackgroundColor3 = Color3.fromHex("#E8343C")
	chipFrame.ZIndex = 20
	chipFrame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = chipFrame
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromHex("#2A0505")
	edge.Thickness = 1.5
	edge.Parent = chipFrame
	local bang = Instance.new("TextLabel")
	bang.BackgroundTransparency = 1
	bang.Size = UDim2.fromScale(1, 1)
	bang.Text = "!"
	bang.TextColor3 = Color3.new(1, 1, 1)
	bang.TextSize = 13
	bang.FontFace = require(script.Parent.UIFonts).Chunky
	bang.ZIndex = 21
	bang.Parent = chipFrame
	chipFrame.Parent = icon.widget
	return chipFrame
end

-- Screen px of the left edge of the right-hand icons (the POSING SHOW pill ends here), or nil while they're hidden.
function TopBar.RightEdge(): number?
	local daily = Icon.getIcon("Daily")
	local widget = daily and daily.widget
	if widget and widget.AbsoluteSize.X > 0 and widget.Visible then
		local gui = widget:FindFirstAncestorWhichIsA("ScreenGui")
		if gui and gui.Enabled then return widget.AbsolutePosition.X end
	end
	return nil
end

local geneticsOpen = false
local shown = nil

-- (prompt 53) while the tutorial runs only coins and LVL stay in the bar: DAILY and settings come back when it ends
local tutorialShown = nil
local function refreshVisible()
	local on = not UIBus.MenuOpen and not geneticsOpen and not SideMenu.IsHidden()
	if on ~= shown then
		shown = on
		Icon.setTopbarEnabled(on)
	end
	local tutorial = UIBus.InTutorial()
	if tutorial ~= tutorialShown then
		tutorialShown = tutorial
		for id in pairs(PILLS) do
			local icon = Icon.getIcon(id)
			if icon then icon:setEnabled(not tutorial) else tutorialShown = nil end -- (not made yet: try again)
		end
	end
end

UIBus.MenuClosed.Event:Connect(refreshVisible)
UIBus.GeneticsVisible.Event:Connect(function(open)
	geneticsOpen = open
	refreshVisible()
end)
SideMenu.Changed:Connect(refreshVisible)
task.spawn(function() -- (MenuClient raises UIBus.MenuOpen when it starts, which can be after this runs)
	while true do
		refreshVisible()
		task.wait(0.4)
	end
end)

-- A left-hand icon (TopBarClient: coins, height, level). Not selectable.
function TopBar.NewIcon(name: string, order: number)
	return TopBar.Style(Icon.new():setName(name):setOrder(order):lock())
end

function TopBar.AddPill(id, labelText, _iconFactory, _order)
	local cfg = PILLS[id]
	local activated = Instance.new("BindableEvent")
	local api = { Activated = activated.Event }
	if not cfg then
		api.button = Instance.new("Frame")
		function api.SetActive() end
		function api.SetDot() end
		function api.SetBadge() end
		function api.SetText() end
		return api
	end
	local icon = Icon.new():setName(id):align("Right"):setOrder(cfg.order):oneClick(true)
	icon:setImage(UIConfig.Icons[cfg.icon])
	if cfg.text then icon:setLabel(cfg.text or labelText) end
	icon:bindEvent("selected", function() activated:Fire() end)
	TopBar.Style(icon)
	local alert = chip(icon)
	api.icon = icon
	api.button = icon.widget
	function api.SetActive() end
	function api.SetDot(_, on) alert.Visible = on == true end
	function api.SetBadge(_, n) alert.Visible = (tonumber(n) or 0) > 0 end
	function api.SetText() end -- (the icons keep their own words)
	return api
end

-- Screen px (from the top of the screen) just under the top bar.
function TopBar.Bottom()
	return game:GetService("GuiService").TopbarInset.Max.Y
end

-- Screen px from the right edge where right-hand panels line up.
function TopBar.Edge()
	return 12
end

-- Screen position of the coins icon (coins fly to it), or nil.
function TopBar.CoinsPosition(): Vector2?
	local coins = Icon.getIcon("Coins")
	local widget = coins and coins.widget
	if widget and widget.AbsoluteSize.X > 0 then
		return widget.AbsolutePosition + Vector2.new(22, widget.AbsoluteSize.Y / 2)
	end
	return nil
end

refreshVisible()
return TopBar
