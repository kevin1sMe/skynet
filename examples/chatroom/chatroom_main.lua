local skynet = require "skynet"

local max_client = 64

skynet.start(function()
	print("Chatroom Server start")
--	local console = skynet.newservice("console")
--	skynet.newservice("debug_console",8000)
	skynet.newservice("chatroom_db")
    --newservice()时会调用对应服务的skynet.start()函数
	local watchdog = skynet.newservice("chatroom_watchdog")
    --初始化watchdog服务。调用它的CMD.start()函数，传递一些参数
    print("chatroom_main.lua|skynet.call(chatroom_watchdog)")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	print("Chatroom Watchdog listen on ", 8888)

	skynet.exit()
end)
