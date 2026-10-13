-- UI images (owner's UI redesign, 13 Oct): the 9-slice pieces, the white line icons and the shop item icons, uploaded to
-- the Myanmar Builders Club group (Images). Names = the file names in Downloads\gym_arc_ui_pieces / gym_arc_ui_icons /
-- gym_arc_shop_icons; ids found by exact name in the group (newest when there were two).
-- Pieces carry their 9-slice data from pieces.json (SliceCenter in image pixels, SliceScale 0.5 because the images are
-- 2x); Shared.UI.Pieces applies them. Text, numbers and icons are never baked into these images.
local UI = {}

UI.Pieces = {
	banner_gold = { image = "rbxassetid://115205618940710", scaleType = "Slice", sliceCenter = { 24, 24, 104, 64 }, sliceScale = 0.5, size = { 128, 88 } }, -- Personal record / bonus banner (stretch horizontally)
	bar_fill_white = { image = "rbxassetid://70877208326440", scaleType = "Slice", sliceCenter = { 8, 0, 40, 16 }, sliceScale = 0.5, size = { 48, 16 } }, -- Progress bar fill: tint with ImageColor3
	bar_track = { image = "rbxassetid://130815257879238", scaleType = "Slice", sliceCenter = { 8, 0, 40, 16 }, sliceScale = 0.5, size = { 48, 16 } }, -- Progress bar track (slice left/right caps only)
	btn_dark = { image = "rbxassetid://79558645245279", scaleType = "Slice", sliceCenter = { 24, 24, 56, 48 }, sliceScale = 0.5, size = { 80, 72 } }, -- Secondary button
	btn_disabled = { image = "rbxassetid://104541942792486", scaleType = "Slice", sliceCenter = { 24, 24, 56, 48 }, sliceScale = 0.5, size = { 80, 72 } }, -- Disabled / Owned button
	btn_gold = { image = "rbxassetid://115290205001292", scaleType = "Slice", sliceCenter = { 24, 24, 56, 48 }, sliceScale = 0.5, size = { 80, 72 } }, -- Gold button
	btn_green = { image = "rbxassetid://127359786325035", scaleType = "Slice", sliceCenter = { 24, 24, 56, 48 }, sliceScale = 0.5, size = { 80, 72 } }, -- Green button (Claim, Auto on)
	btn_red = { image = "rbxassetid://118666360299995", scaleType = "Slice", sliceCenter = { 24, 24, 56, 48 }, sliceScale = 0.5, size = { 80, 72 } }, -- Primary button
	btn_red_pressed = { image = "rbxassetid://139607004382316", scaleType = "Slice", sliceCenter = { 24, 24, 56, 48 }, sliceScale = 0.5, size = { 80, 72 } }, -- Primary button pressed (also move content down 2px)
	btn_white_tint = { image = "rbxassetid://94263610268055", scaleType = "Slice", sliceCenter = { 24, 24, 56, 48 }, sliceScale = 0.5, size = { 80, 72 } }, -- White button with edge: tint with ImageColor3 for any color
	card = { image = "rbxassetid://96201934485200", scaleType = "Slice", sliceCenter = { 28, 28, 68, 68 }, sliceScale = 0.5, size = { 96, 96 } }, -- Card inside panels
	card_gold = { image = "rbxassetid://71840017814532", scaleType = "Slice", sliceCenter = { 28, 28, 68, 68 }, sliceScale = 0.5, size = { 96, 96 } }, -- Highlighted card (gold outline)
	card_selected = { image = "rbxassetid://91356384750016", scaleType = "Slice", sliceCenter = { 28, 28, 68, 68 }, sliceScale = 0.5, size = { 96, 96 } }, -- Selected/equipped card (red outline)
	chip = { image = "rbxassetid://104082743935636", scaleType = "Slice", sliceCenter = { 20, 20, 60, 40 }, sliceScale = 0.5, size = { 80, 60 } }, -- Currency/timer chip
	circle_white = { image = "rbxassetid://88826644116797", scaleType = "Fit", size = { 128, 128 } }, -- Circle: knob, avatar dot, badge (tint)
	close_button = { image = "rbxassetid://99710466327905", scaleType = "Slice", sliceCenter = { 20, 20, 44, 44 }, sliceScale = 0.5, size = { 64, 64 } }, -- X close button background
	hud_box = { image = "rbxassetid://130442784531222", scaleType = "Slice", sliceCenter = { 28, 28, 68, 68 }, sliceScale = 0.5, size = { 96, 96 } }, -- HUD widgets over the 3D world
	keycap = { image = "rbxassetid://104453719007886", scaleType = "Fit", size = { 60, 60 } }, -- "E" key cap on prompts
	menu_button = { image = "rbxassetid://119543809493914", scaleType = "Slice", sliceCenter = { 32, 32, 80, 80 }, sliceScale = 0.5, size = { 112, 112 } }, -- Left HUD menu button
	menu_button_gold = { image = "rbxassetid://135003978318011", scaleType = "Slice", sliceCenter = { 32, 32, 80, 80 }, sliceScale = 0.5, size = { 112, 112 } }, -- Left HUD menu button, highlighted (Shop)
	occupied_pill = { image = "rbxassetid://135340689231547", scaleType = "Slice", sliceCenter = { 24, 24, 72, 48 }, sliceScale = 0.5, size = { 96, 72 } }, -- OCCUPIED billboard pill
	panel = { image = "rbxassetid://123121872692894", scaleType = "Slice", sliceCenter = { 32, 32, 96, 96 }, sliceScale = 0.5, size = { 128, 128 } }, -- Main panel/modal background
	panel_header = { image = "rbxassetid://83160527499076", scaleType = "Slice", sliceCenter = { 32, 32, 96, 64 }, sliceScale = 0.5, size = { 128, 96 } }, -- Panel header strip (top corners only)
	panel_shadow = { image = "rbxassetid://78666998262260", scaleType = "Slice", sliceCenter = { 80, 80, 144, 144 }, sliceScale = 0.5, size = { 224, 224 } }, -- Soft drop shadow, place behind panel, 20px larger each side
	pump_button = { image = "rbxassetid://133633520753151", scaleType = "Fit", size = { 128, 128 } }, -- PUMP button
	pump_button_ring = { image = "rbxassetid://137260792281738", scaleType = "Fit", size = { 144, 144 } }, -- Soft ring behind PUMP
	rep_button = { image = "rbxassetid://72004773138623", scaleType = "Fit", size = { 208, 208 } }, -- Big REP / TAP button (ScaleType Fit)
	rep_button_ring = { image = "rbxassetid://114726965424288", scaleType = "Fit", size = { 232, 232 } }, -- Soft ring behind REP button
	rounded_white_r12 = { image = "rbxassetid://77868079055148", scaleType = "Slice", sliceCenter = { 28, 28, 68, 68 }, sliceScale = 0.5, size = { 96, 96 } }, -- Large tinted tile (trainer art background)
	rounded_white_r5 = { image = "rbxassetid://96053267897517", scaleType = "Slice", sliceCenter = { 12, 12, 28, 24 }, sliceScale = 0.5, size = { 40, 36 } }, -- Tag background: tint with ImageColor3
	rounded_white_r8 = { image = "rbxassetid://129110074875363", scaleType = "Slice", sliceCenter = { 20, 20, 44, 44 }, sliceScale = 0.5, size = { 64, 64 } }, -- Icon tile / grade badge / level badge: tint with ImageColor3
	tab_active = { image = "rbxassetid://96381485218221", scaleType = "Slice", sliceCenter = { 18, 18, 62, 38 }, sliceScale = 0.5, size = { 80, 56 } }, -- Active tab
	toggle_off = { image = "rbxassetid://136521293735673", scaleType = "Slice", sliceCenter = { 22, 0, 58, 44 }, sliceScale = 0.5, size = { 80, 44 } }, -- Toggle track off
	toggle_on = { image = "rbxassetid://72526427816704", scaleType = "Slice", sliceCenter = { 22, 0, 58, 44 }, sliceScale = 0.5, size = { 80, 44 } }, -- Toggle track on
	well = { image = "rbxassetid://83433589437265", scaleType = "Slice", sliceCenter = { 28, 28, 68, 68 }, sliceScale = 0.5, size = { 96, 96 } }, -- Dark inset area (tab strip, inputs)
}

UI.Icons = { -- white on transparent, 128x128 (tint with ImageColor3)
	["arrow-big-up"] = "rbxassetid://102878631565166",
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
	product_shake_bundle = "rbxassetid://107883030118451",
	product_skip_growth_cooldown = "rbxassetid://113267233802315",
	product_stamina_refill = "rbxassetid://136768220289914",
}

return UI
