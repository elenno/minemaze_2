--客户端请求处理，负责客户端请求的分发

local skynet = require "skynet"
local utils = require "utils"
local retcode = require "retcode"

local funs = {}
local login
local agentmgr
local roommgr
local player_manager
local custom_maze_manager

local handler_arr = {
    ["PbLogin.MsgLoginReq"] = function(...) funs.login_req(...) end,
    ["PbPlayer.MsgPlayerInfoReq"] = function(...) funs.player_info_req(...) end,
    ["PbPlayer.MsgChangeNickNameReq"] = function(...) funs.change_nickname_req(...) end,
    ["PbPlayer.MsgFinishChallengeReq"] = function(...) funs.finish_challenge_req(...) end,
    ["PbPlayer.MsgStartChallengeReq"] = function(...) funs.start_challenge_req(...) end,
    ["PbPlayer.MsgUploadCustomMazeReq"] = function(...) funs.upload_custom_maze_req(...) end,
    ["PbPlayer.MsgMyCustomMazeListReq"] = function(...) funs.my_custom_maze_list_req(...) end,
    ["PbPlayer.MsgMazeInfoReq"] = function(...) funs.maze_info_req(...) end,
}

--------------------------------------------------------------------------------

--登录
function funs.login_req(fd, msg)
    utils.print("funs.login_req: fd=" .. fd)
    local player_id = skynet.call(login, "lua", "login", fd, msg)
    if  player_id then
        utils.print("login ok send rsp")
        skynet.send(player_manager, "lua", "on_login", fd, player_id)
        local MsgLoginRsp = {
            platform = msg.platform,
            user_id = msg.user_id
        }      
        utils.print(MsgLoginRsp)
        skynet.send("watchdog", "lua", "socket", "send", fd, 0, "PbLogin.MsgLoginRsp",  MsgLoginRsp)
    else
        local MsgErrorResp = {
            error_code = retcode.LOGIN_ERROR_ACCOUNT_NOT_FOUND
        }
        skynet.send("watchdog", "lua", "socket", "send", fd, 0, "PbCommon.MsgErrorResp",  MsgErrorRsp)
    end 
end

--请求玩家信息
function funs.player_info_req(fd, msg)
    local player_id = skynet.call(login, "lua", "get_player_id_by_fd", fd)
    if nil == player_id 
    then
        return
    end
    skynet.send(player_manager, "lua", "on_query_player_info_req", player_id)
end

--请求修改昵称
function funs.change_nickname_req(fd, msg)
    local nickname = msg.nickname
    local player_id = skynet.call(login, "lua", "get_player_id_by_fd", fd)
    if nil == player_id 
    then
        return
    end

    skynet.send(player_manager, "lua", "on_change_nickname_req", player_id, nickname)
end

--请求完成迷宫
function funs.finish_challenge_req(fd, msg)
    local player_id = skynet.call(login, "lua", "get_player_id_by_fd", fd)
    if nil == player_id
    then
        return
    end

    local maze_type = msg.maze_type
    local maze_id = msg.maze_id

    skynet.send(player_manager, "lua", "finish_challenge", player_id, maze_type, maze_id)
end

--请求开始迷宫
function funs.start_challenge_req(fd, msg)
    local player_id = skynet.call(login, "lua", "get_player_id_by_fd", fd)
    if nil == player_id
    then
        return
    end

    local maze_type = msg.maze_type
    local maze_id = msg.maze_id

    skynet.send(player_manager, "lua", "start_challenge", player_id, maze_type, maze_id)
end

--请求上传自定义迷宫
function funs.upload_custom_maze_req(fd, msg)
    local player_id = skynet.call(login, "lua", "get_player_id_by_fd", fd)
    if nil == player_id then
        return
    end

	--todo 检查参数合法性 字符串要检查敏感字

    local maze_info = {}
	maze_info.maze_name = msg.maze_name
	maze_info.maze_height = msg.maze_height
	maze_info.maze_width = msg.maze_width
	maze_info.maze_map = msg.maze_map
	maze_info.start_pos_x = msg.start_pos_x
	maze_info.start_pos_y = msg.start_pos_y
	maze_info.end_pos_x = msg.end_pos_x
	maze_info.end_pos_y = msg.end_pos_y
	maze_info.head_line = msg.head_line
	maze_info.head_line_remark = msg.head_line_remark
	maze_info.maze_setting_flag = msg.maze_setting_flag

	skynet.send(service.custom_maze_manager, "lua", "on_create_custom_maze_req", fd, player_id, maze_info)
end

--请求玩家自身的自定义迷宫列表
function funs.my_custom_maze_list_req(fd, msg)
    local player_id = skynet.call(login, "lua", "get_player_id_by_fd", fd)
    if nil == player_id then
        return
    end

    skynet.send(service.custom_maze_manager, "lua", "on_query_my_custom_maze_list_req", fd, player_id)
end

--请求某个迷宫的详细信息
function funs.maze_info_req(fd, msg)
    local player_id = skynet.call(login, "lua", "get_player_id_by_fd", fd)
    if nil == player_id then
        return
    end

    local maze_id = msg.maze_id
    local maze_type = msg.maze_type
    if 1 == maze_type then
        skynet.send(service.custom_maze_manager, "lua", "on_query_maze_info_req", fd, player_id, maze_id)
    --elseif
        --todo 读配置中的故事模式的迷宫信息
    end
end

--创建房间
function funs.room_create_req(fd, msg)
    skynet.send(roommgr, "lua", "socket", "create", fd, msg)
end

--进入房间
function funs.room_enter_req(fd, msg)
    skynet.send(roommgr, "lua", "socket", "enter", fd, msg)
end

--------------------------------------------------------------------------------

local CMD = {}

function CMD.init()
    login = skynet.uniqueservice("login")
    player_manager = skynet.uniqueservice("player_manager")
    custom_maze_manager = skynet.uniqueservice("custom_maze_manager")
    --roommgr = skynet.uniqueservice("roommgr")
    --agentmgr = skynet.uniqueservice("agentmgr")
end

--根据协议名，调用对用处理函数
function CMD.handle(fd, msg_name, msg)
    local f = handler_arr[msg_name]
    f(fd, msg)
end

--------------------------------------------------------------------------------

skynet.start(function()
    CMD.init()
    
    skynet.dispatch("lua", function(_, _, cmd, ...)
        local f = CMD[cmd]
        if f then
            f(...)
        else
            log.log("service_clienthandler invalid_cmd %s", cmd)
        end
    end)
end)