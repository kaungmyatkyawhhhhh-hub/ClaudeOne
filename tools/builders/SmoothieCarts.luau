-- SmoothieCarts builder (run once in Studio; see tools/bake.md; owner's feature run, task 5): the two meal carts.
--   Workspace.Gym.StarterGym.Feature_SmoothieBar.SmoothieCart   smoothie cart by the starter gym's front windows
--   Workspace.Town.BeachGym.Feature_SmoothieBar.CoconutCart     coconut cart on the sand by the beach gym entrance
--   Workspace.ProGym.Feature_SmoothieBar                         the pro gym's smoothie bar: its counter, stools, fridge and
--                                                                blenders are the Gyms builder's; this adds a hanging menu
--                                                                board and the order point
-- Each stall has an invisible "OrderPoint" part at the front of its counter (where customers stand) with the attribute
-- MealShop (Config.Meals.Shops) and the tag "MealShop"; MealService puts the prompt on it, so the cart itself never hides it.
-- Requires Kit next to it. Usage: require(game.ServerStorage._Builders.SmoothieCarts).Build()
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local Kit = require(script.Parent.Kit)

local M = Enum.Material
local hex = Kit.hex
local rad = math.rad

local Builder = {}
local orderPoint -- (below)

local WOOD, DARK, STEEL, WHITE, RUBBER = hex("#8A6240"), hex("#1E1E22"), hex("#C9CCD2"), hex("#F4F1EA"), hex("#141416")

local function sign(parent, cf, size, text)
	local board = Kit.prop(parent, "Sign", size, cf, DARK, M.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.3
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.8)
	label.Position = UDim2.fromScale(0, 0.1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = WHITE
	label.FontFace = Theme.Fonts.SemiBold
	label.TextScaled = true -- world sign
	label.Parent = gui
	return board
end

-- The invisible part the prompt sits on, in front of a counter (attribute MealShop + tag "MealShop").
orderPoint = function(parent, cframe, shopId)
	local point = Kit.prop(parent, "OrderPoint", Vector3.new(1, 1, 1), cframe, WHITE, M.SmoothPlastic)
	point.Transparency = 1
	point:SetAttribute("MealShop", shopId)
	CollectionService:AddTag(point, "MealShop")
	return point
end

-- One cart. `base` = the floor point under the cart's middle, LookVector = toward the customers.
function Builder.Cart(parent, name, base, style)
	local cart = Kit.fresh(parent, "Model", name)
	local beach = style == "Coconut"
	local W, D = 4.4, 2
	-- the body on a dark base frame, a white counter top the customers lean on (the stall part)
	Kit.part(cart, "Frame", Vector3.new(W, 0.3, D), base * CFrame.new(0, 0.85, 0), DARK, M.Metal)
	local body = Kit.part(cart, "Body", Vector3.new(W - 0.1, 2, D - 0.1), base * CFrame.new(0, 2, 0), beach and hex("#B88A5A") or WOOD, M.WoodPlanks)
	body.CastShadow = true
	for _, x in ipairs({ -W / 2 + 0.35, 0, W / 2 - 0.35 }) do
		Kit.prop(cart, "Batten", Vector3.new(0.12, 1.9, 0.06), base * CFrame.new(x, 2, -D / 2 - 0.02), DARK, M.Wood)
	end
	Kit.part(cart, "CounterTop", Vector3.new(W + 0.4, 0.16, D + 0.3), base * CFrame.new(0, 3.08, -0.1), WHITE, M.SmoothPlastic)
	orderPoint(cart, base * CFrame.new(0, 3.2, -D / 2 - 0.7), beach and "CoconutCart" or "StarterCart")
	Kit.prop(cart, "CounterEdge", Vector3.new(W + 0.42, 0.06, 0.06), base * CFrame.new(0, 3.0, -D / 2 - 0.26), STEEL, M.Metal)
	-- wheels (two each side) with hubs, and a push handle at the back
	for _, x in ipairs({ -W / 2 + 0.6, W / 2 - 0.6 }) do
		for _, z in ipairs({ -D / 2, D / 2 }) do
			local wheel = Kit.cylinder(cart, "Wheel", 0.25, 1.1, base * CFrame.new(x, 0.55, z + (z < 0 and -0.12 or 0.12)) * CFrame.Angles(0, rad(90), 0), RUBBER, M.Rubber, true)
			wheel.CastShadow = false
			Kit.cylinder(cart, "Hub", 0.27, 0.4, wheel.CFrame, STEEL, M.Metal)
		end
	end
	Kit.cylinder(cart, "Handle", W - 0.6, 0.12, base * CFrame.new(0, 3.3, D / 2 + 0.55), STEEL, M.Metal)
	for _, x in ipairs({ -W / 2 + 0.3, W / 2 - 0.3 }) do
		Kit.prop(cart, "HandleArm", Vector3.new(0.1, 0.1, 0.7), base * CFrame.new(x, 3.3, D / 2 + 0.25), STEEL, M.Metal)
	end
	-- canopy on two posts at the back, with the sign on its front edge
	for _, x in ipairs({ -W / 2 + 0.15, W / 2 - 0.15 }) do
		Kit.part(cart, "Post", Vector3.new(0.14, 3, 0.14), base * CFrame.new(x, 4.6, D / 2 - 0.15), STEEL, M.Metal)
	end
	local awning = beach and hex("#D9C08A") or hex("#2B2B2F")
	Kit.part(cart, "Canopy", Vector3.new(W + 0.8, 0.12, D + 1.2), base * CFrame.new(0, 6.15, -0.2) * CFrame.Angles(rad(-8), 0, 0), awning, beach and M.Fabric or M.Fabric)
	Kit.prop(cart, "CanopyTrim", Vector3.new(W + 0.82, 0.3, 0.06), base * CFrame.new(0, 5.98, -D / 2 - 0.8), beach and hex("#B49A62") or STEEL, beach and M.Fabric or M.Metal)
	local signCf = base * CFrame.new(0, 5.45, -D / 2 - 0.55)
	sign(cart, CFrame.lookAt(signCf.Position, signCf.Position + base.LookVector), Vector3.new(2.8, 0.7, 0.06), beach and "COCONUTS" or "SMOOTHIES")
	-- on the counter: blenders, a stack of cups, fruit (or coconuts)
	for i, x in ipairs({ -1.4, -0.7 }) do
		local at = base * CFrame.new(x, 3.16, 0.35)
		Kit.prop(cart, "BlenderBase", Vector3.new(0.45, 0.35, 0.45), at * CFrame.new(0, 0.17, 0), DARK, M.SmoothPlastic)
		local jar = Kit.prop(cart, "BlenderJar", Vector3.new(0.38, 0.7, 0.38), at * CFrame.new(0, 0.7, 0), hex("#DDE6EA"), M.Glass)
		jar.Transparency = 0.45
		Kit.prop(cart, "Smoothie", Vector3.new(0.34, 0.34, 0.34), at * CFrame.new(0, 0.55, 0), i == 1 and hex("#F2A33A") or hex("#E8DCC8"), M.SmoothPlastic)
	end
	for i = 0, 3 do
		Kit.cylinder(cart, "Cup", 0.26, 0.42, base * CFrame.new(0.6, 3.29 + i * 0.12, -0.45) * CFrame.Angles(0, 0, rad(90)), WHITE, M.SmoothPlastic)
	end
	local fruitColors = beach and { hex("#5A3A22"), hex("#6B4A2E"), hex("#4E3320"), hex("#6B4A2E"), hex("#5A3A22") } or { hex("#E8C21C"), hex("#D7262E"), hex("#2E9E4F"), hex("#F2A33A") }
	for i, color in ipairs(fruitColors) do
		local fruit = Kit.prop(cart, beach and "Coconut" or "Fruit", Vector3.new(beach and 0.55 or 0.35, beach and 0.55 or 0.35, beach and 0.55 or 0.35),
			base * CFrame.new(1.25 + (i % 3) * 0.32, 3.4 + (i > 3 and 0.3 or 0), 0.2 + (i % 2) * 0.3), color, beach and M.Sand or M.SmoothPlastic)
		fruit.Shape = Enum.PartType.Ball
	end
	if beach then
		-- a few coconuts in a crate by the wheel
		Kit.part(cart, "Crate", Vector3.new(1.2, 0.8, 1), base * CFrame.new(W / 2 + 0.9, 0.4, 0.2), WOOD, M.WoodPlanks)
		for i = 1, 3 do
			local c = Kit.prop(cart, "Coconut", Vector3.new(0.55, 0.55, 0.55), base * CFrame.new(W / 2 + 0.6 + (i - 1) * 0.3, 0.95, 0.1 + (i % 2) * 0.3), hex("#5A3A22"), M.Sand)
			c.Shape = Enum.PartType.Ball
		end
	end
	for _, part in ipairs(cart:GetDescendants()) do
		if part:IsA("BasePart") then part.CanTouch = false end
	end
	return cart
end

-- The pro gym's bar: a menu board hanging over the back counter (the items and prices from Config.Meals) and the order
-- point in front of the counter, where the stools are.
function Builder.ProBar(proGym)
	local bar = proGym:FindFirstChild("SmoothieBar", true)
	assert(bar, "ProGym's SmoothieBar (Gyms builder) is missing")
	local feature = proGym:FindFirstChild("Feature_SmoothieBar") or Instance.new("Folder")
	feature.Name = "Feature_SmoothieBar"
	feature.Parent = proGym
	local model = Kit.fresh(feature, "Model", "SmoothieBarMenu")
	local counter = bar:FindFirstChild("CounterTop")
	-- the little card on the counter listed made-up flavors: it shows what the bar really sells now
	local card = bar:FindFirstChild("MenuCard")
	local cardLabel = card and card:FindFirstChildWhichIsA("TextLabel", true)
	if cardLabel then cardLabel.Text = "PROTEIN SHAKE" .. string.char(10) .. "ENERGY SMOOTHIE" .. string.char(10) .. "CHICKEN & RICE" end
	local cx, cz = counter.Position.X, counter.Position.Z -- (customers on the -Z side, the back bar toward +Z)
	orderPoint(model, CFrame.new(cx, counter.Position.Y + 0.2, cz - 1.4), "SmoothieBar")
	-- the menu board: a dark framed panel hanging from two rods over the back counter, facing the stools
	local at = Vector3.new(cx - 1.4, 7.2, -5.2)
	local facing = CFrame.lookAt(at, at - Vector3.zAxis)
	Kit.part(model, "MenuFrame", Vector3.new(4.4, 2.6, 0.12), facing * CFrame.new(0, 0, 0.04), DARK, M.Metal)
	local panel = Kit.prop(model, "Menu", Vector3.new(4.2, 2.4, 0.05), facing * CFrame.new(0, 0, -0.04), hex("#0E0E10"), M.SmoothPlastic)
	for _, x in ipairs({ -1.8, 1.8 }) do
		Kit.prop(model, "Rod", Vector3.new(0.06, 18 - (at.Y + 1.3), 0.06), CFrame.new(at + facing.RightVector * x + Vector3.new(0, (18 - (at.Y + 1.3)) / 2 + 1.3, 0)), STEEL, M.Metal)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0.05, 0), UDim.new(0.05, 0), UDim.new(0.05, 0)
	pad.Parent = gui
	local function text(name, value, props)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Text = value
		label.TextColor3 = WHITE
		label.FontFace = Theme.Fonts.Regular
		label.TextScaled = true -- world sign
		for k, v in pairs(props) do label[k] = v end
		label.Parent = gui
		return label
	end
	text("Title", "SMOOTHIE BAR", { FontFace = Theme.Fonts.SemiBold, Size = UDim2.fromScale(1, 0.2) })
	local Meals = require(ReplicatedStorage.Shared.Config.Meals)
	for i, id in ipairs(Meals.Shops.SmoothieBar.items) do
		local item = Meals.ById[id]
		local y = 0.26 + (i - 1) * 0.24
		text("Item" .. i, item.name, { TextXAlignment = Enum.TextXAlignment.Left, FontFace = Theme.Fonts.SemiBold, Size = UDim2.fromScale(0.7, 0.11), Position = UDim2.fromScale(0, y) })
		text("Price" .. i, item.price .. " coins", { TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromScale(0.3, 0.11), Position = UDim2.fromScale(0.7, y) })
		text("Info" .. i, item.text, { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = hex("#B8B8BE"), Size = UDim2.fromScale(1, 0.08), Position = UDim2.fromScale(0, y + 0.115) })
	end
	return model
end

local function folder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function groundY(x, z)
	local hit = Workspace:Raycast(Vector3.new(x, 4, z), Vector3.new(0, -10, 0))
	return hit and hit.Position.Y or 0
end

function Builder.Build()
	local made = {}
	-- the starter gym: by the front windows, left of the hall door, customers on the room side (-Z)
	local y = groundY(-29, -9)
	table.insert(made, Builder.Cart(folder(Workspace.Gym.StarterGym, "Feature_SmoothieBar"), "SmoothieCart",
		CFrame.lookAt(Vector3.new(-29, y, -9.2), Vector3.new(-29, y, -20)), "Smoothie"))
	-- the beach gym: on the sand just outside its entrance, east of the boardwalk, customers on the boardwalk side (-X)
	local beachY = groundY(7.5, 170)
	table.insert(made, Builder.Cart(folder(Workspace.Town.BeachGym, "Feature_SmoothieBar"), "CoconutCart",
		CFrame.lookAt(Vector3.new(7.5, beachY, 170), Vector3.new(0, beachY, 170)), "Coconut"))
	table.insert(made, Builder.ProBar(Workspace.ProGym))
	return made
end

return Builder
