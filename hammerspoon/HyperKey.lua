--
-- Implements a Hyper key and associated key bindings
--

-- A global variable for Hyper mode
hyper = hs.hotkey.modal.new({}, 'F17')

-- Enter Hyper mode when Hyper key is pressed
function enterHyperMode()
  hyper.triggered = false
  hyper:enter()
end

-- Leave Hyper mode when Hyper is pressed
function exitHyperMode()
  hyper:exit()
  if not hyper.triggered then
    hs.eventtap.keyStroke({'Option'}, 'Space')
 end
end

-- Bind the Hyper key
f13 = hs.hotkey.bind({}, 'F18', enterHyperMode, exitHyperMode)


-- Application launcher
hyper:bind({}, 'return', function()
    hs.eventtap.keyStroke({'ctrl', 'alt'}, 'return')
    hyper.triggered = true
end)

-- Application switcher
hyper:bind({}, 'space', function()
    hs.eventtap.keyStroke({'ctrl', 'alt'}, 'space')
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
