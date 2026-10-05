-- Client-only signals between UI scripts (e.g. inspect mode opening the genetics screen).
local UIBus = {}

local function signal()
	local event = Instance.new("BindableEvent")
	return { Fire = function(_, ...) event:Fire(...) end, Event = event.Event }
end

UIBus.OpenGenetics = signal()
UIBus.GeneticsVisible = signal() -- fired with true/false; other overlays hide while the genetics screen is up
UIBus.StatsVisible = signal()    -- fired with true/false when the Stats overlay opens/closes
UIBus.OpenTitles = signal()      -- the menu screen opens the Title Book
UIBus.OpenSettings = signal()    -- the menu screen opens Settings
UIBus.MenuPanelVisible = signal() -- fired with true/false when Titles/Settings open/close (the menu steps aside)
UIBus.MenuClosed = signal()      -- the player pressed Play on the menu screen

-- True while the menu screen is up (MenuClient sets it as soon as it starts).
UIBus.MenuOpen = false

-- Yields until the menu screen is gone (returns at once if there is no menu).
function UIBus.WaitForMenu()
	while UIBus.MenuOpen do
		UIBus.MenuClosed.Event:Wait()
	end
end

return UIBus
