-- Photo mode (owner's feature run, task 7D): a PHOTO button shows at the mirrors and the posing stage. In photo mode the
-- HUD hides, you turn the camera around yourself (drag) and zoom (wheel / pinch), pick a pose, and HIDE UI clears the
-- screen for a screenshot with your device; then a tap anywhere ends photo mode (PhotoModeClient, client only).
local PhotoMode = {}

-- where the PHOTO button shows: Workspace paths of the mirror glass / stage floor parts (the parts themselves, not their
-- models: a model's box on a client can include far-away pieces) and how close you must be to their edge (studs)
PhotoMode.Spots = {
	{ path = "Gym.StarterGym.WallDecor.MirrorPanel.Mirror", range = 12 }, -- the starter gym's mirror wall
	{ path = "ProGym.Props.MirrorPanel.Mirror", range = 12 },             -- the pro gym's mirror wall
	{ path = "Town.ClothingStore.MirrorPanel.Mirror", range = 8 },        -- the clothing store's mirror
	{ path = "ProgressMirror.Glass", range = 10 },                        -- the progress mirror
	{ path = "Town.PosingStage.Stage", range = 10 },                      -- the posing stage on the beach
}

PhotoMode.Distance = { Start = 9, Min = 4, Max = 20 } -- camera distance from you (studs)
PhotoMode.Pitch = { Start = 0.12, Min = -0.35, Max = 1.1 } -- camera height angle (radians; up = positive)
PhotoMode.DragSpeed = 0.008 -- radians per pixel dragged
PhotoMode.ZoomStep = 1.2    -- studs per mouse wheel notch
PhotoMode.FocusHeight = 1.4 -- studs above your root part the camera turns around

return PhotoMode
