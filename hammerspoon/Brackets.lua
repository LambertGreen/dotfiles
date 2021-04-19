-- Makes typing brackets easier
--
--

-- -- Setup a logger
-- local log = hs.logger.new('HyperKey', 'debug')

-- -- Create a mode for when the `a` key is held down
-- mode_a = hs.hotkey.modal.new()

-- -- Function for when when mode A is entered
-- function enterModeA()
--   log.i('Entering mode A')
--   mode_a.triggered = false
--   mode_a:enter()
-- end

-- -- Function for when when mode A is exited
-- function exitModeA()
--   if mode_a.triggered then
--     log.i('Exiting mode A: other key pressed so exiting mode.')
--   else
--     log.i('Exiting mode A: no other key pressed so sending \'a\'')
--     hyper_a:disable()
--     hs.eventtap.keyStroke({}, "b")
--     hyper_a:enable()
--   end
--   mode_a:exit()
-- end

-- -- Create a hotkey on 'a'
-- hyper_a = hs.hotkey.bind({}, 'a', enterModeA, exitModeA)

-- -- Application launcher
-- mode_a:bind({}, 'j', function()
--     hs.eventtap.keyStroke({"shift"}, "9")
--     hyper_a.triggered = true
-- end)


-- Use `Ctrl+j` to type `(`
hs.hotkey.bind({"ctrl"}, "j", function()
    hs.eventtap.keyStroke({"shift"}, "9")
end)

-- Use `Ctrl+k` to type `{`
hs.hotkey.bind({"ctrl"}, "k", function()
    hs.eventtap.keyStroke({"shift"}, "[")
end)
