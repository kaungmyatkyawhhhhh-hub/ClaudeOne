-- BoostsClient (owner, prompt 14, 21 Oct): the inventory boosts on the HUD (Config.Boosts, ItemService).
--  * Running boosts: an icon with its timer ("9:42") in the row above the stamina bar (HudBottom.Chip: at most 4 show,
--    the rest behind "+2", which also folds the row). Tapping one says its name and what it does.
--  * "Added to inventory": when items arrive (a Shake Bundle bought, a daily reward) a small card with USE NOW shows for a
--    few seconds under the top bar.
--  * Using one: a sound and a short note (the chug is the server's, everyone sees it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Notify = require(Shared.UI.Notify)
local HudBottom = require(Shared.UI.HudBottom)
local UIBus = require(Shared.UI.UIBus)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local New, Colors = Theme.New, Theme.Colors

------------------------------------------------------------------------
-- Timers by the stamina bar
------------------------------------------------------------------------
local chips = {} -- [id] = chip api
for order, item in ipairs(Boosts.Items) do
	if not item.shake then -- (the shake's own chip is ShakeClient's)
		local chip = HudBottom.Chip(item.icon, Color3.fromHex(item.color), 20 + order)
		chip:OnTap(function()
			Audio.PlayUI("Click")
			Notify.Toast(item.name, item.text, item.icon, Color3.fromHex(item.color), "boostinfo" .. item.id)
		end)
		chips[item.id] = chip
	end
end

-- (owner, prompt 25) MAX BOOST: your boosts are past the gains cap (player attribute "MaxBoost", MachineService); the cap
-- goes up with each Body Alter tier (Config.Gains.Cap)
local maxChip = HudBottom.Chip("arrow-big-up", Colors.Gold, 19)
maxChip:SetText("MAX BOOST")
maxChip:OnTap(function()
	Audio.PlayUI("Click")
	local cap = player:GetAttribute("GainsCap")
	Notify.Toast("MAX BOOST", "Your boosts are at the cap" .. (if type(cap) == "number" then " (x" .. cap .. ")" else "")
		.. ". More boosts won't add EXP. Each Body Alter tier raises the cap.", "arrow-big-up", Colors.Gold, "maxboost")
end)
local function refreshMax() maxChip:SetVisible(player:GetAttribute("MaxBoost") == true) end
player:GetAttributeChangedSignal("MaxBoost"):Connect(refreshMax)
refreshMax()

local function refreshChips()
	local t = Workspace:GetServerTimeNow()
	for id, chip in pairs(chips) do
		local ends = player:GetAttribute("Item_" .. id)
		local left = if type(ends) == "number" then ends - t else 0
		chip:SetVisible(left > 0)
		if left > 0 then chip:SetText("", Boosts.Clock(left)) end
	end
end
task.spawn(function()
	while true do
		refreshChips()
		task.wait(0.5)
	end
end)

------------------------------------------------------------------------
-- "Added to inventory" with USE NOW
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "ItemsAdded", DisplayOrder = 48, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local root = Kit.Root(gui)
local card = Theme.Panel({ Name = "Card", Piece = "hud_box", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(330, 60),
	Parent = root }, { New("UIStroke", { Color = Colors.Gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
local tileHolder = New("Frame", { Name = "Icon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(38, 38), Parent = card })
local title = Kit.Text({ Name = "Title", Text = "Added to inventory", Font = "Title", TextSize = 15, TextColor3 = Colors.Gold, Position = UDim2.fromOffset(56, 9),
	Size = UDim2.new(1, -170, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
local sub = Kit.Text({ Name = "Sub", Text = "", Font = "Strong", TextSize = 12, Position = UDim2.fromOffset(56, 31), Size = UDim2.new(1, -170, 0, 16),
	TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
local useNow = Kit.Button("Green", "Use now", { Name = "UseNow", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = card },
	{ width = 104, height = 44, textSize = 14 })
Kit.OnTopbar(function() card.Position = UDim2.new(0.5, 0, 0, Kit.UnderTopbar(root) + 34) end)
local shownId, token = nil, 0

local function hide()
	gui.Enabled = false
	shownId = nil
end

useNow.Activated:Connect(function()
	if not shownId then return end
	Remotes.PlayerAction:FireServer(if shownId == "Shake" then "DrinkShake" else "UseItem", shownId)
	hide()
end)

local function showAdded(id: string, count: number)
	local item = Boosts.ById[id]
	if not item then return end
	-- (bought in the PUMP SHOP window: a toast, the window is busy at the top)
	local shop = player.PlayerGui:FindFirstChild("PumpShop")
	if shop and shop.Enabled then
		Notify.Toast("Added to inventory", "+" .. count .. " " .. item.name, item.icon, Color3.fromHex(item.color), "itemsadded")
		return
	end
	shownId = id
	token += 1
	local mine = token
	for _, child in ipairs(tileHolder:GetChildren()) do child:Destroy() end
	Kit.IconTile(item.icon, Color3.fromHex(item.color), 38, { Parent = tileHolder })
	title.Text = "Added to inventory"
	sub.Text = "+" .. count .. " " .. item.name
	gui.Enabled = true
	Theme.Fade(card, true, 0.2)
	Audio.PlayUI("QuestClaim")
	task.delay(6, function() if token == mine then hide() end end)
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if type(info) ~= "table" then return end
	-- (22 Oct, owner: no boost popups during the tutorial; its shake step says what the shake does)
	local quiet = UIBus.InTutorial()
	if kind == "ItemsAdded" and type(info.id) == "string" then
		if not quiet then showAdded(info.id, tonumber(info.count) or 1) end
	elseif kind == "ItemUsed" and type(info.id) == "string" then
		local item = Boosts.ById[info.id]
		if item then
			if not quiet then Notify.Show(item.name .. ": " .. item.text) end
			Audio.Play2D("DrinkShake")
		end
	end
end)
