-- Aliases
--

-- There is a limit on line length in lua files, so need another way to set LS_COLORS
--
function set_light_mode()
    print("Set LS_COLORS for light mode!")
end

function set_dark_mode()
    print("Set LS_COLORS for dark mode!")
end

-- TODO Double check latest version of Clink to see if there is
-- some support for aliases or not.
--
-- local aliases = clink.get_aliases()
-- aliases["light"] = "clink.light"
-- aliases["dark"] = "clink.dark"


function clink.onfiltermatches(matches)
    for i, match in ipairs(matches) do
        if match == "clink.light" then
            set_light_mode()
            return {}  -- clear the matches to stop command execution
        elseif match == "clink.dark" then
            set_dark_mode()
            return {}  -- clear the matches to stop command execution
        end
    end
    return matches
end
