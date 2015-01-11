local skynet = require "skynet"
local db = {}

local room = {}
local command = {}
local roomid 

function room.get_members(roomid)
    if db[roomid] == nil then
        return 0
    end

    local size = 0
    for _,v in pairs(db[roomid].uin_list) do
        size = size + 1
    end
    return size
end

function command.create(req)
    print("chatroom_db.lua|create() req")
    local id = roomid
    roomid = roomid + 1
    db[id] = { uin_list = { [req.uin] = 0}, 
               msg_list = {uin = 10000, msg = "welcom to room "..id} 
             }
    print("chatroom_db.lua|create room "..id)
    return {roomid = id, msg = "create room success!!"} 
end

function command.chat(req)
    print("chatroom_db.lua|chat() req")
    if req then
        for k,v in pairs(req) do
            print(k,v)
        end
    end

    if db[req.roomid] == nil then
        return {ret = -1, 
                msg = "cannot find roomid:"..req.roomid}
    end

    table.insert(db[req.roomid].msg_list, {uin = req.uin , msg = req.msg})
    print("chatroom_db.lua|chat() insert to chat list success!")
    return { ret = 0, msg = req.msg} 
end

function command.join(req)
    print("chatroom_db.lua|join() req")
    if req then
        for k,v in pairs(req) do
            print(k,v)
        end
    end

    local id = req.roomid

    --是否有此房间
    if db[id] == nil then
        return {ret = -1, msg = "cannot find roomid:"..id}
    end

    --是否已经在房间中
    --for _,v in pairs(db[id].uin_list) do
        --if v == req.uin then
            --return {ret = -2, msg = "uin "..req.uin.." is already in the room!"}
        --end
    --end
    if db[id].uin_list[req.uin] then
        return {ret = -2, msg = "uin "..req.uin.." is already in the room!"}
    end

    --table.insert(db[req.roomid].uin_list, req.uin)
    db[req.roomid].uin_list[req.uin] = 0
    print("chatroom_db.lua|join() insert to chat room uin list success! room members:"..room.get_members(id))
    return { ret = 0, roomid = id,  msg = "join succ as "..req.uin} 
end


function command.exit(req)
    print("chatroom_db.lua|exit() req")
    if req then
        for k,v in pairs(req) do
            print(k,v)
        end
    end

    if req.roomid == nil then
        return {ret = -1, msg = "roomid is nil"}
    end

    if db[req.roomid] == nil then
        return {ret = -1, msg = "cannot find room "..req.roomid}
    end

    --从成员列表中移除此玩家
    --table.remove(db[req.roomid].uin_list, req.uin)
    if db[req.roomid].uin_list[req.uin] then
        db[req.roomid].uin_list[req.uin] = nil
        print("chatroom_db.lua|exit() from room "..req.roomid.." success!")
    else
        return {ret = -3, msg = "uin "..req.uin.." not in room "..req.roomid}
    end

    return { ret = 0, msg = "exit from room "..req.roomid.." success!"} 
end

function command.sync(req)
    print("chatroom_db.lua|sync() req")
    if req then
        for k,v in pairs(req) do
            print(k,v)
        end
    end

    local id = req.roomid
    local uin = req.uin

    if id == nil then
        return {ret = -1, msg = "roomid is nil"}
    end

    if db[id] == nil then
        return {ret = -3, msg = "cannot find room "..id}
    end

    if db[id].uin_list[uin] == nil then
        return {ret = -3, msg = "uin "..uin.." find found in room "..id}
    end

    --根据db[roomid].uin_list[uin] 的值，计算有多少string没有下发
    local msg_sz = #db[id].msg_list

    --下发一条msg
    local cur_msg_idx = db[id].uin_list[uin]
    if msg_sz > cur_msg_idx then
        return  {ret = 0, msg = db[id].msg_list[cur_msg_idx + 1].msg, uin = db[id].msg_list[cur_msg_idx + 1].uin}
    end

    return { ret = 0, msg = "no more new msg.."}
end


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
