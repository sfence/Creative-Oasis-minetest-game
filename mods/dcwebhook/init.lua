-- Minetest Discord Webhook
-- Version v2.1.1 patched
-- Safe patch: prevents clearing secure.http_mods

local http = minetest.request_http_api()
local conf = minetest.settings

if not http then
    minetest.log("error",
        "[Discord Webhook] Cannot access HTTP API. Add this mod to secure.http_mods to grant access.")
    return
end

-- Safe migration (v1.x → v2.x), without writing to minetest.conf
if not conf:get("dcwebhook.url") then
    if conf:get("dcwebhook_url") then
        conf:set("dcwebhook.url", conf:get("dcwebhook_url"))
        conf:remove("dcwebhook_url")

        if conf:get("lang") then
            conf:set("dcwebhook.lang", conf:get("lang"))
        end

        minetest.log("warning",
            "[Discord Webhook] Settings migrated. Please manually ensure your minetest.conf has:")
        minetest.log("warning",
            "dcwebhook.url = <your webhook URL>")
        minetest.log("warning",
            "secure.http_mods = dcwebhook (if not already set)")
    else
        minetest.log("error", "[Discord Webhook] Discord Webhook URL not set. Please set it in minetest.conf")
        return
    end
end

local function defined(key)
    local val = conf:get(key)
    if val == nil or val:match("^%s*$") then
        return nil
    else
        return val
    end
end

local texts = dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/texts.lua")
local lang = defined("dcwebhook.lang") or "en"

-- Default values
local get = {
    date = defined("dcwebhook.date") or "%d.%m.%Y %H:%M",

    send_chat = conf:get_bool("dcwebhook.send_chat", true),
    send_server_status = conf:get_bool("dcwebhook.send_server_status", true),
    send_joins = conf:get_bool("dcwebhook.send_joins", true),
    send_last_login = conf:get_bool("dcwebhook.send_last_login", true),
    send_leaves = conf:get_bool("dcwebhook.send_leaves", true),
    send_welcomes = conf:get_bool("dcwebhook.send_welcomes", true),
    send_deaths = conf:get_bool("dcwebhook.send_deaths", true),

    name_wrapper = defined("dcwebhook.name_wrapper") or "<**@1**>",
    include_server_status = conf:get_bool("dcwebhook.include_server_status", true),

    startup_text = defined("dcwebhook.startup_text") or texts[lang].startup,
    shutdown_text = defined("dcwebhook.shutdown_text") or texts[lang].shutdown,
    join_text = defined("dcwebhook.join_text") or texts[lang].join,
    last_login_text = defined("dcwebhook.last_login_text") or texts[lang].last_login,
    leave_text = defined("dcwebhook.leave_text") or texts[lang].leave,
    welcome_text = defined("dcwebhook.welcome_text") or texts[lang].welcome,
    death_text = defined("dcwebhook.death_text") or texts[lang].death,

    use_embeds_on_joins = conf:get_bool("dcwebhook.use_embeds_on_joins", true),
    use_embeds_on_leaves = conf:get_bool("dcwebhook.use_embeds_on_leaves", true),
    use_embeds_on_welcomes = conf:get_bool("dcwebhook.use_embeds_on_welcomes", true),
    use_embeds_on_deaths = conf:get_bool("dcwebhook.use_embeds_on_deaths", true),
    use_embeds_on_server_updates = conf:get_bool("dcwebhook.use_embeds_on_server_updates", true),
    notification_prefix = defined("dcwebhook.notification_prefix") or "\\*\\*\\*",

    -- Ensure colors are never nil
    startup_color = defined("dcwebhook.startup_color") or 5793266,
    shutdown_color = defined("dcwebhook.shutdown_color") or 8388736,
    join_color = defined("dcwebhook.join_color") or 5763719,
    leave_color = defined("dcwebhook.leave_color") or 15548997,
    welcome_color = defined("dcwebhook.welcome_color") or 5793266,
    death_color = defined("dcwebhook.death_color") or 0xFF0000
}

-- Simple @1, @2 replacement
local function replace(str, ...)
    local arg = {...}
    return str:gsub("@(.)", function(matched)
        return arg[tonumber(matched)]
    end)
end

-- Send webhook
local function send_webhook(data)
    local json = minetest.write_json(data)
    http.fetch({
        url = conf:get("dcwebhook.url"),
        method = "POST",
        extra_headers = {"Content-Type: application/json"},
        data = json
    }, function(result)
        if not result.succeeded then
            minetest.log("error", "[Discord Webhook] Failed to send webhook: " .. (result.error or "unknown"))
        end
    end)
end

-- Main registrations
local function perform_registrations()
    -- Chat messages
    if get.send_chat then
        minetest.register_on_chat_message(function(name, message)
            send_webhook({
                content = replace(get.name_wrapper, name) .. "  " .. message
            })
        end)
    end

    -- Server status
    if get.send_server_status then
        minetest.register_on_shutdown(function()
            local data = {}
            if not get.use_embeds_on_server_updates then
                data.content = get.notification_prefix .. " " .. get.shutdown_text
            else
                data.embeds = {{
                    title = get.shutdown_text,
                    color = get.shutdown_color
                }}
            end
            send_webhook(data)
        end)

        local function startup_message()
            local data = {}
            local status = get.include_server_status and (minetest.get_server_status() or "") or nil
            if not get.use_embeds_on_server_updates then
                data.content = get.notification_prefix .. " " .. get.startup_text ..
                               (status and " - " .. status or "")
            else
                data.embeds = {{
                    title = get.startup_text,
                    description = status,
                    color = get.startup_color
                }}
            end
            send_webhook(data)
        end

        startup_message()
    end

    -- Joins
    if get.send_joins then
        minetest.register_on_joinplayer(function(player, last_login)
            local name = player:get_player_name()
            local data = {}

            if last_login == nil and get.send_welcomes then
                if get.use_embeds_on_welcomes then
                    data.embeds = {{ description = replace(get.welcome_text, name), color = get.welcome_color }}
                else
                    data.content = get.notification_prefix .. " " .. replace(get.welcome_text, name)
                end
            else
                local msg = get.send_last_login and replace(get.last_login_text, name, os.date(get.date, last_login))
                           or replace(get.join_text, name)
                if get.use_embeds_on_joins then
                    data.embeds = {{ description = msg, color = get.join_color }}
                else
                    data.content = get.notification_prefix .. " " .. msg
                end
            end

            send_webhook(data)
        end)
    end

    -- Leaves
    if get.send_leaves then
        minetest.register_on_leaveplayer(function(player)
            local name = player:get_player_name()
            local data = {}

            if get.use_embeds_on_leaves then
                data.embeds = {{ description = replace(get.leave_text, name), color = get.leave_color }}
            else
                data.content = get.notification_prefix .. " " .. replace(get.leave_text, name)
            end

            send_webhook(data)
        end)
    end

    -- Deaths
    if get.send_deaths then
        minetest.register_on_dieplayer(function(player)
            local name = player:get_player_name()
            local data = {}

            if get.use_embeds_on_deaths then
                data.embeds = {{ description = replace(get.death_text, name), color = get.death_color }}
            else
                data.content = get.notification_prefix .. " " .. replace(get.death_text, name)
            end

            send_webhook(data)
        end)
    end
end

-- Delay registration so all mods load
minetest.after(0, function()
    perform_registrations()
end)


-- Ensure all staffrank chat messages also go to Discord
minetest.after(0, function()
    if staffranks then
        -- Wrap original chat function if exists
        local original_chat = staffranks.chat or function(name, message) end

        staffranks.chat = function(name, message)
            -- Call original chat so in-game chat works
            original_chat(name, message)

            -- Remove color codes (Discord can't show hex colors)
            local clean_name = name:gsub("#%x%x%x%x%x%x", "")
            local clean_message = message:gsub("#%x%x%x%x%x%x", "")

            -- Send to Discord via dcwebhook
            if dcwebhook and dcwebhook.send_webhook then
                dcwebhook.send_webhook({ content = "<**" .. clean_name .. "**>  " .. clean_message })
            end
        end
    end
end)

