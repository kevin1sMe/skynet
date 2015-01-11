--2015-01-09 修改使支持get/set/del 命令

package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;examples/?.lua"

local socket = require "clientsocket"
local bit32 = require "bit32"
local proto = require "proto"
local sproto = require "sproto"

local host = sproto.new(proto.s2c):host "package"
local request = host:attach(sproto.new(proto.c2s))

local fd = assert(socket.connect("127.0.0.1", 8888))

local function send_package(fd, pack)
	local size = #pack
    --两个字节包长度
	local package = string.char(bit32.extract(size,8,8)) ..
		string.char(bit32.extract(size,0,8))..
		pack

    print("client.lua|send_package() #pack:"..size)
	socket.send(fd, package)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

    print("client.lua|unpack_package() #pkg len:"..s)

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
        print("client.lua|recv_package() result:"..(result or "nil"))
		return result, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0

local function send_request(name, args)
	session = session + 1
	local str = request(name, args, session)
	send_package(fd, str)
	print("client.lua|Request: session:"..session.." name:"..name)
end

local last = ""

local function print_request(name, args)
	print("REQUEST", name)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		print_package(host:dispatch(v))
	end
end

send_request("handshake")
send_request("set", { what = "hello", value = "world" })
--lua没有string.split(), 自己写一个
string.split = function(s, sep)
    local ret = {}
    string.gsub(s, '[^'..sep..']+', function(w) table.insert(ret, w) end)
    return ret
end

while true do
	dispatch_package()
	local cmd = socket.readstdin()
	if cmd then
        local input_argv = string.split(cmd, "%s")
		--send_request("get", { what = cmd })
        if input_argv[1] == "get" then
            send_request("get", { what = input_argv[2] })
        elseif input_argv[1] == "set" then
            send_request("set", { what = input_argv[2], value = input_argv[3] })
        elseif input_argv[1] == "del" then 
            send_request("del", { what = input_argv[2]})
        elseif input_argv[1] == "size" then
            send_request("size")
        else
            print("unknown cmd")
        end

	else
		socket.usleep(100)
	end
end
