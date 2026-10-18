-- crew_names_backfill (19 Oct, owner: two crews had the tag SRT9): one-time, run in Studio (Edit mode, DataStore access on).
-- Claims every existing crew's name and tag in CrewNamesV1 (what CrewService now checks), oldest crew first. A crew whose
-- tag (or name) an older crew already holds gets a new free tag (or " 2" on its name) and a one-time message for its leader
-- (record.notice, shown by CrewService when they next join). Crews with no members are deleted. DRY_RUN = true only reports.
local DataStoreService = game:GetService("DataStoreService")
local DRY_RUN = true

local crewStore = DataStoreService:GetDataStore("CrewsV1")
local scoreStore = DataStoreService:GetOrderedDataStore("CrewLeaderboardV1")
local namesStore = DataStoreService:GetDataStore("CrewNamesV1")

local function count(members)
	local n = 0
	for _ in pairs(members or {}) do n += 1 end
	return n
end

-- every crew with a leaderboard entry (crews are only listed there)
local crews = {}
local pages = scoreStore:GetSortedAsync(false, 100)
while true do
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local record = crewStore:GetAsync(entry.key)
		table.insert(crews, { id = entry.key, record = record })
	end
	if pages.IsFinished then break end
	pages:AdvanceToNextPageAsync()
end
table.sort(crews, function(a, b)
	return ((a.record and a.record.created) or 0) < ((b.record and b.record.created) or 0)
end)

local taken = {} -- [key] = crewId
local report = {}
local function free(key) return taken[key] == nil end
for _, crew in ipairs(crews) do
	local record = crew.record
	if not record or count(record.members) == 0 then
		table.insert(report, "delete empty / missing crew " .. crew.id .. " (" .. tostring(record and record.name) .. ")")
		if not DRY_RUN then
			pcall(crewStore.RemoveAsync, crewStore, crew.id)
			pcall(scoreStore.RemoveAsync, scoreStore, crew.id)
		end
		continue
	end
	local notices = {}
	local tag = record.tag
	if not free("tag:" .. tag:upper()) then
		local newTag
		for n = 1, 9 do
			local candidate = tag:sub(1, 3):upper() .. n
			if free("tag:" .. candidate) then newTag = candidate break end
		end
		while not newTag do
			local candidate = "C" .. math.random(100, 999)
			if free("tag:" .. candidate) then newTag = candidate end
		end
		table.insert(notices, "Another crew already had the tag " .. tag .. ", so your crew's tag is now " .. newTag .. ".")
		tag = newTag
	end
	local name = record.name
	if not free("name:" .. name:lower()) then
		local n = 2
		while not free("name:" .. (name .. " " .. n):lower()) do n += 1 end
		table.insert(notices, "Another crew already had the name " .. name .. ", so your crew is now " .. name .. " " .. n .. ".")
		name = name .. " " .. n
	end
	taken["tag:" .. tag:upper()] = crew.id
	taken["name:" .. name:lower()] = crew.id
	table.insert(report, string.format("%s %s [%s] owner %s, made %s%s", crew.id, name, tag, tostring(record.owner),
		record.created and os.date("!%Y-%m-%d", record.created) or "?", #notices > 0 and ("  CHANGED: " .. table.concat(notices, " ")) or ""))
	if not DRY_RUN then
		if #notices > 0 then
			crewStore:UpdateAsync(crew.id, function(stored)
				if not stored then return nil end
				stored.tag, stored.name = tag, name
				stored.notice = table.concat(notices, " ")
				return stored
			end)
		end
		namesStore:SetAsync("tag:" .. tag:upper(), crew.id)
		namesStore:SetAsync("name:" .. name:lower(), crew.id)
	end
end
return (DRY_RUN and "DRY RUN\n" or "DONE\n") .. table.concat(report, "\n")
