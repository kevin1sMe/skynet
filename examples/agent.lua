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

function REQUEST:get()
	print("get", self.what)
	local r = skynet.call("SIMPLEDB", "lua", "get", self.what)
	return { result = r }
end

function REQUEST:set()
	print("set", self.what, self.value)
	local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
end

function REQUEST:del()
    print("del", self.what, self.value or "nil")
	local r = skynet.call("SIMPLEDB", "lua", "del", self.what)
    return {result = r}
end

function REQUEST:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

--这里解析client发过来的命令并作响应
local function request(name, args, response)
    print("agent.lua|request() name:"..name)
	local f = assert(REQUEST[name])
	local r = f(args)
	if response then
        print("agent.lua|request() response not nil")
        print(response)
		return response(r)
    else
        print("agent.lua|request() response is nil")
	end
end

local function send_package(pack)
    print("agent.lua|send_package()")
	local size = #pack
	local package = string.char(bit32.extract(size,8,8)) ..
		string.char(bit32.extract(size,0,8))..
		pack

	socket.write(client_fd, package)
end

--在newservice()时除了调用skynet.start()外，这里也会被执行到. agent.lua被加载时执行
--每个agent都会调用到这块的初始化
--注册了一个"client"的协议，定义了它的解包和分发函数
skynet.register_protocol {
    print("agent.lua|when ??"), 
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz) --sproto协议需要定义解码方法, 这里会先解码再dispatch吗? 是的，底层自动调用unpack先
        print("agent.lua|register_protocol unpack sz:"..sz)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (_, _, type, ...)
        print("agent.lua|register_protocol|type:"..type)
		if type == "REQUEST" then
			local ok, result  = pcall(request, ...) --调用上面request()方法将参数传过去
			if ok then
				if result then
                    print("agent.lua|register_protocol|result:"..(result or ""))
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
    print("agent.lua| CMD.start() enter|".." gate:"..gate.." fd:"..fd)

	host = sproto.new(proto.c2s):host "package"
	send_request = host:attach(sproto.new(proto.s2c))
	--skynet.fork(function()
		--while true do
			--send_package(send_request "heartbeat")
            ----FIXME 临时调整间隔
			--skynet.sleep(50000)
		--end
	--end)

	client_fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

skynet.start(function()
    --惯用法是在程序启动时，发个command=start过来，然后这里注册调用CMD.start()去初始化此服务
	skynet.dispatch("lua", function(_,_, command, ...)
        print("agent.lua| skynet.start() dispatch command:"..command)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
