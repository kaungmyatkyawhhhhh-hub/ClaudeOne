-- SpurtMilestoneService (prompt 11, 21 Oct): small rewards on the way to each Growth Spurt. When the goal bar passes
-- 25%, 50% and 75% (Config.GrowthSpurts Milestones, the same share the HUD shows): a few coins (MilestoneCoinMinutes of
-- coins at your stage) and remote "SpurtMilestone" (percent, coins, spurt) for the client's popup + sound (ProgressClient).
-- Checked after reps (GameEvents "Rep", at most once a second per player). Saved: data.spurtMilestones = { spurt, got }
-- (got = how many milestones of that spurt were paid). A record for another spurt (a new spurt, an old save) starts
-- quietly at the milestones already passed, so nobody gets a burst of old rewards. Not at 7'0" (alters have their own).
-- The first spurt's milestones are also the funnel steps 13a / 13b / 13c (Analytics.SpurtMilestone).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local GrowthSpurts = require(Config.GrowthSpurts)
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local PumpShop = require(Config.PumpShop)
local PlayerData = require(script.Parent.PlayerData)
local GameEvents = require(script.Parent.GameEvents)
local Analytics = require(script.Parent.Analytics)

local SpurtMilestoneService = {}

local remote: RemoteEvent
local lastCheck = {} -- [player] = os.clock()

local function passed(share: number): number
	local n = 0
	for i, percent in ipairs(GrowthSpurts.Milestones) do
		if share >= percent / 100 then n = i end
	end
	return n
end

function SpurtMilestoneService.Check(player)
	local data = PlayerData.Get(player)
	if not data or not data.muscles then return end
	local spurts = data.growthSpurts or 0
	if GrowthSpurts.IsMaxed(spurts) then return end
	local progress = GrowthSpurts.Progress(data, Muscles.Groups, Machines.TrainableMuscles(spurts))
	local n = passed(GrowthSpurts.Share(progress, Muscles.Groups))
	local record = type(data.spurtMilestones) == "table" and data.spurtMilestones or nil
	if not record or record.spurt ~= spurts then
		-- (a fresh record: the milestones already passed count as paid; a brand-new spurt starts below 25% anyway)
		PlayerData.SetTable(player, "spurtMilestones", { spurt = spurts, got = n })
		return
	end
	local got = tonumber(record.got) or 0
	if n <= got then return end
	local each = math.max(1, math.floor(PumpShop.Rate(spurts) * GrowthSpurts.MilestoneCoinMinutes + 0.5))
	local coins = each * (n - got)
	PlayerData.AddCoins(player, coins)
	PlayerData.SetTable(player, "spurtMilestones", { spurt = spurts, got = n })
	local percent = GrowthSpurts.Milestones[n]
	remote:FireClient(player, { percent = percent, coins = coins, spurt = spurts + 1, last = n == #GrowthSpurts.Milestones })
	if spurts == 0 then
		for i = got + 1, n do Analytics.SpurtMilestone(player, GrowthSpurts.Milestones[i]) end
	end
end

function SpurtMilestoneService.Start()
	remote = ReplicatedStorage.Remotes:FindFirstChild("SpurtMilestone")
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = "SpurtMilestone"
		remote.Parent = ReplicatedStorage.Remotes
	end
	GameEvents.On("Rep", function(player)
		local now = os.clock()
		if now - (lastCheck[player] or 0) < 1 then return end
		lastCheck[player] = now
		SpurtMilestoneService.Check(player)
	end)
	Players.PlayerRemoving:Connect(function(player) lastCheck[player] = nil end)
end

return SpurtMilestoneService
