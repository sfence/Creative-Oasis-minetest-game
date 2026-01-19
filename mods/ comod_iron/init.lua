
minetest.after(0, function()
    -- Recipe: 1 steel block → 9 steel ingots
    minetest.register_craft({
        output = "default:steel_ingot 9",
        recipe = {
            {"default:steelblock"}
        }
    })
    
	minetest.register_craft({
		type = "cooking",
		output = "default:steel_ingot",
		recipe = "technic:wrought_iron_dust",
		cooktime = 8
	})


end)




