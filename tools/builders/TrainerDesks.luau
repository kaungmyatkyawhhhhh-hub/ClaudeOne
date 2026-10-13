-- TrainerDesks builder (run once in Studio, Edit mode; see tools/bake.md): a Trainer Desk at the front of each gym
-- (owner's feature run, task 7B): a wood counter with a white top, steel corner trims and a dark kick plate, a front
-- panel saying PERSONAL TRAINERS, a sign board on two posts behind it, a stool, and small props on the counter (a
-- clipboard, a stopwatch, a whistle, a water bottle). An invisible TrainerPoint part in front of the counter (tag
-- "TrainerDesk") carries the prompt (TrainerService); it opens the Trainers panel in hire mode.
-- Places (free floor checked 13 Oct): starter gym front left (between the smoothie cart and the shake machine), pro gym
-- front left, beach gym just inside the gate.
-- Usage: require(game.ServerStorage._Builders.TrainerDesks).Build()
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Theme = require(ReplicatedStorage.Shared.UI.Theme)
local Kit = require(script.Parent.Kit)

local M = Enum.Material
local hex = Kit.hex
local rad = math.rad

local Builder = {}

local WOOD, DARK, STEEL, WHITE, RUBBER = hex("#8A6240"), hex("#1E1E22"), hex("#C9CCD2"), hex("#F4F1EA"), hex("#141416")

-- where: { folder path, floor point under the desk's middle, the point the desk faces (the customers' side) }
Builder.Places = {
	{ parent = { "Gym", "StarterGym" }, at = Vector3.new(-17.5, 0, -7.6), face = Vector3.new(-17.5, 0, -20), gym = "Starter" },
	{ parent = { "ProGym" }, at = Vector3.new(61, 0, -7.6), face = Vector3.new(61, 0, -20), gym = "Pro" },
	{ parent = { "Town", "BeachGym" }, at = Vector3.new(26, 0, 175.6), face = Vector3.new(26, 0, 190), gym = "Beach", beach = true },
}

local function floorY(point)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace:FindFirstChild("NPCs") }
	local hit = Workspace:Raycast(point + Vector3.new(0, 8, 0), Vector3.new(0, -20, 0), params)
	return hit and hit.Position.Y or point.Y
end

local function text(board, top, bottom)
	local gui = board:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChild("Text")
	if not label then return end
	label.Size = UDim2.fromScale(1, 0.62)
	label.Text = top
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.3)
	sub.Text = bottom
	sub.TextColor3 = hex("#B8B8BE")
	sub.FontFace = Theme.Fonts.Regular
	sub.TextScaled = true -- world sign
	sub.Parent = gui
end

-- One desk. `base` = the floor point under the desk's middle; its -Z (LookVector) faces the customers.
function Builder.Desk(parent, base, beach)
	local desk = Kit.fresh(parent, "Model", "TrainerDesk")
	local W, D, H = 6.4, 2.2, 3.1
	local bodyColor = beach and hex("#B88A5A") or WOOD
	-- counter: kick plate, wood body, steel corner trims, white top with a steel front edge
	Kit.part(desk, "KickPlate", Vector3.new(W, 0.3, D), base * CFrame.new(0, 0.15, 0), RUBBER, M.Rubber)
	local body = Kit.part(desk, "Body", Vector3.new(W - 0.2, H - 0.45, D - 0.2), base * CFrame.new(0, 0.3 + (H - 0.45) / 2, 0), bodyColor, M.WoodPlanks)
	body.CastShadow = true
	for _, x in ipairs({ -W / 2 + 0.08, W / 2 - 0.08 }) do
		for _, z in ipairs({ -D / 2 + 0.08, D / 2 - 0.08 }) do
			Kit.prop(desk, "Trim", Vector3.new(0.16, H - 0.45, 0.16), base * CFrame.new(x, 0.3 + (H - 0.45) / 2, z), STEEL, M.Metal)
		end
	end
	Kit.part(desk, "CounterTop", Vector3.new(W + 0.3, 0.18, D + 0.3), base * CFrame.new(0, H - 0.06, 0), WHITE, M.SmoothPlastic)
	Kit.prop(desk, "CounterEdge", Vector3.new(W + 0.32, 0.06, 0.06), base * CFrame.new(0, H - 0.17, -D / 2 - 0.15), STEEL, M.Metal)
	-- front panel with the name
	local panel = Kit.sign(desk, "FrontPanel", Vector3.new(W - 1.4, 1.1, 0.08), base * CFrame.new(0, 1.75, -D / 2 - 0.04), "PERSONAL TRAINERS", WHITE, DARK, 60)
	panel.Material = M.SmoothPlastic
	Kit.prop(desk, "PanelFrame", Vector3.new(W - 1.2, 1.3, 0.05), base * CFrame.new(0, 1.75, -D / 2 - 0.01), STEEL, M.Metal)
	-- sign board on two posts behind the counter
	for _, x in ipairs({ -W / 2 + 0.4, W / 2 - 0.4 }) do
		Kit.part(desk, "Post", Vector3.new(0.22, 6.6, 0.22), base * CFrame.new(x, 3.3, D / 2 + 0.5), DARK, M.Metal)
		Kit.prop(desk, "PostFoot", Vector3.new(0.6, 0.12, 0.6), base * CFrame.new(x, 0.06, D / 2 + 0.5), DARK, M.Metal)
	end
	local board = Kit.sign(desk, "SignBoard", Vector3.new(W - 0.5, 1.6, 0.14), base * CFrame.new(0, 5.6, D / 2 + 0.5), "PERSONAL TRAINERS", WHITE, DARK, 50)
	text(board, "PERSONAL TRAINERS", "Hire a coach · perks while you train")
	Kit.prop(desk, "SignTrim", Vector3.new(W - 0.3, 0.08, 0.18), base * CFrame.new(0, 6.44, D / 2 + 0.5), STEEL, M.Metal)
	Kit.prop(desk, "SignTrim", Vector3.new(W - 0.3, 0.08, 0.18), base * CFrame.new(0, 4.76, D / 2 + 0.5), STEEL, M.Metal)
	-- a stool behind the counter
	local stool = base * CFrame.new(1.6, 0, D / 2 + 1.4)
	Kit.cylinder(desk, "StoolSeat", 0.16, 1.1, stool * CFrame.new(0, 2.25, 0) * CFrame.Angles(0, 0, rad(90)), DARK, M.Fabric)
	Kit.cylinder(desk, "StoolPost", 2.1, 0.16, stool * CFrame.new(0, 1.12, 0) * CFrame.Angles(0, 0, rad(90)), STEEL, M.Metal)
	Kit.cylinder(desk, "StoolRing", 0.08, 0.9, stool * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, rad(90)), STEEL, M.Metal)
	Kit.cylinder(desk, "StoolBase", 0.1, 1.0, stool * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, rad(90)), DARK, M.Metal)
	-- props on the counter
	local top = base * CFrame.new(0, H + 0.03, 0)
	local clip = top * CFrame.new(-1.8, 0.03, -0.2) * CFrame.Angles(0, rad(12), 0)
	Kit.prop(desk, "Clipboard", Vector3.new(0.8, 0.05, 1.05), clip, hex("#7A5230"), M.Wood)
	Kit.prop(desk, "Paper", Vector3.new(0.66, 0.02, 0.82), clip * CFrame.new(0, 0.035, 0.05), WHITE, M.SmoothPlastic)
	Kit.prop(desk, "Clip", Vector3.new(0.36, 0.08, 0.12), clip * CFrame.new(0, 0.05, -0.45), STEEL, M.Metal)
	local watch = top * CFrame.new(-0.6, 0.06, 0.2)
	Kit.cylinder(desk, "Stopwatch", 0.1, 0.5, watch * CFrame.Angles(0, 0, rad(90)), DARK, M.SmoothPlastic)
	Kit.cylinder(desk, "StopwatchFace", 0.02, 0.38, watch * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, rad(90)), WHITE, M.SmoothPlastic)
	Kit.prop(desk, "StopwatchButton", Vector3.new(0.08, 0.08, 0.12), watch * CFrame.new(0, 0, -0.3), STEEL, M.Metal)
	local whistle = top * CFrame.new(0.5, 0.07, -0.3) * CFrame.Angles(0, rad(-30), 0)
	Kit.prop(desk, "Whistle", Vector3.new(0.34, 0.14, 0.14), whistle, STEEL, M.Metal)
	Kit.prop(desk, "Lanyard", Vector3.new(0.9, 0.02, 0.05), whistle * CFrame.new(0.55, -0.05, 0.1) * CFrame.Angles(0, rad(25), 0), hex("#D7262E"), M.Fabric)
	local bottle = top * CFrame.new(2.1, 0.45, 0.3)
	Kit.cylinder(desk, "Bottle", 0.8, 0.32, bottle * CFrame.Angles(0, 0, rad(90)), hex("#2B7BD8"), M.SmoothPlastic)
	Kit.cylinder(desk, "BottleCap", 0.14, 0.24, bottle * CFrame.new(0, 0.47, 0) * CFrame.Angles(0, 0, rad(90)), WHITE, M.SmoothPlastic)
	-- the prompt's part, in front of the counter
	local point = Kit.prop(desk, "TrainerPoint", Vector3.new(1, 1, 1), base * CFrame.new(0, 3.2, -D / 2 - 0.8), WHITE, M.SmoothPlastic)
	point.Transparency = 1
	CollectionService:AddTag(point, "TrainerDesk")
	return desk
end

function Builder.Build()
	local built = {}
	for _, place in ipairs(Builder.Places) do
		local parent = Workspace
		for _, name in ipairs(place.parent) do parent = parent and parent:FindFirstChild(name) end
		if parent then
			local folder = parent:FindFirstChild("Feature_Trainers") or Instance.new("Folder")
			folder.Name = "Feature_Trainers"
			folder.Parent = parent
			local old = folder:FindFirstChild("TrainerDesk")
			if old then old:Destroy() end -- (first: the floor ray must not land on the old desk)
			local at = Vector3.new(place.at.X, floorY(place.at), place.at.Z)
			local face = Vector3.new(place.face.X, at.Y, place.face.Z)
			local desk = Builder.Desk(folder, CFrame.lookAt(at, face), place.beach)
			desk:SetAttribute("Gym", place.gym)
			table.insert(built, place.gym .. string.format(" (%.1f, %.1f, %.1f)", at.X, at.Y, at.Z))
		end
	end
	return "built desks: " .. table.concat(built, ", ")
end

return Builder
