local skynet = require "skynet"
local log = require "log"
local mongo_manager = require "mongo_manager"
local ZZMathBit = require "tools/bit"
local utils = require "utils"

local player_map = {}
local player_manager = {}

function player_manager.on_login(fd, player_id) 
	log.log("player_manager on_login   player_id:%d", player_id)
	local player_info = player_manager.get_player(player_id)
	player_info.last_login_time = os.time()
	player_info.net_id = fd
	player_manager.save_player(player_id, player_info)
	--记录当前登录时间
	--下发相关数据（关卡等信息）
	
	player_manager.send_player_info(player_id, player_info)
end

function player_manager.on_logout(player_id) 
	log.log("player_manager on_logout player_id=" .. player_id)
	local player_info = player_manager.get_player(player_id)
	player_info.last_logout_time = os.time()
	player_info.net_id = -1
	player_manager.save_player(player_id, player_info)
end

function player_manager.get_player(player_id) 
	if not player_map[player_id] then 
		--从数据库取数据到缓存
		local player = mongo_manager.get_data("player", {player_id = player_id})
		if player then
			player_map[player_id] = player
		else
			--todo 暂时填简单的数据
			local player_tmp = {}
			player_tmp.player_id = player_id
			player_tmp.player_name = "测试账号"
			player_tmp.last_login_time = 0
			player_tmp.last_logout_time = 0
			player_tmp.story_record = 0 -- 用位运算，去表示7个故事关卡的完成情况
			player_tmp.challenging_maze_type = -1 -- 正在挑战的迷宫类型
			player_tmp.challenging_maze_id = -1 -- 正在挑战的迷宫id
			player_tmp.face_direction = 0 -- 朝向（ 0 1 2 3 ）
			player_tmp.cur_pos_x = -1
			player_tmp.cur_pos_y = -1
			player_tmp.net_id = -1
			player_map[player_id] = player_tmp
		end
		
	end
		
	return player_map[player_id]
end

function player_manager.save_player(player_id, player)
	player_map[player_id] = player

	--写到数据库里
	mongo_manager.save_data("player", {player_id = player_id}, player)
end

function player_manager.send_player_info(player_id, player_info)
	local MsgPlayerInfoResp = {}
	MsgPlayerInfoResp.player_id = player_info.player_id
	MsgPlayerInfoResp.player_name = player_info.player_name
	MsgPlayerInfoResp.story_record = player_info.story_record
	MsgPlayerInfoResp.challenging_maze_type = player_info.challenging_maze_type
	MsgPlayerInfoResp.challenging_maze_id = player_info.challenging_maze_id
	--MsgPlayerInfoResp.face_direction = player_info.face_direction
	--MsgPlayerInfoResp.cur_pos_x = player_info.cur_pos_x
	--MsgPlayerInfoResp.cur_pos_y = player_info.cur_pos_y

	--调用watchdog把proto传出去
	skynet.send("watchdog", "lua", "socket", "send", player_info.net_id, 0, "PbPlayer.MsgPlayerInfoResp",  MsgPlayerInfoResp)
end

function player_manager.on_query_player_info_req(player_id)
	local player_info = player_manager.get_player(player_id)
	player_manager.send_player_info(player_id, player_info)
end

function player_manager.start_challenge(player_id, maze_type, maze_id)
	local player_info = player_manager.get_player(player_id)
	if not player_info then
		return
	end

	player_info.challenging_maze_type = maze_type
	player_info.challenging_maze_id = maze_id
	--player_info.face_direction = 0   todo  根据maze_type读取该地图

	player_manager.send_player_info(player_id, player_info)
end

function player_manager.finish_challenge(player_id, maze_type, maze_id)
	local player_info = player_manager.get_player(player_id)
	if not player_info then
		return false
	end

	if player_info.challenging_maze_type ~= maze_type then
		return false 
	end

	if player_info.challenging_maze_id ~= maze_id then
		return false 
	end

	--todo 检测maze_type maze_id合法性 配合配置

	player_info.challenging_maze_type = -1
	player_info.challenging_maze_id = -1
	player_info.face_direction = 0
	player_info.cur_pos_x = -1
	player_info.cur_pos_y = -1

	if maze_type == 0 then --todo 判断是否故事模式
		player_info.story_record = player_info.story_record + ZZMathBit.orOp(1, maze_id)
	end

	player_manager.send_player_info(player_id, player_info)
end

function player_manager.on_change_nickname_req(player_id, nickname)
	local player_info = player_manager.get_player(player_id)
	player_info.player_name = nickname  --TODO 加敏感词检测 加重复检测
	player_manager.save_player(player_id, player_info)	
	player_manager.send_player_info(player_id, player_info)
end

function player_manager.send_operate_notice(player_id, notice_code)
	local player_info = player_manager.get_player(player_id)
	if not player_info then
		return false
	end

	local MsgNoticeResp = {}
	MsgNoticeResp.notice_code = notice_code
	skynet.send("watchdog", "lua", "socket", "send", player_info.net_id, 0, "PbCommon.MsgNoticeResp",  MsgNoticeResp)
end

function load_all_player()
	utils.print("load_all_player on start.............")
	local all_player_data = mongo_manager.get_all_data("player", {}, {_id = 0})
	if all_player_data then
		while all_player_data:hasNext() do
			local player_info = all_player_data:next()
			utils.print(player_info)
			player_map[player_info.player_id] = player_info
		end
	end
    utils.print("load_all_player finish...")
end

function player_manager.init()
    load_all_player()
end

skynet.start(function()
    player_manager.init()

    skynet.dispatch("lua", function(_, _, cmd, ...)
        utils.print("player_manager service dispatch cmd=" .. cmd)
        local f = player_manager[cmd]
        if f then
            local ret = f(...)
            skynet.ret(skynet.pack(ret))
        else
            log.log("player_manager service invalid_cmd %s", cmd)
			skynet.ret(skynet.pack(nil, "player_manager service_clienthandler invalid_cmd " .. cmd))
        end
    end)
end)