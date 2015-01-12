local skynet = require "skynet"
local netpack = require "netpack"
local socket = require "socket"
local sproto = require "sproto"
local bit32 = require "bit32"

local host
local send_request

local CMD = {}
local REQUEST = {}
local client_fd
--玩家当前所在的roomid,
local roomid

--创建房间并返回房间号
function REQUEST:create()
	local r = skynet.call("chatroom_db", "lua", "create", self)
    roomid = r.roomid
    print("chatroom_agent.lua|create and get roomid:"..(roomid or ""))
	return r
end

--在房间中聊天
function REQUEST:chat()
	print("chatroom_agent.lua|chat")
	local r = skynet.call("chatroom_db", "lua", "chat", self)
	return r
end

--进入某个房间
function REQUEST:join()
	print("chatroom_agent.lua|join")
    local r = skynet.call("chatroom_db", "lua", "join", self)
    if r.roomid then
        roomid = r.roomid
        print("chatroom_agent.lua|uin:"..client_fd.." join into room:"..roomid)
    end
	return r
end

--退出房间
function REQUEST:exit()
	print("chatroom_agent.lua|exit")
    local r = skynet.call("chatroom_db", "lua", "exit", {roomid = self.roomid, uin = self.uin})
    if r.ret ~= nil and r.ret == 0 then
        roomid = nil
    end

	return r
end

--这里解析client发过来的命令并作响应, 但这里的response是哪来的-->response是由host:dispatch产生, 回包方法
local function request(name, args, response)
    print("chatroom_agent.lua|enter request() name:"..name)
	local f = assert(REQUEST[name])

    args.uin = client_fd

    if args.roomid == nil then 
        args.roomid = roomid 
    else
        print("chatroom_agent.lua|request() name:"..name.." roomid is "..args.roomid)
    end

	local r = f(args)
    if response then
        print(response)
		return response(r)
	end
end

local function send_package(pack)
    print("chatroom_agent.lua|send_package()")
	local size = #pack
	local package = string.char(bit32.extract(size,8,8)) ..
		string.char(bit32.extract(size,0,8))..
		pack

	socket.write(client_fd, package)
end

--在newservice()时除了调用skynet.start()外，这里也会被执行到. chatroom_agent.lua被加载时执行
--每个agent都会调用到这块的初始化
--注册了一个"client"的协议，定义了它的解包和分发函数
skynet.register_protocol {
    print("chatroom_agent.lua|skynet.register_protocol"), 
	name = "client",
	id = skynet.PTYPE_CLIENT,

	unpack = function (msg, sz) --在收到PTYPE_CLIENT协议时，在skynet.lua/raw_dispatch_message方法会调用到这里
        print("chatroom_agent.lua|register_protocol unpack sz:"..sz)
        --下面这个是host:dispatch()的返回值形式
        --return "REQUEST", proto.name, result, gen_response(self, proto.response, header_tmp.session)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (_, _, type, ...) --在type前面两个_,_是跳过了source,session, 见skynet.lua/raw_dispatch_message 
        print("chatroom_agent.lua|register_protocol|type:"..type)
        local args = {...}
        for k,v in pairs(args) do
            print("chatroom_agent.lua|register_protocol|type:"..type, k,v)
        end
		if type == "REQUEST" then
			local ok, result  = pcall(request, ...) --调用上面request()方法将参数传过去, 注意这里给request的参数列表
			if ok then
				if result then
                    print(result)
					send_package(result)
				end
			else
				skynet.error(result)
			end
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

function CMD.start(gate, fd, proto)
    print("chatroom_agent.lua| CMD.start() enter|".." gate:"..gate.." fd:"..fd)

	host = sproto.new(proto.c2s):host "package"
	send_request = host:attach(sproto.new(proto.s2c))

    --定时同步聊天室的消息给各个客户端
    skynet.fork(function()
        while true do
            if roomid then
    	        local r = skynet.call("chatroom_db", "lua", "sync", {roomid = roomid, uin = fd})
                if r.ret ~= nil and r.ret ==0 then
                    --注意这里虽然是主动回包给客户端，但其实proto.s2c这个sync应该是request才是，而不是response
                    --原因是send_request是host:attach()实现的，它的内部用了sproto.encode(proto.request, ...)
                    send_package(send_request("sync", r))
                end
            end
            skynet.sleep(500)
        end
    end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.close(fd)
    print("chatroom_agent.lua| CMD.close() fd:"..fd)
    if roomid then
	    local r = skynet.call("chatroom_db", "lua", "exit", {roomid = roomid, uin = fd})
    end
end

skynet.start(function()
    --惯用法是在程序启动时，发个command=start过来，然后这里注册调用CMD.start()去初始化此服务
	skynet.dispatch("lua", function(_,_, command, ...)
        print("chatroom_agent.lua| skynet.start() dispatch command:"..command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
