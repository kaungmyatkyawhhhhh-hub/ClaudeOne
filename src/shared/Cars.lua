--[[
	Car roster. All names are fictional so the game is safe to publish.

	Stats
	  TopSpeed   : mph
	  ZeroToSixty: seconds
	  Handling   : 0..1 (grip + steering response)
	  Price      : $ (0 = free starter)
]]

export type CarSpec = {
	Id: string,
	Name: string,
	Class: string,
	TopSpeed: number,
	ZeroToSixty: number,
	Handling: number,
	Price: number,
	Color: Color3,
	Accent: Color3?,
	Order: number,
}

local Cars = {}

Cars.Classes = { "Sedan", "Coupe", "SUV", "Supercar", "Hypercar" }

Cars.ClassLabels = {
	Sedan = "SEDAN",
	Coupe = "COUPE",
	SUV = "SUV",
	Supercar = "SUPERCAR",
	Hypercar = "HYPERCAR",
}

local list: { CarSpec } = {
	-- Sedans
	{ Id = "aurelia_s4", Name = "Aurelia S4", Class = "Sedan", TopSpeed = 124, ZeroToSixty = 7.2, Handling = 0.55, Price = 0, Color = Color3.fromRGB(196, 199, 204), Order = 1 },
	{ Id = "meridian_lx", Name = "Meridian SRT", Class = "Sedan", TopSpeed = 155, ZeroToSixty = 4.8, Handling = 0.62, Price = 18000, Color = Color3.fromRGB(38, 50, 58), Order = 2 },
	{ Id = "kensho_m5", Name = "Kensho M-Sport", Class = "Sedan", TopSpeed = 165, ZeroToSixty = 3.9, Handling = 0.72, Price = 65000, Color = Color3.fromRGB(104, 18, 98), Order = 3 },

	-- Coupes
	{ Id = "strada_c2", Name = "Strada C2", Class = "Coupe", TopSpeed = 150, ZeroToSixty = 5.0, Handling = 0.7, Price = 32000, Color = Color3.fromRGB(188, 192, 200), Accent = Color3.fromRGB(24, 60, 210), Order = 4 },
	{ Id = "kaizen_rz", Name = "Kaizen RZ", Class = "Coupe", TopSpeed = 172, ZeroToSixty = 4.1, Handling = 0.8, Price = 78000, Color = Color3.fromRGB(160, 12, 22), Accent = Color3.fromRGB(18, 18, 20), Order = 5 },
	{ Id = "brute_srx", Name = "Brute SRX", Class = "Coupe", TopSpeed = 168, ZeroToSixty = 3.6, Handling = 0.66, Price = 95000, Color = Color3.fromRGB(176, 14, 18), Accent = Color3.fromRGB(16, 16, 18), Order = 6 },
	{ Id = "outlaw_69", Name = "Outlaw '69", Class = "Coupe", TopSpeed = 175, ZeroToSixty = 3.4, Handling = 0.7, Price = 120000, Color = Color3.fromRGB(232, 233, 235), Accent = Color3.fromRGB(14, 14, 16), Order = 7 },

	-- SUVs
	{ Id = "atlas_x7", Name = "Atlas X7", Class = "SUV", TopSpeed = 135, ZeroToSixty = 6.1, Handling = 0.5, Price = 40000, Color = Color3.fromRGB(40, 44, 50), Order = 8 },
	{ Id = "monolith_gt", Name = "Monolith GT", Class = "SUV", TopSpeed = 180, ZeroToSixty = 3.6, Handling = 0.6, Price = 145000, Color = Color3.fromRGB(12, 12, 14), Accent = Color3.fromRGB(255, 180, 0), Order = 9 },

	-- Supercars
	{ Id = "vortex_v10", Name = "Vortex V10", Class = "Supercar", TopSpeed = 205, ZeroToSixty = 2.9, Handling = 0.86, Price = 240000, Color = Color3.fromRGB(120, 200, 20), Order = 10 },
	{ Id = "spectre_720", Name = "Spectre 720", Class = "Supercar", TopSpeed = 212, ZeroToSixty = 2.8, Handling = 0.88, Price = 320000, Color = Color3.fromRGB(255, 120, 0), Order = 11 },
	{ Id = "rosso_f8", Name = "Rosso F8", Class = "Supercar", TopSpeed = 210, ZeroToSixty = 2.8, Handling = 0.9, Price = 360000, Color = Color3.fromRGB(200, 10, 20), Order = 12 },

	-- Hypercars
	{ Id = "phantom_w16", Name = "Phantom W16", Class = "Hypercar", TopSpeed = 261, ZeroToSixty = 2.4, Handling = 0.9, Price = 1200000, Color = Color3.fromRGB(20, 40, 90), Accent = Color3.fromRGB(15, 15, 18), Order = 13 },
	{ Id = "eclipse_jx", Name = "Eclipse JX", Class = "Hypercar", TopSpeed = 278, ZeroToSixty = 2.3, Handling = 0.93, Price = 2500000, Color = Color3.fromRGB(226, 84, 8), Accent = Color3.fromRGB(16, 16, 18), Order = 14 },
	{ Id = "velluto_p7", Name = "Velluto P7", Class = "Hypercar", TopSpeed = 268, ZeroToSixty = 2.5, Handling = 0.92, Price = 3200000, Color = Color3.fromRGB(62, 18, 88), Accent = Color3.fromRGB(206, 156, 58), Order = 15 },
}

Cars.List = list
Cars.ById = {} :: { [string]: CarSpec }
for _, spec in list do
	Cars.ById[spec.Id] = spec
end

Cars.StarterId = "aurelia_s4"
Cars.CutsceneId = "eclipse_jx"

-- Realistic paint palette for NPC traffic
Cars.TrafficColors = {
	Color3.fromRGB(235, 236, 238), -- white
	Color3.fromRGB(235, 236, 238),
	Color3.fromRGB(20, 21, 24), -- black
	Color3.fromRGB(20, 21, 24),
	Color3.fromRGB(165, 168, 172), -- silver
	Color3.fromRGB(165, 168, 172),
	Color3.fromRGB(88, 92, 98), -- gunmetal
	Color3.fromRGB(26, 44, 82), -- navy
	Color3.fromRGB(130, 20, 26), -- dark red
	Color3.fromRGB(190, 30, 35), -- red
	Color3.fromRGB(36, 70, 52), -- racing green
	Color3.fromRGB(150, 128, 98), -- champagne
	Color3.fromRGB(40, 90, 160), -- blue
}

function Cars.get(id: string): CarSpec
	return Cars.ById[id] or Cars.ById[Cars.StarterId]
end

return Cars
