--
-- Automatic Hammerspoon config reloading on save-to-disk
--
function reloadConfig(files)
    for _,file in pairs(files) do
        if file:sub(-4) == ".lua" then
            hs.reload()
        end
    end
end
-- Automatically reload config when it changes.
myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
-- Unfortunately the above does not handle symlinks, so point to git repo for dotfiles.
myWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/dev/my/dotfiles/hammerspoon/", reloadConfig):start()
