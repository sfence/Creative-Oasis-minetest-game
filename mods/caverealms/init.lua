-- caverealms v0.8 modified for higher spawn rates

caverealms = {}

local modpath = minetest.get_modpath(minetest.get_current_modname())

dofile(modpath.."/config.lua")
dofile(modpath.."/crafting.lua")
dofile(modpath.."/nodes.lua")
dofile(modpath.."/functions.lua")
dofile(modpath.."/abms.lua")

if caverealms.config.falling_icicles then
	dofile(modpath.."/falling_ice.lua")
	print("[caverealms] falling icicles enabled.")
end

local FORTRESSES = caverealms.config.fortresses
local FOUNTAINS = caverealms.config.fountains

-- Parameters
local YMIN = caverealms.config.ymin
local YMAX = caverealms.config.ymax
local TCAVE = -0.2
local BLEND = 128

-- Decoration chances (increased)
local STAGCHA = caverealms.config.stagcha * 8      -- stalagmites
local STALCHA = caverealms.config.stalcha * 8      -- stalactites
local CRYSTAL = caverealms.config.crystal * 6      -- glow crystal
local GEMCHA = caverealms.config.gemcha * 3
local MUSHCHA = caverealms.config.mushcha * 3
local MYCCHA = caverealms.config.myccha * 3
local WORMCHA = caverealms.config.wormcha * 3
local GIANTCHA = caverealms.config.giantcha * 5
local ICICHA = caverealms.config.icicha * 3
local FLACHA = caverealms.config.flacha * 2
local FOUNCHA = caverealms.config.founcha * 5
local FORTCHA = caverealms.config.fortcha * 5

local DM_TOP = caverealms.config.dm_top
local DM_BOT = caverealms.config.dm_bot
local DEEP_CAVE = caverealms.config.deep_cave

-- 3D noise
local np_cave = {
	offset = 0, scale = 1,
	spread = {x=512, y=256, z=512},
	seed = 59033, octaves = 6, persist = 0.63
}
local np_wave = {
	offset = 0, scale = 1,
	spread = {x=256, y=256, z=256},
	seed = -400000000089, octaves = 3, persist = 0.67
}
local np_biome = {
	offset = 0, scale = 1,
	spread = {x=250, y=250, z=250},
	seed = 9130, octaves = 3, persist = 0.5
}

subterrain = {}
local yblmin = YMIN + BLEND * 1.5
local yblmax = YMAX - BLEND * 1.5

-- On generated
minetest.register_on_generated(function(minp, maxp, seed)
	if minp.y > YMAX or maxp.y < YMIN then return end

	local t1 = os.clock()
	local x0, y0, z0 = minp.x, minp.y, minp.z
	local x1, y1, z1 = maxp.x, maxp.y, maxp.z
	print ("[caverealms] chunk minp ("..x0.." "..y0.." "..z0..")")

	local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new{MinEdge=emin, MaxEdge=emax}
	local data = vm:get_data()
	
	local c_air = minetest.get_content_id("air")
	local c_stone = minetest.get_content_id("default:stone")

	if minetest.get_modpath("moontest") then
		c_air = minetest.get_content_id("moontest:vacuum")
		c_stone = minetest.get_content_id("moontest:stone")
	end

	-- grab content IDs for other nodes
	local c_ice = minetest.get_content_id("default:ice")
	local c_thinice = minetest.get_content_id("caverealms:thin_ice")
	local c_crystal = minetest.get_content_id("caverealms:glow_crystal")
	local c_gem1 = minetest.get_content_id("caverealms:glow_gem")
	local c_moss = minetest.get_content_id("caverealms:stone_with_moss")
	local c_worm = minetest.get_content_id("caverealms:glow_worm")
	local c_iciu = minetest.get_content_id("caverealms:icicle_up")
	local c_icid = minetest.get_content_id("caverealms:icicle_down")

	local sidelen = x1 - x0 + 1
	local chulens = {x=sidelen, y=sidelen, z=sidelen}
	local chulens2D = {x=sidelen, y=sidelen, z=1}
	local minposxyz = {x=x0, y=y0, z=z0}
	local minposxz = {x=x0, y=z0}

	local nvals_cave = minetest.get_perlin_map(np_cave, chulens):get3dMap_flat(minposxyz)
	local nvals_wave = minetest.get_perlin_map(np_wave, chulens):get3dMap_flat(minposxyz)
	local nvals_biome = minetest.get_perlin_map(np_biome, chulens2D):get2dMap_flat({x=x0+150, y=z0+50})

	local nixyz = 1
	local nixz = 1
	local nixyz2 = 1

	for z = z0, z1 do
		for y = y0, y1 do
			local tcave = TCAVE

			local vi = area:index(x0, y, z)
			for x = x0, x1 do
				if (nvals_cave[nixyz] + nvals_wave[nixyz])/2 > tcave then
					data[vi] = c_air
				end
				nixyz = nixyz + 1
				vi = vi + 1
			end
		end
	end

	--send data back to voxelmanip
	vm:set_data(data)
	vm:set_lighting({day=0, night=0})
	vm:calc_lighting()
	vm:write_to_map(data)

	local chugent = math.ceil((os.clock() - t1) * 1000)
	print ("[caverealms] "..chugent.." ms")
end)

print("[caverealms] loaded (high chance version)!")
