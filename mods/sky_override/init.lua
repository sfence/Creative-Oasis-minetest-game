-- sky_override/init.lua
-- Sets a normal sky for all players and re-applies it regularly

-- Function to set normal sky for a player
local function set_normal_sky(player)
    player:set_sky({
        type = "regular",
        sky_color = {
            day_sky = "#87CEEB",
            day_horizon = "#FFFFFF",
            dawn_sky = "#FFA07A",
            dawn_horizon = "#FFDAB9",
            night_sky = "#000000",
            night_horizon = "#000000",
            indoors = "#FFFFFF",
        },
        clouds = true,
        sun = true,
        moon = true,
    })
end

-- Apply sky when a player joins
minetest.register_on_joinplayer(function(player)
    set_normal_sky(player)
end)

-- Reapply sky every 5 seconds to prevent glitches
local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer >= 5 then
        timer = 0
        for _, player in ipairs(minetest.get_connected_players()) do
            set_normal_sky(player)
        end
    end
end)
