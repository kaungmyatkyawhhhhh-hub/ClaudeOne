-- StyleService (prompt 61, owner 23 Oct; every number in Config/Style): the PUMP SHOP's STYLE items, cosmetic only.
-- Bought in the PUMP SHOP's STYLE tab (PumpShopService checks the place and calls StyleService.Buy; coins checked here),
-- worn from there or the Inventory (PlayerAction "WearStyle", kind, target, variant). Bought once, kept forever.
--   * NAME TAG colour: the player attribute "NameColor" ("#hex" or "#hex1,#hex2"); a "NameTag" billboard over the head
--     shows the display name in it (Roblox's own name hides while one is worn)
--   * TITLE colour: the player attribute "TitleColor" (TitleService colours the title's words with it)
--   * AURA colours: AuraService puts "<effect>@<colour>" on the character for the aura worn (AuraVFX turns the effect's
--     colours to that hue)
--   * ALTER tints: the player attribute "AlterTint" for the alter worn (BodyService.PublishData; MuscleRig tints the skin)
-- Save: data.style = { owned = { [item id] = true }, name, title, aura = { [aura id] = colour }, alter = { [alter id] = tint } }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Style = require(Config.Style)
local Auras = require(Config.Auras)
local Alters = require(Config.Alters)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local PlayerData = require(script.Parent.PlayerData)
local ActionService = require(script.Parent.ActionService)

local StyleService = {}

local NAME_HEIGHT = 0.62 -- studs
local NAME_OFFSET = 1.95 -- studs above the head centre (where Roblox's own name sits; the title is above it)

local function stateOf(data)
	local state = type(data.style) == "table" and data.style or {}
	state.owned = type(state.owned) == "table" and state.owned or {}
	state.aura = type(state.aura) == "table" and state.aura or {}
	state.alter = type(state.alter) == "table" and state.alter or {}
	data.style = state
	return state
end

-- the auras and alters this player has (their colour variants can be bought / worn)
local function aurasOf(player): { any }
	local AuraService = require(script.Parent.AuraService)
	local list = {}
	for _, aura in ipairs(Auras.List) do
		if AuraService.Has(player, aura.id) then table.insert(list, aura) end
	end
	return list
end
local function altersOf(data): { any }
	local list = {}
	local highest = Alters.State(data).highest or 0
	for n = 1, highest do
		local alter = Alters.Get(n)
		if alter and Style.AlterVariants[alter.id] then table.insert(list, alter) end
	end
	return list
end
local function itemFor(player, data, id: string)
	for _, item in ipairs(Style.Items(aurasOf(player), altersOf(data))) do
		if item.id == id then return item end
	end
	return nil
end

------------------------------------------------------------------------
-- Showing it
------------------------------------------------------------------------
local function nameTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head then return end
	local old = head:FindFirstChild("NameTag")
	if old then old:Destroy() end
	local colors = Style.Decode(player:GetAttribute("NameColor"))
	if humanoid then
		humanoid.DisplayDistanceType = if colors then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
	end
	if not colors then return end
	local New = Theme.New
	local tag = New("BillboardGui", { Name = "NameTag", Size = UDim2.fromScale(6, NAME_HEIGHT), StudsOffset = Vector3.new(0, NAME_OFFSET, 0),
		MaxDistance = 60, LightInfluence = 0, Parent = head })
	local text = New("TextLabel", { Name = "Name", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = player.DisplayName,
		FontFace = Theme.Fonts.Heading, TextScaled = true, TextColor3 = if #colors > 1 then Color3.new(1, 1, 1) else colors[1], Parent = tag }, {
		New("UITextSizeConstraint", { MinTextSize = Theme.TextSize.Small, MaxTextSize = 40 }),
		New("UIStroke", { Color = Theme.Colors.Shadow, Thickness = 1.5, Transparency = 0.3 }),
	})
	if #colors > 1 then
		New("UIGradient", { Color = ColorSequence.new(colors[1], colors[2]), Parent = text })
	end
end

function StyleService.Apply(player)
	local data = PlayerData.Get(player)
	if not data then return end
	local state = stateOf(data)
	player:SetAttribute("NameColor", Style.ColorValue(state.name))
	player:SetAttribute("TitleColor", Style.ColorValue(state.title))
	nameTag(player)
	pcall(function() require(script.Parent.TitleService).RefreshTag(player) end)
	pcall(function() require(script.Parent.AuraService).Refresh(player) end)
	pcall(function() require(script.Parent.BodyService).PublishData(player, data) end)
end

local function save(player, state)
	PlayerData.SetTable(player, "style", state)
	StyleService.Apply(player)
end

-- wear (variant) or take off (variant nil) one kind: "Name" / "Title" (target unused), "Aura" / "Alter" (target = its id)
local function wear(player, kind, target, variant)
	local data = PlayerData.Get(player)
	if not data or type(kind) ~= "string" then return end
	local state = stateOf(data)
	if variant ~= nil then
		if type(variant) ~= "string" then return end
		local id = if kind == "Name" or kind == "Title" then kind .. "_" .. variant else kind .. "_" .. tostring(target) .. "_" .. variant
		if not state.owned[id] then return end
	end
	if kind == "Name" then
		state.name = variant
	elseif kind == "Title" then
		state.title = variant
	elseif kind == "Aura" and type(target) == "string" and Auras.ById[target] then
		state.aura[target] = variant
	elseif kind == "Alter" and type(target) == "string" then
		state.alter[target] = variant
	else
		return
	end
	save(player, state)
end

-- PUMP SHOP (PumpShopService has checked the place): buy one, worn at once. -> ok, a failure text
function StyleService.Buy(player, id): (boolean, string?)
	local data = PlayerData.Get(player)
	if not data or type(id) ~= "string" then return false end
	local state = stateOf(data)
	if state.owned[id] then return false end
	local item = itemFor(player, data, id)
	if not item then return false end
	if not PlayerData.SpendCoins(player, item.price) then return false, "Not enough coins: " .. item.name .. " costs " .. item.price .. "." end
	state.owned[id] = true
	PlayerData.SetTable(player, "style", state)
	wear(player, item.kind, item.aura and item.aura.id or item.alter and item.alter.id, item.variant)
	return true
end

function StyleService.Start()
	ActionService.Register("WearStyle", function(player, arg)
		if type(arg) ~= "table" then return end
		wear(player, arg.kind, arg.target, arg.variant)
	end)
	local function hook(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			task.wait(0.5)
			if player.Parent then StyleService.Apply(player) end
		end)
		task.spawn(function()
			PlayerData.WaitFor(player)
			if player.Parent then StyleService.Apply(player) end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
end

return StyleService
