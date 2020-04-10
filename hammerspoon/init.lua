-- My Hammerspoon config

-- Set the global log level
hs.logger.setGlobalLogLevel("verbose")

require('HyperKey')
require('ConfigWatcher')
require('ControlTapToEscape')
require('ShowKeys')

-- Alert whenever this config is loaded.
hs.alert.show("Hammerspoon: config loaded")
