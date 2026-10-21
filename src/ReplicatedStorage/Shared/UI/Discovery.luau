-- Discovery (prompt 31, 22 Oct): UNDISCOVERED items (curiosity), shared by the Inventory (ALTERS, AURAS, TITLES) and the
-- TRAINERS window's MY TRAINERS.
--   * Discovery.Overlay(tile): the UNDISCOVERED face over a tile: a dark fill, a "?" in a dark ring, "???" and a small
--     gray UNDISCOVERED (no name, no description). Its Visible = undiscovered.
--   * What the player has already seen is saved per list (settings.revealed[list] = "id,id,..."; PlayerData checks it).
--     Discovery.New(list, ids) = the discovered ids not seen yet (none the first time: what you have then counts as seen,
--     so nobody gets a pile of reveals); Discovery.Seen(list, ids) saves them.
--   * Discovery.Reveal(tile): the first time a list is opened after something new: its UNDISCOVERED face folds away
--     and a small gold burst plays.
--   * Discovery.Dot(button, on): the red dot on a tab (or chip) while it has something new.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local ClientData = require(script.Parent.Parent.ClientData)

local New, Colors = Theme.New, Theme.Colors

local Discovery = {}

Discovery.Gray = Color3.fromHex("#8A878F")
Discovery.Fill = Color3.fromHex("#141216")

function Discovery.Overlay(tile: GuiObject, corner: number?): Frame
	local overlay = New("Frame", { Name = "Undiscovered", BackgroundColor3 = Discovery.Fill, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), ZIndex = 20, Visible = false, Parent = tile }, {
		New("UICorner", { CornerRadius = UDim.new(0, corner or 10) }),
		New("UIStroke", { Color = Color3.fromHex("#2E2A30"), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	local ring = New("Frame", { Name = "Ring", BackgroundColor3 = Color3.fromHex("#0A090B"), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7),
		Size = UDim2.fromOffset(34, 34), ZIndex = 21, Parent = overlay }, {
		New("UICorner", { CornerRadius = UDim.new(1, 0) }),
		New("UIStroke", { Color = Color3.fromHex("#3A363D"), Thickness = 1.5 }),
	})
	Kit.Text({ Name = "Mark", Text = "?", Font = "Chunky", TextSize = 22, TextColor3 = Discovery.Gray, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = ring })
	Kit.Text({ Name = "Name", Text = "???", Font = "Chunky", TextSize = 15, TextColor3 = Discovery.Gray, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(1, -10, 0, 17), ZIndex = 21, Parent = overlay })
	Kit.Text({ Name = "Label", Text = "UNDISCOVERED", Font = "Chunky", TextSize = 10, TextColor3 = Color3.fromHex("#6A676F"), AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -10, 0, 12), ZIndex = 21, Parent = overlay })
	return overlay
end

------------------------------------------------------------------------
-- What's been seen (saved)
------------------------------------------------------------------------
local pending = {} -- [list] = "id,id" sent but not back yet (so a second refresh doesn't reveal twice)

local function savedSet(list: string): { [string]: boolean }?
	local text = pending[list]
	if not text then
		local data = ClientData.IsLoaded() and ClientData.Get() or nil
		local revealed = data and data.settings and data.settings.revealed
		text = type(revealed) == "table" and revealed[list] or nil
	end
	if type(text) ~= "string" then return nil end
	local set = {}
	for id in string.gmatch(text, "[^,]+") do set[id] = true end
	return set
end

-- the discovered ids not seen yet ({} the first time: everything then counts as seen)
function Discovery.New(list: string, ids: { string }): { [string]: boolean }
	local seen = savedSet(list)
	local fresh = {}
	if not seen then return fresh end
	for _, id in ipairs(ids) do
		if not seen[id] then fresh[id] = true end
	end
	return fresh
end

function Discovery.HasNew(list: string, ids: { string }): boolean
	return next(Discovery.New(list, ids)) ~= nil
end

-- saves `ids` as seen (only when something changed)
function Discovery.Seen(list: string, ids: { string })
	local seen = savedSet(list)
	local changed = seen == nil
	if seen then
		for _, id in ipairs(ids) do
			if not seen[id] then changed = true break end
		end
	end
	if not changed then return end
	local merged = seen or {}
	for _, id in ipairs(ids) do merged[id] = true end
	local all = {}
	for id in pairs(merged) do table.insert(all, id) end
	table.sort(all)
	local text = table.concat(all, ",")
	pending[list] = text
	ReplicatedStorage:WaitForChild("Remotes").PlayerAction:FireServer("SetSettings", { revealed = { [list] = text } })
	task.delay(10, function() if pending[list] == text then pending[list] = nil end end)
end

------------------------------------------------------------------------
-- The reveal and the dot
------------------------------------------------------------------------
-- the UNDISCOVERED face folds away (like a card turning) and a gold burst plays; `overlay` = the tile's Discovery.Overlay
function Discovery.Reveal(tile: GuiObject, overlay: GuiObject?)
	if overlay then
		overlay.Visible = true
		overlay.Size = UDim2.fromScale(1, 1)
		local fold = TweenService:Create(overlay, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromScale(0, 1) })
		fold.Completed:Connect(function()
			overlay.Visible = false
			overlay.Size = UDim2.fromScale(1, 1)
		end)
		fold:Play()
	end
	task.delay(if overlay then 0.2 else 0, function()
		if not tile.Parent then return end
		-- a soft gold flash over the tile
		local flash = New("Frame", { Name = "RevealFlash", BackgroundColor3 = Colors.Gold, BackgroundTransparency = 0.35, Size = UDim2.fromScale(1, 1), ZIndex = 25,
			Parent = tile }, { New("UICorner", { CornerRadius = UDim.new(0, 10) }) })
		TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		-- eight sparks out from the middle
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local spark = New("Frame", { Name = "RevealSpark", BackgroundColor3 = Color3.fromHex("#FFF3C4"), AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(7, 7), ZIndex = 26, Parent = tile }, { New("UICorner", { CornerRadius = UDim.new(1, 0) }) })
			TweenService:Create(spark, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, math.cos(angle) * 46, 0.5, math.sin(angle) * 36), Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 1 }):Play()
			task.delay(0.55, function() spark:Destroy() end)
		end
		-- and the tile pops
		local scale = tile:FindFirstChild("RevealScale") or New("UIScale", { Name = "RevealScale", Parent = tile })
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(0.5, function() flash:Destroy() end)
	end)
end

-- the red dot in a tab's (or chip's) top-right corner (in a Folder: the button's own list layout leaves it alone)
function Discovery.Dot(button: GuiObject, on: boolean)
	local dot = button:FindFirstChild("NewDot", true)
	if not dot then
		if not on then return end
		local holder = New("Folder", { Name = "NewDotHolder", Parent = button })
		dot = New("Frame", { Name = "NewDot", BackgroundColor3 = Colors.Red, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(10, 10), ZIndex = 30, Parent = holder }, {
			New("UICorner", { CornerRadius = UDim.new(1, 0) }),
			New("UIStroke", { Color = Color3.fromHex("#0A090B"), Thickness = 1.5 }),
		})
	end
	dot.Visible = on
end

return Discovery
