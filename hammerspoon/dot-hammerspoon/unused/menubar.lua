
-- TODO: Use MenuBar to show status of "programming mode" so that one can leave programming mode off most of
-- the time and enable it just when needed, which will mean we don't run into the password field entry issues.
--
mb = hs.menubar.new(nil)
updateStatus = function(event)
  if(event == "on") then
    mb:setTitle("🔴")
  elseif(event == "off") then
    mb:setTitle("🟢")
  end
end
