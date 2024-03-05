local wezterm = require 'wezterm'

-- Color schemes
--
local light_theme = "OneHalfLight"
local dark_theme = "OneHalfDark"

local function scheme_for_appearance(appearance)
	if appearance:find "Dark" then
		return dark_theme
	else
		return light_theme
	end
end

-- Allow working with both the current release and the nightly
--
local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Set font
--
if wezterm.target_triple:find('windows') then
	config.font = wezterm.font 'Iosevka NFM'
elseif wezterm.target_triple:find('apple') then
	config.font = wezterm.font 'Iosevka NFM'
	config.font_size = 15
else
	config.font = wezterm.font 'Iosevka NFM'
end
config.hide_tab_bar_if_only_one_tab = true

-- Background transparency
--
if wezterm.target_triple:find('windows') then
	config.window_background_opacity = 0.95
	-- TODO: This option is still pretty new, and hence one should check for
	-- existence before use
	-- config.win32_system_backdrop = 'Acrylic'
elseif wezterm.target_triple:find('apple') then
	config.window_background_opacity = 0.95
	config.macos_window_background_blur = 20
	config.window_decorations = "TITLE | RESIZE | MACOS_FORCE_ENABLE_SHADOW"
end

-- Color Scheme
--
-- We are trying defaulting to a dark theme. Uncomment the below to default to system.
-- config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())
config.color_scheme = dark_theme -- scheme_for_appearance(wezterm.gui.get_appearance())

local function ToggleTheme(window, _)
	-- local current_mode = wezterm.get_config().color_scheme
	local current_mode = window:effective_config().color_scheme
	local overrides = window:get_config_overrides() or {}

	if current_mode == light_theme then
		overrides.color_scheme = dark_theme
	else
		overrides.color_scheme = light_theme
	end

	window:set_config_overrides(overrides)
	wezterm.log_info("Switched to: " .. overrides.color_scheme)
end


-- Keybindings
--
config.enable_csi_u_key_encoding = true

config.leader = { key = 'a', mods = "CTRL|ALT", timeout_milliseconds = 2000 }
config.keys = {
	{ key = "f",  mods = "CMD|CTRL", action = "ToggleFullScreen" },
	{ key = "t",  mods = "CMD|CTRL", action = wezterm.action_callback(ToggleTheme) },
	{ key = "\"", mods = "LEADER",   action = wezterm.action { SplitVertical = { domain = "CurrentPaneDomain" } } },
	{ key = "%",  mods = "LEADER",   action = wezterm.action { SplitHorizontal = { domain = "CurrentPaneDomain" } } },
	{ key = "z",  mods = "LEADER",   action = "TogglePaneZoomState" },
	{ key = "c",  mods = "LEADER",   action = wezterm.action { SpawnTab = "CurrentPaneDomain" } },
	{ key = "o",  mods = "LEADER",   action = wezterm.action { ActivatePaneDirection = "Next" } },
	{ key = "h",  mods = "LEADER",   action = wezterm.action { ActivatePaneDirection = "Left" } },
	{ key = "j",  mods = "LEADER",   action = wezterm.action { ActivatePaneDirection = "Down" } },
	{ key = "k",  mods = "LEADER",   action = wezterm.action { ActivatePaneDirection = "Up" } },
	{ key = "l",  mods = "LEADER",   action = wezterm.action { ActivatePaneDirection = "Right" } },
	{ key = "H",  mods = "LEADER",   action = wezterm.action { AdjustPaneSize = { "Left", 5 } } },
	{ key = "J",  mods = "LEADER",   action = wezterm.action { AdjustPaneSize = { "Down", 5 } } },
	{ key = "K",  mods = "LEADER",   action = wezterm.action { AdjustPaneSize = { "Up", 5 } } },
	{ key = "L",  mods = "LEADER",   action = wezterm.action { AdjustPaneSize = { "Right", 5 } } },
	{ key = 'p',  mods = "LEADER",   action = wezterm.action { ActivateTabRelative = -1 } },
	{ key = 'n',  mods = "LEADER",   action = wezterm.action { ActivateTabRelative = 1 } },
	{ key = "1",  mods = "LEADER",   action = wezterm.action { ActivateTab = 0 } },
	{ key = "2",  mods = "LEADER",   action = wezterm.action { ActivateTab = 1 } },
	{ key = "3",  mods = "LEADER",   action = wezterm.action { ActivateTab = 2 } },
	{ key = "4",  mods = "LEADER",   action = wezterm.action { ActivateTab = 3 } },
	{ key = "5",  mods = "LEADER",   action = wezterm.action { ActivateTab = 4 } },
	{ key = "6",  mods = "LEADER",   action = wezterm.action { ActivateTab = 5 } },
	{ key = "7",  mods = "LEADER",   action = wezterm.action { ActivateTab = 6 } },
	{ key = "8",  mods = "LEADER",   action = wezterm.action { ActivateTab = 7 } },
	{ key = "9",  mods = "LEADER",   action = wezterm.action { ActivateTab = 8 } },
	{ key = "&",  mods = "LEADER",   action = wezterm.action { CloseCurrentTab = { confirm = true } } },
	{ key = "x",  mods = "LEADER",   action = wezterm.action { CloseCurrentPane = { confirm = true } } },
}

return config
