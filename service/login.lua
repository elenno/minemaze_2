local skynet = require "skynet"
local mongo_manager = require "mongo_manager"
local utils = require "utils"
local log = require "log"

local CMD = {}
local users = {}
local fd_user_map = {}
local fd_player_id_map = {}
local CUR_PLAYER_ID = 1
local player_manager

function CMD.login(fd, msg)
	log.log("CMD.login fd=" .. fd)
    user = users[msg.user_id]
    if  user ~= nil then
        user.is_online = true
        user.socket_fd = fd
        fd_user_map[fd] = msg.user_id
        fd_player_id_map[fd] = user.player_id
        log.log("CMD.login user_id=" .. msg.user_id)
		return true
	end

	return false
end

function CMD.on_logout(fd)  --todo
    log.log("CMD.on_logout fd=" .. fd)
    local user_id = fd_user_map[fd]
    local player_id = fd_player_id_map[fd]
    if user_id ~= nil then
        user = users[user_id]
        if user ~= nil then
            user.is_online = false
            user.socket_fd = -1
            log.log("CMD.on_logout user logout, username=" .. user_id)
        end
    end

    if player_id ~= nil then
        skynet.send(player_manager, "lua", "on_logout", player_id)
        log.log("CMD.on_logout player_manager logout, player_id=" .. player_id)
    end
    
    log.log("CMD.on_logout finish")
end

function CMD.get_player_id_by_fd(fd)
    return fd_player_id_map[fd]
end

function load_all_users()
	utils.print("load_all_users on start.............")
	local users_data = mongo_manager.get_all_data("users", {}, {_id = 0})
	if users_data then
		while users_data:hasNext() do
			local user_info = users_data:next()
			utils.print(user_info)
			users[user_info.user_name] = {
                player_id = user_info.player_id,
                is_online = false,
                socket_fd = -1
            }
			if user_info.player_id and user_info.player_id > CUR_PLAYER_ID then
				CUR_PLAYER_ID = user_info.player_id
			end
		end
	end
    utils.print("load_all_users finish...")
end

function CMD.init()
    load_all_users()
    player_manager = skynet.uniqueservice("player_manager")
end

skynet.start(function()
    CMD.init()

    skynet.dispatch("lua", function(_, _, cmd, ...)
        utils.print("login dispatch cmd=" .. cmd)
        local f = CMD[cmd]
        if f then
            f(...)
        else
            log.log("login service_clienthandler invalid_cmd %s", cmd)
        end
    end)
end)