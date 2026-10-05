-- ArmWrestleTable builder (run once in Studio; see tools/bake.md): the arm wrestling table on the right side of the
-- starter gym (Config.Social.ArmWrestle.TableSpot) with two Seats ("Stool1", "Stool2", each with an
-- "ArmWrestlePrompt"), tag "ArmWrestleTable". Output: Workspace.ArmWrestleTable. ArmWrestleService runs matches.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Kit)
local Config = require(ReplicatedStorage.Shared.Config.Social).ArmWrestle

local ArmWrestleTable = {}

function ArmWrestleTable.Build(Workspace)
	local model = Kit.fresh(Workspace, "Model", "ArmWrestleTable")
	local base = CFrame.new(Config.TableSpot)
	local dark = Kit.hex("#1E1E22")
	local steel = Kit.hex("#9EA2A8")
	local pad = Kit.hex("#221E1E")
	local wood = Kit.hex("#765236")
	-- the table: a padded top on a wood frame with a steel edge, a thick post with a collar, a cross foot
	Kit.part(model, "Top", Vector3.new(2.6, 0.25, 2.2), base * CFrame.new(0, 3.1, 0), pad, Enum.Material.Leather)
	Kit.part(model, "TopFrame", Vector3.new(2.8, 0.18, 2.4), base * CFrame.new(0, 2.9, 0), wood, Enum.Material.Wood)
	Kit.prop(model, "Edge", Vector3.new(2.84, 0.05, 2.44), base * CFrame.new(0, 2.98, 0), steel, Enum.Material.Metal)
	Kit.part(model, "Post", Vector3.new(0.5, 2.8, 0.5), base * CFrame.new(0, 1.45, 0), dark, Enum.Material.Metal)
	Kit.prop(model, "PostCollar", Vector3.new(0.7, 0.2, 0.7), base * CFrame.new(0, 2.75, 0), steel, Enum.Material.Metal)
	Kit.part(model, "Foot", Vector3.new(2.2, 0.2, 0.4), base * CFrame.new(0, 0.1, 0), dark, Enum.Material.Metal)
	Kit.part(model, "Foot", Vector3.new(0.4, 0.2, 2.2), base * CFrame.new(0, 0.1, 0), dark, Enum.Material.Metal)
	-- elbow pads (the two colors tell the sides apart) and the hand pegs
	Kit.part(model, "PadA", Vector3.new(0.6, 0.12, 0.8), base * CFrame.new(-0.75, 3.28, 0), Kit.hex("#D7262E"), Enum.Material.Leather)
	Kit.part(model, "PadB", Vector3.new(0.6, 0.12, 0.8), base * CFrame.new(0.75, 3.28, 0), Kit.hex("#1F5FBF"), Enum.Material.Leather)
	Kit.part(model, "Peg", Vector3.new(0.12, 0.6, 0.12), base * CFrame.new(0, 3.5, 0.75), steel, Enum.Material.Metal)
	Kit.prop(model, "Peg", Vector3.new(0.12, 0.6, 0.12), base * CFrame.new(0, 3.5, -0.75), steel, Enum.Material.Metal)
	Kit.prop(model, "Line", Vector3.new(0.04, 0.01, 2.0), base * CFrame.new(0, 3.23, 0), Kit.hex("#F2F0EA"), Enum.Material.SmoothPlastic)
	for index, side in ipairs({ -1, 1 }) do
		-- a real Seat (the cushion), so players sit with the normal sitting pose; it faces the table
		local seatPosition = Config.TableSpot + Vector3.new(side * 2.2, 1.65, 0)
		local stool = Instance.new("Seat")
		stool.Name = "Stool" .. index
		stool.Size = Vector3.new(1.3, 0.3, 1.3)
		stool.CFrame = CFrame.lookAt(seatPosition, Vector3.new(Config.TableSpot.X, seatPosition.Y, Config.TableSpot.Z))
		stool.Transparency = 1 -- the round cushion below is what you see
		stool.Anchored = true
		stool.TopSurface, stool.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		stool.Parent = model
		Kit.prompt(stool, "ArmWrestlePrompt", "Arm wrestle", "Sit down", 7)
		local cushion = Kit.prop(model, "Cushion", Vector3.new(0.3, 1.4, 1.4), CFrame.new(seatPosition) * CFrame.Angles(0, 0, math.rad(90)), pad, Enum.Material.Leather)
		cushion.Shape = Enum.PartType.Cylinder
		local floor = Config.TableSpot + Vector3.new(side * 2.2, 0, 0)
		Kit.part(model, "StoolPost", Vector3.new(0.25, 1.4, 0.25), CFrame.new(floor + Vector3.new(0, 0.8, 0)), dark, Enum.Material.Metal)
		Kit.prop(model, "StoolBase", Vector3.new(1.1, 0.12, 1.1), CFrame.new(floor + Vector3.new(0, 0.06, 0)), dark, Enum.Material.Metal)
		Kit.prop(model, "FootRing", Vector3.new(1.0, 0.08, 0.08), CFrame.new(floor + Vector3.new(0, 0.6, 0.45)), steel, Enum.Material.Metal)
		Kit.prop(model, "FootRing", Vector3.new(1.0, 0.08, 0.08), CFrame.new(floor + Vector3.new(0, 0.6, -0.45)), steel, Enum.Material.Metal)
	end
	CollectionService:AddTag(model, "ArmWrestleTable")
	return model
end

return ArmWrestleTable
