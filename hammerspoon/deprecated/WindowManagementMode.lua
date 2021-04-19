-- Provides modal keybinds to window management
--
local wm = require('window_management')
local obj = {}

obj.windowMgmtMode = hs.hotkey.modal.new()

obj.windowMgmtModeEnter = function()
    obj.windowMgmtMode.triggered = true
    obj.windowMgmtMode:enter()
    hs.alert.show('WindowMgmt mode on')
 end

obj.windowMgmtModeExit = function ()
    obj.windowMgmtMode.triggered = false
    obj.windowMgmtMode:exit()
    hs.alert.show('WindowMgmt mode off')
end

obj.windowMgmtMode:bind({}, 'h', wm.moveWindowLeft)
obj.windowMgmtMode:bind({}, 'j', wm.moveWindowDown)
obj.windowMgmtMode:bind({}, 'k', wm.moveWindowUp)
obj.windowMgmtMode:bind({}, 'l', wm.moveWindowRight)
obj.windowMgmtMode:bind({}, 'u', wm.moveWindowTopLeft)
obj.windowMgmtMode:bind({}, 'i', wm.moveWindowTopRight)
obj.windowMgmtMode:bind({}, 'n', wm.moveWindowBottomLeft)
obj.windowMgmtMode:bind({}, 'm', wm.moveWindowBottomRight)
obj.windowMgmtMode:bind({}, 'f', wm.moveWindowMaximize)
obj.windowMgmtMode:bind({}, 'd', wm.moveWindowCenter)
obj.windowMgmtMode:bind({}, 's', wm.showWindowSwitcher)
obj.windowMgmtMode:bind({}, 'p', wm.mousePointerMoveToOtherScreen)
obj.windowMgmtMode:bind({}, 'Escape', obj.windowMgmtModeExit)

return obj
