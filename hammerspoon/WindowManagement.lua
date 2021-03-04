-- Provides window management functions
-- 
-- Currently window movement is being delegated to Divvy because:
-- 1. I am already paid for Divvy and am using it both on macOS and Windows
-- 2. Divvy provides nice mouse controls (e.g. menubar access)
-- 3. Divvy provides margins/gaps
--
-- It is possible to replace Divvy with Hammerspoon scripting, but I don't
-- plan on doing this until there is a clear need to do so.
-- 
local obj = {}
local moveWindowPrefix = {'ctrl', 'cmd', 'alt'}

-- Window movement
obj.moveWindowLeft = function() hs.eventtap.keyStroke(moveWindowPrefix, 'h') end
obj.moveWindowDown = function() hs.eventtap.keyStroke(moveWindowPrefix, 'j') end
obj.moveWindowUp = function() hs.eventtap.keyStroke(moveWindowPrefix, 'k') end
obj.moveWindowRight = function() hs.eventtap.keyStroke(moveWindowPrefix, 'l') end
obj.moveWindowTopLeft = function() hs.eventtap.keyStroke(moveWindowPrefix, 'u') end
obj.moveWindowTopRight = function() hs.eventtap.keyStroke(moveWindowPrefix, 'i') end
obj.moveWindowBottomLeft = function() hs.eventtap.keyStroke(moveWindowPrefix, 'n') end
obj.moveWindowBottomRight = function() hs.eventtap.keyStroke(moveWindowPrefix, 'm') end
obj.moveWindowMaximize = function() hs.eventtap.keyStroke(moveWindowPrefix, 'f') end
obj.moveWindowCenter = function() hs.eventtap.keyStroke(moveWindowPrefix, 'd') end

return obj
