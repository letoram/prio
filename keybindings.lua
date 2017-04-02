--
-- see actions.lua for bindable functions
--
-- For stateful keybindings, like C-W, C-G:
-- [M1 .. "W"] = "set_temp_prefix_1"
-- ["t1_" .. M1 .. "G"] = "destroy_active_tab"
--
-- For triggering on release, add the suffix _f"
--
-- other assignable functions:
-- menu_path(name1/name2/name3...)
-- switch

local M1 = "lmeta_";
local M2 = "rmeta_";
local M3 = "lmeta_rmeta_";
return {
-- window controls
	[M1 .. "F4"] = "destroy_active_tab",
	[M3 .. "F4"] = "destroy_active_window",
	[M3 .. "1"] = "select_tab_1",
	[M3 .. "2"] = "select_tab_2",
	[M3 .. "3"] = "select_tab_3",
	[M3 .. "4"] = "select_tab_4",
	[M3 .. "5"] = "select_tab_5",
	[M3 .. "6"] = "select_tab_6",
	[M3 .. "7"] = "select_tab_7",
	[M3 .. "8"] = "select_tab_8",
	[M3 .. "9"] = "select_tab_9",
	[M3 .. "0"] = "select_tab_10",
	[M1 .. "h"] = "next_tab",
	[M1 .. "l"] = "prev_tab",
	[M1 .. "v"] = "clipboard_paste",

-- window positioning / sizing controls
	[M2 ..    "j"] = "select_up",
	[M2 ..    "k"] = "select_down",
	[M2 ..    "h"] = "select_left",
	[M2 ..    "l"] = "select_right",
	[M3 ..    "j"] = "move_up",
	[M3 ..    "k"] = "move_down",
	[M3 ..    "h"] = "move_left",
	[M3 ..    "l"] = "move_right",
	[M3 ..    "m"] = "toggle_maximize",
	[M1 ..   "UP"] = "shrink_h",
	[M1 .. "DOWN"] = "grow_h",
	[M1 .. "LEFT"] = "shrink_w",
	[M1 .."RIGHT"] = "grow_w",
	[M3 ..   "UP"] = "assign_top",
	[M3 .. "DOWN"] = "assign_bottom",
	[M3 .. "LEFT"] = "assign_left",
	[M3 .."RIGHT"] = "assign_right"
};
