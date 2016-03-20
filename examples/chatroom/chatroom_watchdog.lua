package.path = "./examples/chatroom/?.lua;" .. package.path

local skynet = require "skynet"
local netpack = require "netpack"
local proto = require "chatroom_proto"

local CMD = {}
local SOCKET = {}
local gate
local agent = {}

function SOCKET.open(fd, addr)
	skynet.error("New client from : " .. addr)
	agent[fd] = skynet.newservice("chatroom_agent")
	skynet.call(agent[fd], "lua", "start", gate, fd, proto)
end

local function close_agent(fd)
	local a = agent[fd]
	if a then
        --玩家客户端断开，需要从房间列表中移除
	    skynet.call(a, "lua", "close", fd)

		skynet.kill(a)
		agent[fd] = nil
	end
end

function SOCKET.close(fd)
	print("socket close",fd)
	close_agent(fd)
end

function SOCKET.error(fd, msg)
	print("socket error",fd, msg)
	close_agent(fd)
end

function SOCKET.data(fd, msg)
end

function CMD.start(conf)
    print("chatroom_watchdog.lua|CMD.start")
	skynet.call(gate, "lua", "open" , conf)
end

skynet.start(function()
    print("chatroom_watchdog.lua|skynet.start")
	skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
		if cmd == "socket" then
			local f = SOCKET[subcmd]
			f(...)
			-- socket api don't need return
		else
			local f = assert(CMD[cmd])
			skynet.ret(skynet.pack(f(subcmd, ...)))
		end
	end)

	gate = skynet.newservice("gate")
end)
