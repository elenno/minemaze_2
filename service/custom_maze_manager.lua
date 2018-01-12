local skynet = require "skynet"
local log = require "log"
local mongo_manager = require "mongo_manager"
local ZZMathBit = require "tools/bit"
local utils = require "utils"
local retcode = require "retcode"

local custom_maze_manager = {}  -- manager
local custom_maze_map = {}  -- 玩家迷宫列表
local maze_info_map = {}  -- 迷宫信息map
local player_manager

function custom_maze_manager.get_player_custom_maze(player_id) 
	if not custom_maze_map[player_id] then 
		--从数据库取数据到缓存
		local custom_maze = mongo_manager.get_data("custom_maze", {player_id = player_id})
		if custom_maze then
			custom_maze_map[player_id] = custom_maze
		else
			--todo 暂时填简单的数据
			local custom_maze_tmp = {}
			custom_maze_tmp.player_id = player_id
			custom_maze_tmp.custom_maze_list = {}
			
			custom_maze_map[player_id] = custom_maze_tmp
		end
		
	end
		
	return custom_maze_map[player_id]
end

function custom_maze_manager.get_maze_info(maze_id)
	if not maze_info_map[maze_id] then
		--从数据库取数据到缓存
		local maze_info = mongo_manager.get("maze_info", {maze_id = maze_id})
		if maze_info then
			maze_info_map[maze_id] = maze_info
		else
			return nil
		end
	end

	return maze_info_map[maze_id]
end

function custom_maze_manager.save_player_custom_maze(player_id, custom_maze)
	custom_maze_map[player_id] = custom_maze
	mongo_manager.save_data("custom_maze", {player_id = player_id}, custom_maze)
end

function custom_maze_manager.save_maze_info(maze_id, maze_info)
	maze_info_map[maze_id] = maze_info
	mongo_manager.save_data("maze_info", {maze_id = maze_id}, maze_info)	
end

function custom_maze_manager.add_custom_maze(player_id, maze_id)
	local custom_maze = custom_maze_manager.get_player_custom_maze(player_id)
	local is_found = false
	for i = 1, #custom_maze.custom_maze_list do
		if maze_id == custom_maze.custom_maze_list[i] then
			is_found = true
		end
	end

	if not is_found then
		table.insert(custom_maze.custom_maze_list, #custom_maze.custom_maze_list + 1, maze_id)
		custom_maze_manager.save_player_custom_maze(player_id, custom_maze);
	end
end

function custom_maze_manager.on_create_custom_maze_req(fd, player_id, maze_info)
	local maze_id = mongo_manager.get_data_count("custom_maze", {}) -- TODO 改为获取最大的maze_id+1
	maze_info["maze_id"] = maze_id
	maze_info["player_id"] = player_id
	maze_info["enable"] = true
	custom_maze_manager.add_custom_maze(player_id, maze_id) --add包含了save了
	custom_maze_manager.save_maze_info(maze_id, maze_info)	--保存自定义迷宫

	skynet.send(player_manager, "lua", "send_operate_notice", player_id, retcode.OK)
end

function custom_maze_manager.on_edit_custom_maze_req(fd, player_id, maze_info)
	local maze_info_2 = custom_maze_manager.get_maze_info(maze_info.maze_id)
	if nil ~= maze_info_2 and maze_info_2.enable and maze_info_2.player_id == player_id then
		maze_info.player_id = player_id
		maze_info.enable = true
		custom_maze_manager.save_maze_info(maze_info.maze_id, maze_info)
		skynet.send(player_manager, "lua", "send_operate_notice", player_id, retcode.OK)
	end
end

function custom_maze_manager.on_query_my_custom_maze_list_req(fd, player_id)
	local MsgMyCustomMazeListResp = {}
	local custom_maze = custom_maze_manager.get_player_custom_maze(player_id)
	for i = 1, #custom_maze.custom_maze_list do 
		local maze_info = custom_maze_manager.get_maze_info(custom_maze.custom_maze_list[i])
		if nil ~= maze_info and maze_info.enable then
			local SimpleCustomMazeInfo = {}
			SimpleCustomMazeInfo.maze_id = maze_info.maze_id
			SimpleCustomMazeInfo.maze_name = maze_info.maze_name
			SimpleCustomMazeInfo.maze_height = maze_info.maze_height
			SimpleCustomMazeInfo.maze_width = maze_info.maze_width
			table.insert(MsgMyCustomMazeListResp.maze_list, SimpleCustomMazeInfo)
		end
	end

	MsgMyCustomMazeListResp.maze_count = #MsgMyCustomMazeListResp.maze_list
	skynet.send("watchdog", "lua", "socket", "send", fd, 0, "PbPlayer.MsgMyCustomMazeListResp",  MsgMyCustomMazeListResp)
end

function custom_maze_manager.on_delete_custom_maze_req(fd, player_id, maze_id)
	local my_custom_maze = custom_maze_manager.get_player_custom_maze(player_id)
	for i = 1, #my_custom_maze.custom_maze_list do
		if maze_id == my_custom_maze.custom_maze_list[i] then
			local maze_info = custom_maze_manager.get_maze_info(maze_id)
			if nil ~= maze_info then
				if maze_info.player_id == player_id then
					maze_info.enable = false
					custom_maze_manager.save_maze_info(maze_id, maze_info)
					
				end
			end

			table.remove(my_custom_maze.custom_maze_list, i)
			custom_maze_manager.save_player_custom_maze(player_id, my_custom_maze)
			break
		end 
	end

	custom_maze_manager.on_query_my_custom_maze_list_req(fd, player_id)
end

function custom_maze_manager.on_query_maze_info_req(fd, player_id, maze_id)
	local maze_info = custom_maze_manager.get_maze_info(maze_id)
	if nil ~= maze_info then
		local MsgMazeInfoResp = {}
		MsgMazeInfoResp.maze_type = 1
		MsgMazeInfoResp.maze_id = maze_id
		MsgMazeInfoResp.maze_name = maze_info.maze_name
		MsgMazeInfoResp.maze_height = maze_info.maze_height
		MsgMazeInfoResp.maze_width = maze_info.maze_width
		MsgMazeInfoResp.maze_map = maze_info.maze_map
		MsgMazeInfoResp.start_pos_x = maze_info.start_pos_x
		MsgMazeInfoResp.start_pos_y = maze_info.start_pos_y
		MsgMazeInfoResp.end_pos_x = maze_info.end_pos_x
		MsgMazeInfoResp.end_pos_y = maze_info.end_pos.y
		MsgMazeInfoResp.head_line = maze_info.head_line
		MsgMazeInfoResp.head_line_remark = maze_info.head_line_remark
		MsgMazeInfoResp.maze_setting_flag = maze_info.maze_setting_flag

		skynet.send("watchdog", "lua", "socket", "send", fd, 0, "PbPlayer.MsgMazeInfoResp",  MsgMazeInfoResp)
	end
end

function load_all_custom_maze()
	utils.print("load_all_custom_maze on start.............")
	local all_data = mongo_manager.get_all_data("custom_maze", {}, {_id = 0})
	if all_data then
		while all_data:hasNext() do
			local info = all_data:next()
			utils.print(info)
			custom_maze_map[info.player_id] = info
		end
	end
    utils.print("load_all_custom_maze finish...")
end

function load_all_maze_info()
	utils.print("load_all_maze_info on start.............")
	local all_data = mongo_manager.get_all_data("maze_info", {}, {_id = 0})
	if all_data then
		while all_data:hasNext() do
			local info = all_data:next()
			utils.print(info)
			maze_info_map[info.maze_id] = info
		end
	end
    utils.print("load_all_maze_info finish...")
end

function custom_maze_manager.init()
	load_all_custom_maze()
	load_all_maze_info()
	player_manager = skynet.uniqueservice("player_manager")
end

skynet.start(function()
    custom_maze_manager.init()

    skynet.dispatch("lua", function(_, _, cmd, ...)
        utils.print("custom_maze_manager service dispatch cmd=" .. cmd)
        local f = custom_maze_manager[cmd]
        if f then
            f(...)
        else
            log.log("custom_maze_manager service invalid_cmd %s", cmd)
        end
    end)
end)