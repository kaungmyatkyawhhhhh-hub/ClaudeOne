-- NightGlow builder (run once in Studio, Edit mode; see tools/bake.md): tags what lights up at night in town
-- (owner's feature run, task 7C; NightLightService switches them at dusk and dawn, Config/DayNight):
--   * NightWindow: the shop windows (clothing store, smoothie bar, sauna; warm, still see-through so the displays show)
--     and a share of the town buildings' windows (DayNight.WindowLitShare, picked with a fixed seed so it stays the
--     same; mostly warm, a few cool). Each gets its day look (DayColor, DayMaterial, DayTransparency) and its night look
--     (NightColor, NightTransparency) as attributes.
--   * NightSign: the gym signs and shop signs (their SurfaceGuis light themselves at night).
-- Nothing is added or moved: only tags and attributes. Safe to run again (it clears its own tags first).
-- Usage: require(game.ServerStorage._Builders.NightGlow).Build()
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local DayNight = require(ReplicatedStorage.Shared.Config.DayNight)

local Builder = {}

local WARM = { Color3.fromHex("#FFD9A3"), Color3.fromHex("#FFC98A"), Color3.fromHex("#FFE2B8") }
local COOL = Color3.fromHex("#DDE8FF")
local SHOP_WINDOWS = { Glass = true, DisplayWindow = true, WindowGlass = true }
local SHOPS = { "ClothingStore", "SmoothieBar", "Sauna" }
local SIGN_NAMES = { ShopSign = true, GymSign = true, ProSign = true, RoofSign = true, SaunaSign = true, Sign = true, SignBoard = true, AreaSign = true }

local function hasSurfaceGui(inst)
	for _, d in ipairs(inst:GetDescendants()) do if d:IsA("SurfaceGui") then return true end end
	return false
end

local function window(part, color, transparency)
	part:SetAttribute("DayColor", part.Color)
	part:SetAttribute("DayMaterial", part.Material.Name)
	part:SetAttribute("DayTransparency", part.Transparency)
	part:SetAttribute("NightColor", color)
	part:SetAttribute("NightTransparency", transparency)
	CollectionService:AddTag(part, "NightWindow")
end

function Builder.Build()
	for _, tag in ipairs({ "NightWindow", "NightSign" }) do
		for _, inst in ipairs(CollectionService:GetTagged(tag)) do CollectionService:RemoveTag(inst, tag) end
	end
	local town = Workspace:FindFirstChild("Town")
	if not town then return "no Workspace.Town" end
	local rng = Random.new(7)
	local shopWindows, litWindows, allWindows, signs = 0, 0, 0, 0
	-- shop windows: all lit, see-through
	for _, shopName in ipairs(SHOPS) do
		local shop = town:FindFirstChild(shopName)
		for _, d in ipairs(shop and shop:GetDescendants() or {}) do
			if d:IsA("BasePart") and SHOP_WINDOWS[d.Name] then
				window(d, WARM[1], 0.45)
				shopWindows += 1
			end
		end
	end
	-- the town buildings' windows: a share lit
	local buildings = town:FindFirstChild("Buildings")
	for _, d in ipairs(buildings and buildings:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == "Glass" then
			allWindows += 1
			if rng:NextNumber() < DayNight.WindowLitShare then
				local color = rng:NextNumber() < 0.15 and COOL or WARM[rng:NextInteger(1, #WARM)]
				window(d, color, 0)
				litWindows += 1
			end
		end
	end
	-- signs with a SurfaceGui
	for _, d in ipairs(town:GetDescendants()) do
		if SIGN_NAMES[d.Name] and (d:IsA("BasePart") or d:IsA("Model")) and hasSurfaceGui(d) then
			CollectionService:AddTag(d, "NightSign")
			signs += 1
		end
	end
	return string.format("shop windows %d, town windows lit %d of %d, signs %d", shopWindows, litWindows, allWindows, signs)
end

return Builder
