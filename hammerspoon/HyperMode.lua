-- Implements a Hyper modal mode
--
-- Based on: https://github.com/dbmrq/dotfiles/blob/master/home/.hammerspoon/vim.lua

-- Setup a logger
local log = hs.logger.new('HyperMode', 'debug')

hyperMod = {'ctrl', 'command'}
hyperKey = 'Space'
showKey = '/'

hs.hotkey.showHotkeys(hyperMod, showKey)

local hyperMode = hs.hotkey.modal.new()

hyperModeEnter = function()
    hyperMode.triggered = true
    hyperMode:enter()
    hs.alert.show('Hyper mode on')
 end

hyperModeExit = function ()
    hyperMode.triggered = false
    hyperMode:exit()
    hs.alert.show('Hyper mode off')
end

hs.hotkey.bind(hyperMod, hyperKey, function()
    if not hyperMode.triggered then
      hyperModeEnter()
    else
      hyperModeExit()
    end
end)

-- HomeRow movement keys (loosely based on Vim bindings)
--
hyperMode:bind({}, 'h', function() hs.eventtap.keyStroke({}, 'Left') end)
hyperMode:bind({}, 'j', function() hs.eventtap.keyStroke({}, 'Down') end)
hyperMode:bind({}, 'k', function() hs.eventtap.keyStroke({}, 'Up') end)
hyperMode:bind({}, 'l', function() hs.eventtap.keyStroke({}, 'Right') end)

hyperMode:bind({'ctrl'}, 'u', function() hs.eventtap.keyStroke({}, 'PageUp') end)
hyperMode:bind({'ctrl'}, 'd', function() hs.eventtap.keyStroke({}, 'PageDown') end)

hyperMode:bind({'alt'}, 'h', function() hs.eventtap.keyStroke({'alt'}, 'Right') end)
hyperMode:bind({'alt'}, 'l', function() hs.eventtap.keyStroke({'alt'}, 'Left') end)

hyperMode:bind({'cmd'}, 'h', function() hs.eventtap.keyStroke({'cmd'}, 'Left') end)
hyperMode:bind({'cmd'}, 'j', function() hs.eventtap.keyStroke({'cmd'}, 'Down') end)
hyperMode:bind({'cmd'}, 'k', function() hs.eventtap.keyStroke({'cmd'}, 'Up') end)
hyperMode:bind({'cmd'}, 'l', function() hs.eventtap.keyStroke({'cmd'}, 'Right') end)

hyperMode:bind({}, 'Escape', hyperModeExit)

-- Window Manager Mode
-- 
local windowMgmtMode = hs.hotkey.modal.new()
windowMgmtModeEnter = function()
    windowMgmtMode.triggered = true
    windowMgmtMode:enter()
    hs.alert.show('WindowMgmt mode on')
 end

windowMgmtModeExit = function ()
    windowMgmtMode.triggered = false
    windowMgmtMode:exit()
    hs.alert.show('WindowMgmt mode off')
end

hyperMode:bind({}, 'w', function()
    if not windowMgmtMode.triggered then
      hyperModeExit()
      windowMgmtModeEnter()
    else
      windowMgmtModeExit()
      hyperModeEnter()
    end
end)

windowMgmtMode:bind({}, 'h', function() hs.eventtap.keyStroke({'ctrl, cmd, alt'}, 'h') end)
windowMgmtMode:bind({}, 'j', function() hs.eventtap.keyStroke({'ctrl, cmd, alt'}, 'j') end)
windowMgmtMode:bind({}, 'k', function() hs.eventtap.keyStroke({'ctrl, cmd, alt'}, 'k') end)
windowMgmtMode:bind({}, 'l', function() hs.eventtap.keyStroke({'ctrl, cmd, alt'}, 'l') end)
windowMgmtMode:bind({}, 'Escape', windowMgmtModeExit)
