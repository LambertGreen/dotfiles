-- My Hammerspoon config

-- Set the global log level
hs.logger.defaultLogLevel = "info"

require('HyperMode')
require('ConfigWatcher')
require('ControlTapToEscape')
require('ShiftToBrackets')
require('ShowKeys')
require('AppWatcher')

-- Alert whenever this config is loaded.
hs.alert.show("Hammerspoon: config loaded")
