-- comod_pvp/init.lua
-- PvP toggle mod for MTG

-- Function to remove nearby arrows (optional, if arrow entities exist)
local function remove_nearby_arrows(player, radius)
    local pos = player:get_pos()
    radius = radius or 5
    local objects = minetest.get_objects_inside_radius(pos, radius)
    for _, obj in ipairs(objects) do
        local luaentity = obj:get_luaentity()
        if luaentity and luaentity.name == "mcl_bows:arrow_entity" then
            obj:remove()
        end
    end
end

-- Check if PvP is enabled for a player
local function is_pvp_enabled(player)
    return player:get_meta():get_string("pvp_enabled") == "true"
end

-- Toggle PvP for a player and send chat message
local function toggle_pvp(player)
    local meta = player:get_meta()
    if is_pvp_enabled(player) then
        meta:set_string("pvp_enabled", "false")
        minetest.chat_send_player(player:get_player_name(), "You disabled PvP mode!")
    else
        meta:set_string("pvp_enabled", "true")
        minetest.chat_send_player(player:get_player_name(), "You enabled PvP mode!")
    end
end

-- Show PvP toggle GUI
local function show_pvp_formspec(player)
    local button_label = is_pvp_enabled(player) and "Disable PvP" or "Enable PvP"
    local formspec = "size[6,3]" ..
                     "label[1.5,0.5;PvP Settings]" ..
                     "button[2,1.2;2,1;toggle_pvp;" .. button_label .. "]"
    minetest.show_formspec(player:get_player_name(), "comod_pvp:gui", formspec)
end

-- Show PvP warning with auto height
local function show_pvp_warning(player, message)
    -- Count number of lines in the message (split by \n)
    local line_count = 1
    for _ in message:gmatch("\n") do
        line_count = line_count + 1
    end

    -- Compute formspec height: each line takes ~0.7, plus space for button
    local height = 0.7 * line_count + 1.5
    if height < 2 then height = 2 end -- minimum height

    local button_y = 0.7 * line_count + 0.5

    local formspec = "size[6," .. height .. "]" ..
                     "label[0.5,0.5;" .. minetest.formspec_escape(message) .. "]" ..
                     "button_exit[2," .. button_y .. ";2,1;ok;OK]"

    minetest.show_formspec(player:get_player_name(), "comod_pvp:warning", formspec)
end

-- /toggle_pvp command
minetest.register_chatcommand("toggle_pvp", {
    description = "Open PvP toggle GUI",
    privs = {interact = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            show_pvp_formspec(player)
        end
    end,
})

-- Handle formspec button click
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == "comod_pvp:gui" and fields.toggle_pvp then
        toggle_pvp(player)
        show_pvp_formspec(player) -- refresh GUI
    end
end)

-- Prevent damage if PvP is disabled and show GUI warning
minetest.register_on_punchplayer(function(player, hitter, ...)
    if player:is_player() and hitter:is_player() then
        local player_pvp = is_pvp_enabled(player)
        local hitter_pvp = is_pvp_enabled(hitter)

        if not hitter_pvp then
            remove_nearby_arrows(player, 5)
            show_pvp_warning(hitter, "Your PvP mode is disabled!\nYou cannot hit other players.\nType /toggle_pvp to enable.")
            return true
        elseif not player_pvp then
            remove_nearby_arrows(player, 5)
            show_pvp_warning(hitter, "Their PvP mode is disabled!\nYou cannot hit them.\nThey need to type /toggle_pvp to enable.")
            return true
        end
    end
end)

-- Initialize PvP setting as disabled on join
minetest.register_on_joinplayer(function(player)
    local meta = player:get_meta()
    if meta:get_string("pvp_enabled") == "" then
        meta:set_string("pvp_enabled", "false")
    end
end)
