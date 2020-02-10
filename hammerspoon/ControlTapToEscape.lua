-- Makes the Control key double up as an Escape key.
-- Works well together with mapping the Capslock key to Control key.
--    Capslock can be mapped to Control using OS Preferences or Karabiner Elements.
--
-- From: https://gist.github.com/zcmarine/f65182fe26b029900792fa0b59f09d7f

len = function(t)
    local length = 0
    for k, v in pairs(t) do
        length = length + 1
    end
    return length
end

send_escape = false
enabled_for_application = true
prev_modifiers = {}

modifier_handler = function(evt)
    -- evt:getFlags() holds the modifiers that are currently held down
    local curr_modifiers = evt:getFlags()

    if curr_modifiers["ctrl"] and len(curr_modifiers) == 1 and len(prev_modifiers) == 0 then
        -- We need this here because we might have had additional modifiers, which
        -- we don't want to lead to an escape, e.g. [Ctrl + Cmd] —> [Ctrl] —> [ ]
        send_escape = true
    elseif prev_modifiers["ctrl"]  and len(curr_modifiers) == 0 and send_escape and enabled_for_application then
        send_escape = false
        print("Control tapped: Sending Escape key.")
        hs.eventtap.keyStroke({}, "ESCAPE")
    else
        send_escape = false
    end
    prev_modifiers = curr_modifiers
    return false
end


-- Setup a filter to prevent hyper hotkeys for remoting applications.
 hs.window.filter.new('Remotix')
  :subscribe(hs.window.filter.windowFocused, function() enabled_for_application = false end)
    :subscribe(hs.window.filter.windowUnfocused,function() enabled_for_application = true end)

-- Call the modifier_handler function anytime a modifier key is pressed or released
modifier_tap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, modifier_handler)
modifier_tap:start()


-- If any non-modifier key is pressed, we know we won't be sending an escape
non_modifier_tap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(evt)
    send_escape = false
    return false
end)
non_modifier_tap:start()
