local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.default_prog = { "wsl.exe", "~" }
config.font_dirs = {
  wezterm.home_dir .. "/AppData/Local/Microsoft/Windows/Fonts",
}
config.font = wezterm.font("FiraCode Nerd Font Mono")
config.font_size = 10.0
config.color_scheme = "Tokyo Night"
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}

-- Zsh sets the pane title to "<directory> [INSERT|NORMAL]". WezTerm uses
-- that pane title for the tab, keeping the shell's vi mode visible.

return config
