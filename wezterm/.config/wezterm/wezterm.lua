local wezterm = require 'wezterm'

function scheme_for_appearance(appearance)
	if appearance:find "Dark" then
		return "Catppuccin Mocha"
	else
		return "Catppuccin Latte"
	end
end

return {
	font = wezterm.font 'Iosevka NF',
	hide_tab_bar_if_only_one_tab = true,
	color_scheme = scheme_for_appearance(wezterm.gui.get_appearance()),
}
