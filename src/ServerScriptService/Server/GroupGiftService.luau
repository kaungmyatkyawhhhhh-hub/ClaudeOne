-- GroupGiftService (owner, 23 Oct): the group perks welcome gift. A member of the group that owns GYM ARC
-- (Config/Trainers GroupGift.groupId) gets it once (saved: data.groupGift.given): GroupGift.coins coins, GroupGift.rolls free
-- trainer roll(s), the CREW MEMBER title (Config/Titles, condition "groupGift") and a free COACH LOU (Rare) at BASE LV 1
-- with the normal roll reveal ("NEW!" or a dupe; TrainerService.Gift sends it). The client shows a welcome toast and the
-- reveal once the menu is done (TrainerClient, the Trainers remote's "Gift"). Joining never waits: the group check runs
-- in its own thread, in pcall, tried once more after RETRY seconds if it errors. Studio: Workspace attribute TestGroupGift
-- = true acts as a member (once per save, as usual: use FreshPlayer to see it again).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Trainers = require(ReplicatedStorage.Shared.Config.Trainers)
local PlayerData = require(script.Parent.PlayerData)
local Economy = require(game:GetService("ReplicatedStorage").Shared.Config.Economy) -- (prompt 61: rewards at the player's stage)
local Analytics = require(script.Parent.Analytics)

local GroupGiftService = {}

local RETRY = 5

local function isMember(player: Player): boolean?
	if RunService:IsStudio() and Workspace:GetAttribute("TestGroupGift") == true then return true end
	for attempt = 1, 2 do
		local ok, result = pcall(function() return player:IsInGroup(Trainers.GroupGift.groupId) end)
		if ok then return result == true end
		if attempt == 1 then task.wait(RETRY) end
	end
	warn("[GroupGiftService] couldn't check the group for " .. player.Name)
	return nil
end

local function give(player: Player)
	local data = PlayerData.Get(player)
	if not data or (type(data.groupGift) == "table" and data.groupGift.given) then return end
	if not isMember(player) or not player.Parent then return end
	data = PlayerData.Get(player)
	if not data or (type(data.groupGift) == "table" and data.groupGift.given) then return end
	local gift = Trainers.GroupGift
	-- saved first: it's given once, whatever happens next
	PlayerData.SetTable(player, "groupGift", { given = true, at = os.time() })
	PlayerData.AddCoins(player, Economy.Reward(data.growthSpurts, Economy.Rewards.GroupGift, gift.coins)) -- (prompt 61)
	require(script.Parent.TitleService).Check(player) -- (the CREW MEMBER title: condition "groupGift")
	local ok, err = pcall(function() require(script.Parent.TrainerService).Gift(player, gift.trainer, gift.rolls) end)
	if not ok then warn("[GroupGiftService] the trainer gift failed for " .. player.Name .. ": " .. tostring(err)) end
	Analytics.Event(player, "GroupGift", 1)
end

function GroupGiftService.Start()
	PlayerData.Loaded:Connect(function(player) task.spawn(give, player) end)
	for _, player in ipairs(Players:GetPlayers()) do
		if PlayerData.Get(player) then task.spawn(give, player) end
	end
end

return GroupGiftService
