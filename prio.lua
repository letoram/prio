--
-- A Quick/Dirty RIO (Plan9) like desktop
--
-- globals:
-- priocfg  : loaded config.lua table
-- priobg   : background / global event catcher
-- priowindows : all available windows
-- priohidden :
-- priostate : (def: nil), hook for menu->delete + mouse pick
-- prioactions : table of macro- like functions to bind to keys
-- priobindings : list of active keybindings (str -> field in prioactions)
--
priowindows = {};
priohidden = {};
CLIPBOARD_MESSAGE = "";

function prio()
	priosym = system_load("symtable.lua")(); -- keyboard translation
	priocfg = system_load("config.lua")();
	system_load("uifx.lua")(); -- shadows
	system_load("mouse.lua")(); -- mouse gesture abstraction etc.
	system_load("window.lua")(); -- window creation
	system_load("menu.lua")(); -- global menus
	system_load("extrun.lua")(); -- helper functions for window spawn
	system_load("shaders.lua")(); -- eyecandy
	prioactions = system_load("actions.lua")(); -- bindable actions
	priobindings = system_load("keybindings.lua")(); -- keysym+mods -> actions

-- mipmap is build-time default off, vfilter is bilinear
	switch_default_texfilter(FILTER_NONE);

-- default gain value for all new sources
	audio_gain(0, priocfg.global_gain);

-- some platforms/devices don't support this and we should provide
-- a fallback, but that's missing now
	kbd_repeat(priocfg.repeat_period, priocfg.repeat_delay);

-- we'll always "overdraw" when updating due to the background image
	priobg = fill_surface(VRESW, VRESH, 0, 0, 0);
	image_shader(priobg, shader_get("background"));
	show_image(priobg);

-- asynch- load background and overwrite existing if found
	if (priocfg.background and resource(priocfg.background)) then
		load_image_asynch(priocfg.background,
			function(source, status)
				if (status.kind == "loaded") then
					image_sharestorage(source, priobg);
				end
				delete_image(source);
		end);
	end

	local add_cursor = function(name, hx, hy)
		mouse_add_cursor(name, load_image("cursor/" ..name ..".png"), hx, hy, {});
	end
	add_cursor("rz_diag_l", 0, 0);
	add_cursor("rz_diag_r", 0, 0);
	add_cursor("rz_down", 0, 0);
	add_cursor("rz_left", 0, 0);
	add_cursor("rz_right", 0, 0);
	add_cursor("rz_up", 0, 0);
	add_cursor("hide", 0, 0);
	add_cursor("grabhint", 0, 0);
	add_cursor("drag", 0, 0);
	add_cursor("destroy", 6, 7);
	add_cursor("new", 8, 6);
	add_cursor("default", 0, 0);

-- so "over" events don't switch cursor when we're in a special mode
	local orig_mouse_sw = mouse_switch_cursor;
	mouse_switch_cursor = function(img)
		if (not priostate) then
			orig_mouse_sw(img);
		end
	end

	priosym:load_keymap(priocfg.keymap);

-- try mouse- grab (if wanted)
	mouse_setup(BADID, 65535, 1, true, false);
	mouse_cursor_sf(priocfg.mouse_cursor_scale, priocfg.mouse_cursor_scale);

-- this is used when we're running in some kind of nested setting, like
-- with the LWA or SDL input platforms
	 if (priocfg.mouse_grab) then
		toggle_mouse_grab(MOUSE_GRABON);
	end

	mouse_addlistener({
		name = "background",
		own = priobg,
		click = cancel_menu,
		rclick = prio_menu,
	}, {"click", "rclick"});

-- rebuild config now that we have access to everything
	prio_update_density(VPPCM);
	system_load("autorun.lua")(); -- whatever the user needs to have setup
end

function system_message(str)
	local msg, linew, w, h = render_text({priocfg.menu_fontstr, str});
	if (valid_vid(last_msg)) then
		delete_image(last_msg);
	end
	last_msg = msg;

	if (valid_vid(msg)) then
		expire_image(msg, 50);
		move_image(msg, 0, VRESH - h);
		show_image(msg);
		order_image(msg, 65535);
	end
end

if (DEBUGLEVEL > 1) then
	debug_message = system_message;
else
	debug_message = function() end
end

-- two modes, one with normal forwarding etc. one with a region-select
function prio_normal_input(iotbl)
	if (iotbl.status) then
		print("status");
		for k,v in pairs(iotbl) do print(k, v); end
	end

	if (iotbl.mouse) then
		mouse_iotbl_input(iotbl);
		return;

-- on keyboard input, apply translation and run any defined keybinding
-- for synthetic keyrepeat, the patch result would need to be cached and
-- propagated in the _clock_pulse.
	elseif (iotbl.translated) then
		local a, b = priosym:patch(iotbl, true);

-- falling edge (release) gets its own suffix to allow binding something on
-- rising edge and something else on falling edge
		if (not iotbl.active) then
			b = b .. "_f";
		end

-- slightly more difficult for dealing with C-X, C-W style choords where
-- C-* is bound to a translation prefix and the next non-modifier press
-- consumes it
		if (iotbl.active and priosym.prefix and
			not priosym:is_modifier(iotbl)) then
			b = priosym.prefix .. b;
			priosym.prefix = nil;
		end

		debug_message(string.format(
			"resolved symbol: %s, binding? %s, action? %s", b,
			priobindings[b] and priobindings[b] or "[missing]",
			(priobindings[b] and prioactions[priobindings[b]]) and "yes" or "no"));

		if (priobindings[b] and prioactions[priobindings[b]]) then
			prioactions[priobindings[b]]();
			return;
		end
	end

-- we have a keyboard key without a binding OR a game/other device,
-- forward normally if the window is connected to an external process
	if (priowin and valid_vid(priowin.target, TYPE_FRAMESERVER)) then
		target_input(priowin.target, iotbl);
	end
end

-- selection / creation input handler, when switching to the region
-- select through menu/new, the normal _input function is simply
-- replaced with this one.
function prio_region_input(iotbl)
	mouse_switch_cursor("new");
	if (iotbl.mouse) then
		if (iotbl.digital) then
			if (not iotbl.active) then
				return;
			end
			if (mouse_state().in_select) then
				mouse_select_end(function(x1, y1, x2, y2)
					if (x2-y1 > 32 and y2-y1 > 32) then
						prio_terminal(x1, y1, x2 - x1, y2 - y1);
					end
					prio_input = prio_normal_input;
				end);
			else
				local col = color_surface(1, 1, unpack(priocfg.select_color));
				blend_image(col, priocfg.select_opacity);
				image_shader(col, shader_get("selection"));
				mouse_select_begin(col);
			end
		else
			mouse_iotbl_input(iotbl);
		end
	end
end

-- mouse event handlers need a CLK in order to handle time- based
-- events like hover.
function prio_clock_pulse()
	mouse_tick(1);
end

function prio_update_density(vppcm)
	VPPCM = vppcm;
	priocfg = system_load("config.lua")();
	local factor = vppcm / 28.3687;
	for k,v in ipairs({
			"menu_fontsz", "border_width", "tab_spacing", "tab_fontsz"
		}) do
		priocfg[v] = math.ceil(priocfg[v] * factor);
	end

	priocfg.menu_fontstr = string.format("%s%d ",
		priocfg.menu_fontstr, priocfg.menu_fontsz);
	priocfg.tab_fontstr = string.format("%s%d ",
		priocfg.tab_fontstr, priocfg.tab_fontsz);

-- send to all windows that the density has potentially changed
	if (prio_iter_windows) then
		for v in prio_iter_windows(false, true) do
			target_displayhint(v, 0, 0, TD_HINT_IGNORE, {ppcm = vppcm});
		end
	end

	mouse_cursor_sf(factor, factor);
end

-- this special hook is a necessary evil right now when running
-- as arcan_lwa and the parent moves output display or resizes window
function VRES_AUTORES(w, h, vppcm, flags, source)
	if (vppcm > 0 and math.abs(vppcm - VPPCM) > 1) then
		prio_update_density(vppcm);
	end

	local oldw = VRESW;
	local oldh = VRESH;

-- will update the VRESW/VRESH globals
	resize_video_canvas(w, h);
	resize_image(priobg, w, h);

-- reposition all windows to have the same relative spot,
-- and invalidate to relayout
	for k,v in pairs(priowindows) do
		local props = image_surface_properties(v.anchor);
		local sx = w - oldw;
		local sy = h - oldh;
		move_image(v.anchor,
			(props.x + sx) < 0 and 0 or (props.x + sx),
			(props.y + sy) < 0 and 0 or (props.y + sy)
		);
	end
end

prio_input = prio_normal_input;
