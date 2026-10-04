-- Client-only signals between UI scripts (e.g. inspect mode opening the genetics screen).
local UIBus = {}

local function signal()
	local event = Instance.new("BindableEvent")
	return { Fire = function(_, ...) event:Fire(...) end, Event = event.Event }
end

UIBus.OpenGenetics = signal()
UIBus.GeneticsVisible = signal() -- fired with true/false; other overlays hide while the genetics screen is up

return UIBus
