-- HotbarClient (owner, 21 Oct): the items you EQUIP from Inventory > Boosts, in a hotbar like Roblox's own toolbar, in
-- Black + Gold. Roblox's toolbar is turned off: it sits at the very bottom centre, right where the stamina bar is.
--  * One slot per Tool in your backpack / hand, in the order they arrived: the number (1-9) top left, the item's icon,
--    the count you own bottom right (Boosts items: "BoostItem" attribute on the Tool, ItemService). A tool that isn't a
--    boost shows its name.
--  * Tap a slot or press its number to hold it; again to put it away. The one in your hand has a gold border and sits a
--    little higher.
--  * Bottom centre, above the boost timers row (HudBottom), so it never covers the stamina bar, STOP / EXERCISE (bottom
--    left) or REP / PUMP (bottom right). Hidden whenever HudBottom is (menus, full screens, posing) and when it's empty.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Audio = require(Shared.Audio)

local New, Colors = Theme.New, Theme.Colors
local player = Players.LocalPlayer

local SLOT = 50
local GAP = 6
local BOTTOM = 10 + 34 + 8 + 44 + 6 -- HudBottom: its gap + the stamina bar + 8 + the boost timers row + 6
local LIFT = 4                       -- the slot in your hand sits this much higher
local KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }

-- Roblox's toolbar off (retried: SetCore isn't ready at the very start)
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then break end
		task.wait(0.5)
	end
end)

local gui = Theme.ScreenGui({ Name = "Hotbar", DisplayOrder = 4, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local root = Kit.Root(gui)
local bar = New("Frame", { Name = "Slots", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -BOTTOM),
	Size = UDim2.fromOffset(0, SLOT + LIFT), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = root }, {
	Theme.List(Enum.FillDirection.Horizontal, GAP, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
})

local order = {} -- Tools in the order they arrived
local slots = {} -- [Tool] = { frame, face, stroke, count }

local function humanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end
local function held(tool: Tool): boolean
	return player.Character ~= nil and tool.Parent == player.Character
end
local function countOf(tool: Tool): number?
	local id = tool:GetAttribute("BoostItem")
	local items = ClientData.Get().items
	return if type(id) == "string" and type(items) == "table" then tonumber(items[id]) or 0 else nil
end

local function toggle(tool: Tool)
	local h = humanoid()
	if not h or h.Health <= 0 then return end
	if held(tool) then
		h:UnequipTools()
	else
		h:EquipTool(tool)
	end
	Audio.PlayUI("Click")
end

local function render()
	-- forget tools that are gone (used up, unequipped in the Inventory, respawn)
	for i = #order, 1, -1 do
		local tool = order[i]
		local inBag = tool.Parent == player:FindFirstChildOfClass("Backpack") or held(tool)
		if not inBag then
			table.remove(order, i)
			if slots[tool] then slots[tool].frame:Destroy() slots[tool] = nil end
		end
	end
	for index, tool in ipairs(order) do
		local slot = slots[tool]
		if not slot then
			local frame = New("Frame", { Name = "Slot", BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT, SLOT + LIFT), Parent = bar })
			local face = Theme.Panel({ Name = "Face", Piece = "hud_box", Clickable = true, AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(SLOT, SLOT), Parent = frame })
			local stroke = New("UIStroke", { Name = "Held", Color = Colors.Gold, Thickness = 2, Enabled = false,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = face })
			local item = Boosts.ById[tool:GetAttribute("BoostItem") or ""]
			if item then
				Kit.IconTile(item.icon, Color3.fromHex(item.color), 30, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5), Parent = face })
			else
				Kit.Text({ Name = "Name", Text = tool.Name, Font = "Strong", TextSize = 10, TextWrapped = true, Size = UDim2.new(1, -6, 1, -14),
					Position = UDim2.fromOffset(3, 12), Parent = face })
			end
			local number = Kit.Text({ Name = "Key", Text = "", Font = "Number", TextSize = 11, TextColor3 = Colors.Muted,
				Position = UDim2.fromOffset(5, 2), Size = UDim2.fromOffset(12, 12), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = face })
			local count = Kit.Text({ Name = "Count", Text = "", Font = "Number", TextSize = 11, AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -4, 1, -2), Size = UDim2.fromOffset(30, 12), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, Parent = face })
			face.Activated:Connect(function() toggle(tool) end)
			slot = { frame = frame, face = face, stroke = stroke, number = number, count = count }
			slots[tool] = slot
		end
		slot.frame.LayoutOrder = index
		slot.number.Text = if index <= #KEYS then tostring(index) else ""
		local n = countOf(tool)
		slot.count.Text = if n then "x" .. n else ""
		local inHand = held(tool)
		slot.stroke.Enabled = inHand
		slot.face.Position = UDim2.new(0.5, 0, 1, if inHand then -LIFT else 0)
	end
end

local function watchTool(tool)
	if not tool:IsA("Tool") or table.find(order, tool) then return end
	table.insert(order, tool)
	render()
end
local function watchContainer(container: Instance)
	for _, child in ipairs(container:GetChildren()) do watchTool(child) end
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then watchTool(child) render() end
	end)
	container.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then task.defer(render) end -- (backpack -> hand moves arrive as removed + added)
	end)
end
local function onCharacter(character)
	watchContainer(character)
	local backpack = player:WaitForChild("Backpack", 10)
	if backpack then watchContainer(backpack) end
	render()
end
if player.Character then task.spawn(onCharacter, player.Character) end
player.CharacterAdded:Connect(onCharacter)

task.spawn(function()
	ClientData.Get()
	ClientData.Changed:Connect(function(path)
		if path[1] == "items" then render() end
	end)
end)

-- 1-9 hold / put away the item in that slot (not while typing)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui.Enabled then return end
	local index = table.find(KEYS, input.KeyCode)
	local tool = index and order[index]
	if tool then toggle(tool) end
end)

-- shown with HudBottom (same menus / full screens / posing), only when there is something to hold
task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui")
	while true do
		local hud = playerGui:FindFirstChild("HudBottom")
		gui.Enabled = #order > 0 and hud ~= nil and hud.Enabled
		task.wait(0.3)
	end
end)
