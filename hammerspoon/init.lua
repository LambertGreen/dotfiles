-- My Hammerspoon config

-- Set the global log level
hs.logger.setGlobalLogLevel("verbose")

-- require('HyperKey')
require('HyperMode')
require('ConfigWatcher')
-- Disabling the below to try out getting this functionality directly from Karabiner-elements.
-- The reason for this is that I found that it is taking Hammerspoon to long to register the
-- pressing of the Escape key i.e. I need faster interactivity.
-- require('ControlTapToEscape')
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
