local skynet = require "skynet"
local db = {}

local command = {}

function command.GET(key)
	return db[key]
end

function command.SET(key, value)
	local last = db[key]
	db[key] = value
	return last
end

--add for test
function command.DEL(key)
    local ret = db[key]
    db[key] = nil
    return ret
end

function command.SIZE()
    local size = 0
    for _,_ in pairs(db) do
        size = size + 1
    end
    print("simpledb.lua|command.SIZE "..size)
    return size
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = command[string.upper(cmd)]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)
	skynet.register "SIMPLEDB"
end)
