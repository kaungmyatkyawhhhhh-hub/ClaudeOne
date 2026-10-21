-- GuideClient (prompt 39, 22 Oct): unlock guides and locked menu tiles, with the tutorial's pieces (Config/Guides has every
-- line, condition and target).
--  * Locked tiles (Guides.Locks): SideMenu.SetLocked (dimmed + a gold padlock, never hidden); a tap shakes it and toasts
--    "LOCKED · Unlocks at Growth Spurt 1" + the tease (+ "54% there"). Opening it any other way (UIBus.OpenShop, the
--    Agency desk...) shows the same toast (UIBus.IsLocked / UIBus.ShowLocked, the panels check them). When it opens: the
--    padlock pops off with a sparkle and the gold NEW glow stays until the tile is tapped once (saved: "New:<tile>").
--  * Guides (Guides.List): Coach Dex's dialog (Shared/UI/CoachDialog, the tutorial's box) with its lines, then:
--      tile  -> a gold glow + bouncing arrow on it, the rest of the screen dims a little; done when it's tapped
--      place -> the gold path (GuidePath), the gold marker with its name and a gold GO TO button that teleports
--               (GuidePath.Teleport); done when the player is there
--      none  -> done after the lines
--    A small SKIP pill; done by itself after Guides.Timeout s. Saved once (PlayerAction "Guide"); a first-time guide done
--    pays its reward (PlayerEvent "GuideReward": the gold "+25"). Never while on a machine, in a menu / window, a posing
--    show, a trainer roll, the Growth Spurt / alter popup or the tutorial; one at a time, Guides.Gap s apart (BigGap after
--    a big one). Settings "Show Tips" (the "hints" setting) Off = no guides.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Guides = require(Shared.Config.Guides)
local GrowthSpurts = require(Shared.Config.GrowthSpurts)
local Alters = require(Shared.Config.Alters)
local Muscles = require(Shared.Config.Muscles)
local Machines = require(Shared.Config.Machines)
local ClientData = require(Shared.ClientData)
local Theme = require(Shared.UI.Theme)
local Kit = require(Shared.UI.Kit)
local Pieces = require(Shared.UI.Pieces)
local Notify = require(Shared.UI.Notify)
local SideMenu = require(Shared.UI.SideMenu)
local UIBus = require(Shared.UI.UIBus)
local GuidePath = require(Shared.UI.GuidePath)
local CoachDialog = require(Shared.UI.CoachDialog)
local GoTo = require(Shared.GoTo)
local Audio = require(Shared.Audio)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local New, Colors = Theme.New, Theme.Colors

local data = ClientData.Get()

------------------------------------------------------------------------
-- State: what's open, what's ready
------------------------------------------------------------------------
local function seen(id: string): boolean
	local guides = data.guides
	return type(guides) == "table" and type(guides.seen) == "table" and guides.seen[id] == true
end

-- the Growth Spurt / Body Alter "ready" states (like ProgressClient), and the goal bar's share
local function readyState()
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	local spurt = GrowthSpurts.Progress(data, Muscles.Groups, trainable)
	local state = {}
	if spurt.maxed then
		local alter = Alters.Progress(data, Muscles.Groups, trainable)
		state.alterReady = alter.ready == true and not alter.locked
		local highest = type(data.alter) == "table" and data.alter.highest or 0
		state.alterTier = state.alterReady and Alters.TierOf(highest + 1) > Alters.TierOf(highest)
	else
		state.spurtReady = spurt.ready == true
		state.share = GrowthSpurts.Share(spurt, Muscles.Groups)
	end
	return state
end

------------------------------------------------------------------------
-- Locked tiles
------------------------------------------------------------------------
local lockedNow = {} -- [tile] = true while locked
local function showLocked(tile: string)
	local lock = Guides.LockByTile[tile]
	if not lock then return end
	local title, sub = Guides.LockedLines(lock, data, readyState().share)
	Audio.PlayUI("Click", { pitch = 0.7 })
	Notify.Toast(title, sub, "lock", Colors.Gold, "locked" .. tile)
	Remotes.PlayerAction:FireServer("LockedTap", tile)
end
-- (the panels' other ways in check these: UIBus.OpenShop, the Agency desk, the Inventory / Genetics links)
UIBus.IsLocked = function(tile: string): boolean return lockedNow[tile] == true end
UIBus.ShowLocked = showLocked

local function refreshLocks(first: boolean)
	for _, lock in ipairs(Guides.Locks) do
		local locked = not Guides.Met(lock.need, data)
		local was = lockedNow[lock.tile]
		lockedNow[lock.tile] = locked or nil
		SideMenu.SetLocked(lock.tile, locked, function() showLocked(lock.tile) end)
		if not locked and was and not first then
			Audio.PlayUI("TierUnlocked")
		end
		-- the gold NEW glow until it's tapped once
		local newId = "New:" .. lock.tile
		SideMenu.SetNew(lock.tile, not locked and not seen(newId), function()
			Remotes.PlayerAction:FireServer("Guide", { id = newId, how = "tap" })
		end)
	end
end

------------------------------------------------------------------------
-- The guide's own pieces: the dialog, a SKIP pill, a GO TO button, the pointer on a tile
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "Guide", DisplayOrder = 23, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local root = Kit.Root(gui)
local dialog = CoachDialog.new(root, nil)
local RightColumn = require(Shared.UI.RightColumn)
local skip = Kit.Button("Quiet", "Skip", { Name = "Skip", AnchorPoint = Vector2.new(1, 0), Visible = false, Parent = root }, { width = 92, height = 40, textSize = 14 })
skip.Position = UDim2.new(1, -(RightColumn.Width + 60), 0, 56)
Kit.OnTopbar(function() skip.Position = UDim2.new(1, -(RightColumn.Width + 60), 0, Kit.UnderTopbar(root)) end)
local goButton = Kit.Button("Gold", "Go", { Name = "GoTo", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Visible = false, Parent = root },
	{ width = 240, height = 46, textSize = 16 })
-- (the dialog and the GO TO button sit above the hotbar while it shows, like the tutorial's)
task.spawn(function()
	local lifted = nil
	while true do
		local hotbar = playerGui:FindFirstChild("Hotbar")
		local want = hotbar ~= nil and hotbar.Enabled
		if want ~= lifted then
			lifted = want
			local lift = if want then 64 else 0
			dialog.frame.Position = UDim2.new(0.5, 0, 1, -(10 + lift))
			goButton.Position = UDim2.new(0.5, 0, 1, -(112 + lift))
		end
		task.wait(0.3)
	end
end)

-- the pointer: a gold glow around the tile and a gold arrow bouncing next to it; the rest of the screen dims a little
local pointGui = New("ScreenGui", { Name = "GuidePoint", DisplayOrder = 60, ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })
pointGui.ScreenInsets = Enum.ScreenInsets.None -- (whole-screen pixels: the target's position is converted below)
local dimGui = New("ScreenGui", { Name = "GuideDim", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false, Parent = playerGui })
dimGui.ScreenInsets = Enum.ScreenInsets.None
New("Frame", { Name = "Dim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.72, Size = UDim2.fromScale(1, 1), Parent = dimGui })
local glow = New("Frame", { Name = "Glow", BackgroundTransparency = 1, Parent = pointGui }, {
	New("UICorner", { CornerRadius = UDim.new(0, 12) }),
	New("UIStroke", { Name = "Stroke", Color = Colors.Gold, Thickness = 3 }),
})
local arrow = Pieces.Icon("arrow-big-up", Colors.Gold, { Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Parent = pointGui })
arrow:SetAttribute("KeepColor", true)
local pointed: GuiObject? = nil
local function onScreen(object: GuiObject?): boolean
	if not object or not object:IsDescendantOf(playerGui) or object.AbsoluteSize.X < 2 then return false end
	local node: Instance? = object
	while node and node ~= playerGui do
		if node:IsA("GuiObject") and not node.Visible then return false end
		if node:IsA("LayerCollector") and not node.Enabled then return false end
		node = node.Parent
	end
	return true
end
local function pointAt(object: GuiObject?)
	pointed = object
	local targetGui = object and object:FindFirstAncestorWhichIsA("ScreenGui")
	pointGui.Enabled = object ~= nil
	dimGui.Enabled = object ~= nil
	if targetGui then
		pointGui.DisplayOrder = targetGui.DisplayOrder + 1
		dimGui.DisplayOrder = targetGui.DisplayOrder - 1
	end
end
RunService.RenderStepped:Connect(function()
	if not pointed then return end
	if not pointed.Parent then pointAt(nil) return end
	-- (AbsolutePositions share one screen space; this gui's own origin sits at its AbsolutePosition, so subtract it)
	local position = pointed.AbsolutePosition - pointGui.AbsolutePosition
	local size = pointed.AbsoluteSize
	glow.Position = UDim2.fromOffset(position.X - 4, position.Y - 4)
	glow.Size = UDim2.fromOffset(size.X + 8, size.Y + 8)
	local stroke = glow:FindFirstChild("Stroke") :: UIStroke
	local t = os.clock()
	stroke.Transparency = 0.1 + 0.4 * (0.5 + 0.5 * math.sin(t * 5))
	local bounce = math.sin(t * 6) * 6
	local center = position + size / 2
	local width = pointGui.AbsoluteSize.X
	if center.X < width * 0.35 then -- (a tile on the left: the arrow on its right, pointing at it; outside the side menu)
		local bar = pointed:FindFirstAncestor("MenuBar") :: GuiObject?
		local right = if bar and bar:IsA("GuiObject") then bar.AbsolutePosition.X + bar.AbsoluteSize.X - pointGui.AbsolutePosition.X else position.X + size.X
		arrow.Rotation = -90
		arrow.Position = UDim2.fromOffset(math.max(position.X + size.X, right) + 26 + bounce, center.Y)
	elseif center.X > width * 0.65 then
		arrow.Rotation = 90
		arrow.Position = UDim2.fromOffset(position.X - 28 - bounce, center.Y)
	else
		arrow.Rotation = 180
		arrow.Position = UDim2.fromOffset(center.X, position.Y - 28 - bounce)
	end
end)

-- what a guide's `tile` is on screen
local function tileButton(tile: string): GuiObject?
	if tile == "GrowthSpurt" then
		local column = playerGui:FindFirstChild("RightColumn")
		local holder = column and column:FindFirstChild("GrowthSpurt", true)
		return holder and holder:FindFirstChild("Tile") :: GuiObject?
	end
	return SideMenu.Button(tile)
end

------------------------------------------------------------------------
-- Running a guide
------------------------------------------------------------------------
local onMachine = false
Remotes.MachineState.OnClientEvent:Connect(function(state)
	if state == "Enter" then onMachine = true elseif state == "Exit" then onMachine = false end
end)
local BUSY_GUIS = { "TrainerRoll", "GrowReady", "AlterPopup", "Tutorial" }
local function free(): boolean
	if UIBus.MenuOpen or UIBus.GeneticsUp or UIBus.InTutorial() or onMachine then return false end
	if player:GetAttribute("WindowOpen") or UIBus.CoverOpen(playerGui) then return false end
	for _, name in ipairs(BUSY_GUIS) do
		local busy = playerGui:FindFirstChild(name)
		if busy and busy:IsA("LayerCollector") and busy.Enabled then return false end
	end
	return true
end
local function tipsOn(): boolean
	return not (type(data.settings) == "table" and data.settings.hints == "Off")
end

local running = nil -- { guide, id, finish(how) }
local lastEnd, lastBigEnd = -math.huge, -math.huge
local startedAt = os.clock()

local function finish(how: string)
	local run = running
	if not run or run.done then return end
	run.done = true
	running = nil
	dialog.Hide()
	pointAt(nil)
	goButton.Visible = false
	skip.Visible = false
	if run.guide.place then
		GuidePath.Hide("Guide")
		GuidePath.Unmark()
	end
	lastEnd = os.clock()
	if run.guide.big then lastBigEnd = os.clock() end
	Remotes.PlayerAction:FireServer("Guide", { id = run.id, how = how })
	-- (saved here too at once, so the same guide never starts again before the server's copy arrives)
	data.guides = type(data.guides) == "table" and data.guides or { seen = {} }
	data.guides.seen = type(data.guides.seen) == "table" and data.guides.seen or {}
	data.guides.seen[run.id] = true
	-- (its reminder never also plays for the same Growth Spurt / alter: the server saves it too)
	for _, other in ipairs(Guides.List) do
		if other.after == run.guide.id then data.guides.seen[Guides.SaveId(other, data)] = true end
	end
end

local function point(run)
	local guide = run.guide
	if guide.tile then
		local button = tileButton(guide.tile)
		if not onScreen(button) then finish("done") return end
		pointAt(button)
		local connection
		connection = (button :: any).Activated:Connect(function()
			connection:Disconnect()
			if running == run then finish("done") end
		end)
	elseif guide.place then
		GuidePath.Show(guide.place, "Guide")
		GuidePath.Mark(guide.place, nil, guide.label)
		Kit.SetButton(goButton, "Gold", "Go to " .. (guide.label or "it"))
		goButton.Visible = true
		-- done when the player is there (teleported or walked)
		task.spawn(function()
			while running == run do
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local spot = GoTo.Point(guide.place)
				if not spot and rootPart then
					local model = GoTo.Find(guide.place, rootPart.Position, data.growthSpurts or 0)
					spot = model and model:GetPivot().Position
				end
				if rootPart and spot and (rootPart.Position - spot).Magnitude < 16 then
					finish("done")
					return
				end
				task.wait(0.5)
			end
		end)
	else
		finish("done")
	end
end

local function start(guide, id: string)
	local run = { guide = guide, id = id, done = false }
	running = run
	Remotes.PlayerAction:FireServer("Guide", { id = id, how = "shown" })
	dialog.SetReward(guide.reward)
	skip.Visible = true
	Audio.PlayUI("Whoosh")
	dialog.Show(guide.lines, function()
		if running == run then point(run) end
	end)
	task.delay(Guides.Timeout, function()
		if running == run then finish("timeout") end
	end)
end

goButton.Activated:Connect(function()
	local run = running
	if not run or not run.guide.place then return end
	Audio.PlayUI("Click")
	task.spawn(function()
		if GuidePath.Teleport(run.guide.place) and running == run then finish("done") end
	end)
end)
skip.Activated:Connect(function()
	if not running then return end
	Audio.PlayUI("Click")
	finish("skip")
end)

-- the next guide that's due, if any
local function nextGuide()
	local state = readyState()
	for _, guide in ipairs(Guides.List) do
		local id = Guides.SaveId(guide, data)
		if not seen(id) and (not guide.after or seen(guide.after)) and Guides.Met(guide.need, data, state) then
			return guide, id
		end
	end
	return nil
end

Remotes.PlayerEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "GuideReward" and type(info) == "table" and tonumber(info.coins) then
		Notify.Reward("+" .. tostring(info.coins), "Coach Dex's reward", "coin", Colors.Gold, "QuestClaim", "guidereward")
	end
end)

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------
task.spawn(function()
	UIBus.WaitForMenu()
	refreshLocks(true)
	startedAt = os.clock()
	while true do
		task.wait(1)
		refreshLocks(false)
		if running then
			-- a guide waits while a menu or a machine takes the screen (its timeout still runs)
			local hide = onMachine or player:GetAttribute("WindowOpen") == true
			gui.Enabled = not hide
			if hide then pointAt(nil) end
		elseif tipsOn() and free() and os.clock() - startedAt >= Guides.StartDelay then
			local guide, id = nextGuide()
			if guide then
				local gap = if guide.big then Guides.BigGap else Guides.Gap
				if os.clock() - lastEnd >= Guides.Gap and os.clock() - lastBigEnd >= gap then
					gui.Enabled = true
					start(guide, id)
				end
			end
		end
	end
end)
player.CharacterAdded:Connect(function() startedAt = os.clock() end)
