--!strict
-- AccessoryService (owner, 8 Oct night): nobody wears Back, Front or Neck accessories (capes, backpacks, guitars, wings,
-- scarves, necklaces ...): they hide the muscles. Every character in the world (players, gym NPCs, visiting legends, the
-- statue) loses them the moment they appear: on spawn, after an outfit change (Wardrobe / store) or a body rebuild
-- (ApplyDescription adds them back, this takes them off again). Hats, hair and face accessories stay.
local Workspace = game:GetService("Workspace")

local AccessoryService = {}

local HIDDEN_TYPES = {
	[Enum.AccessoryType.Back] = true,
	[Enum.AccessoryType.Front] = true,
	[Enum.AccessoryType.Neck] = true,
}
-- (old accessories have no AccessoryType: where they attach tells)
local HIDDEN_ATTACHMENTS = { BodyBackAttachment = true, BodyFrontAttachment = true, NeckAttachment = true }

function AccessoryService.ShouldHide(accessory: Accessory): boolean
	if HIDDEN_TYPES[accessory.AccessoryType] then return true end
	local handle = accessory:FindFirstChild("Handle")
	if handle then
		for _, child in ipairs(handle:GetChildren()) do
			if child:IsA("Attachment") and HIDDEN_ATTACHMENTS[child.Name] then return true end
		end
	end
	return false
end

local function check(item: Instance)
	if not item:IsA("Accessory") then return end
	local owner = item.Parent
	if not (owner and owner:FindFirstChildOfClass("Humanoid")) then return end
	if AccessoryService.ShouldHide(item) then
		-- deferred: the accessory is still being set up (welded) by whoever added it
		task.defer(function()
			if item.Parent then item:Destroy() end
		end)
	end
end

function AccessoryService.Start()
	for _, item in ipairs(Workspace:GetDescendants()) do check(item) end
	Workspace.DescendantAdded:Connect(check)
end

return AccessoryService
