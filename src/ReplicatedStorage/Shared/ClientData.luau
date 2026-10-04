-- Client-side read-only mirror of this player's data.
-- ClientData.Get() yields until loaded; ClientData.Changed fires (path, value).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local ClientData = {}

local changedEvent = Instance.new("BindableEvent")
ClientData.Changed = changedEvent.Event

local data = nil

-- Changes sent before the snapshot was taken are already in it, so drop them.
Remotes.DataChanged.OnClientEvent:Connect(function(path, value)
	if not data then return end
	local parent = data
	for i = 1, #path - 1 do
		parent = parent[path[i]]
	end
	parent[path[#path]] = value
	changedEvent:Fire(path, value)
end)

task.spawn(function()
	while not data do
		local ok, result = pcall(function()
			return Remotes.GetData:InvokeServer()
		end)
		if ok and result then
			data = result
		else
			task.wait(1)
		end
	end
end)

function ClientData.Get()
	while not data do
		task.wait()
	end
	return data
end

function ClientData.IsLoaded()
	return data ~= nil
end

return ClientData
