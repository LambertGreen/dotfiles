-- Provides application control
--
-- Application quit
local obj = {}
app = nil

obj.appKill9 = function()
    app = hs.application.frontmostApplication()
    hs.focus()
    local result = hs.dialog.blockAlert("Force kill application", "Are you sure?", "OK", "Cancel", "warning")
    if result == "OK" then
      app:kill9()
    end
end

return obj
