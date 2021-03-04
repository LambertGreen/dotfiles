-- Provides mouse pointer control
--
local obj = {}

-- Mouse pointer move to other screen
obj.movePointerToOtherScreen = function()
    local screen = hs.mouse.getCurrentScreen()
    local nextScreen = screen:next()
    local rect = nextScreen:fullFrame()
    local center = hs.geometry.rectMidPoint(rect)
    hs.mouse.setAbsolutePosition(center)
end

return obj
