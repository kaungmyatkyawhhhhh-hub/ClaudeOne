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
UIBus.OpenTitles = signal()      -- the menu screen opens the Title Book
UIBus.OpenSettings = signal()    -- the menu screen opens Settings
UIBus.MenuPanelVisible = signal() -- fired with true/false when Titles/Settings open/close (the menu steps aside)
UIBus.MenuClosed = signal()      -- the player pressed Play on the menu screen
UIBus.RepFlash = signal()        -- a rep landed: (weights { [muscleId] = 0..1 }, strong) for the body-map widget's flash

-- Screens that cover the middle of the view: the Stats labels and the Muscles button step aside while any is open.
UIBus.CoverGuis = { "Wardrobe", "Emotes", "Crew", "ClothingStore", "ProgressMirror", "ArmWrestle", "Settings", "TitleBook", "Store", "GeneticsScreen", "MusclesScreen" }
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

-- Side panels (Settings, Daily, Wardrobe, Crew, Poses, Titles, Muscles) register a close function. Opening one closes the others,
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

return UIBus
