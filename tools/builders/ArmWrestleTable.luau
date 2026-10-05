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
	Kit.part(model, "Top", Vector3.new(2.6, 0.25, 2.2), base * CFrame.new(0, 3.1, 0), dark)
	Kit.part(model, "Post", Vector3.new(0.5, 3, 0.5), base * CFrame.new(0, 1.5, 0), steel, Enum.Material.Metal)
	Kit.part(model, "Foot", Vector3.new(2, 0.2, 2), base * CFrame.new(0, 0.1, 0), dark)
	Kit.part(model, "PadA", Vector3.new(0.5, 0.08, 0.7), base * CFrame.new(-0.75, 3.26, 0), Kit.hex("#D7262E"))
	Kit.part(model, "PadB", Vector3.new(0.5, 0.08, 0.7), base * CFrame.new(0.75, 3.26, 0), Kit.hex("#1F5FBF"))
	Kit.part(model, "Peg", Vector3.new(0.12, 0.6, 0.12), base * CFrame.new(0, 3.5, 0.75), steel, Enum.Material.Metal)
	for index, side in ipairs({ -1, 1 }) do
		-- a real Seat, so players sit with the normal sitting pose; it faces the table
		local seatPosition = Config.TableSpot + Vector3.new(side * 2.2, 0.9, 0)
		local stool = Instance.new("Seat")
		stool.Name = "Stool" .. index
		stool.Size = Vector3.new(1.4, 1.8, 1.4)
		stool.CFrame = CFrame.lookAt(seatPosition, Vector3.new(Config.TableSpot.X, seatPosition.Y, Config.TableSpot.Z))
		stool.Color = dark
		stool.Material = Enum.Material.SmoothPlastic
		stool.Anchored = true
		stool.TopSurface, stool.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		stool.Parent = model
		Kit.prompt(stool, "ArmWrestlePrompt", "Arm wrestle", "Sit down", 7)
	end
	CollectionService:AddTag(model, "ArmWrestleTable")
	return model
end

return ArmWrestleTable
