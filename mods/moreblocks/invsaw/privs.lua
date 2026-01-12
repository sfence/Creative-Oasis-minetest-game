-- luacheck: globals minetest invsaw

-- Use only 'interact' privilege for saw
local function can_use_saw(player)
    return minetest.check_player_privs(player, {interact=true})
end

-- Override invsaw's check function
if invsaw and invsaw.check_use_status then
    local old_check = invsaw.check_use_status
    invsaw.check_use_status = function(player)
        if can_use_saw(player) then
            -- Enable saw icon / functionality
            old_check(player)
        else
            -- Optional: disable icon if player can't interact
            old_check(player)
        end
    end
end

-- Call check_use_status when a player joins
minetest.register_on_joinplayer(function(player)
    if can_use_saw(player) then
        if invsaw.check_use_status then
            invsaw.check_use_status(player)
        end
    end
end)

-- No need to register or override old privs, so we remove all the old code
-- invsaw.settings.priv and invsaw.settings.creative_priv are ignored
