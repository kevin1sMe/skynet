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

local handler = {}

function handler.open(source, conf)
	watchdog = conf.watchdog or source
end

function handler.message(fd, msg, sz)
	-- recv a package, forward it
    print("gate.lua|handler.message() fd:"..fd)
	local c = connection[fd]
	local agent = c.agent
	if agent then
		skynet.redirect(agent, c.client, "client", 0, msg, sz)
	else
		skynet.send(watchdog, "lua", "socket", "data", fd, netpack.tostring(msg, sz))
	end
end

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

function handler.disconnect(fd)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "close", fd)
end

function handler.error(fd, msg)
	close_fd(fd)
	skynet.send(watchdog, "lua", "socket", "error", fd, msg)
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
	gateserver.openclient(fd)
end

function CMD.accept(source, fd)
	local c = assert(connection[fd])
	unforward(c)
    print("gate.lua|CMD.accept() openclient fd:"..fd)
	gateserver.openclient(fd)
end

function CMD.kick(source, fd)
	gateserver.closeclient(fd)
end

function handler.command(cmd, source, ...)
    print("gate.lua|handler.command() cmd:"..cmd.." source:"..source)
	local f = assert(CMD[cmd])
	return f(source, ...)
end

gateserver.start(handler)
