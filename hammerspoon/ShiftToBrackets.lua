-- Makes the Shift keys, when tapped, double up as a square and curly braces keys.

-- Constants
LSHIFT_TAP_KEY = '['
RSHIFT_LSHIFT_TAP_KEY = '{'
RSHIFT_TAP_KEY = ']'
LSHIFT_RSHIFT_TAP_KEY = '}'

-- Variables
local log = hs.logger.new('ShiftToBrackets')
local left_shift_is_down = false
local right_shift_is_down = false
local is_prev_modifiers = false

-- Helper functions
is_single_modifier = function(t)
    local length = 0
    for _ in pairs(t) do
        length = length + 1
        if length > 1 then
            break
        end
    end
    if length == 1 then
        return true
    end
    return false
end

empty = function(t)
    if next(t) == nil then
        return true
    end
    return false
end

-- Setup a excluded application filter
exclusion = hs.window.filter.new{'loginwindow'}
exclusion:subscribe(hs.window.filter.windowFocused,
    function()
        shift_to_brackets_modifier_tap:stop()
        shift_to_brackets_non_modifier_tap:stop()
        send_escape = false
    end)
exclusion:subscribe(hs.window.filter.windowUnfocused,
    function()
        shift_to_brackets_modifier_tap:start()
        shift_to_brackets_non_modifier_tap:start()
    end)

strokeReplacementKey = function(shiftkey, replacementKey)
    log.d(tostring(shiftkey) .. ' tapped: sending ' .. tostring(replacementKey) .. ' key.')
    hs.eventtap.keyStrokes(replacementKey)
end

logKeyDown = function(key)
    log.d(tostring(key) .. ' pressed down.')
end

-- On shift modifier down check if we should convert to a bracket
shift_to_brackets_modifier_tap = hs.eventtap.new(
    {hs.eventtap.event.types.flagsChanged},
    function(evt)
        if(hs.eventtap.isSecureInputEnabled()) then
            return true;
        end

        local curr_modifiers = evt:getFlags()
        local curr_key = hs.keycodes.map[evt:getKeyCode()]

        if curr_key == "shift" then
            if is_single_modifier(curr_modifiers) and not is_prev_modifiers then
                logKeyDown(curr_key)
                left_shift_is_down = true
            elseif empty(curr_modifiers) and left_shift_is_down then
                strokeReplacementKey(curr_key, LSHIFT_TAP_KEY)
            elseif is_single_modifier(curr_modifiers) and right_shift_is_down then
                strokeReplacementKey(curr_key, RSHIFT_LSHIFT_TAP_KEY)
                left_shift_is_down = false
            end
        elseif curr_key == "rightshift" then
            if is_single_modifier(curr_modifiers) and not is_prev_modifiers then
                logKeyDown(curr_key)
                right_shift_is_down = true
            elseif empty(curr_modifiers) and right_shift_is_down then
                strokeReplacementKey(curr_key, RSHIFT_TAP_KEY)
            elseif is_single_modifier(curr_modifiers) and left_shift_is_down then
                strokeReplacementKey(curr_key, LSHIFT_RSHIFT_TAP_KEY)
                right_shift_is_down = false
            end
        end

        is_prev_modifiers = not empty(curr_modifiers)
        return false
    end
)

-- If any non-modifier key is pressed, we know we won't be sending a bracket
shift_to_brackets_non_modifier_tap = hs.eventtap.new(
    {hs.eventtap.event.types.keyDown},
    function(evt)
        left_shift_is_down = false
        right_shift_is_down = false
        is_prev_modifiers = false
        return false
    end
)

-- Start taps
shift_to_brackets_modifier_tap:start()
shift_to_brackets_non_modifier_tap:start()
