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
	terminal_font_sz = 12 * FONT_PT_SZ,
	terminal_hint = 2, -- 0: off, mono, light, normal
	terminal_cfg = "palette=solarized-black:cc=68,72,60:"; -- END with :
	default_font = {"optimus.ttf", "emoji.ttf"},
	default_font_sz = 12 * FONT_PT_SZ,

-- popup menu
	menu_border_color = {34, 36, 30},
	menu_background_color = {0, 0, 0},
	menu_border_width = 2,
	menu_select_color = {96, 46, 21},
	menu_select_alpha = 0.8,

-- these get merged together (and fontsz magnified to match display density
-- hence the trailing ,
	menu_fontsz = 18,
	menu_fontstr = [[\#bababa\ffonts/optimus.ttf,]],

-- selection region
	select_color = {127, 127, 127},
	select_opacity = 0.8,

-- default window behavior
	force_size = true,

-- window visuals
	border_width = 8,
	border_alpha = 1.0,
	active_color = {69, 52, 51},
	inactive_color = {39, 33, 23},

-- defined in uifx.lua, called after window creation
	effect_hook = prio_effect_hook,

-- default tab colors
	tab_active = {74, 68, 57},
	tab_inactive = {41, 35, 26},

-- type specific colors
	tab_colors = {
	},

	tab_fontsz = 18,
	tab_fontstr = [[\#bababa\ffonts/optimus.ttf,]],
	tab_inactive_alpha = 1.0,
	tab_inactive_fontalpha = 0.5,
	tab_spacing = 5
};
