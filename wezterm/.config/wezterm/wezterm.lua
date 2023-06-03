local wezterm = require 'wezterm'

function scheme_for_appearance(appearance)
	if appearance:find "Dark" then
		return "Catppuccin Mocha"
	else
		return "Catppuccin Latte"
	end
end

-- Allow working with both the current release and the nightly
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Set font
if wezterm.target_triple == 'x86_64-pc-windows-msvc' then
	config.font = wezterm.font 'Iosevka NF'
else
	config.font = wezterm.font 'Iosevka Nerd Font'
end
config.hide_tab_bar_if_only_one_tab = true

-- Color scheme
config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())

-- Background transparency
if wezterm.target_triple:find('windows') then
	config.window_background_opacity = 0.95
	config.win32_system_backdrop = 'Acrylic'
elseif wezterm.target_triple:find('apple') then
	config.window_background_opacity = 0.80
	config.macos_window_background_blur = 10
end

return config
