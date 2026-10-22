-- Client-only signals between UI scripts (e.g. inspect mode opening the genetics screen).
local UIBus = {}

local function signal()
	local event = Instance.new("BindableEvent")
	return { Fire = function(_, ...) event:Fire(...) end, Event = event.Event }
end

UIBus.OpenGenetics = signal()
UIBus.GeneticsVisible = signal() -- fired with true/false; other overlays hide while the genetics screen is up
UIBus.StatsVisible = signal()    -- fired with true/false when the Stats button shows/hides the labels around the character
UIBus.StatsLabels = signal()     -- same moment, for StatsLabelsClient (true = show the labels)
UIBus.MusclesVisible = signal()  -- fired with true/false when the "Your muscles" panel opens/closes
UIBus.OpenMuscles = signal()     -- any screen can ask for the "Your muscles" panel (the machine body map taps it)
UIBus.GoCoach = signal()        -- (prompt 31) go to Coach Dex's counter (the Shop window's link)
UIBus.GoPumpShop = signal()     -- (prompt 28) go to the PUMP SHOP (the Shop window's link; was a side menu tile)
UIBus.OpenAgency = signal()      -- (tab? "My") open the TRAINERS window (prompt 24; prompt 28: "My" = its MY TRAINERS tab)
UIBus.StartAlter = signal()      -- (prompt 22) start the Body Alter transformation (the PUMP SHOP's ALTER NOW)
UIBus.OpenNeeds = signal()       -- (prompt 54) open "what to train" for the next Growth Spurt / alter (Coach Dex's WHAT TO TRAIN)
UIBus.OpenInventory = signal()   -- (tab "Titles" / "Auras" / "Items", auraId?) open the Inventory window on a tab
UIBus.OpenTitles = UIBus.OpenInventory -- (the old name: the Inventory window was the Titles window)
UIBus.OpenSettings = signal()    -- the menu screen opens Settings
UIBus.MenuPanelVisible = signal() -- fired with true/false when Inventory/Settings open/close (the menu steps aside)
UIBus.MenuClosed = signal()      -- the player pressed Play on the menu screen
UIBus.OpenShop = signal()        -- (tab id) the coins "+" and other buttons open the Shop on a tab ("Coins", "Passes")
UIBus.OpenQuests = signal()      -- (tab id) open the Quests panel on a tab ("Daily", "Rewards", "Achievements")
UIBus.OpenStats = signal()       -- (tab id) open the Stats panel on a tab ("Muscles", "Lifts", "Genetics")
UIBus.AutoRepCard = signal()     -- (prompt 60) the REP button's AUTO chip: show the Auto Rep card (OfferClient)
UIBus.AutoRepOffer = signal()    -- (prompt 60) a set ended after 150+ hand-tapped reps: the soft Auto Rep offer (OfferClient)
UIBus.RepFlash = signal()        -- a rep landed: (weights { [muscleId] = 0..1 }, strong) for the body-map widget's flash

-- Screens that cover the middle of the view: the Stats labels and the Muscles button step aside while any is open.
UIBus.CoverGuis = { "Wardrobe", "Emotes", "Crew", "ClothingStore", "ProgressMirror", "ArmWrestle", "Settings", "Inventory", "Store", "GeneticsScreen", "MusclesScreen", "DailyQuests", "Trainers", "MealShop", "PosingRound", "TrainerRoll" } -- (prompt 49: the roll reveal)
function UIBus.CoverOpen(playerGui)
	for _, name in ipairs(UIBus.CoverGuis) do
		local gui = playerGui:FindFirstChild(name)
		if gui and gui:IsA("ScreenGui") and gui.Enabled then return true end
	end
	return false
end

-- True while the player is on a machine (BodyMapClient keeps it). Short screens drop the world stat labels meanwhile.
UIBus.Training = false
UIBus.ShortScreen = 460 -- screens shorter than this (phones in landscape) are "short"

-- Side panels (Settings, Daily, Wardrobe, Crew, Poses, Inventory, Muscles) register a close function. Opening one closes the others,
-- and getting on a machine closes all of them (so nothing floats over the lift or stays open with no way to close it).
local panels = {}
function UIBus.RegisterPanel(name, close)
	panels[name] = close
end
function UIBus.PanelOpened(name)
	for other, close in pairs(panels) do
		if other ~= name then close() end
	end
end
function UIBus.CloseAllPanels()
	for _, close in pairs(panels) do close() end
end

-- True while the menu screen is up (MenuClient sets it as soon as it starts).
UIBus.MenuOpen = false

-- Yields until the menu screen is gone (returns at once if there is no menu).
function UIBus.WaitForMenu()
	while UIBus.MenuOpen do
		UIBus.MenuClosed.Event:Wait()
	end
end

-- (prompt 11, 21 Oct) Yields until the player is really playing: the menu is gone, the genetics screen (first join) is
-- closed and `extra` seconds (3) have passed. Heavy things that aren't needed to start (the shop's Roblox prices and
-- pictures, other preloads) wait for this, so joining and the tutorial's first steps never stall on them.
UIBus.GeneticsUp = false
UIBus.GeneticsVisible.Event:Connect(function(visible) UIBus.GeneticsUp = visible == true end)
function UIBus.WaitForGameplay(extra: number?)
	UIBus.WaitForMenu()
	task.wait(1.5) -- (the genetics screen opens a moment after Play)
	while UIBus.GeneticsUp do
		UIBus.GeneticsVisible.Event:Wait()
	end
	task.wait(extra or 3)
end

-- (22 Oct, owner: "hide the non-tutorial UI during the tutorial") The tutorial's state for the rest of the HUD.
--   UIBus.InTutorial()        true while the tutorial runs (the save's tutorial step, so it's right from the first frame)
--   UIBus.TutorialTarget      the current step's MachineId / "Coach", or nil (TutorialClient keeps it); the machine signs
--                             show only on it
--   UIBus.TutorialChanged     fires when the step or its target changes, and when the tutorial ends
--   UIBus.AfterTutorial(fn)   runs fn now, or once the tutorial is over (season / Muscle of the Day notices)
-- (prompt 39b) locks (GuideClient): UIBus.IsLocked(key) / UIBus.ShowLocked(key) for a side menu tile id or a menu tab
-- ("Inventory/Gear"); LocksChanged fires when one opens (Kit.Tabs repaints its padlocks)
UIBus.LocksChanged = signal()
UIBus.TutorialTarget = nil
UIBus.TutorialChanged = signal()
function UIBus.InTutorial(): boolean
	local Shared = script.Parent.Parent
	local ok, ClientData = pcall(require, Shared.ClientData)
	if not ok or not ClientData.IsLoaded() then return false end
	local Onboarding = require(Shared.Config.Onboarding)
	local data = ClientData.Get()
	return (data.onboarding and data.onboarding.tutorialStep or Onboarding.Done) < Onboarding.Done
end
function UIBus.AfterTutorial(fn)
	task.spawn(function()
		local Shared = script.Parent.Parent
		require(Shared.ClientData).Get()
		while UIBus.InTutorial() do task.wait(1) end
		fn()
	end)
end

return UIBus
