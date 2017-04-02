return {
-- input tuning
	keymap = "default.lua",
	drag_resize_inertia = 8,
	repeat_period = 100, -- ticks between press/release
	repeat_delay = 300, -- delay before feature is enabled

-- mouse control
	mouse_grab = true,
	mouse_cursor_scale = 1.0,
	mouse_input_scale_x = 1.0,
	mouse_input_scale_y = 1.0,

	background = "background.png", -- will load/stretch if found
	animation_speed = 20,
	global_gain = 1.0,

-- external programs
	terminal_font = {"hack.ttf", "emoji.ttf"},
	terminal_font_sz = 10 * FONT_PT_SZ,
	terminal_hint = 2, -- 0: off, mono, light, normal
	terminal_cfg = "palette=solarized-black:bgalpha=190:"; -- END with :
	default_font = {"fonts.ttf", "emoji.ttf"},
	default_font_sz = 12 * FONT_PT_SZ,

-- popup menu
	menu_border_color = {66, 174, 57},
	menu_background_color = {47, 122, 40},
	menu_border_width = 2,
	menu_select_color = {255, 255, 255},
	menu_select_alpha = 0.3,

-- these get merged together (and fontsz magnified to match display density
-- hence the trailing ,
	menu_fontsz = 14,
	menu_fontstr = [[\#ffffff\ffonts/default.ttf,]],

-- selection region
	select_color = {0, 255, 0},
	select_opacity = 0.8,

-- default window behavior
	force_size = true,

-- window visuals
	border_width = 5,
	border_alpha = 0.8,
	active_color = {164, 164, 192},
	inactive_color = {92, 92, 128},

-- defined in uifx.lua, called after window creation
	effect_hook = prio_effect_hook,

-- default tab colors
	tab_active = {255, 211, 0},
	tab_inactive = {179, 148, 0},

-- type specific colors
	tab_colors = {
		["bridge-x11"] = {0xff, 0xc5, 0x6a},
		["bridge-wayland"] = {0x60, 0xe6, 0xc1},
		["application"] = {0x80, 0x73, 0xe9},
		["game"] = {0xff, 0xa0, 0x6a},
		["multimedia"] = {0x63, 0xec, 0x8c},
		["lightweight arcan"] = {0xf3, 0x66, 0xa6},
		["tui"] = {0x60, 0xe6, 0xbe},
		["remoting"] = {0xff, 0x6e, 0x6b}
	},

	tab_fontsz = 14,
	tab_fontstr = [[\#ffffff\ffonts/default.ttf,]],
	tab_inactive_alpha = 1.0,
	tab_inactive_fontalpha = 0.5,
	tab_spacing = 5
};
