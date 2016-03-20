--[[
--这个是使用gateserver.lua的具体范例。 
--skynet提供了一个通用的模版lualib/snax/gateserver.lua来启动一个网关服务器。
--通过TCP连接和客户端交换数据

TCP基于数据流，但一般我们需要以带长度信息的数据包的结构来做数据交换。
gateserver做的就是这个工作，把数据切割成包的形式转发到可以处理它的地址。
]]--

local skynet = require "skynet"
local gateserver = require "snax.gateserver"
local netpack = require "netpack"

local watchdog
local connection = {}	-- fd -> connection : { fd , client, agent , ip, mode }
local forwarding = {}	-- agent -> connection

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
}

--handler是一组自定义的消息处理函数。
--open/close 内部保留， 用于gate打开，关闭监听端口
local handler = {}


--如果你希望在监听端口打开的时候，做一些初始化操作，可以提供open这个方法。
--source: 请求来源地址
--conf: 开启gate服务的参数列表
function handler.open(source, conf)
	watchdog = conf.watchdog or source
end

--当一个完整的包被切分好后,message方法被调用。
--msg: 是一个C指针
--sz: 数值。 表示包长度(c指针指向的内存块的长度)
--NOTICE： 这个c指针需要在处理完毕后调用c方法 skynet_free释放。
--（通常建议直接用封装好的库netpack.tostring来做这些底层的数据处理）；
-- 或是通过 skynet.redirect转发给别的skynet服务处理
function handler.message(fd, msg, sz)
	-- recv a package, forward it
    print("gate.lua|handler.message() fd:"..fd.." sz:"..sz)
	local c = connection[fd]
	local agent = c.agent
	if agent then
        print("gate.lua|handler.message() fd:"..fd.." redirect to agent")
		skynet.redirect(agent, c.client, "client", 0, msg, sz)
	else
        print("gate.lua|handler.message() fd:"..fd.." send to watchdog")
		skynet.send(watchdog, "lua", "socket", "data", fd, netpack.tostring(msg, sz))
	end
end

--当一个新连接建立后，connect方法被调用。
--fd: 连接的socket fd
--addr: 新连接的ip地址(通常用于log输出)
function handler.connect(fd, addr)
    print("gate.lua|handler.connect() fd:"..fd)
	local c = {
		fd = fd,
		ip = addr,
	}
	connection[fd] = c
    --发给watchdog(agent.lua) 
    print("gate.lua|handler.connect() skynet.send to watchdog fd:"..fd.." addr:"..addr)
	skynet.send(watchdog, "lua", "socket", "open", fd, addr)
end

local function unforward(c)
    print("gate.lua|unforward() c.agent:"..(c.agent or "").." c.client:"..(c.client or ""))
    --非空则清除掉forwarding映射关系
	if c.agent then
		forwarding[c.agent] = nil
		c.agent = nil
		c.client = nil
	end
end

local function close_fd(fd)
	local c = connection[fd]
	if c then
		unforward(c)
		connection[fd] = nil
	end
end

--当一个连接断开，disconnect被调用
--fd: 哪个连接断开
function handler.disconnect(fd)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "close", fd)
end

--当一个连接异常（通常意味着断开）， error被调用
--fd: 异常连接
--msg: 错误信息（常用于log输出)
function handler.error(fd, msg)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "error", fd, msg)
end

function handler.warning(fd, size)
	skynet.send(watchdog, "lua", "socket", "warning", fd, size)
end

local CMD = {}

function CMD.forward(source, fd, client, address)
    print("gate.lua|CMD.forward() fd:"..fd.." client:"..(client or "").." address:"..(address or ""))
	local c = assert(connection[fd])
	unforward(c)
	c.client = client or 0
	c.agent = address or source
	forwarding[c.agent] = c
    print("gate.lua|CMD.forward() openclient fd:"..fd)
    --gateserver.openclient() 在每次收到handler.connect后，你都需要调用openclient让fd上的消息进入。
    --默认状态下，fd仅仅是连接上你的服务器，但无法发送消息给你。
    --这个步骤需要你显式的调用是因为，或许你需要在新连接建立后，把fd的控制权转交给别的服务。
    --那么可以在一切准备好后，再放行消息。
	gateserver.openclient(fd)
end

function CMD.accept(source, fd)
	local c = assert(connection[fd])
	unforward(c)
    print("gate.lua|CMD.accept() openclient fd:"..fd)
	gateserver.openclient(fd)
end

function CMD.kick(source, fd)
    --主动踢掉一个连接
	gateserver.closeclient(fd)
end

--如果你希望让服务处理一些skynet内部消息，可以注册command方法。
--收到lua协议的skynet消息，会调用这个方法。
--cmd: 消息的第一个值，通常约定为一个字符串，指明是什么指令
--source: 消息的来源地址
--这个方法的返回值，会通过skynet.ret/skynet.pack返回给来源服务
function handler.command(cmd, source, ...)
    print("gate.lua|handler.command() cmd:"..cmd.." source:"..source)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)
