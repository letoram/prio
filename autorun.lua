local enable_led = true;

-- animated bonfire, using two images where one is the
-- greyscale / suspended unkindled version, crossfade on doubleclick
local bfh, bonfire;
local dblclick = null_surface(64, 64)
local bonfire_2 = null_surface(64, 64);
local bonfire_3 = null_surface(64, 64);
move_image(bonfire_3, -64, -64);

local kbd_ind = 2;
local bl_ind = 1;

bfh = function(source, status)
	if (status.kind == "resized") then
		show_image(source);
		local xp = VRESW - 1.05 * status.width;
		local yp = VRESH - status.width;
		resize_image(source, status.width, status.height);
		move_image(source, xp, yp);
		image_sharestorage(source, bonfire_2);
		resize_image(dblclick, 0.3 * status.width, status.height);
		move_image(dblclick, xp + 0.33 * status.width, yp);
		copy_image_transform(source, bonfire_2);
		hide_image(bonfire_2);
-- vlc has a tendency to crash
	elseif (status.kind == "terminated") then
		delete_image(source);
		bonfire = launch_decode("wallpaper/bonfire.mp4", "loop", bfh);
		image_sharestorage(bonfire, bonfire_2);
		image_sharestorage(bonfire, bonfire_3);
	end
end

function string.split(instr, delim)
	if (not instr) then
		return {};
	end

	local res = {};
	local strt = 1;
	local delim_pos, delim_stp = string.find(instr, delim, strt);

	while delim_pos do
		table.insert(res, string.sub(instr, strt, delim_pos-1));
		strt = delim_stp + 1;
		delim_pos, delim_stp = string.find(instr, delim, strt);
	end

	table.insert(res, string.sub(instr, strt));
	return res;
end

bonfire = launch_decode("wallpaper/bonfire.mp4", "loop", bfh);

-- setup a mapping to two led controllers, the arcan_db ext_led settings
-- will always get the first indices, so treat ext_led as keyboard and
-- ext_led_2 as display ambience.
local kindleshader = shader_get("bonfire_led");
if (enable_led) then
local cont = alloc_surface(64, 64);
image_sharestorage(bonfire, bonfire_3);
show_image(bonfire_3);
image_shader(bonfire_3, kindleshader);
move_image(bonfire_3, 0, 0);
image_set_txcos(bonfire_3, {0.45, 0.45, 0.5, 0.45, 0.5, 0.5, 0.45, 0.5});
define_calctarget(cont, {bonfire_3}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -2,
	function(tbl, w, h)
		w = w - 1;
		h = h - 1;
-- display (0..7 = top, 8..15 = left, 16..23 = bottom, 24..31 = right)
		for i=0,7 do
			local r,g,b = tbl:get(w/8*i, 0, 3);
			set_led_rgb(bl_ind, i, r, g, b, true);
			r, g, b = tbl:get(w/8*i, h, 3);
			set_led_rgb(bl_ind, 16+i, r, g, b, true);
		end
		for i=0,7 do
			local r,g,b = tbl:get(0, h/8*i, 3);
			set_led_rgb(bl_ind, 8+i, r, g, b, true);
			r,g,b = tbl:get(w, h/8*i, 3);
			set_led_rgb(bl_ind, 24+i, r, g, b, i ~= 7);
		end
-- keyboard, not so picky with distribution here, correct would be to
-- define a 2d->2d function that took physical layout into account
		for i=0,106 do
			local r,g,b = tbl:get(i % w, i / w, 3);
			set_led_rgb(kbd_ind, i, r, g, b, i ~= 106);
		end
	end
);
end

image_mask_set(bonfire, MASK_UNPICKABLE);
image_texfilter(bonfire, FILTER_BILINEAR);
image_mask_set(bonfire_2, MASK_UNPICKABLE);
image_texfilter(bonfire_2, FILTER_BILINEAR);
image_texfilter(bonfire_3, FILTER_LINEAR);

local shid = shader_get("bonfire");
shader_uniform(shid, "fact", "f", 1.0);
image_shader(bonfire, shader_get("bonfire"));
image_shader(bonfire_2, shader_get("luma_nored"));

-- bonfire double-click capture invisible
show_image(dblclick);
order_image(dblclick, 2);

for k,v in pairs(mouse_cursors()) do
	v.shader = shader_get("mouse");
end
image_shader(mouse_state().cursor, shader_get("mouse"));
shader_uniform(shader_get("mouse"), "color", "fff", 0.4, 0.35, 0.35);

-- when kindling the fire
local function kindle(ctx)
	resume_target(bonfire);
	instant_image_transform(bonfire);
	instant_image_transform(bonfire_2);
	instant_image_transform(bonfire_3);
	blend_image(bonfire, 1.0, 10);
	blend_image(bonfire_2, 0.0, 20);
	blend_image(bonfire_3, 1.0, 20);
	priocfg.active_color = {69, 52, 51};
	priocfg.inactive_color = {39, 33, 23};
	priocfg.tab_active = {74, 68, 57};
	priocfg.tab_inactive = {41, 35, 26};
	shader_uniform(shader_get("mouse"), "color", "fff", 0.4, 0.32, 0.30);
	for k,v in ipairs(prio_windows_linear()) do
		v:border_color(unpack(priocfg.inactive_color));
		v:resize(v.width, v.height, true);
		image_shader(v.canvas, shader_get("canvas_normal"));
	end
	if (priowin) then
		priowin:border_color(unpack(priocfg.inactive_color));
	end
	ctx.kindled = true;
end

local function unkindle(ctx)
	suspend_target(bonfire);
	instant_image_transform(bonfire);
	instant_image_transform(bonfire_2);
	instant_image_transform(bonfire_3);
	blend_image(bonfire, 0.0, 80);
	blend_image(bonfire_2, 1.0, 80);
	blend_image(bonfire_3, 0.01, 80);
	shader_uniform(shader_get("mouse"), "color", "fff", 0.7, 0.7, 0.7);
	priocfg.active_color = {69, 69, 69};
	priocfg.inactive_color = {39, 39, 39};
	priocfg.tab_active = {80, 80, 80};
	priocfg.tab_inactive = {40, 40, 40};
	for k,v in ipairs(prio_windows_linear()) do
		v:border_color(unpack(priocfg.inactive_color));
		v:resize(v.width, v.height, true);
		image_shader(v.canvas, shader_get("canvas_grey"));
	end
	if (priowin) then
		priowin:border_color(unpack(priocfg.inactive_color));
	end
	ctx.kindled = false;
end

local mouse_ctx = {
	name = "bonfire",
	kindled = true,
	own = function(ctx, vid)
		return vid == dblclick;
	end,
	dblclick = function(ctx)
		if (not ctx.kindled) then
			kindle(ctx);
		else
			unkindle(ctx);
		end
	end
};
mouse_addlistener(mouse_ctx, {"dblclick"});

-- listen to a pipe, read cpu-use, mem-use, disk-free
-- map to stamina, health, humanity and intensity
local hud = load_image("hud.png");
local memuse_bar = color_surface(228, 8, 107, 82, 81);
local cpuuse_bar = color_surface(228, 8, 57, 82, 65);
show_image({memuse_bar, cpuuse_bar, hud});
link_image(memuse_bar, hud);
link_image(cpuuse_bar, hud);
move_image(memuse_bar, 74, 20);
move_image(cpuuse_bar, 74, 38);
image_shader(memuse_bar, shader_get("vgradient"));
image_shader(cpuuse_bar, shader_get("vgradient"));
order_image(hud, 2);

-- approximate the text effect, unfortunately the text renderer lacks an
-- outline mode, so this will look a bit shitty
local df_text;
local function update_stats(df, mem, cpu)
	if (type(df) == "number") then
		df = df > 99 and 99 or df;
	end
	local rstr = "\\#aaaaaa\\ffonts/optimus.ttf,40 " .. tostring(df);
	if (valid_vid(df_text)) then
		render_text(df_text, rstr);
	else
		df_text = render_text(rstr);
		link_image(df_text, hud);
		image_inherit_order(df_text, true);
		order_image(df_text, 1);
		image_mask_set(df_text, MASK_UNPICKABLE);
		show_image(df_text);
		move_image(df_text, 22, 15);
	end
	resize_image(memuse_bar, 228 - 228 * mem, 8, 25);
	resize_image(cpuuse_bar, 228 - 228 * cpu, 8, 25);
end
zap_resource("status");
input_ch = open_nonblock("<status");
update_stats(10, 0.2, 0.6, 45);

local tick = prio_clock_pulse;
prio_clock_pulse = function(...)
	tick(...);
	local line = input_ch:read();
	if (line == nil or string.len(line) == 0) then
		return;
	end
	local tbl = string.split(line, " ");
	if (#tbl == 2) then
		local t1 = tonumber(tbl[1]);
		local total, used = current_context_usage();
		local disk = tonumber(string.sub(tbl[2], 1, string.len(tbl[2])-1));
		update_stats(disk, used / total, t1 > 0 and t1 / 100 or 0);
	end
end

local autores = VRES_AUTORES;
VRES_AUTORES = function(w, h, vppcm, flags, source)
	autores(w, h, vppcm, flags, source);
	local status = image_surface_resolve(bonfire);
	local xp = VRESW - 1.05 * status.width;
	local yp = VRESH - status.width;
	move_image(bonfire, xp, yp);
	move_image(bonfire_2, xp, yp);
	move_image(dblclick, xp + 0.33 * status.width, yp);
end
