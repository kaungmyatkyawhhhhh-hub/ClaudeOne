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
local lockedNow = {} -- [tile id or "<menu>/<tab>"] = true while locked
local function showLocked(key: string)
	local lock = Guides.LockOf(key)
	if not lock then return end
	local title, sub = Guides.LockedLines(lock, data, readyState().share)
	Audio.PlayUI("Click", { pitch = 0.7 })
	Notify.Toast(title, sub, "lock", Colors.Gold, "locked" .. key)
	Remotes.PlayerAction:FireServer("LockedTap", key)
end
-- (the panels' other ways in check these: UIBus.OpenShop, the Agency desk, the Inventory / Genetics links; and every
-- menu tab with a lock, Kit.Tabs / Kit.OpenTab)
UIBus.IsLocked = function(tile: string): boolean return lockedNow[tile] == true end
UIBus.ShowLocked = showLocked

local function lockState()
	-- (a pass's auras count as owning an aura: the AURAS tab opens for a pass owner)
	return { passAura = player:GetAttribute("Pass_AuraPack") == true or player:GetAttribute("Pass_VIP") == true }
end
local function refreshLocks(first: boolean)
	local state = lockState()
	local changedAny = first
	-- (prompt 39b) the tabs inside menus
	for _, lock in ipairs(Guides.TabLocks) do
		local locked = not Guides.Met(lock.need, data, state)
		if (lockedNow[lock.key] == true) ~= locked then changedAny = true end
		lockedNow[lock.key] = locked or nil
	end
	for _, lock in ipairs(Guides.Locks) do
		local locked = not Guides.Met(lock.need, data, state)
		if (lockedNow[lock.tile] == true) ~= locked then changedAny = true end
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
	if changedAny then UIBus.LocksChanged:Fire() end
end

------------------------------------------------------------------------
-- The guide's own pieces: the dialog, a SKIP pill, a GO TO button, the pointer on a tile
------------------------------------------------------------------------
local gui = Theme.ScreenGui({ Name = "Guide", DisplayOrder = 23, Parent = playerGui })
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
local root = Kit.Root(gui)
local dialog = CoachDialog.new(root, nil)
-- (prompt 53) SKIP: the tutorial's small dark pill (Shared/UI/SkipPill), one tap here
local finish -- (below)
local skip = require(Shared.UI.SkipPill).new("GuideSkip", function()
	finish("skip") -- (nothing when no guide is running)
end, false)
local goButton = Kit.Button("Gold", "Go", { Name = "GoTo", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -130), Visible = false, Parent = root },
	{ width = 240, height = 38, textSize = 15 })
Theme.SetChrome(goButton) -- (owner, 23 Oct, chrome reset)
-- (the dialog and the GO TO button sit above the hotbar / stamina bar like the tutorial's, GO TO 12 px above the dialog)
task.spawn(function()
	while true do
		local clear = CoachDialog.BottomClear(root)
		dialog.frame.Position = UDim2.new(0.5, 0, 1, -clear)
		local above = dialog.Height()
		goButton.Position = UDim2.new(0.5, 0, 1, -(clear + (if above > 0 then above + CoachDialog.Gap else 0)))
		task.wait(0.2)
	end
end)

-- the pointer (prompt 53a: Shared/UI/Spotlight, the tutorial's too): the rest of the screen dims, a gold glow on the tile and
-- a gold arrow bouncing next to it
local Spotlight = require(Shared.UI.Spotlight)
local onScreen = Spotlight.Shown
local function pointAt(object: GuiObject?)
	Spotlight.Point(object)
end

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
local BUSY_GUIS = { "TrainerRoll", "GrowReady", "AlterReady", "Tutorial", "Offer" } -- (prompt 39b: not with an offer card; AlterReady = AlterPopup's)
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

function finish(how: string)
	local run = running
	if not run or run.done then return end
	run.done = true
	running = nil
	UIBus.GuideRunning = false
	dialog.Hide()
	pointAt(nil)
	goButton.Visible = false
	skip.SetShown(false)
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
					local model = GoTo.Find(guide.place, rootPart.Position, data)
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
	UIBus.GuideRunning = true
	Remotes.PlayerAction:FireServer("Guide", { id = id, how = "shown" })
	-- (prompt 61) the reward at your stage, as the server pays it
	local Economy = require(Shared.Config.Economy)
	dialog.SetReward(if guide.reward then Economy.Reward(ClientData.Get().growthSpurts, Economy.Rewards.Guide, guide.reward) else nil)
	skip.SetShown(true)
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
				-- (Studio: a "TestGuideGap" number on Workspace = the gaps, to check a queue quickly)
				local testGap = if RunService:IsStudio() then tonumber(workspace:GetAttribute("TestGuideGap")) else nil
				local gap = testGap or (if guide.big then Guides.BigGap else Guides.Gap)
				if os.clock() - lastEnd >= (testGap or Guides.Gap) and os.clock() - lastBigEnd >= gap then
					gui.Enabled = true
					start(guide, id)
				end
			end
		end
	end
end)
player.CharacterAdded:Connect(function() startedAt = os.clock() end)
