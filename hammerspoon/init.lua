-- My Hammerspoon config

-- Set the global log level
hs.logger.setGlobalLogLevel("verbose")

-- require('HyperKey')
require('HyperMode')
require('ConfigWatcher')
require('ControlTapToEscape')
require('ShowKeys')

-- Alert whenever this config is loaded.
hs.alert.show("Hammerspoon: config loaded")


-- TODO: Use the below chooser code for providing user a menu
-- 
-- local chooser = hs.chooser.new(function(choice)
--       hs.alert.show(choice['text'])
-- end)

-- chooser:choices({
--       {
--          ["text"] = "Alfred\n",
--          ["subText"] = "macOS only\n",
--       },
--       {
--          ["text"] = "Quicksilver\n",
--          ["subText"] = "macOS only\n",
--       },
--       {
--          ["text"] = "Hammerspoon\n",
--          ["subText"] = "macOS only\n",
--       },
--       {
--          ["text"] = "Emacs\n",
--          ["subText"] = "is everywhere :)\n",
--       },
-- })
-- chooser:show()
