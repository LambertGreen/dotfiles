--
-- Implements a Hyper key and associated key bindings
--
-- We are using the F14 key as the Hyper key since this key is correctly
-- transmitted by Remotix (used to remotely work on Mac from our Windows machine.)
-- Note: We do need to unregister F14/F15 keys in 'System Preferences'->Keyboard->Shortcuts as
-- they are by default registered Display (inc/dec brightness). One must not only uncheck the values
-- but assign different ones and reboot.

-- Setup a logger
local log = hs.logger.new('HyperKey', 'debug')

-- A global variable for Hyper mode
hyper = hs.hotkey.modal.new()

-- Enter Hyper mode when Hyper key is pressed
function enterHyperMode()
  log.i('Hyper down.')
  hyper.triggered = false
  hyper:enter()
end

-- Leave Hyper mode when Hyper is pressed
function exitHyperMode()
  log.i('Hyper up.')
  hyper:exit()
end

-- Update 1: Ok I have made a big change: instead of using the additional left side spacebar key on the FreeStyle Pro
-- as the Hyper key, I have made it the Command key.  The reasons for this are:
--
-- 1. I had hoped to map many Hyper key bindings to control the system by having Hammerspoon send Command based
-- system hotkeys.  But the system has low level hooking for the Command key, and so there were cases where Hammerspoon, sending
-- the Command key did not result in the system handling it.  An example of this is: opening an application preferences with the
-- system hotkey "Cmd+,".
--
-- 2. There is no other convenient key to use as a Hyper key now, since Capslock is already being used for a meta Control/Escape key,
-- which is super valuable for coding.
--
-- 3. My actual use cases for the Hyper key are not the typical cases i.e. I don't need it for launching specific apps, since Alfred
-- handles this case quite fine.  Other cases like using vim-style bindings for arrow keys are best addressed by using applications
-- that natively support them anyway.
--
-- 4. I am already getting some nice benefits from using the left space key as the Command key e.g. I saved this very document
-- in Emacs by pressing "Cmd+s" (it was pressed mistakenly (was trying to do Spc+b+s), but resulted in the desired behavior).
--
-- Update 2: I am not quite satified with the loss of the Hyper key. I am noticing that MacOS often allows one to change hotkeys
-- so I am hoping that for even the "Cmd" based actions, that I can achieve them by letting MacOS rebind the particular actions to
-- a Hyper key based shortcut. However instead of making such changes, what I ended up doing is simply not using the OS 'hyper'
-- keys i.e. Cmd/Win. And right now I am not even using a 'Hyper' mode.  Basically I have setup the following that seems fine for now:
-- 1. Application Launcher: CTRL+Enter
-- 2. Application Swithcer: CTRL+Space
-- 3. Window Manager:       CTRL+Backspace
-- 

-- Bind F14 as the Hyper key
f14 = hs.hotkey.bind({}, 'f14', enterHyperMode, exitHyperMode)

-- Setup a filter to prevent hyper hotkeys for remoting applications.
hs.window.filter.new('Remotix')
  :subscribe(hs.window.filter.windowFocused, function() f14:disable() end)
    :subscribe(hs.window.filter.windowUnfocused,function() f14:enable() end)

-- Virtual Desktop mode (w for workspace)
hyper:bind({'ctrl'}, 'k', function()
    log.i('Switch desktop: <- ')
    -- hs.eventtap.keyStroke({'ctrl'}, 'left')
    hs.eventtap.event.newKeyEvent({'ctrl'}, '1', true):post()
    hs.timer.usleep(1000)
    hs.eventtap.event.newKeyEvent({'ctrl'}, '1', false):post()
    hyper.triggered = true
end)

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

-- Breakout of Parallels VM to host
-- Note: This does not work! The reason is that Parallels listens for this hotkey
-- on a lower level, and Hammerspoon is not even getting access to intercept keys
-- when a VM is running.
hyper:bind({}, ',',  function()
    log.i('Invoking Preferences: cmd + ,')
    hs.eventtap.keyStroke({'cmd'}, ',')
    hyper.triggered = true
end)
