--[[

	Gravel Sieve Mod (fixed + custom outputs)
	========================================

	(Original header preserved)

]]--

gravelsieve = {
}

-- Load support for I18n
gravelsieve.S = minetest.get_translator("gravelsieve")
local S = gravelsieve.S

-- try to load hammer helper (if present)
local modpath = minetest.get_modpath("gravelsieve")
if modpath and minetest.get_modpath("gravelsieve") then
	local ok, err = pcall(function() dofile(minetest.get_modpath("gravelsieve") .. "/hammer.lua") end)
	-- ignore if missing
end

gravelsieve.ore_rarity = tonumber(minetest.settings:get("gravelsieve_ore_rarity")) or 1.16
gravelsieve.ore_max_elevation = tonumber(minetest.settings:get("gravelsieve_ore_max_elevation")) or 0
gravelsieve.ore_min_elevation = tonumber(minetest.settings:get("gravelsieve_ore_min_elevation")) or -30912
local y_spread = math.max(1 + gravelsieve.ore_max_elevation - gravelsieve.ore_min_elevation, 1)

-- Increase the probability over the natural occurrence
local PROBABILITY_FACTOR = tonumber(minetest.settings:get("gravelsieve_probability_factor")) or 3

local STEP_DELAY = tonumber(minetest.settings:get("gravelsieve_step_delay")) or 1.0

-- tubelib aging feature
local AGING_LEVEL1 = nil
local AGING_LEVEL2 = nil


-- Ore probability table  (1/n)
gravelsieve.ore_probability = {
}

gravelsieve.process_probabilities = {}


-- Pipeworks support placeholders (may be overridden if pipeworks present)
local pipeworks_after_dig = nil
local pipeworks_after_place = function(pos, placer) end

if minetest.get_modpath("pipeworks") and pipeworks ~= nil then
	pipeworks_after_dig = pipeworks.after_dig
	pipeworks_after_place = pipeworks.after_place
end

local function calculate_probability(item)
	local ymax = math.min(item.y_max, gravelsieve.ore_max_elevation)
	local ymin = math.max(item.y_min, gravelsieve.ore_min_elevation)
	-- avoid division by zero for y range
	local y_range = ((ymax - ymin) / y_spread)
	if y_range <= 0 then y_range = 1 end
	return (gravelsieve.ore_rarity / PROBABILITY_FACTOR) *
			(item.clust_scarcity or 1) / ((item.clust_num_ores or 1) * y_range)
end

local function pairs_by_values(t, f)
    if not f then
        f = function(a, b) return a > b end
    end
    local s = {}
    for k, v in pairs(t) do
        table.insert(s, {k, v})
    end
    table.sort(s, function(a, b)
        return f(a[2], b[2])
    end)
    local i = 0
    return function()
        i = i + 1
        local v = s[i]
        if v then
            return unpack(v)
        else
            return nil
        end
    end
end

local function parse_drop(drop)
	local d, count = drop:match("^%s*(%S+)%s+(%d+)%s*$")
	if d and count then
		return d, tonumber(count)
	end
	d, count = drop:match("%s*craft%s+\"?([^%s\"]+)\"?%s+(%d+)%s*")
	if d and count then
		return d, tonumber(count)
	end
	return drop, 1
end

-- collect all registered ores and calculate the probability
local function add_ores()
	if not minetest.registered_ores then
		return
	end
	for _,item in  pairs(minetest.registered_ores) do
		if item and item.ore and minetest.registered_nodes[item.ore] then
			local drop = minetest.registered_nodes[item.ore].drop
			if type(drop) == "string"
			and drop ~= item.ore
			and drop ~= ""
			and item.ore_type == "scatter"
			and item.wherein == "default:stone"
			and item.clust_scarcity ~= nil and item.clust_scarcity > 0
			and item.clust_num_ores ~= nil and item.clust_num_ores > 0
			and item.y_max ~= nil and item.y_min ~= nil then
				local count
				drop, count = parse_drop(drop)

				local probability = calculate_probability(item)
				if probability > 0 then
					local probabilityFraction = (count or 1) / probability
					local cur_probability = gravelsieve.ore_probability[drop]
					if cur_probability then
						gravelsieve.ore_probability[drop] = cur_probability + probabilityFraction
					else
						gravelsieve.ore_probability[drop] = probabilityFraction
					end
				end
			end
		end
	end
	minetest.log("action", "[gravelsieve] ore probabilities:")
	local overall_probability = 0.0
	for name,probability in pairs_by_values(gravelsieve.ore_probability) do
		if probability and probability ~= 0 then
			minetest.log("action", ("[gravelsieve] %-32s: 1 / %.02f"):format(name, 1.0 / probability))
			overall_probability = overall_probability + probability
		end
	end
	minetest.log("action", ("[gravelsieve] Overall probability %f"):format(overall_probability))
end

local function default_configuration()
	local normal_gravel = "default:gravel"
	local sieved_gravel = "gravelsieve:sieved_gravel"
	local gravel_probabilities = table.copy(gravelsieve.ore_probability)
	local overall_probability = 0
	for _,v in pairs(gravel_probabilities) do
		overall_probability = overall_probability + v
	end
	local remainder_probability = 0
	if overall_probability < 1 then
		remainder_probability = 1 - overall_probability
	end
	-- Give remainder half chance to normal gravel and half to sieved gravel
	gravel_probabilities[normal_gravel] = (gravel_probabilities[normal_gravel] or 0) + remainder_probability / 2.0
	gravel_probabilities[sieved_gravel] = (gravel_probabilities[sieved_gravel] or 0) + remainder_probability / 2.0

	return {
		[normal_gravel] = gravel_probabilities,
		[sieved_gravel] = {
			[sieved_gravel] = 1
		}
	}
end
-- DISABLED normalization: we want true num / total
local function normalize_probabilities(conf)
	return conf
end


local function normalize_config(current_config)
	local normalized_config = {}
	-- Normalize all inputs so their output probabilities always add up to 1
	for input, output_probabilities in pairs(current_config) do
		if output_probabilities then
			normalized_config[input] = normalize_probabilities(output_probabilities)
		end
	end
	return normalized_config
end

local function merge_config(def_conf, new_conf)
	local result_conf = table.copy(def_conf)
	for key,val in pairs(new_conf) do
		if type(val) == 'table' and type(result_conf[key]) == 'table' then
			result_conf[key] = merge_config(result_conf[key], val)
		else
			result_conf[key] = val
		end
	end
	return result_conf
end

local function configure_probabilities_step(current_config, funct_or_table)
	local var_type = type(funct_or_table)
	local conf
	if var_type == 'function' then
		conf = funct_or_table()
	elseif var_type == 'table' then
		conf = funct_or_table
	end
	if conf then
		return merge_config(current_config, conf)
	end
	return current_config
end

local configured = false
local set_probabilities = {default_configuration}

function gravelsieve.set_probabilities(funct_or_table)
	if configured then
		-- This is here so you can do hard overrides after everything has loaded if you need to
		-- Otherwise the order mods are loaded may cause them to override your configs
		local current_config = gravelsieve.process_probabilities or {}
		current_config = configure_probabilities_step(current_config, funct_or_table)
		gravelsieve.process_probabilities = normalize_config(current_config)
	else
		-- Build up a list of callbacks to be run after all mods are loaded
		table.insert(set_probabilities, funct_or_table)
	end
end

local function configure_probabilities()
	configured = true
	add_ores()
	local current_config = {}

	-- Run through all configs in order and merge them
	for _,funct_or_table in ipairs(set_probabilities) do
		current_config = configure_probabilities_step(current_config, funct_or_table)
	end
	gravelsieve.process_probabilities = normalize_config(current_config)
end

minetest.after(1, configure_probabilities)

local sieve_formspec =
	"size[8,8]"..
	(default and default.gui_bg or "")..
	(default and default.gui_bg_img or "")..
	(default and default.gui_slots or "")..
	"list[context;src;1,1.5;1,1;]"..
	"image[3,1.5;1,1;gui_furnace_arrow_bg.png^[transformR270]"..
	"list[context;dst;4,0;4,4;]"..
	"list[current_player;main;0,4.2;8,4;]"..
	"listring[context;dst]"..
	"listring[current_player;main]"..
	"listring[context;src]"..
	"listring[current_player;main]"


local function allow_metadata_inventory_put(pos, listname, index, stack, player)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	if listname == "src" then
		return stack:get_count()
	elseif listname == "dst" then
		return 0
	end
	return 0
end

local function allow_metadata_inventory_move(pos, from_list, from_index, to_list, to_index, count, player)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local stack = inv:get_stack(from_list, from_index)
	return allow_metadata_inventory_put(pos, to_list, to_index, stack, player)
end

local function allow_metadata_inventory_take(pos, listname, index, stack, player)
	if player and minetest.is_protected(pos, player:get_player_name()) then
		return 0
	end
	return stack:get_count()
end


-- handle the sieve animation
local function swap_node(pos, meta, start)
	local node = minetest.get_node(pos)
	local idx = meta:get_int("idx") or 0
	if start then
		if idx == 3 then
			idx = 0
		end
	else
		idx = (idx + 1) % 4
	end
	meta:set_int("idx", idx)
	local name = meta:get_string("node_name") or "gravelsieve:auto_sieve"
	node.name = name .. tostring(idx)
	minetest.swap_node(pos, node)
	return idx == 3
end

-- place ores to dst using true num / total
local function move_random_ore(inv, item)
	local probabilities = gravelsieve.process_probabilities[item]
	if not probabilities then return false end

	-- calculate total weight
	local total = 0
	for _, num in pairs(probabilities) do
		if type(num) == "number" and num > 0 then
			total = total + num
		end
	end
	if total <= 0 then return false end

	-- roll in range [0, total)
	local roll = math.random() * total
	local acc = 0

	for ore, num in pairs(probabilities) do
		acc = acc + num
		if roll <= acc then
			local ore_item = ItemStack(ore)
			if not inv:room_for_item("dst", ore_item) then
				return false
			end
			inv:add_item("dst", ore_item)
			return true
		end
	end

	return false
end


-- move gravel and ores to dst
local function move_src2dst(meta, pos, inv, item, dst)
	local src = ItemStack(item)
	if inv:room_for_item("dst", dst) and inv:contains_item("src", src) then
		local res = swap_node(pos, meta, false)
		if res then                                     -- time to move one item?
			local processed = move_random_ore(inv, item)
			if processed then
				inv:remove_item("src", src)
			end
		end
		return true  -- process finished
	end
	return false -- process still running
end

-- timer callback, alternatively called by on_punch
local function sieve_node_timer(pos, elapsed)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()

	for item,probabilities in pairs(gravelsieve.process_probabilities) do
		if probabilities and move_src2dst(meta, pos, inv, item) then
			--aging(pos, meta)
			return true
		end
	end

	minetest.get_node_timer(pos):stop()
	return false
end


for automatic = 0,1 do
for idx = 0,4 do
	local nodebox_data = {
		{ -8/16, -8/16, -8/16,   8/16, 4/16, -6/16 },
		{ -8/16, -8/16,  6/16,   8/16, 4/16,  8/16 },
		{ -8/16, -8/16, -8/16,  -6/16, 4/16,  8/16 },
		{  6/16, -8/16, -8/16,   8/16, 4/16,  8/16 },
		{ -6/16, -2/16, -6/16,  6/16, 8/16, 6/16 },
	}
	nodebox_data[5][5] =    (8 - 2*idx) / 16

	local node_name
	local description
	local tiles_data
	local tube_info
	if automatic == 0 then
		node_name = "gravelsieve:sieve"
		description = S("Gravel Sieve")
		tiles_data = {
			-- up, down, right, left, back, front
			"gravelsieve_gravel.png",
			"gravelsieve_gravel.png",
			"gravelsieve_sieve.png",
			"gravelsieve_sieve.png",
			"gravelsieve_sieve.png",
			"gravelsieve_sieve.png",
		}
	else
		node_name = "gravelsieve:auto_sieve"
		description = S("Automatic Gravel Sieve")
		tiles_data = {
			-- up, down, right, left, back, front
			"gravelsieve_gravel.png",
			"gravelsieve_gravel.png",
			"gravelsieve_auto_sieve.png",
			"gravelsieve_auto_sieve.png",
			"gravelsieve_auto_sieve.png",
			"gravelsieve_auto_sieve.png",
		}

		-- Pipeworks support
		tube_info = {
			insert_object = function(pos, node, stack, direction)
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				if automatic == 0 then
					local meta = minetest.get_meta(pos)
					swap_node(pos, meta, true)
				else
					minetest.get_node_timer(pos):start(STEP_DELAY)
				end
				return inv:add_item("src", stack)
			end,
			can_insert = function(pos, node, stack, direction)
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				return inv:room_for_item("src", stack)
			end,
			input_inventory = "dst",
			connect_sides = {left = 1, right = 1, front = 1, back = 1, bottom = 1, top = 1}
		}
	end

	local not_in_creative_inventory
	if idx == 3 then
		tiles_data[1] = "gravelsieve_top.png"
		not_in_creative_inventory = 0
	else
		not_in_creative_inventory = 1
	end


	minetest.register_node(node_name..idx, {
		description = description,
		tiles = tiles_data,
		use_texture_alpha = "clip",
		drawtype = "nodebox",
        drop = node_name,

		tube = tube_info,     --  NEW

		node_box = {
			type = "fixed",
			fixed = nodebox_data,
		},
		selection_box = {
			type = "fixed",
			fixed = { -8/16, -8/16, -8/16,   8/16, 4/16, 8/16 },
		},

		on_timer = sieve_node_timer,

		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_int("idx", idx)        -- for the 4 sieve phases
			meta:set_int("gravel_cnt", 0)   -- counter to switch between gravel and sieved gravel
			meta:set_string("node_name", node_name)
			meta:set_string("formspec", sieve_formspec)
			local inv = meta:get_inventory()
			inv:set_size('src', 1)
			inv:set_size('dst', 16)
		end,

		-- Pipeworks support
		after_dig_node = pipeworks_after_dig,

		after_place_node = function(pos, placer)
			local meta = minetest.get_meta(pos)
			meta:set_string("infotext", "Gravel Sieve")

			-- Pipeworks support
			pipeworks_after_place(pos, placer)
		end,

		on_metadata_inventory_move = function(pos)
			if automatic == 0 then
				local meta = minetest.get_meta(pos)
				swap_node(pos, meta, true)
			else
				minetest.get_node_timer(pos):start(STEP_DELAY)
			end
		end,

		on_metadata_inventory_take = function(pos)
			if automatic == 0 then
				local meta = minetest.get_meta(pos)
				local inv = meta:get_inventory()
				if inv:is_empty("src") then
					-- sieve should be empty
					meta:set_int("idx", 2)
					swap_node(pos, meta, false)
					meta:set_int("gravel_cnt", 0)
				end
			else
				minetest.get_node_timer(pos):start(STEP_DELAY)
			end
		end,

		on_metadata_inventory_put = function(pos)
			if automatic == 0 then
				local meta = minetest.get_meta(pos)
				swap_node(pos, meta, true)
			else
				minetest.get_node_timer(pos):start(STEP_DELAY)
			end
		end,

		on_punch = function(pos, node, puncher, pointed_thing)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if inv:is_empty("dst") and inv:is_empty("src") then
				minetest.node_punch(pos, node, puncher, pointed_thing)
			else
				sieve_node_timer(pos, 0)
			end
		end,

		on_dig = function(pos, node, puncher, pointed_thing)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if inv:is_empty("dst") and inv:is_empty("src") then
				minetest.node_dig(pos, node, puncher, pointed_thing)
			end
		end,

		allow_metadata_inventory_put = allow_metadata_inventory_put,
		allow_metadata_inventory_move = allow_metadata_inventory_move,
		allow_metadata_inventory_take = allow_metadata_inventory_take,

		paramtype = "light",
		sounds = (default and default.node_sound_wood_defaults and default.node_sound_wood_defaults()) or nil,
		paramtype2 = "facedir",
		sunlight_propagates = true,
		is_ground_content = false,
		groups = {choppy=2, cracky=1, not_in_creative_inventory=not_in_creative_inventory, tubedevice = 1, tubedevice_receiver = 1},
		drop = node_name.."3",
		on_blast = function() end,
	})
end
end


------------------------------------------------------------------------
-- Optional adaption to tubelib
------------------------------------------------------------------------
if minetest.global_exists("tubelib") then
	minetest.register_node("gravelsieve:sieve_defect", {
		tiles = {
			-- up, down, right, left, back, front
			"gravelsieve_top.png",
			"gravelsieve_gravel.png",
			"gravelsieve_auto_sieve.png^tubelib_defect.png",
		},
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{ -8/16, -8/16, -8/16,   8/16, 4/16, -6/16 },
				{ -8/16, -8/16,  6/16,   8/16, 4/16,  8/16 },
				{ -8/16, -8/16, -8/16,  -6/16, 4/16,  8/16 },
				{  6/16, -8/16, -8/16,   8/16, 4/16,  8/16 },
				{ -6/16, -2/16, -6/16,   6/16, 2/16,  6/16 },
			},
		},
		selection_box = {
			type = "fixed",
			fixed = { -8/16, -8/16, -8/16,   8/16, 4/16, 8/16 },
		},

		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_int("idx", 0)        -- for the 4 sieve phases
			meta:set_int("gravel_cnt", 0)   -- counter to switch between gravel and sieved gravel
			meta:set_string("node_name", "gravelsieve:auto_sieve")
			meta:set_string("formspec", sieve_formspec)
			local inv = meta:get_inventory()
			inv:set_size('src', 1)
			inv:set_size('dst', 16)
		end,

		after_place_node = function(pos, placer)
			local meta = minetest.get_meta(pos)
			meta:set_string("infotext", S("Gravel Sieve"))
		end,

		on_dig = function(pos, node, puncher, pointed_thing)
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			if inv:is_empty("dst") and inv:is_empty("src") then
				minetest.node_dig(pos, node, puncher, pointed_thing)
			end
		end,

		allow_metadata_inventory_put = allow_metadata_inventory_put,
		allow_metadata_inventory_move = allow_metadata_inventory_move,
		allow_metadata_inventory_take = allow_metadata_inventory_take,

		paramtype = "light",
		sounds = (default and default.node_sound_wood_defaults and default.node_sound_wood_defaults()) or nil,
		paramtype2 = "facedir",
		sunlight_propagates = true,
		is_ground_content = false,
		groups = {choppy=2, cracky=1, not_in_creative_inventory=1},
		on_blast = function() end,
	})

	tubelib.register_node("gravelsieve:auto_sieve3",
		{
			"gravelsieve:auto_sieve0",
			"gravelsieve:auto_sieve1",
			"gravelsieve:auto_sieve2",
			"gravelsieve:sieve_defect",
		},
		{
		on_pull_item = function(pos, side)
			local meta = minetest.get_meta(pos)
			return tubelib.get_item(meta, "dst")
		end,
		on_push_item = function(pos, side, item)
			minetest.get_node_timer(pos):start(STEP_DELAY)
			local meta = minetest.get_meta(pos)
			return tubelib.put_item(meta, "src", item)
		end,
		on_unpull_item = function(pos, side, item)
			local meta = minetest.get_meta(pos)
			return tubelib.put_item(meta, "dst", item)
		end,
		on_node_load = function(pos)
			minetest.get_node_timer(pos):start(STEP_DELAY)
		end,
		on_node_repair = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_int("tubelib_aging", 0)
			meta:set_int("idx", 2)
			meta:set_string("node_name", "gravelsieve:auto_sieve")
			local inv = meta:get_inventory()
			inv:set_size('src', 1)
			inv:set_size('dst', 16)
			swap_node(pos, meta, false)
			minetest.get_node_timer(pos):start(STEP_DELAY)
			return true
		end,
	})
end

minetest.register_node("gravelsieve:sieved_gravel", {
	description = S("Sieved Gravel"),
	tiles = {"default_gravel.png"},
	groups = {crumbly=2, falling_node=1, not_in_creative_inventory=1},
	sounds = (default and default.node_sound_gravel_defaults and default.node_sound_gravel_defaults()) or nil,
})

minetest.register_node("gravelsieve:compressed_gravel", {
	description = S("Compressed Gravel"),
	tiles = {"gravelsieve_compressed_gravel.png"},
	groups = {cracky=2, crumbly = 2, cracky = 2},
	sounds = (default and default.node_sound_gravel_defaults and default.node_sound_gravel_defaults()) or nil,
})

minetest.register_craft({
	output = "gravelsieve:sieve3",
	recipe = {
		{"group:wood", "",                      "group:wood"},
		{"group:wood", "default:steel_ingot",   "group:wood"},
		{"group:wood", "",                      "group:wood"},
	},
})

minetest.register_craft({
	output = "gravelsieve:auto_sieve3",
	type = "shapeless",
	recipe = {
		"gravelsieve:sieve3", "default:mese_crystal",  "default:mese_crystal",
	},
})

minetest.register_craft({
	output = "gravelsieve:compressed_gravel",
	recipe = {
		{"gravelsieve:sieved_gravel", "gravelsieve:sieved_gravel"},
		{"gravelsieve:sieved_gravel", "gravelsieve:sieved_gravel"},
	},
})

minetest.register_craft({
	type = "cooking",
	output = "default:cobble",
	recipe = "gravelsieve:compressed_gravel",
	cooktime = 10,
})

minetest.register_alias("gravelsieve:sieve", "gravelsieve:sieve3")
minetest.register_alias("gravelsieve:auto_sieve", "gravelsieve:auto_sieve3")

-- adaption to hopper
if minetest.get_modpath("hopper") and hopper ~= nil and hopper.add_container ~= nil then
	hopper:add_container({
		{"bottom", "gravelsieve:auto_sieve0", "src"},
		{"top", "gravelsieve:auto_sieve0", "dst"},
		{"side", "gravelsieve:auto_sieve0", "src"},

		{"bottom", "gravelsieve:auto_sieve1", "src"},
		{"top", "gravelsieve:auto_sieve1", "dst"},
		{"side", "gravelsieve:auto_sieve1", "src"},

		{"bottom", "gravelsieve:auto_sieve2", "src"},
		{"top", "gravelsieve:auto_sieve2", "dst"},
		{"side", "gravelsieve:auto_sieve2", "src"},

		{"bottom", "gravelsieve:auto_sieve3", "src"},
		{"top", "gravelsieve:auto_sieve3", "dst"},
		{"side", "gravelsieve:auto_sieve3", "src"},
	})
end

-- adaption to Circular Saw (moreblocks)
if minetest.get_modpath("moreblocks") and stairsplus and stairsplus.register_all then
	stairsplus:register_all("gravelsieve", "compressed_gravel", "gravelsieve:compressed_gravel", {
		description = S("Compressed Gravel"),
		groups = {cracky=2, crumbly=2, choppy=2, not_in_creative_inventory=1},
		tiles = {"gravelsieve_compressed_gravel.png"},
		sounds = (default and default.node_sound_stone_defaults and default.node_sound_stone_defaults()) or nil,
	})
end

----------------------------------------------------------------
-- CUSTOM: force sieve to output only the list you provided
-- Input: default:gravel should produce only the items below.
-- Sieved gravel produces only sieved_gravel (keeps behavior).
----------------------------------------------------------------

gravelsieve.set_probabilities({
	-- when input is normal gravel, choose only from this list
	["default:gravel"] = {
		["default:gold_lump"] = 1,
		["technic:uranium_lump"] = 1,
		["moreores:silver_lump"] = 1,
		["ruby:ruby"] = 1,
		["sapphire:sapphire"] = 1,
		["emerald:emerald"] = 1,
		["amethyst:amethyst_ingot"] = 1,
		["default:iron_lump"] = 1,
		["default:coal_lump"] = 1,
		["default:copper_lump"] = 1,
		["default:tin_lump"] = 1,
		["technic:chromium_lump"] = 1,
		["technic:zinc_lump"] = 1,
		["terumet:lump_raw"] = 1,
		["gravelsieve:sieved_gravel"] = 1,
		["default:gravel"] = 1,
	},
	-- keep sieved_gravel producing itself only (so compressed/processing remains sane)
	["gravelsieve:sieved_gravel"] = {
		["gravelsieve:sieved_gravel"] = 1
	}
})

-- Re-apply the custom override again after mods loaded (defensive)
minetest.register_on_mods_loaded(function()
	-- ensure our override persists if something else tried to replace process_probabilities
	gravelsieve.set_probabilities({
		["default:gravel"] = {
			["default:gold_lump"] = 8,
			["technic:uranium_lump"] = 23,
			["moreores:silver_lump"] = 18,
			["ruby:ruby"] = 25,
			["sapphire:sapphire"] = 25,
			["emerald:emerald"] = 25,
			["amethyst:amethyst_ingot"] = 30,
			["default:iron_lump"] = 50,
			["default:coal_lump"] = 40,
			["default:copper_lump"] = 40,
			["default:tin_lump"] = 55,
			["technic:chromium_lump"] = 76,
			["technic:zinc_lump"] = 79,
			["terumet:lump_raw"] = 26,
			["gravelsieve:sieved_gravel"] = 21,
			["default:gravel"] = 25,
		},
		["gravelsieve:sieved_gravel"] = {
			["gravelsieve:sieved_gravel"] = 1
		}
	})
end)
