local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.default_prog = { "wsl.exe", "~" }
config.font_dirs = {
  wezterm.home_dir .. "/AppData/Local/Microsoft/Windows/Fonts",
}
config.font = wezterm.font("FiraCode Nerd Font Mono")
config.color_scheme = "Tokyo Night"
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}

return config

