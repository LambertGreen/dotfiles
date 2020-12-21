-- Makes the Control key double up as an Escape key.
-- Works well together with mapping the Capslock key to Control key.
--    Capslock can be mapped to Control using OS Preferences or Karabiner Elements.
--
-- From: https://gist.github.com/zcmarine/f65182fe26b029900792fa0b59f09d7f

local log = hs.logger.new('CtrlToEscape')
local send_escape = false
local prev_modifiers = {}

len = function(t)
    local length = 0
    for _ in pairs(t) do
        length = length + 1
    end
    return length
end

empty = function(t)
    if next(t) == nil then
        return true
    end
    return false
end

-- Setup a excluded application filter
exclusion = hs.window.filter.new{'Remotix'}
exclusion:subscribe(hs.window.filter.windowFocused,
    function()
        ctrl_to_escape_modifier_tap:stop()
        ctrl_to_escape_non_modifier_tap:stop()
        send_escape = false
    end)
exclusion:subscribe(hs.window.filter.windowUnfocused,
    function()
        ctrl_to_escape_modifier_tap:start()
        ctrl_to_escape_non_modifier_tap:start()
    end)

-- On ctrl down check if we should convert to an escape
ctrl_to_escape_modifier_tap = hs.eventtap.new(
    {hs.eventtap.event.types.flagsChanged},
    function(evt)
        local curr_modifiers = evt:getFlags()

        if curr_modifiers["ctrl"] and len(curr_modifiers) == 1 and empty(prev_modifiers) then
            send_escape = true
        elseif send_escape and prev_modifiers["ctrl"] and empty(curr_modifiers) then
            hs.eventtap.event.newKeyEvent('escape', true):post()
            hs.eventtap.event.newKeyEvent('escape', false):post()
            send_escape = false
            log.d('Control tapped: sent escape key.')
        else
            send_escape = false
        end

        prev_modifiers = curr_modifiers
        return true
    end
)

-- If any non-modifier key is pressed, we know we won't be sending an escape
ctrl_to_escape_non_modifier_tap = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown},
    function(evt)
        send_escape = false
        return false
    end
)

ctrl_to_escape_modifier_tap:start()
ctrl_to_escape_non_modifier_tap:start()
