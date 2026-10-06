--!strict
-- AreaSignsClient: signs of areas that unlock with Growth Spurts (tagged "AreaSign" by the builders, attributes Gym =
-- a Machines.GymUnlock key and Title). While the area is locked for you the sign shows its title plus
-- "Opens at Growth Spurt N"; once it's open it shows just the title. Local only (each player sees their own state).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Machines = require(Shared.Config.Machines)
local ClientData = require(Shared.ClientData)

local TAG = "AreaSign"

local function refresh(sign: Instance)
	local gui = sign:FindFirstChildWhichIsA("SurfaceGui")
	local title = gui and gui:FindFirstChild("Title") :: TextLabel?
	local rule = gui and gui:FindFirstChild("Rule") :: TextLabel?
	if not (title and rule) then return end
	local gym = sign:GetAttribute("Gym")
	local need = typeof(gym) == "string" and Machines.GymUnlock[gym] or 0
	local data = ClientData.Get()
	local spurts = data and data.growthSpurts or 0
	local locked = spurts < need
	title.Text = tostring(sign:GetAttribute("Title") or title.Text)
	if locked then
		title.Size = UDim2.fromScale(0.94, 0.56)
		title.Position = UDim2.fromScale(0.03, 0.04)
		rule.Text = "Opens at Growth Spurt " .. tostring(need)
		rule.Size = UDim2.fromScale(0.94, 0.34)
		rule.Position = UDim2.fromScale(0.03, 0.62)
		rule.Visible = true
	else
		title.Size = UDim2.fromScale(0.94, 0.9)
		title.Position = UDim2.fromScale(0.03, 0.05)
		rule.Visible = false
	end
end

local function refreshAll()
	for _, sign in ipairs(CollectionService:GetTagged(TAG)) do refresh(sign) end
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(refresh)
ClientData.Changed:Connect(function(path: any)
	if typeof(path) ~= "table" or path[1] == "growthSpurts" then
		refreshAll()
	end
end)
refreshAll()
