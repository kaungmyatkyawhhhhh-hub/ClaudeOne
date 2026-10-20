-- BodyPump: the cheap pump (owner, 20 Oct; it replaces the muscle-mesh pump, which rewrote the meshes ~10 times per pump):
-- the whole character grows SCALE bigger over UP seconds and back over DOWN (Model:ScaleTo, no mesh write), with a short
-- gold flash (a Highlight) and a few gold sparks. Client side. Only YOUR character is scaled (everyone else's sizes come from
-- the server and MuscleClient puts them back); others get the flash and the sparks.
--   BodyPump.Play(model)  -- a level-up pump (every 10th level, MuscleClient) or a pose hit (PoseClient)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.UI.Theme)

local BodyPump = {}

local SCALE = 0.035
local UP, DOWN = 0.15, 0.4
local FLASH = 0.55        -- the gold flash's strongest fill (1 = none)
local SPARKS = 10
local SPARK_TEXTURE = "rbxassetid://82372237523631" -- spark_star.png (AuraVFX)

local running = {} -- [model] = { base = its scale before the pump, started = os.clock() }

local function scaleRun(model: Model)
	local run = running[model]
	if run then
		run.started = os.clock() -- (a pump during a pump starts again from the top, from the same base)
		return
	end
	run = { base = model:GetScale(), started = os.clock() }
	running[model] = run
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - run.started
		local k
		if t < UP then
			k = math.sin(t / UP * math.pi / 2)
		elseif t < UP + DOWN then
			k = math.cos((t - UP) / DOWN * math.pi / 2)
		end
		if not model.Parent or not k then
			connection:Disconnect()
			running[model] = nil
			if model.Parent then model:ScaleTo(run.base) end
			return
		end
		model:ScaleTo(run.base * (1 + SCALE * k))
	end)
end

local function flash(model: Model)
	local light = Instance.new("Highlight")
	light.Name = "PumpFlash"
	light.FillColor = Theme.Colors.Gold
	light.FillTransparency = FLASH
	light.OutlineTransparency = 1
	light.DepthMode = Enum.HighlightDepthMode.Occluded
	light.Adornee = model
	light.Parent = model
	TweenService:Create(light, TweenInfo.new(UP + DOWN, Enum.EasingStyle.Sine), { FillTransparency = 1 }):Play()
	task.delay(UP + DOWN + 0.05, function() light:Destroy() end)
end

local function sparks(model: Model)
	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("HumanoidRootPart")
	if not (torso and torso:IsA("BasePart")) then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "PumpSparks"
	emitter.Texture = SPARK_TEXTURE
	emitter.Color = ColorSequence.new(Theme.Colors.Gold)
	emitter.LightEmission = 1
	emitter.Brightness = 2
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 5
	emitter.Acceleration = Vector3.new(0, -6, 0)
	emitter.Rate = 0
	emitter.Parent = torso
	emitter:Emit(SPARKS)
	task.delay(1, function() emitter:Destroy() end)
end

function BodyPump.Play(model: Model?)
	if not (model and model.Parent) then return end
	if model == Players.LocalPlayer.Character then scaleRun(model) end
	flash(model)
	sparks(model)
end

return BodyPump
