local PATH,IP = ...

IP = IP or "127.0.0.1"

package.path = string.format("%s/client/?.lua;%s/skynet/lualib/?.lua", PATH, PATH)
package.cpath = string.format("%s/skynet/luaclib/?.so;%s/lsocket/?.so;%s/luaclib/?.so", PATH, PATH, PATH)

local socket = require "simplesocket"
local message = require "simplemessage"
local retcode = require "retcode"

message.register()

message.peer(IP, 12346)
message.connect()

print("IP = " .. IP)

local event = {}

message.bind({}, event)

function event:push(args)
	print("server push", args.text)
end

function event:test(resp)
	--print("resp test args= %d %d %s %d", resp.param1, resp.param2, resp.param3, resp.param4)
	--print("req test args= %d %d %s %d", req.param1, req.param2, req.param3, req.param4)
end

function event:MsgPlayerInfoResp(args)
	print("player_info resp" .. args.player_name .. " " .. args.player_id .. " " .. args.story_record .. " " .. args.challenging_maze_type .. " " .. args.challenging_maze_id)
end

function event:MsgLoginRsp(args)
	print("event:MsgLoginRsp...")
	message.request("PbPlayer.MsgPlayerInfoReq", {})
	--message.request("PbPlayer.MsgChangeNickNameReq", { nickname = "elenno" })
end

message.request("PbLogin.MsgLoginReq", {platform=1, user_id="alice"})

--message.request("CSSignin", { name = "alice" })
--message.request("test", { param1 = 1, param2 = 2, param3 = "test123", param4 = 3})
--[[
	message.request("upload_maze", {
	maze_name = "test_name",
		maze_height = 4,
		maze_width = 4,
		maze_map = "0000111100001111",
		start_pos_x = 0,
		start_pos_y = 0,
		end_pos_x = 1,
		end_pos_y = 1,
		head_line = "this is headline",
		head_line_remark = "this is remark",
		maze_setting_flag = 0
})
--]]

while true do
	message.update()
end
