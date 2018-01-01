local skynet = require "skynet"

local max_client = 10240

skynet.start(function()
    skynet.error("Server start")

    skynet.newservice("console")
    skynet.newservice("debug_console", 12345)

    local watchdog = skynet.uniqueservice("watchdog")
    skynet.call(watchdog, "lua", "start", {
        port = 12346,
        maxclient = max_client,
        nodelay = true,
    })
    skynet.error("watchdog Listen on", 12346)

    --service = skynet.newservice("mongodb")
    --skynet.send(service, "lua", "init")

    skynet.exit()
end)
