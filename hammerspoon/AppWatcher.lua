-- Application watcher

-- Setup a logger
local log = hs.logger.new('AppWatcher')

function applicationWatcherCallback(appName, eventType, appObject)
    log.i(appName)
end

watcher = hs.application.watcher.new(applicationWatcherCallback)
watcher:start()
