-- spawn_waypoint/init.lua

local spawn_pos = {x = -490, y = 31, z = -540}
local waypoint_name = "[Spawn]"

-- name -> hud_id
local player_waypoints = {}

local function update_waypoint(player)
    if not player or not player:is_player() then
        return
    end

    local name = player:get_player_name()
    if not name or name == "" then
        return
    end

    -- Create waypoint once (no spam, no flicker)
    if not player_waypoints[name] then
        player_waypoints[name] = player:hud_add({
            hud_elem_type = "waypoint",
            world_pos = spawn_pos,
            text = waypoint_name,
            number = 0x0000FF, -- blue
        })
    end
end

-- Ensure waypoint exists for all players
local timer = 0
minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < 1 then return end
    timer = timer - 1

    for _, player in ipairs(minetest.get_connected_players()) do
        update_waypoint(player)
    end
end)

-- Add shortly after join
minetest.register_on_joinplayer(function(player)
    minetest.after(0.2, function()
        update_waypoint(player)
    end)
end)

-- Cleanup on leave
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    if name then
        player_waypoints[name] = nil
    end
end)
