local skynet = require "skynet"
local db = {}

local command = {}
local roomid 

function command.create(req)
    print("chatroom_db.lua|req")
    local id = roomid
    roomid = roomid + 1
    db[id] = {"welcom to room "..id}
    print("chatroom_db.lua|create room "..id)
    return {roomid = id, msg = "create room success!!"} 
end

--function command.SET(key, value)
	--local last = db[key]
	--db[key] = value
	--return last
--end

----add for test
--function command.DEL(key)
    --local ret = db[key]
    --db[key] = nil
    --return ret
--end

--function command.SIZE()
    --local size = 0
    --for _,_ in pairs(db) do
        --size = size + 1
    --end
    --print("chatroom_db.lua|command.SIZE "..size)
    --return size
--end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		--local f = command[string.upper(cmd)]
		local f = command[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)
	skynet.register "chatroom_db"
    roomid = 1
end)
