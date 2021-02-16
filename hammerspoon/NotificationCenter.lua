-- Provides Notification Center control
--
-- Note: This relies on specific keybindings that need to be set
-- in System Preferences -> Keyboard -> Shortcuts
-- 
local obj = {}

local hyperMod = {'ctrl', 'shift', 'alt', 'cmd'}

obj.toggleNotificationCenter = function() hs.eventtap.keyStroke(hyperMod, 'n') end
obj.toggleDoNotDisturb = function() hs.eventtap.keyStroke(hyperMod, 'd') end

return obj
