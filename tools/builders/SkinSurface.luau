-- Makes ReplicatedStorage.SkinSurface (the skin SurfaceAppearance template cloned onto the body parts and muscle blobs).
-- Run once in Studio's command bar (Edit mode): scripts can't set ColorMap at runtime. Ids: Config/Body.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Body = require(ReplicatedStorage.Shared.Config.Body)
local old = ReplicatedStorage:FindFirstChild("SkinSurface")
if old then old:Destroy() end
local sa = Instance.new("SurfaceAppearance")
sa.Name = "SkinSurface"
sa.ColorMap = Body.SkinColorMap
sa.RoughnessMap = Body.SkinRoughnessMap
sa.Parent = ReplicatedStorage
