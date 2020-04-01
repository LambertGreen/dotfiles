--
-- Implements a Hyper key and associated key bindings
--
-- We are using F14/F15 keys in particular since these keys are correctly
-- transmitted by Remotix (used to remotely work on Mac from our Windows machine.)
-- Note: We do need to unregister these 2 keys in 'System Preferences'->Keyboard->Shortcuts as
-- they are by default registered Display (inc/dec brightness). One must not only uncheck the values
-- but assign different ones and reboot.

-- A global variable for Hyper mode
hyper = hs.hotkey.modal.new({}, 'f15')

-- Enter Hyper mode when Hyper key is pressed
function enterHyperMode()
  hyper.triggered = false
  print("Hyper (f14) down.")
  hyper:enter()
end

-- Leave Hyper mode when Hyper is pressed
function exitHyperMode()
  print("Hyper (f14) up.")
  hyper:exit()
end

-- Bind the Hyper key
f14 = hs.hotkey.bind({}, 'f14', enterHyperMode, exitHyperMode)

-- Setup a filter to prevent hyper hotkeys for remoting applications.
hs.window.filter.new('Remotix')
  :subscribe(hs.window.filter.windowFocused, function() f14:disable() end)
    :subscribe(hs.window.filter.windowUnfocused,function() f14:enable() end)


-- Application launcher
hyper:bind({}, 'return', function()
    hs.eventtap.keyStroke({'ctrl', 'alt'}, 'return')
    hyper.triggered = true
end)

-- Application switcher: interactive
hyper:bind({}, 'space', function()
    hs.eventtap.keyStroke({'ctrl', 'alt'}, 'space')
    hyper.triggered = true
end)

-- Application switcher: fast alt-tab
hyper:bind({}, 'tab', function()
    hs.eventtap.keyStroke({'command'}, 'tab')
    hyper.triggered = true
end)

-- Application window resizer
hyper:bind({}, 'w', function()
    hs.eventtap.keyStroke({'ctrl', 'alt'}, 'w')
    hyper.triggered = true
end)

-- Application quit
hyper:bind({}, 'q', function()
    hs.eventtap.keyStroke({'ctrl', 'alt'}, 'q')
    local app = hs.application.frontmostApplication()
    app:kill()
    hyper.triggered = true
end)

-- Application window minimize
hyper:bind({}, 'n', function()
    hs.window.focusedWindow():minimize()
 hyper.triggered = true
end)

-- Mouse pointer hide/show
-- Requires application: Cursorer
hyper:bind({}, '.', function()
    hs.eventtap.keyStroke({'ctrl', 'alt', 'shift'}, '.')
    hyper.triggered = true
end)

--
-- Arrow keys
--
hyper:bind({}, 'h', function()
    hs.eventtap.keyStroke({}, 'left')
    hyper.triggered = true
end)

hyper:bind({}, 'j', function()
    hs.eventtap.keyStroke({}, 'down')
    hyper.triggered = true
end)

hyper:bind({}, 'k', function()
    hs.eventtap.keyStroke({}, 'up')
    hyper.triggered = true
end)

hyper:bind({}, 'l', function()
    hs.eventtap.keyStroke({}, 'right')
    hyper.triggered = true
end)

-- Hints
hyper:bind({}, '/', nil, function()
    hs.hints.windowHints(getAllValidWindows() )
end)
 
-- utils
function getAllValidWindows ()
    local allWindows = hs.window.allWindows()
    local windows = {}
    local index = 1
    for i = 1, #allWindows do
        local w = allWindows[i]
        if w:screen() then
            windows[index] = w
            index = index + 1
        end
    end
    return windows
end
