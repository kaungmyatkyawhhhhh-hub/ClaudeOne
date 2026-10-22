-- HotbarClient (owner, 21 Oct): the items you EQUIP from Inventory > Boosts, in a hotbar like Roblox's own toolbar, in
-- Black + Gold. Roblox's toolbar is turned off: it sits at the very bottom centre, right where the stamina bar is.
--  * One slot per Tool in your backpack / hand, in the order they arrived: the number (1-9) top left, the item's icon,
--    the count you own bottom right (Boosts items: "BoostItem" attribute on the Tool, ItemService). A tool that isn't a
--    boost shows its name.
--  * (prompt 28b) Tap a slot or press its number to hold it (the bottle in your hand); again to put it away. The one in
--    your hand has a gold border and sits a little higher. While you hold a boost, tap / click the screen (Roblox's own
--    Tool activate: a drag still turns the camera, a tap on a button never drinks) = the drink: ~1 s (ItemService checks
--    the cooldown and uses the item at the end); the slot shows a radial sweep meanwhile (the DrinkItem / DrinkUntil
--    player attributes). The first time you hold one: "Tap the screen to drink it." The shake is slot 1 (it replaces
--    the old DRINK SHAKE button).
--  * (prompt 28) Pinned to the bottom centre like Roblox's own toolbar (10 px above the safe area, never moving with the
--    character); the stamina bar and the boost timers (HudBottom.SetLift) move up above it while it shows. STOP / EXERCISE
--    (bottom left) and REP / PUMP (bottom right) stay in the corners. Hidden whenever HudBottom is (menus, full screens,
--    posing) and when it's empty. (Owner, 21 Oct) Hidden on a machine too, and whatever you hold is put away (the server
--    does it as well); it shows again when you get off.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Boosts = require(Shared.Config.Boosts)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local HudBottom = require(Shared.UI.HudBottom)
local Audio = require(Shared.Audio)

local New, Colors = Theme.New, Theme.Colors
local player = Players.LocalPlayer

local SLOT = 50
local GAP = 6
local BOTTOM = 10                    -- above the bottom safe area (prompt 28: was above the stamina bar, mid-screen)
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
-- (prompt 28) many slots on a small phone: the row shrinks so it stays between STOP (bottom left) and REP (bottom right)
local CORNERS = 2 * 175 -- mockup px kept free for the machine HUD's corners (MachineHud: corner + REP 150 wide)
local fit = New("UIScale", { Parent = bar })
local function fitRow()
	local count = 0
	for _, child in ipairs(bar:GetChildren()) do
		if child:IsA("GuiObject") then count += 1 end
	end
	local natural = count * SLOT + math.max(0, count - 1) * GAP
	local room = root.AbsoluteSize.X / math.max(Kit.Scale(), 0.01) - CORNERS
	-- (never under ~44 px a slot: a thumb still hits it)
	local minScale = math.min(1, 44 / (SLOT * math.max(Kit.Scale(), 0.01)))
	fit.Scale = if natural > room and natural > 0 then math.max(minScale, room / natural) else 1
end

local order = {} -- Tools: the shake first, then in the order they arrived
local arrived = {} -- [Tool] = arrival number
local watchTool -- (below)
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

local Notify = require(Shared.UI.Notify)
local hinted = false
local function toggle(tool: Tool)
	local h = humanoid()
	if not h or h.Health <= 0 then return end
	if held(tool) then
		h:UnequipTools()
	else
		h:EquipTool(tool)
		-- (prompt 28b) the first boost you hold this session: how to drink it
		if not hinted and tool:GetAttribute("BoostItem") then
			hinted = true
			Notify.Hint(if UserInputService.TouchEnabled then "Tap the screen to drink it." else "Click to drink it.")
		end
	end
	Audio.PlayUI("Click")
end

-- (prompt 28b) the radial sweep over a slot while its drink runs: two half discs, each a hard-edged UIGradient that
-- turns (the right half covers 12 -> 6 o'clock, then the left half 6 -> 12)
local HARD = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1) })
local function makeSweep(face: GuiObject)
	local sweep = New("CanvasGroup", { Name = "Sweep", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 0.35,
		Visible = false, ZIndex = 4, Parent = face }, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
	local halves = {}
	for i, side in ipairs({ "Right", "Left" }) do
		local clip = New("Frame", { Name = side, BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 4,
			Position = UDim2.fromScale(if side == "Right" then 0.5 else 0, 0), Size = UDim2.fromScale(0.5, 1), Parent = sweep })
		local disc = New("Frame", { Name = "Disc", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 4,
			Position = UDim2.fromScale(if side == "Right" then -1 else 0, 0), Size = UDim2.fromScale(2, 1), Parent = clip })
		halves[i] = New("UIGradient", { Transparency = HARD, Rotation = if side == "Right" then 0 else 180, Parent = disc })
	end
	return { frame = sweep, right = halves[1], left = halves[2] }
end
local function setSweep(sweep, share: number?)
	sweep.frame.Visible = share ~= nil
	if not share then return end
	local angle = math.clamp(share, 0, 1) * 360
	sweep.right.Rotation = math.min(angle, 180)
	sweep.left.Rotation = math.max(angle, 180)
end

local function render()
	-- forget tools that are gone (used up, unequipped in the Inventory, respawn)
	for i = #order, 1, -1 do
		local tool = order[i]
		local inBag = tool.Parent == player:FindFirstChildOfClass("Backpack") or held(tool)
		if not inBag then
			table.remove(order, i)
			if slots[tool] then slots[tool].frame:Destroy() slots[tool] = nil end
			arrived[tool] = nil
		end
	end
	-- the shake first (slot 1: the tutorial points at it), then the order they arrived
	table.sort(order, function(a, b)
		local sa, sb = a:GetAttribute("BoostItem") == "Shake", b:GetAttribute("BoostItem") == "Shake"
		if sa ~= sb then return sa end
		return (arrived[a] or 0) < (arrived[b] or 0)
	end)
	for index, tool in ipairs(order) do
		local slot = slots[tool]
		if not slot then
			local boostId = tool:GetAttribute("BoostItem")
			local frame = New("Frame", { Name = if type(boostId) == "string" then "Slot_" .. boostId else "Slot", BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT, SLOT + LIFT), Parent = bar })
			-- (owner, 23 Oct, chrome reset: the hotbar keeps its look)
			local face = Theme.Panel({ Name = "Face", Piece = "hud_box_gold", Clickable = true, AnchorPoint = Vector2.new(0.5, 1),
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
			slot = { frame = frame, face = face, stroke = stroke, number = number, count = count, sweep = makeSweep(face) }
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

local arrival = 0
function watchTool(tool)
	if not tool:IsA("Tool") or table.find(order, tool) then return end
	arrival += 1
	arrived[tool] = arrival
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

-- (prompt 28b) the drink's sweep: the slot of the item being drunk fills clockwise until the drink ends
local DRINK = Boosts.DrinkSeconds or 1
game:GetService("RunService").RenderStepped:Connect(function()
	local id = player:GetAttribute("DrinkItem")
	local untilTime = player:GetAttribute("DrinkUntil")
	local left = if type(untilTime) == "number" then untilTime - workspace:GetServerTimeNow() else 0
	for tool, slot in pairs(slots) do
		local on = id ~= nil and tool:GetAttribute("BoostItem") == id and left > 0
		setSweep(slot.sweep, if on then 1 - left / DRINK else nil)
	end
end)

-- 1-9 hold / put away the item in that slot (not while typing)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not gui.Enabled then return end
	local index = table.find(KEYS, input.KeyCode)
	local tool = index and order[index]
	if tool then toggle(tool) end
end)

-- on a machine (MachineState Enter / Exit): hidden, hands empty
local onMachine = false
Remotes.MachineState.OnClientEvent:Connect(function(state)
	if state == "Enter" then
		onMachine = true
		local h = humanoid()
		if h then h:UnequipTools() end
	elseif state == "Exit" then
		onMachine = false
	end
end)

-- shown with HudBottom (same menus / full screens / posing), only when there is something to hold
task.spawn(function()
	local playerGui = player:WaitForChild("PlayerGui")
	while true do
		local hud = playerGui:FindFirstChild("HudBottom")
		gui.Enabled = #order > 0 and hud ~= nil and hud.Enabled and not onMachine
		-- (prompt 28) the stamina bar and the boost icons sit above the slots while they show
		if gui.Enabled then fitRow() end
		HudBottom.SetLift(if gui.Enabled then math.ceil((SLOT + LIFT) * fit.Scale) + 6 else 0)
		task.wait(0.3)
	end
end)
