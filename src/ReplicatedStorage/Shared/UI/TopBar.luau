-- TopBar (client): our icons on Roblox's own top bar, made with TopbarPlus (owner, 14 Oct: TopbarPlus v3.4.0 by
-- ForeverHD, ReplicatedStorage.Packages.Icon, the official Creator Store model 92368439343389, unedited so it can be
-- updated). TopbarPlus draws them like Roblox's buttons (same height, line and theme) and moves icons that don't fit
-- into its overflow menu.
--   left (TopBarClient): coins | height ("7'0"" + "MAX" when capped) | level ("LVL 60", caption: progress to the next)
--   right (TopBar.AddPill): Daily | Quests | Settings
-- Hidden on the main menu, the genetics screen and full-width screens (Icon.setTopbarEnabled; Roblox's own buttons
-- stay). Anything under the top bar starts at GuiService.TopbarInset.Max.Y + 8 (Kit.UnderTopbar).
-- TopBar.AddPill(id, text, iconFactory, order): "Daily", "Quests" and "Settings" make a right-hand icon; any other id
-- gets an inert stand-in. Returns { button, icon, SetActive(on), SetDot(on), SetBadge(n), SetText(text), Activated }.
-- TopBar.NewIcon(name, order): a left-hand icon (TopBarClient).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIBus = require(script.Parent.UIBus)
local SideMenu = require(script.Parent.SideMenu)
local UIConfig = require(script.Parent.Parent.Config.UI)
local Icon = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Icon"))

local TopBar = {}
TopBar.Icon = Icon

-- the right-hand icons: id -> look (order counts from the screen's right edge)
local PILLS = {
	Daily = { order = 1, text = "Daily", icon = "calendar-days" },
	Quests = { order = 2, text = "Quests", icon = "list-checks" },
	Settings = { order = 3, icon = "settings" },
}

local geneticsOpen = false
local shown = nil
local never = Instance.new("BindableEvent") -- notices only clear when the game says so (not on a click)

local function refreshVisible()
	local on = not UIBus.MenuOpen and not geneticsOpen and not SideMenu.IsHidden()
	if on ~= shown then
		shown = on
		Icon.setTopbarEnabled(on)
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

-- A badge with a number (0 = none) on an icon (TopbarPlus notices)
local function noticeSetter(icon)
	local count = 0
	return function(n: number)
		n = math.max(0, math.floor(n))
		if n == count then return end
		count = n
		icon:clearNotices()
		for _ = 1, math.min(n, 9) do icon:notify(never.Event) end
	end
end

-- A left-hand icon (TopBarClient: coins, height, level). Not selectable.
function TopBar.NewIcon(name: string, order: number)
	return Icon.new():setName(name):setOrder(order):lock()
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
	local setNotices = noticeSetter(icon)
	api.icon = icon
	api.button = icon.widget
	function api.SetActive() end
	function api.SetDot(_, on) setNotices(on and 1 or 0) end
	function api.SetBadge(_, n) setNotices(tonumber(n) or 0) end
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
