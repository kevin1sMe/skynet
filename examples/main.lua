local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

local max_client = 64

skynet.start(function()
	print("Server start")
	skynet.uniqueservice("protoloader")
	local console = skynet.newservice("console")
--	skynet.newservice("debug_console",8000)
	skynet.newservice("simpledb")
    --newservice()时会调用对应服务的skynet.start()函数
	local watchdog = skynet.newservice("watchdog")
    --初始化watchdog服务。调用它的CMD.start()函数，传递一些参数
    print("main.lua|skynet.call(watchdog)")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	print("Watchdog listen on ", 8888)

	skynet.exit()
end)
