
-- material properties table

-- h = probability of degradation (hardness) into lower quality material
-- r = probability of displacement (resistance) to a lower elevation
-- t = list of target materials, first one is default, others will be picked based on surroundings

return {
	-- default game materials
	["default:dirt"]
		= { h = 1.0, r = 1.0, t = { "default:sand", "default:desert_sand" }},
	["default:dirt_with_grass"]
		= { h = 1.0, r = 1.0, t = { "default:dirt" }, drop_as="default:dirt"},
	["default:dirt_with_grass_footsteps"]
		= { h = 1.0, r = 1.0, t = { "default:dirt" }, drop_as="default:dirt"},
	["default:dirt_with_snow"]
		= { h = 1.0, r = 1.0, t = { "default:dirt" }, drop_as="default:dirt"},
	["default:sand"]
     = { h = 0.01, r = 1.0, t = { "default:clay" }, slope=0.51 },
	["default:desert_sand"]
		= { h = 0.01, r = 1.0, t = { "default:clay" }, slope=0.51 },
	["default:gravel"]
    = { h = 0.15, r = 0.5, t = { "default:dirt" }, slope=0.7, min_cnt=3,max_cnt=4 },
	["default:clay"]
		= { h = 0.0, r = 0.3, t = { "default:clay" }},
	["default:sandstone"]
		= { h = 0.05, r = 0.05, t = { "default:gravel" }},
	["default:cobble"]
		= { h = 0.05, r = 0.05, t = { "default:gravel" }},
	["default:mossycobble"]
		= { h = 0.05, r = 0.05, t = { "default:gravel" }},
	["default:desert_cobble"]
		= { h = 0.05, r = 0.05, t = { "default:gravel" }},
	["default:desert_stone"]
		= { h = 0.01, r = 0.01, t = { "default:desert_cobble" }},
	["default:stone"]
		= { h = 0.01, r = 0.01, t = { "default:cobble", "default:desert_cobble" }},
	["default:stone_with_coal"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["default:stone_with_iron"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["default:stone_with_copper"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["default:stone_with_gold"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["default:stone_with_mese"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["default:stone_with_diamond"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},

	-- mg
	["mg:dirt_with_dry_grass"]
		= { h = 1.0, r = 1.0, t = { "default:dirt" }, drop_as="default:dirt"},

	-- woodsoils
	["woodsoils:dirt_with_leaves_1"]
     = { h = 1.0, r = 1.0, t = { "default:dirt" }},
	["woodsoils:dirt_with_leaves_2"]
     = { h = 1.0, r = 1.0, t = { "woodsoils:dirt_with_leaves_1" }},
	["woodsoils:grass_with_leaves_1"]
		= { h = 1.0, r = 1.0, t = { "woodsoils:dirt_with_leaves_2" }},
	["woodsoils:grass_with_leaves_2"]
		= { h = 1.0, r = 1.0, t = { "woodsoils:grass_with_leaves_1" }},

	-- dryplants
	["dryplants:grass_short"]
		= { h = 1.0, r = 1.0, t = { "default:dirt" }},

	-- moreores
	["moreores:mineral_mithril"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["moreores:mineral_silver"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["moreores:mineral_tin"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["moreores:mineral_tin"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},

	-- technic
	["technic:mineral_chromium"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["technic:mineral_uranium"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
	["technic:mineral_zinc"]
		= { h = 0.0001, r = 0.01, t = { "default:stone", "default:desert_stone" }},
}
