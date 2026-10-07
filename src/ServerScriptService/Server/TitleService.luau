-- Titles: tracks lifetime/session rep stats, grants titles when their conditions are met,
-- awards linked badges, and shows the equipped title above the player's head.
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Titles = require(Config.Titles)
local Muscles = require(Config.Muscles)
local Machines = require(Config.Machines)
local GrowthSpurts = require(Config.GrowthSpurts)
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.Remotes

local SET_BREAK = 4 -- seconds without a rep ends a set (matches the HUD)

local TitleService = {}
local sessions = {} -- [player] = { sessionReps, setReps, lastRep }

local function session(player)
	local s = sessions[player]
	if not s then
		s = { sessionReps = 0, setReps = 0, lastRep = 0 }
		sessions[player] = s
	end
	return s
end

-- Equipped title above the head (and above the player's name): Oswald in the rarity color with a
-- thin dark stroke and a tiny plate disc in front. Sized in studs so it reads the same at any distance.
-- The client adds the legendary shine and dims the local player's own title.
local TAG = {
	Height = 0.7,        -- studs
	Offset = 2.75,       -- studs above the head center (clears the name)
	MaxDistance = 60,
	DiscScale = 0.6,     -- disc height relative to the text height
	Gap = 0.18,          -- studs between disc and text
}
local function textRatio(text)
	-- width / height of the text in the heading font, so the billboard can be exactly as wide as the title
	local ok, bounds = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = Theme.Fonts.Heading
		params.Size = 100
		params.Width = 100000
		return TextService:GetTextBoundsAsync(params)
	end)
	if ok and bounds.Y > 0 then return bounds.X / bounds.Y end
	return #text * 0.5
end

-- (measuring the text yields: on join the spawn and the data load both update the tag at once, and each made its own, so
-- two tags sat on top of each other. Only the newest update builds a tag, and every old one goes first.)
local tagUpdates = setmetatable({}, { __mode = "k" }) -- [player] = number of the newest update
local function clearTags(head)
	for _, child in ipairs(head:GetChildren()) do
		if child.Name == "TitleTag" then child:Destroy() end
	end
end

local function updateTag(player)
	local update = (tagUpdates[player] or 0) + 1
	tagUpdates[player] = update
	local data = PlayerData.Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then return end
	local title = data.titles.equipped and Titles.ById[data.titles.equipped]
	if not title then
		clearTags(head)
		return
	end

	local New = Theme.New
	local text = title.name
	local rarity = Theme.Rarity[title.rarity]
	local textWidth = textRatio(text) * TAG.Height
	if tagUpdates[player] ~= update or not head.Parent then return end -- a newer update is building it
	clearTags(head)
	local discWidth = TAG.Height * TAG.DiscScale
	local width = discWidth + TAG.Gap + textWidth
	local tag = New("BillboardGui", {
		Name = "TitleTag",
		Size = UDim2.fromScale(width, TAG.Height),
		StudsOffset = Vector3.new(0, TAG.Offset, 0),
		MaxDistance = TAG.MaxDistance,
		LightInfluence = 0,
		Parent = head,
	}, {
		Theme.List(Enum.FillDirection.Horizontal, nil, Enum.HorizontalAlignment.Center),
	})
	tag:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(TAG.Gap / width, 0)
	tag:SetAttribute("Rarity", title.rarity)
	tag:SetAttribute("Owner", player.UserId)
	-- text is the rarity color; secret titles have a black plate, so their text stays white to be readable
	local textColor = title.rarity == "Secret" and Theme.Colors.Text or rarity.Fill
	local disc = Theme.PlateDisc(rarity, { Name = "Disc", LayoutOrder = 1, Size = UDim2.fromScale(discWidth / width, TAG.DiscScale), Parent = tag })
	Theme.Aspect(1, Enum.DominantAxis.Height).Parent = disc
	New("TextLabel", {
		Name = "Title",
		LayoutOrder = 2,
		Size = UDim2.fromScale(textWidth / width, 1),
		BackgroundTransparency = 1,
		Text = text,
		FontFace = Theme.Fonts.Heading,
		TextScaled = true, -- stud-sized billboard: the only place text may scale
		TextColor3 = textColor,
		Parent = tag,
	}, {
		New("UITextSizeConstraint", { MinTextSize = Theme.TextSize.Small, MaxTextSize = 48 }),
		New("UIStroke", { Color = Theme.Colors.Shadow, Thickness = 1, Transparency = 0.45 }), -- subtle, only for readability
	})
end

local function context(player, data)
	local groups, goalGroups = {}, {}
	local trainable = Machines.TrainableMuscles(data.growthSpurts)
	for _, group in ipairs(Muscles.Groups) do
		groups[group.id] = Muscles.GetGroupLevel(data.muscles, group.id)
		goalGroups[group.id] = GrowthSpurts.GoalLevel(data.muscles, group, trainable)
	end
	return {
		data = data,
		groups = groups,
		goalGroups = goalGroups,
		cap = GrowthSpurts.GetLevelCap(data.growthSpurts),
		mastery = GrowthSpurts.GetMasteryLevel(data.growthSpurts),
		heightInches = GrowthSpurts.GetHeight(data.growthSpurts),
		session = session(player),
	}
end

function TitleService.Equip(player, titleId)
	if PlayerData.EquipTitle(player, titleId) then
		updateTag(player)
	end
end

-- Grant every title whose condition is now met.
function TitleService.Check(player)
	local data = PlayerData.Get(player)
	if not data then return end
	local ctx = context(player, data)
	for _, title in ipairs(Titles.List) do
		if not data.titles.owned[title.id] and Titles.Check(title, ctx) then
			if PlayerData.GrantTitle(player, title.id) then
				if not data.titles.equipped then TitleService.Equip(player, title.id) end
				if title.badgeId then
					pcall(BadgeService.AwardBadge, BadgeService, player.UserId, title.badgeId)
				end
				Remotes.PlayerEvent:FireClient(player, "TitleUnlocked", { id = title.id })
			end
		end
	end
end

-- Called by MachineService for every validated rep.
function TitleService.OnRep(player)
	local data = PlayerData.Get(player)
	if not data then return end
	local s = session(player)
	local now = os.clock()
	if now - s.lastRep > SET_BREAK then s.setReps = 0 end
	s.setReps += 1
	s.lastRep = now
	s.sessionReps += 1
	PlayerData.SetStat(player, "totalReps", data.stats.totalReps + 1)
	if s.setReps > data.stats.bestSet then
		PlayerData.SetStat(player, "bestSet", s.setReps)
	end
	TitleService.Check(player)
end

function TitleService.Start()
	local function hook(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			PlayerData.WaitFor(player)
			updateTag(player)
		end)
		task.spawn(function()
			if PlayerData.WaitFor(player) then
				TitleService.Check(player) -- e.g. genetics titles on join
				updateTag(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in ipairs(Players:GetPlayers()) do hook(player) end
	Players.PlayerRemoving:Connect(function(player) sessions[player] = nil end)
end

return TitleService
