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
