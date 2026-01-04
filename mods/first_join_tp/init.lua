minetest.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	if meta:get_string("player_already_joined") ~= "true" then
		player:set_pos({x = -490, y = 31, z = -540})
		meta:set_string("player_already_joined", "true")
	end
end)
