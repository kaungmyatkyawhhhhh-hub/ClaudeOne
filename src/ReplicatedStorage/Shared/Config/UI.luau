-- UI images and texts (owner's UI v2, 13 Oct: Gym League style).
--   Icons      the white line icons (Downloads\gym_arc_ui_icons, Myanmar Builders Club group, found by exact name)
--   ShopIcons  pass / product art (Downloads\gym_arc_shop_icons, same group)
--   MenuIcons  the 3D left-menu icons (Downloads\gym_arc_ui_3d_icons\menu_*.png)
--   Trainers   the trainer portraits (trainer_*.png), MenuArt the main menu + loading art (menu_art.png)
-- MenuIcons / Trainers / MenuArt were uploaded from Studio on 13 Oct (owner's account inventory; the group search had no
-- copies). The old 9-slice pieces of the cancelled dark style (gym_arc_ui_pieces) are gone.
local UI = {}

UI.Icons = { -- white on transparent, 128x128 (tint with ImageColor3)
	["arrow-big-up"] = "rbxassetid://102878631565166",
	["backpack"] = "rbxassetid://101113089317721", -- (the INVENTORY tile, uploaded from Studio 14 Oct: owner's inventory)
	["bell"] = "rbxassetid://83280875131790",
	["biceps-flexed"] = "rbxassetid://97319043121415",
	["calendar-days"] = "rbxassetid://78358912964734",
	["check"] = "rbxassetid://90075743979620",
	["chevron-left"] = "rbxassetid://104361304325924",
	["clipboard-list"] = "rbxassetid://118864122479802",
	["coin"] = "rbxassetid://121522080656318",
	["cup-soda"] = "rbxassetid://128798416449653",
	["dumbbell"] = "rbxassetid://122080504295664",
	["eye"] = "rbxassetid://115883383273756",
	["flame"] = "rbxassetid://139361661471819",
	["footprints"] = "rbxassetid://128859392333419",
	["gift"] = "rbxassetid://104023620046034",
	["hand"] = "rbxassetid://134483091426088",
	["heart-pulse"] = "rbxassetid://102140500949119",
	["info"] = "rbxassetid://112629782440537",
	["list-checks"] = "rbxassetid://71818957910507",
	["lock"] = "rbxassetid://75966488043124",
	["medal"] = "rbxassetid://79550313138070",
	["minus"] = "rbxassetid://79222452250575",
	["music"] = "rbxassetid://134418843744768",
	["plus"] = "rbxassetid://118188417466628",
	["repeat"] = "rbxassetid://90406944643110",
	["robux"] = "rbxassetid://132174906835375",
	["ruler"] = "rbxassetid://119048837096602",
	["settings"] = "rbxassetid://132158968942811",
	["shopping-cart"] = "rbxassetid://104195456453228",
	["smile"] = "rbxassetid://135824139813360",
	["sparkles"] = "rbxassetid://138040093285838",
	["star"] = "rbxassetid://117253109435071",
	["timer"] = "rbxassetid://75013353235617",
	["trophy"] = "rbxassetid://114017953395696",
	["users"] = "rbxassetid://123386640554214",
	["volume-2"] = "rbxassetid://94482563880485",
	["x"] = "rbxassetid://119047779782135",
	["zap"] = "rbxassetid://75531954798825",
}

UI.ShopIcons = { -- shop items that aren't a real pass / product (those read their icon from GetProductInfo)
	pass_2x_coins = "rbxassetid://117458912009974",
	pass_2x_exp = "rbxassetid://107654800854539",
	pass_aura_pack = "rbxassetid://71823894969577",
	pass_auto_rep = "rbxassetid://81453886607037",
	pass_extra_pet_slot = "rbxassetid://101817661114755",
	pass_extra_trainer = "rbxassetid://122731883610191",
	pass_vip = "rbxassetid://125824576729448",
	product_coins_large = "rbxassetid://89371119234841",
	product_coins_medium = "rbxassetid://90925282294067",
	product_coins_small = "rbxassetid://119709746715062",
	-- (these two were uploaded from Studio on 14 Oct, so they're in the owner's own inventory, not the group)
	product_dna_token = "rbxassetid://87375007150587",
	product_quest_reroll = "rbxassetid://124460070314904",
	product_shake_bundle = "rbxassetid://107883030118451",
	-- (owner's Downloads\gym_arc_shop_icons\product_endless_stamina.png, uploaded from Studio 14 Oct: owner's inventory)
	product_endless_stamina = "rbxassetid://96813280646116",
}

UI.MenuIcons = { -- 3D menu icons: NOT USED (owner, 13 Oct: keep the old left menu tiles); kept only as a record
	menu_shop = "rbxassetid://104966488045071",
	menu_quests = "rbxassetid://103446520698076",
	menu_muscles = "rbxassetid://92738638488258",   -- the Stats tile
	menu_trainers = "rbxassetid://71228174724353",
	menu_titles = "rbxassetid://76507667998298",
	menu_emotes = "rbxassetid://75490148811539",
	menu_crew = "rbxassetid://136275598337928",
	menu_settings = "rbxassetid://100011256897276",
}

UI.Trainers = { -- portraits shown in the Trainers panel (by Config/Trainers id order: exp, stamina, coins, pump); re-rendered
	-- 14 Oct from the new trainer models (same camera, dark backdrop), uploaded from Studio = the owner's own inventory
	trainer_exp = "rbxassetid://123149177753009",
	trainer_stamina = "rbxassetid://73804538355114",
	trainer_coins = "rbxassetid://100097169445664",
	trainer_pump = "rbxassetid://86536100657185",
}

UI.MenuArt = "rbxassetid://99238211044120" -- main menu + loading screen (right side, fading into the dark)
-- the GYM ARC logo image (Downloads\gym_arc_ui_3d_icons\logo.png, 1182x286, uploaded from Studio 14 Oct): loading screen + menu
UI.Logo = "rbxassetid://84167052331251"
-- The SKATE button (owner's Downloads\gym_arc_ui_3d_icons\skate_button.png: the whole round button, ring and background
-- included). Uploaded 14 Oct from Studio, so it sits in the owner's own inventory, not the group: to use a group copy,
-- upload it to Myanmar Builders Club and put its id here.
UI.SkateButton = "rbxassetid://117777612617836"

-- Loading screen tips (one at a time, rotating)
UI.LoadingTips = {
	"Spot other players on their lifts to earn coins!",
	"Tap fast while lifting to fill PUMP: pumped reps grow twice as much.",
	"Weak muscles grow fastest. Train the group that needs work.",
	"Every Growth Spurt makes you taller and grows your gains for good.",
	"Drinks at the smoothie bar give short boosts. Check the timers above your stamina bar.",
	"Claim your Daily Reward every day: day 7 is the big one.",
	"Trainers follow you around and give a small boost while they do.",
	"Titles are earned, never bought. Some of them are secret.",
	"Running on a treadmill raises your max stamina.",
	"The pro gym opens at Growth Spurt 2. Watch through the glass until then.",
}

-- The main menu's UPDATES window: newest first (date, title, a few short lines). Add an entry for each update and change
-- UpdatesStamp: the UPDATES button shows a red dot until the player opens the window (saved as settings.updatesSeen).
UI.UpdatesStamp = "14 Oct"
UI.MenuVersion = "v1.0 · Update 1" -- small, bottom right of the main menu
UI.Updates = {
	{ date = "14 Oct", title = "Free machines", lines = {
		"Every machine and every weight is free: your muscle level is all you need.",
		"PUMP is a bar again: fill it with reps, then tap it (or Space) for double gains.",
		"A new main menu.",
	} },
	{ date = "13 Oct", title = "New look", lines = {
		"Every menu has a fresh, bright new style.",
		"Quests, Daily Reward and Achievements live in one window.",
		"Tap the GROW tile or Muscles to see your Stats: muscles, lifts and genetics.",
	} },
	{ date = "13 Oct", title = "Trainers", lines = {
		"Hire a trainer anywhere: tap his picture in the Trainers menu.",
		"Each trainer gives a small boost while he follows you.",
	} },
	{ date = "13 Oct", title = "Fixes", lines = {
		"Leaving a machine always works (STOP TRAINING or jump).",
		"Finish the tutorial for 50 coins. You can skip it too.",
	} },
}

return UI
