-- My Hammerspoon config

-- Set the global log level
hs.logger.defaultLogLevel = "info"

-- require('HyperKey')
require('HyperMode')
require('ConfigWatcher')
-- Update 1: Disabling the below to try out getting this functionality directly from Karabiner-elements.
-- The reason for this is that I found that it is taking Hammerspoon to long to register the
-- pressing of the Escape key i.e. I need faster interactivity.
-- Update 2: Enabling this again because Karabiner-elements requires installing a kernel driver, and I don't
--  want to install it on the company laptop. So I hope that this "slower" escape, will be ok: tradeoffs.
require('ControlTapToEscape')
require('ShiftToBrackets')
require('ShowKeys')
require('AppWatcher')

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

-- TODO: Use MenuBar to show status of "programming mode" so that one can leave programming mode off most of
-- the time and enable it just when needed, which will mean we don't run into the password field entry issues.
--
-- mb = hs.menubar.new(nil)
-- updateStatus = function(event)
--   if(event == "on") then
--     mb:setTitle("🔴")
--   elseif(event == "off") then
--     mb:setTitle("🟢")
--   end
-- end
