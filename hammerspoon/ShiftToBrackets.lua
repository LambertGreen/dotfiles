-- Makes the Shift keys double up as a parenthesis and curly braces keys.

-- Setup a logger
local log = hs.logger.new('Coding', 'debug')

len = function(t)
    local length = 0
    for k, v in pairs(t) do
        length = length + 1
    end
    return length
end

left_shift_is_down = false
right_shift_is_down = false
brackets_prev_modifiers = {}

brackets_modifier_handler = function(evt)

    local curr_modifiers = evt:getFlags()
    local curr_key = hs.keycodes.map[evt:getKeyCode()]

    if curr_key == "shift" then
        if len(curr_modifiers) == 1 and len(brackets_prev_modifiers) == 0 then
            -- we need this here because we might have had additional modifiers, which
            -- we don't want to lead to an escape, e.g. [ctrl + cmd] —> [ctrl] —> [ ]
            left_shift_is_down = true
        elseif len(curr_modifiers) == 1 and right_shift_is_down then
            log.i('LShift tapped: sending { key.')
            hs.eventtap.keyStrokes("{")
        elseif len(curr_modifiers) == 0 and left_shift_is_down then
            log.i('LShift tapped: sending ( key.')
            hs.eventtap.keyStrokes("(")
            left_shift_is_down = false
        end
    elseif curr_key == "rightshift" then
        if len(curr_modifiers) == 1 and len(brackets_prev_modifiers) == 0 then
            -- We need this here because we might have had additional modifiers, which
            -- we don't want to lead to an escape, e.g. [Ctrl + Cmd] —> [Ctrl] —> [ ]
            right_shift_is_down = true
        elseif len(curr_modifiers) == 1 and left_shift_is_down then
            log.i('RShift tapped: sending } key.')
            hs.eventtap.keyStrokes("}")
        elseif len(curr_modifiers) == 0 and right_shift_is_down then
            log.i('RShift tapped: sending ) key.')
            hs.eventtap.keyStrokes(")")
            right_shift_is_down = false
        end
    end

    brackets_prev_modifiers = curr_modifiers
    return false
end

-- Call the modifier_handler function anytime a modifier key is pressed or released
brackets_modifier_tap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, brackets_modifier_handler)
brackets_modifier_tap:start()

-- If any non-modifier key is pressed, we know we won't be sending a bracket
brackets_non_modifier_tap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(evt)
    left_shift_is_down = false
    right_shift_is_down = false
    return false
end)
brackets_non_modifier_tap:start()
