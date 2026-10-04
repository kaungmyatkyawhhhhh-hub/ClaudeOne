-- Muscle of the Day: writes today's group on the chalkboard by the front desk (Workspace ... MuscleOfTheDayBoard,
-- its SurfaceGui "Muscle" label) and on the board's MuscleOfTheDay attribute. The 2x itself is in Config.Gains.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Muscles = require(Config.Muscles)
local MuscleOfTheDay = require(Config.MuscleOfTheDay)

local MuscleOfTheDayService = {}

local function updateBoard()
	local board = Workspace:FindFirstChild("MuscleOfTheDayBoard", true)
	if not board then return end
	local groupId = MuscleOfTheDay.GroupId()
	board:SetAttribute("MuscleOfTheDay", groupId)
	local label = board:FindFirstChild("Muscle", true)
	if label and label:IsA("TextLabel") then
		label.Text = Muscles.GroupById[groupId].name .. " · " .. MuscleOfTheDay.Multiplier .. "x gains"
	end
end

function MuscleOfTheDayService.Start()
	updateBoard()
	task.spawn(function()
		while true do
			-- wake up just after midnight UTC (and at least every 10 minutes, in case the clock jumps)
			task.wait(math.min(MuscleOfTheDay.SecondsLeft() + 2, 600))
			updateBoard()
		end
	end)
end

return MuscleOfTheDayService
