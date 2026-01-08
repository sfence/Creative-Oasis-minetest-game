local S = core.get_translator(core.get_current_modname())

random_messages = {}

if core.settings:get("random_messages_disabled") == "true" then
	return
end


local messages = {
	S("You can craft tools and items using a crafting grid. Open your inventory to start crafting"),
	S("Furnaces allow you to smelt ores and cook items using fuel like coal or wood"),
	S("Sneak (Shift) prevents you from falling off edges while building or mining"),
}

local MESSAGE_INTERVAL = tonumber(core.settings:get("random_messages_interval")) or 120

function random_messages.get_random_message()
	return messages[math.random(1, #messages)]
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer > MESSAGE_INTERVAL then
		if #core.get_connected_players() > 0 then
			core.chat_send_all(
				core.colorize("#808080", random_messages.get_random_message()),
				"random_messages"
			)
		end
		timer = 0
	end
end)
