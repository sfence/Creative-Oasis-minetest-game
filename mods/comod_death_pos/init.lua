local storage = minetest.get_mod_storage()
local death_markers = {}

-- Add death marker function
local function add_death_marker(player, pos)
    local name = player:get_player_name()

    -- Remove old HUD marker if exists
    if death_markers[name] then
        player:hud_remove(death_markers[name])
        death_markers[name] = nil
    end

    -- Add red waypoint marker
    death_markers[name] = player:hud_add({
        hud_elem_type = "waypoint",
        name = "You died here!",
        number = 0xFF0000, -- red
        world_pos = pos
    })
end

-- On death
minetest.register_on_dieplayer(function(player)
    local name = player:get_player_name()
    local pos = vector.round(player:get_pos())

    -- Save death position (for relog)
    storage:set_string(name, minetest.serialize(pos))

    -- Send chat message
    minetest.chat_send_player(
        name,
        minetest.colorize("#ff0000",
            "You died at: X=" .. pos.x .. " Y=" .. pos.y .. " Z=" .. pos.z
        )
    )

    -- Add marker
    add_death_marker(player, pos)
end)

-- On join (restore marker after relog)
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    local data = storage:get_string(name)

    if data ~= "" then
        local pos = minetest.deserialize(data)
        if pos then
            add_death_marker(player, pos)
        end
    end
end)
