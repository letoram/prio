--
-- exports:
-- prio_windows_iconsize
-- prio_windows_linear(hide_hidden) => tbl
-- prio_sel_nearest(wnd, dir)
-- prio_menu_spawn(lst, x, y, ctx)
-- prio_new_window(vid, aid, opts)
--

local dirtbl = {"l", "r", "t", "b"};

-- need a linear array for window draw order management
local wndlist = {};

function prio_windows_iconsize()
	return priocfg.menu_fontsz * 4 * FONT_PT_SZ * (VPPCM / 28.3687);
end

function prio_windows_linear(hide_hidden)
	local res = {};
	for i,v in ipairs(wndlist) do
		if (not hide_hidden or not priohidden[v]) then
			table.insert(res, v);
		end
	end

	return res;
end

local function reorder_windows()
	for i,v in ipairs(wndlist) do
		order_image(v.anchor, (i+1) * 10);
	end
end

local function window_decor_tab_layout(wnd)
-- right now, we ignore accomodating title, later
	if (wnd.tabs) then
		local bw = priocfg.border_width;
		local xpos = priocfg.tab_spacing;
		local y = image_surface_resolve(wnd.anchor).y - (wnd.tab_labelh + bw);
		if (y < 0) then nudge_image(wnd.anchor, 0, -1*y); end

		for i,v in ipairs(wnd.tab_slots) do
			local w = v.label_w + bw + bw;
			local h = wnd.tab_labelh + bw;
			resize_image(v.vid, w, h);
			move_image(v.label, bw, bw);
			crop_image(v.label, v.label_w, wnd.tab_labelh);
			move_image(v.vid, xpos, -wnd.tab_labelh - (math.floor(0.5 * bw)));
			xpos = xpos + w + priocfg.tab_spacing;
			if (v == wnd.active_tab) then
				local col = v.active_color and
					v.active_color or priocfg.tab_active;
				image_color(v.vid, unpack(col));
				blend_image({v.vid, v.label}, 1.0);
				order_image(v.vid, 2);
			else
				local col = v.inactive_color and v.inactive_color or
					priocfg.tab_inactive;
				image_color(v.vid, unpack(col));
				blend_image(v.vid, priocfg.tab_inactive_alpha);
				blend_image(v.label, priocfg.tab_inactive_fontalpha);
				order_image(v.vid, -1);
			end
		end
		if (wnd.min_w < xpos) then
			wnd.min_w = xpos;
			wnd:resize(wnd.width, wnd.height);
		end
	end
end

local function tab_drop_preview(ctx)
	if (ctx.preview) then
		reset_image_transform(ctx.preview);
		expire_image(ctx.preview, priocfg.animation_speed);
		blend_image(ctx.preview, 0.0, priocfg.animation_speed);
		ctx.preview = nil;
	end
end

local function window_decor_resize(wnd, neww, newh)
	local bw = priocfg.border_width;
	if (not wnd.decor.l) then return; end
	resize_image(wnd.decor.l, bw, newh);
	resize_image(wnd.decor.r, bw, newh);
	resize_image(wnd.decor.t, neww + bw + bw, bw);
	resize_image(wnd.decor.b, neww + bw + bw, bw);
	move_image(wnd.decor.l, -bw, 0);
	move_image(wnd.decor.b, -bw, 0);
	move_image(wnd.decor.t, -bw, -bw);
	window_decor_tab_layout(wnd);
end

local function window_bordercolor(wnd, r, g, b)
	for i,v in ipairs(dirtbl) do
		if (not wnd.decor[v]) then return; end
		image_color(wnd.decor[v], r, g, b);
	end
end

--
-- different cases:
-- 1  2  3
-- 4     5
-- 6  7  8
--
local function resize_move(ctx, dx, dy, move, inx, iny)
	local wnd = ctx.wnd;
	if (not wnd.anchor) then
		return;
	end
	local props = image_surface_properties(wnd.anchor);

-- setup two accumulators
	if (not ctx.state) then
		ctx.state = {dx, dy};
	else
		ctx.state[1] = ctx.state[1] + dx;
		ctx.state[2] = ctx.state[2] + dy;
	end

	local rzx = 0;
	local rzy = 0;

-- if the absolute accumulation exceeds inertia, resize that many steps
	if (math.abs(ctx.state[1]) >= inx) then
		rzx = math.floor(ctx.state[1] / inx);
		ctx.state[1] = ctx.state[1] - (rzx * inx);
	end

	if (math.abs(ctx.state[2]) >= iny) then
		rzy = math.floor(ctx.state[2] / iny);
		ctx.state[2] = ctx.state[2] - (rzy * iny);
	end

	local neww = wnd.width + rzx * inx;
	local newh = wnd.height + rzy * iny;
	neww = neww < wnd.min_w and wnd.min_w or neww;
	newh = newh < wnd.min_h and wnd.min_h or newh;

	if (neww == wnd.width and newh == wnd.height) then
		return;
	end

	local nx = props.x;
	local ny = props.y;

	if (move == 1) then
		nx = nx + (wnd.width - neww);
		ny = ny + (wnd.height - newh);
	elseif (move == 2) then
		ny = ny + (wnd.height - newh);
	elseif (move == 3) then
		nx = nx + (wnd.width - neww);
	elseif (move == 4) then
		ny = ny + (wnd.height - newh);
	end

-- this will look "jittery" if target is slow to resize or we
-- don't autocrop
	if (wnd.autocrop or wnd.force_size or not
		valid_vid(wnd.target, TYPE_FRAMESERVER)) then
		wnd:resize(neww, newh);
		move_image(wnd.anchor, nx, ny);
	else
		target_displayhint(wnd.target, neww, newh);
		wnd.defer_x = nx;
		wnd.defer_y = ny;
	end
end

local function window_update_tprops(wnd)
	image_set_txcos_default(wnd.canvas, wnd.flip_y);

	if (wnd.autocrop) then
		local ip = image_storage_properties(wnd.canvas);
		image_scale_txcos(wnd.canvas,
			wnd.width / ip.width, wnd.height / ip.height);
	end

	image_shader(wnd.canvas, wnd.shader and wnd.shader or "DEFAULT");
end

-- assumption: cursor is on [vid]
local function set_trigger_point(ctx, vid)
	if (ctx.wnd.drag_track) then
		return;
	end

-- track the drag- point so we can warp the mouse on regions
-- with high drag- inertia or delayed synch
	local props = image_surface_resolve_properties(vid);
	local mx,my = mouse_xy();
	local rel_x = (mx - props.x) / props.width;
	local rel_y = (my - props.y) / props.height;
	rel_x = rel_x < 0 and 0 or rel_x;
	rel_x = rel_x > 1 and 1 or rel_x;
	rel_y = rel_y < 0 and 0 or rel_y;
	rel_y = rel_y > 1 and 1 or rel_y;

	ctx.wnd.drag_track = {
		vid = vid,
		start_x = mx,
		start_y = my,
		rel_x = rel_x,
		rel_y = rel_y
};
end

local function decor_v_drag(ctx, vid, dx, dy)
	if (ctx.wnd ~= priowin) then
		return;
	end

	local inx = priocfg.drag_resize_inertia;
	local iny = priocfg.drag_resize_inertia;
	set_trigger_point(ctx, vid);

	ctx.wnd:select();
	if (ctx.wnd.inertia) then
		inx = ctx.wnd.inertia[1];
		iny = ctx.wnd.inertia[2];
	end

	local uln = ctx.ul_near;
	if (ctx.diag == -1) then
		if (uln) then
			resize_move(ctx, -dx, -dy, 1, inx, iny);
		else
			resize_move(ctx, dx,  -dy, 4, inx, iny);
		end
	elseif (ctx.diag == 0) then
		if (uln) then
			resize_move(ctx, -dx, 0, 3, inx, iny);
		else
			resize_move(ctx,  dx, 0, 0, inx, iny);
		end
	elseif (ctx.diag == 1) then
		if (uln) then
			resize_move(ctx, -dx, dy, 3, inx, iny);
		else
			resize_move(ctx, dx, dy, 0, inx, iny);
		end
	else
-- means the _over event didn't fire before drag, shouldn't happen
	end
end

local function synch_tab_sizes(wnd)
	for k,v in pairs(wnd.tabs) do
		if (valid_vid(v.source, TYPE_FRAMESERVER)) then
			local props = image_storage_properties(v.source);
			if (v.source ~= wnd.target and (props.width ~= wnd.width or
				props.height ~= wnd.height)) then
				target_displayhint(v.source, wnd.width, wnd.height);
			end
		end
	end
end

local function decor_drop(ctx)
	ctx.state = nil;
	if (ctx.wnd.drag_track) then
		if (valid_vid(ctx.wnd.drag_track.hint)) then
			delete_image(ctx.wnd.drag_track.hint);
		end
		ctx.wnd.drag_track = nil;
	end
	synch_tab_sizes(ctx.wnd);
end

local function decor_h_drag(ctx, vid, dx, dy)
	if (ctx.wnd ~= priowin) then
		return;
	end

-- cases: 1,2,3 - 6,7,8
	local inx = priocfg.drag_resize_inertia;
	local iny = priocfg.drag_resize_inertia;
	set_trigger_point(ctx, vid);
	ctx.wnd:select();
	if (ctx.wnd.inertia) then
		inx = ctx.wnd.inertia[1];
		iny = ctx.wnd.inertia[2];
	end

	local uln = ctx.ul_near;
	if (ctx.diag == -1) then
		if (ctx.ul_near) then
			resize_move(ctx, -dx, -dy, 1, inx, iny);
		else
			resize_move(ctx, -dx,  dy, 3, inx, iny);
		end
	elseif (ctx.diag == 0) then
		if (uln) then
			resize_move(ctx, 0,-dy, 2, inx, iny);
		else
			resize_move(ctx, 0, dy, 0, inx, iny);
		end
	elseif (ctx.diag == 1) then
		if (uln) then
			resize_move(ctx, dx, -dy, 4, inx, iny);
		else
			resize_move(ctx, dx, dy, 0, inx, iny);
		end
	else
-- means the _over event didn't fire before drag, shouldn't happen
	end
end

local function decor_v_over(ctx, vid, x, y)
	if (ctx.wnd ~= priowin) then
		return;
	end

	local props = image_surface_resolve_properties(vid);
	local ly = y - props.y;
	local margin = props.height * 0.1;
	if (ly < margin) then
		ctx.diag = -1;
		mouse_switch_cursor(ctx.ul_near and "rz_diag_r" or "rz_diag_l");
	elseif (ly > props.height - margin) then
		ctx.diag = 1;
		mouse_switch_cursor(ctx.ul_near and "rz_diag_l" or "rz_diag_r");
	else
		ctx.diag = 0;
		mouse_switch_cursor(ctx.ul_near and "rz_left" or "rz_right");
	end
end

local function decor_h_over(ctx, vid, x, y)
	if (ctx.wnd ~= priowin) then
		return;
	end

	local props = image_surface_resolve_properties(vid);
	local lx = x - props.x;
	local margin = props.width * 0.1;
	if (lx < margin) then
		ctx.diag = -1;
		mouse_switch_cursor(ctx.ul_near and "rz_diag_r" or "rz_diag_l");
	elseif (lx > props.width - margin) then
		mouse_switch_cursor(ctx.ul_near and "rz_diag_l" or "rz_diag_r");
		ctx.diag = 1;
	else
		ctx.diag = 0;
		mouse_switch_cursor(ctx.ul_near and "rz_up" or "rz_down");
	end
end

local function get_maximize_dir()
	local x, y = mouse_xy();
	if (x <= 5) then
		return "l";
	end
	if (x >= VRESW-5) then
		return "r";
	end
	if (y <= 5) then
		return "t";
	end
	if (y >= VRESH-5) then
		return "b";
	end
end

local function update_drag_hint(ctx, vid)
	local d = get_maximize_dir();
	if (d and not ctx.drag_hint) then
		local hint = color_surface(1, 1, unpack(priocfg.select_color));
		link_image(hint, ctx.wnd.anchor);
		image_inherit_order(hint, true);
		image_shader(hint, shader_get("maximize_hint"));
		image_mask_clear(hint, MASK_POSITION);
		order_image(hint, -1);
		ctx.drag_hint = hint;
	end

	if (ctx.wnd.maximized) then
		ctx.wnd:maximize();
		local mx, my = mouse_xy();
		ctx.wnd:move(mx, my);
	end

	local speed = priocfg.animation_speed;
	if (not d) then
		if (ctx.drag_hint) then
			reset_image_transform(ctx.drag_hint);
			resize_image(ctx.drag_hint, 1, 1, speed);
			expire_image(ctx.drag_hint, speed);
			ctx.drag_hint = nil;
		end
		return;
	end

	blend_image(ctx.drag_hint, 0.5, speed);

	if (d == "t") then
		move_image(ctx.drag_hint, 0, 0);
		resize_image(ctx.drag_hint, VRESW, 0.5*VRESH, speed);
	elseif (d == "l") then
		move_image(ctx.drag_hint, 0, 0);
		resize_image(ctx.drag_hint, 0.5 * VRESW, VRESH, speed);
	elseif (d == "r") then
		move_image(ctx.drag_hint, 0.5 * VRESW, 0);
		resize_image(ctx.drag_hint, 0.5 * VRESW, VRESH, speed);
	elseif (d == "b") then
		move_image(ctx.drag_hint, 0, 0.5 * VRESH);
		resize_image(ctx.drag_hint, VRESW, 0.5*VRESH, speed);
	end
end

local function tab_drag(ctx, vid, dx, dy)
-- only used when cursor is at edges
	mouse_switch_cursor("drag");
	nudge_image(ctx.wnd.anchor, dx, dy);
	update_drag_hint(ctx, vid);
end

local function tab_drop(ctx)
	if (valid_vid(ctx.drag_hint)) then
		delete_image(ctx.drag_hint);
		ctx.drag_hint = nil;
	end
	mouse_switch_cursor("grabhint");
	local dir = get_maximize_dir();
	if (dir) then
		ctx.wnd:maximize(dir);
	end
end

local function wnd_is_tab(ctx, vid)
	return ctx.wnd.tabs[vid] ~= nil;
end

local function tab_sel(wnd, tab)
	if (wnd.dead) then
--		print(debug.traceback());
		return;
	end

-- send hide event
	if (wnd.active_tab and valid_vid(
		wnd.active_tab.source, TYPE_FRAMESERVER)) then
		target_displayhint(wnd.active_tab.source, 0, 0, TD_HINT_INVISIBLE);
	end

	wnd.active_tab = tab;

-- Copy all the tab properties over to the outer window, this is really
-- poorly done and the window/content,target separation should have been
-- set from the start. Now it's not easy.
	wnd.aid = tab.source_audio;
	wnd.inertia = tab.inertia;
	wnd.autocrop = tab.autocrop;
	wnd.shader = tab.shader;
	wnd.force_size = tab.force_size;
	wnd.flip_y = tab.flip_y;
	wnd.clipboard_in = tab.clipboard_in;
	wnd.clipboard_out = tab.clipboard_out;
	wnd.mouse_cursor = tab.mouse_cursor;
	wnd.mouse_hidden = tab.mouse_hidden;

	image_shader(wnd.canvas, shader_get(tab.shader));

-- send show event
	if (valid_vid(tab.source, TYPE_FRAMESERVER)) then
		wnd.target = tab.source;
		target_displayhint(wnd.target, 0, 0, 0);
		image_sharestorage(tab.source, wnd.canvas);
	end

	window_update_tprops(wnd);
	window_decor_tab_layout(wnd);
end

local function run_tab(ctx, vid, ind)
	local wnd = ctx.wnd;
	local tab = wnd.tabs[vid];

	tab_drop_preview(ctx);

	if (not wnd:select()) then
		return;
	end

	if (tab and tab ~= wnd.active_tab) then
		tab_sel(wnd, tab);
	end

	if (tab.handler) then
		tab.handler(wnd, tab, ind);
	end
end

local function tab_click(ctx, vid)
	run_tab(ctx, vid, MOUSE_LBUTTON);
end

local function tab_rclick(ctx, vid)
	run_tab(ctx, vid, MOUSE_RBUTTON);
end

local function tab_button(ctx, vid, ind, act)
	mouse_switch_cursor(act and "drag" or "grabhint");
end

local function tab_dblclick(ctx, vid)
	ctx.wnd:maximize("f");
end

local function decor_sel(ctx)
	ctx.wnd:select();
end

local function decor_reset()
	mouse_switch_cursor();
end

local function tab_hover(ctx, vid, x, y, act)
	local tab = ctx.wnd.tabs[vid];

	if (ctx.preview) then
		tab_drop_preview(ctx);
	end

	if (not act or ctx.wnd ~= priowin or ctx.wnd.active_tab == tab) then
		return;
	end

-- build preview surface and attach to mouse cursor,
-- resize to a readable size, wait then grow to source size
	local cvid = mouse_state().cursor;
	local props = image_storage_properties(tab.source);
	local base = prio_windows_iconsize();
	ctx.preview = null_surface(2, 2);
	if (not valid_vid(ctx.preview)) then
		return;
	end
	image_sharestorage(tab.source, ctx.preview);
	show_image(ctx.preview);
	image_mask_set(ctx.preview, MASK_UNPICKABLE);
	link_image(ctx.preview, cvid);
	resize_image(ctx.preview, base, base, priocfg.animation_speed);
	resize_image(ctx.preview, base, base, priocfg.animation_speed*2);
	resize_image(ctx.preview,
		props.width, props.height, priocfg.animation_speed*4);
	image_inherit_order(ctx.preview, true);
	props = image_surface_resolve(cvid);
	move_image(ctx.preview, props.width, props.height);
	order_image(ctx.preview, 1);
end

local function tab_over(ctx, vid)
	mouse_switch_cursor("grabhint");
	tab_drop_preview(ctx);
end

local function tab_out(ctx, vid)
	mouse_switch_cursor();
	tab_drop_preview(ctx);
end

-- build the decorations: tttt
--                        l  r
--                        bbbb and anchor for easier resize
--
-- for fancier things like rounded corners and directional shadows,
-- build and attach a shader to the decor
local function build_decorations(wnd, opts)
	local bw = priocfg.border_width;
	for k,v in ipairs(dirtbl) do
		wnd.decor[v] = color_surface(1, 1, 0, 0, 0);
		image_inherit_order(wnd.decor[v], true);
		blend_image(wnd.decor[v], priocfg.border_alpha);
		image_shader(wnd.decor[v], shader_get("decor_" .. v));
		wnd.margin[v] = bw;
	end

	link_image(wnd.decor.r, wnd.anchor, ANCHOR_UR);
	link_image(wnd.decor.l, wnd.anchor, ANCHOR_UL);
	link_image(wnd.decor.b, wnd.anchor, ANCHOR_LL);
	link_image(wnd.decor.t, wnd.anchor);

	if (not opts.no_mouse) then
		wnd.decor_mh.r = { wnd = wnd, name = "decor_r", own = wnd.decor.r,
			ul_near = false, motion = decor_v_over, drag = decor_v_drag,
			click = decor_sel, rclick = prio_menu, drop = decor_drop,
			out = decor_reset
		};
		wnd.decor_mh.t = { wnd = wnd, name = "decor_t", own = wnd.decor.t,
			ul_near = true, motion = decor_h_over, drag = decor_h_drag,
			click = decor_sel, rclick = prio_menu, out = decor_reset,
			out = decor_reset, drop = decor_drop
		};
		wnd.decor_mh.l = { wnd = wnd, name = "decor_l", own = wnd.decor.l,
			ul_near = true, motion = decor_v_over, drag = decor_v_drag,
			click = decor_sel, rclick = prio_menu, out = decor_reset,
			out = decor_reset, drop = decor_drop
		};
		wnd.decor_mh.b = { wnd = wnd, name = "decor_b", own = wnd.decor.b,
			ul_near = false, motion = decor_h_over, drag = decor_h_drag,
			click = decor_sel, rclick = prio_menu, drop = decor_drop,
			out = decor_reset
		};

		for k,v in ipairs(dirtbl) do
			mouse_addlistener(wnd.decor_mh[v], {"drag",
				"click", "rclick", "drop", "motion", "out"});
		end

		if (not wnd.tab_block) then
			wnd.tabs_mh = {
				wnd = wnd, name = "wnd_tabs", own = wnd_is_tab,
				drag = tab_drag, drop = tab_drop,
				click = tab_click, rclick = tab_rclick, button = tab_button,
				over = tab_over, out = tab_out, hover = tab_hover,
				dblclick = tab_dblclick
			};
			mouse_addlistener(wnd.tabs_mh,
				{"drag", "drop", "over", "out", "hover",
					"button", "click", "rclick", "dblclick"});
		end
	end

	if (opts.effect_hook) then
		opts.effect_hook(wnd);
	elseif (priocfg.effect_hook) then
		priocfg.effect_hook(wnd);
	end

	window_decor_resize(wnd, wnd.width, wnd.height);
end

local function window_resize(wnd, neww, newh, nofwd)
	local pad_v = wnd.margin.t - wnd.margin.b;
	local pad_h = wnd.margin.l - wnd.margin.r;
	neww = (neww > VRESW - pad_h) and (VRESW - pad_h) or neww;
	newh = (newh > VRESH - pad_v) and (VRESH - pad_v) or newh;

	resize_image(wnd.canvas, neww, newh);
	resize_image(wnd.anchor, neww, newh);
	window_decor_resize(wnd, neww, newh);

	if ((neww ~= wnd.width or newh ~= wnd.height)
		and not nofwd and valid_vid(wnd.target, TYPE_FRAMESERVER)) then
		target_displayhint(wnd.target, neww, newh);
	end

	if (wnd.defer_x) then
		move_image(wnd.anchor, wnd.defer_x, wnd.defer_y);
		if (wnd.drag_track and valid_vid(wnd.drag_track.vid)) then
			local props = image_surface_resolve_properties(wnd.drag_track.vid);
			wnd.drag_track.start_x = props.x + props.width * wnd.drag_track.rel_x;
			wnd.drag_track.start_y = props.y + props.height * wnd.drag_track.rel_y;
		end
		wnd.defer_x = nil;
	end

	if (wnd.autocrop) then
		local ip = image_storage_properties(wnd.canvas);
		image_set_txcos_default(wnd.canvas, wnd.origio_ll);
		image_scale_txcos(wnd.canvas, neww / ip.width, newh / ip.height);
	end

	wnd.width = neww;
	wnd.height = newh;

	for k,v in ipairs(wnd.event_hooks) do
		v(wnd, "resize");
	end
end

local function find_nearest(bp_x, bp_y, dir)
	local lst = {};
	for k,v in pairs(priowindows) do
		local props = image_surface_resolve_properties(v.canvas);
		local cx = bp_x - (props.x + 0.5 * props.width);
		local cy = bp_y - (props.y + 0.5 * props.height);
		local dist;
		if (dir) then
			if (dir == "t" and cy > 0) then
				table.insert(lst, {wnd = v, dist = cy});
			elseif (dir == "l" and cx > 0) then
				table.insert(lst, {wnd = v, dist = cx});
			elseif (dir == "r" and cx < 0) then
				table.insert(lst, {wnd = v, dist = -cx});
			elseif (dir == "b" and cy < 0) then
				table.insert(lst, {wnd = v, dist = -cy});
			end
		else
			local dist = math.sqrt(cx * cx + cy * cy);
			table.insert(lst, {wnd = v, dist = dist});
		end
	end

	for i=#lst,1,-1 do
		if (lst[i].wnd.select_block) then
			table.remove(lst, i);
		end
	end

	table.sort(lst, function(a, b) return a.dist < b.dist; end);
	return lst;
end

function prio_sel_nearest(wnd, dir)
	local props = image_surface_resolve_properties(wnd.canvas);
	local lst = find_nearest(props.x + props.width * 0.5,
		props.y + props.height * 0.5, dir);
	if (lst[1]) then
		lst[1].wnd:select();
	end
end

function prio_menu_spawn(list, x, y, ctx)
-- populate a table of the labels to draw
	if (priostate) then
		priostate();
	end

	if (priomenu) then
		priomenu:destroy();
	end

	local labels = {
		priocfg.menu_fontstr
	};
	if (#list == 0) then
		return;
	end

	local rlist = {};

-- dynamic label evaluation, ignore items that are used only for keybinds.
	for k,v in ipairs(list) do
		label = v.label;
		if (type(v.label) == "function") then
			label = v.label(ctx);
		end
		if ((not v.eval or v.eval()) and not v.hidden and
			type(label) == "string" and string.len(label) > 0) then
			table.insert(rlist, v);
			table.insert(labels, label);
			table.insert(labels, [[\n\r]]);
		end
	end

-- this version of render text only treats odd (1- ind.) indices
-- as valid format strings and others as data, so no further escaping
	local vid, lineheights = render_text(labels);
	if (not valid_vid(vid)) then
		warning("couldn't render menu text");
		return;
	end

	local bw = priocfg.menu_border_width;
	local props = image_surface_properties(vid);
	local w = props.width;
	local h = props.height;

-- create background with added spacing for the border
	local csurf = fill_surface(w + 2*bw, h + 2*bw,
		unpack(priocfg.menu_background_color));
	link_image(vid, csurf);
	image_inherit_order(vid, true);
	order_image(vid, 2);
	move_image(vid, bw, bw);
	show_image(vid);
	image_mask_set(vid, MASK_UNPICKABLE);

-- cursor to indiciate selection
	local cursor = fill_surface(
		w+2*bw, lineheights[2], unpack(priocfg.menu_select_color));
	move_image(cursor, -bw, -bw);
	blend_image(cursor, priocfg.menu_select_alpha);
	link_image(cursor, vid);
	image_inherit_order(cursor, true);
	order_image(cursor, -1);
	image_mask_set(cursor, MASK_UNPICKABLE);

	local fullw = w + 2 * bw;
	local fullh = h + 2 * bw;

	if (x + w >= VRESW) then
		x = VRESW - w;
	end

	if (x < 0) then
		x = 0;
	end

	if (y + h >= VRESH) then
		y = VRESH - h;
	end

	if (y < 0) then
		y = 0;
	end

-- reuse the window drawing code but disable resizing and tabs
	local wnd = prio_new_window(csurf, BADID, {
		tab_block = true, x = x, y = y, w = w+2*bw, h = h+2*bw, no_mouse = true});

-- motion and click handler that manage the cursor
	wnd:border_color(unpack(priocfg.menu_border_color));

	local index = 1;
-- different mouse handler that updates cursor and activates selection
	wnd.motion = function(wnd, id, mx, my)
		local rely = my - y;
		for i=1,#lineheights-1 do
			if (rely >= lineheights[i]) then
				index = i;
			end
		end
		move_image(cursor, -bw, -bw + lineheights[index]);
	end
	local olddest = wnd.destroy;
	wnd.destroy = function() olddest(wnd); priomenu = nil; end
	wnd.rclick = function() wnd:destroy(); end
	wnd.click = function()
		if (not wnd.delete_protect) then
			wnd:destroy();
		end

		if (rlist[index].handler) then
			rlist[index].handler(ctx);
		end
	end
	mouse_addlistener(wnd, {"motion", "click", "rclick"});
	priomenu = wnd;
	order_image(wnd.anchor, 65530);
end

local function window_select(wnd)
	if (priostate and priostate(wnd)) then
		return;
	end

	cancel_menu();

	if (priowin) then
		if (priowin ~= wnd) then
			priowin:deselect();
		else
			return true;
		end
	end

	local oldi;
	for i,v in ipairs(wndlist) do
		if (v == wnd) then
			oldi = i;
			table.remove(wndlist, i);
			break;
		end
	end
	table.insert(wndlist, wnd);

	priowin = wnd;
	if (valid_vid(wnd.target)) then
		wnd.dispmask = (bit.band(wnd.dispmask, bit.bnot(TD_HINT_UNFOCUSED)));
		target_displayhint(wnd.target, 0, 0, wnd.dispmask);
	end
	wnd:border_color(unpack(priocfg.active_color));
	reorder_windows();

	for k,v in ipairs(wnd.event_hooks) do
		v(wnd, "select", oldi);
	end
	return true;
end

local function window_deselect(wnd)
	if (valid_vid(wnd.target)) then
		wnd.dispmask = bit.bor(wnd.dispmask, TD_HINT_UNFOCUSED);
		target_displayhint(wnd.target, 0, 0, wnd.dispmask);
	end
	wnd:border_color(unpack(priocfg.inactive_color));
	if (priowin == wnd) then
		priowin = nil;
	end

	for k,v in ipairs(wnd.event_hooks) do
		v(wnd, "deselect");
	end
end

local function window_lost(wnd, source)
-- last tab, drop windows
	if (#wnd.tab_slots <= 1) then
		wnd:destroy();
		return;
	end

	dst = wnd.tab_source[source];
	assert(dst);

-- clean up resources
	wnd.tabs[dst.vid] = nil;
	wnd.tab_source[source] = nil;
	table.remove(wnd.tab_slots, dst.ind);
	delete_image(dst.vid);

-- reindex, update decorations and labels
	for i=1,#wnd.tab_slots do
		wnd.tab_slots[i].ind = i;
	end

-- pick a new active tab if we have to
	if (not wnd.active_tab == dst) then
		return;
	end

	local ind = dst.ind;
	for i=1,10 do
		ind = ind + 1;
		if (ind > 10) then
			ind = 1;
		end
		if (wnd.tab_slots[ind] ~= nil) then
			tab_sel(wnd, wnd.tab_slots[ind]);
			return;
		end
	end
end

local function window_hide(wnd)
	if (wnd.delete_protect) then
		return;
	end

	wnd:deselect();
	hide_image(wnd.anchor);
	for k,v in ipairs(wnd.event_hooks) do
		v(wnd, "hide");
	end

	table.insert(priohidden, wnd);
	priohidden[wnd] = true;
end

local function window_show(wnd)
	for k,v in ipairs(priohidden) do
		if (v == wnd) then
			wnd:select();
			table.remove(priohidden, k);
			priohidden[wnd] = nil;
			show_image(wnd.anchor);
			for k,v in ipairs(wnd.event_hooks) do
				v(wnd, "show");
			end
			return;
		end
	end
end

local function window_destroy(wnd)
	local cp = image_surface_resolve_properties(wnd.canvas);
	if (priowin == wnd) then
		priowin = nil;
	end

	local mx,my = mouse_xy();
	if (image_hit(wnd.canvas, mx, my)) then
		mouse_switch_cursor();
		mouse_show();
	end

-- drop global tracking
	for i=#wndlist,1,-1 do
		if (wndlist[i] == wnd) then
			table.remove(wndlist, i);
		end
	end

	for k,v in pairs(priowindows) do
		if (v == wnd) then
			priowindows[k] = nil;
		end
	end

-- might come from an event on a hidden window
	for k,v in ipairs(priohidden) do
		if (v == wnd) then
			table.remove(priohidden, k);
			priohidden[wnd] = nil;
			break;
		end
	end

-- remove mouse handlers
	for k,v in pairs(wnd.decor_mh) do
		mouse_droplistener(v);
	end
	if (wnd.tabs_mh) then
		mouse_droplistener(wnd.tabs_mh);
	end
	mouse_droplistener(wnd);

	for k,v in ipairs(wnd.event_hooks) do
		v(wnd, "destroy");
	end

-- anchor will just cascade delete everything like tabs etc.
	delete_image(wnd.anchor);

-- but reset the table to identify any dangling refs.
	for k,v in pairs(wnd) do
		wnd[k] = nil;
	end
	wnd.dead = true;

-- find something else to select
	if (not priowin) then
		find_nearest(cp.x + 0.5 * cp.width, cp.y + 0.5 * cp.y, 1, 1);
	end
end

local function window_move(wnd, x, y)
	move_image(wnd.anchor, x, y);
end

local function window_maximize(wnd, dir)
-- revert
	if (wnd.maximized) then
		wnd:move(wnd.maximized.x, wnd.maximized.y);
		wnd:resize(wnd.maximized.w, wnd.maximized.h);
		wnd.maximized = nil;
		return;
	end

-- let move/resize account for decorations
	local props = image_surface_resolve_properties(wnd.anchor);
	wnd.maximized = {
		x = props.x, y = props.y,
		w = wnd.width, h = wnd.height
	};
	local pad_w = wnd.margin.l + wnd.margin.r;
	local pad_h = wnd.margin.t + wnd.margin.b;
	if (dir == "f") then
		wnd:resize(VRESW - pad_w, VRESH - pad_h);
		wnd:move(wnd.margin.l, wnd.margin.t);
	elseif (dir == "l") then
		wnd:move(wnd.margin.l, wnd.margin.t);
		wnd:resize(math.floor((0.5 * VRESW) - pad_w), VRESH - pad_h);
	elseif (dir == "r") then
		wnd:resize(math.floor((0.5 * VRESW) - pad_w), VRESH - pad_h);
		wnd:move(math.ceil(VRESW * 0.5)+ wnd.margin.l, wnd.margin.t);
	elseif (dir == "t") then
		wnd:move(wnd.margin.l, wnd.margin.t);
		wnd:resize(VRESW - pad_w, math.floor((0.5 * VRESH) - pad_h));
	elseif (dir == "b") then
		wnd:resize(VRESW - pad_w, math.floor((0.5 * VRESH) - pad_h));
		wnd:move(wnd.margin.l, math.ceil(VRESH * 0.5) + wnd.margin.t);
	end
end

local function step_sz(wnd)
	local ssx = wnd.inertia and wnd.inertia[1] or priocfg.drag_resize_inertia;
	local ssy = wnd.inertia and wnd.inertia[2] or priocfg.drag_resize_inertia;
	return ssx, ssy;
end

local function window_step_move(wnd, steps, xd, yd)
	local sx, sy = step_sz(wnd);
	nudge_image(wnd.anchor, xd * sx, yd * sy);
end

local function window_step_sz(wnd, steps, xd, yd)
	local sx, sy = step_sz(wnd);
	local neww = wnd.width + steps * sx * xd;
	local newh = wnd.height + steps * sy * yd;
	wnd:resize(neww, newh);
end

local function window_mousemotion(ctx, vid, x, y)
	local outm = {
		kind = "analog",
		mouse = true,
		relative = false,
		devid = 0,
		subid = 0,
		samples = {0}
	};
	if (not valid_vid(ctx.target, TYPE_FRAMESERVER)) then
		return;
	end

	local props = image_surface_resolve_properties(ctx.anchor);
	outm.samples[1] = x - props.x;

-- relative or absolute? for absolute, we need to scale
	target_input(ctx.target, outm);
	outm.samples[1] = y - props.y;
	outm.subid = 1;
	target_input(ctx.target, outm);
end

local function window_mousebutton(ctx, devid, ind, act)
-- trick to avoid spurious "release" events being forwarded
	if (ctx == priowin) then
		if (priowin.tab_cooldown) then
			priowin.tab_cooldown = nil;
			return;
		end
	else
		if (act) then
			ctx:select();
		end
		return;
	end

	if (priostate and priostate(ctx)) then
		return;
	end

	if (ctx.mouse_btns and ctx.mouse_btns[ind] ~= act) then
		ctx.mouse_btns[ind] = act;
		if (valid_vid(ctx.target, TYPE_FRAMESERVER)) then
			target_input(ctx.target, {digital = true, mouse = true,
				devid = 0, subid = ind, active = act});
		end
	end
end


local function window_mouseover(ctx)
	if (ctx.mouse_cursor) then
		mouse_custom_cursor(ctx.mouse_cursor);
	elseif (ctx.mouse_hidden) then
		mouse_hide();
	else
		mouse_switch_cursor();
	end
end

local function window_mouseout(ctx)
	mouse_show();
	mouse_switch_cursor();

	if (not valid_vid(ctx.target, TYPE_FRAMESERVER)) then
		return;
	end

-- release any buttons that are held
	for i,v in pairs(ctx.mouse_btns) do
		if (v) then
			ctx.mouse_btns[i] = false;
			target_input(ctx.target,
				{digital = true, mouse = true, devid = 0, subid = i, active = false});
		end
	end
end

local function def_tabh(wnd, tab, btn)
	assert(valid_vid(tab.source));
	if (btn == MOUSE_RBUTTON) then
		tab_menu(wnd, tab);
	end
end

local function window_tab_set(wnd, ind)
	if (wnd.tab_block) then
		return;
	end

-- special case, relative
	if (ind == -1 or ind == -2) then
		local step = ind == -2 and 1 or -1;
		local dind = wnd.active_tab.ind;
		for i=1,10 do
			dind = dind + step;
			dind = dind < 0 and 10 or (dind > 10 and 1 or dind);
			if (wnd.tab_slots[dind]) then
				tab_sel(wnd, wnd.tab_slots[dind]);
				return;
			end
		end
	else
-- specific index
		if (wnd.tab_slots[ind]) then
			tab_sel(wnd, wnd.tab_slots[ind]);
		end
	end
end

--
-- Return an iterator for iterating windows, windows-with-external
-- connection and/or window+tabs
--
function prio_iter_windows(external, with_tabs)
	local ctx = {};

	for k,v in pairs(priowindows) do
		if (not external or valid_vid(v.target, TYPE_FRAMESERVER)) then
			table.insert(ctx, k, v);
		end

		if (with_tabs) then
			for i=1,10 do
				if (v.tab_slots[i] ~= nil and (not external or
					valid_vid(v.tab_slots[i].source, TYPE_FRAMESERVER))) then
					table.insert(ctx, v.tab_slots[i].source);
				end
			end
		end

	end

	local i = 0;
	local c = #ctx;
	return function()
		i = i + 1;
		return ctx[i];
	end
end

local function window_tab_add(wnd, source, callback, opts)
	local ind = 0;
	if (wnd.tab_block) then
		return;
	end

	for i=1,10 do
		if (wnd.tab_slots[i] == nil) then
			ind = i;
			break;
		end
	end
	if (ind == 0) then
		return;
	end

	local new = {
		vid = color_surface(32, 32, 0, 0, 0),
		ind = ind,
		source = valid_vid(source) and source or null_surface(1, 1),
		handler = callback and callback or def_tabh
	};
	if (new.vid == BADID) then
		return;
	end

	if (new.source == BADID) then
		delete_image(new.vid);
		return;
	end

	image_shader(new.vid, shader_get("tab"));

-- just take some number, we want the dimensions, relayout will
-- fix positioning and color settings
	new.label = render_text(priocfg.tab_fontstr .. tostring(ind));
	if (not valid_vid(new.label)) then
		delete_image(new.vid);
		return;
	end

-- position / link as normal
	local props = image_storage_properties(new.label);
	new.label_w = props.width;
	if (props.height > wnd.tab_labelh) then
		wnd.tab_labelh = props.height;
	end
	link_image(new.label, new.vid);
	image_inherit_order(new.label, true);
	image_inherit_order(new.vid, true);
	order_image(new.vid, 1);
	order_image(new.label, 1);
	image_mask_set(new.label, MASK_UNPICKABLE);
	link_image(new.vid, wnd.decor.t);
	link_image(new.source, new.vid); -- for autodeletion
	show_image({new.vid, new.label});
	wnd.tabs[new.vid] = new;
	wnd.tab_slots[ind] = new;
	wnd.tab_source[new.source] = new;
	wnd.margin.t = priocfg.border_width + wnd.tab_labelh;

	if (not wnd.active_tab) then
		wnd.active_tab = new;
	else
		synch_tab_sizes(wnd);
	end

-- project shared options
	if (opts) then
		new.force_size = opts.force_size;
		new.autocrop = opts.autocrop;
		new.shader = opts.shader;
		new.flip_y = opts.flip_y;
		new.inactive_color = opts.inactive_color;
		new.active_color = opts.active_color;
		new.mouse_hidden = opts.mouse_hidden;
	end

	window_decor_resize(wnd, wnd.width, wnd.height);
	tab_sel(wnd, new);

	for k,v in ipairs(wnd.event_hooks) do
		v(wnd, "tab_added", new);
	end

	return new;
end

local function window_paste(wnd, msg)
	if (not wnd.clipboard_out) then
		if (not valid_vid(wnd.target, TYPE_FRAMESERVER)) then
			return;
		end
		local tgt_clip = define_nulltarget(wnd.target,
		function()
		end);
		if (not valid_vid(tgt_clip)) then
			return;
		end

		wnd.clipboard_out = tgt_clip;
		if (wnd.active_tab) then
			wnd.active_tab.clipboard_out = tgt_clip;
			link_image(tgt_clip, wnd.active_tab.vid);
		else
			link_image(wnd.clipboard_out, wnd.anchor);
		end
	end

-- slightly incorrect as target_input can come up short, the
-- real option is to have a background timer and continously flush
	if (msg and string.len(msg) > 0) then
		target_input(wnd.clipboard_out, msg);
	end
end

function prio_new_window(vid, aid, opts)
	assert(opts and opts.x and opts.y and opts.w and opts.h);

-- create anchor to track and control position and ordering
	local anchor = null_surface(opts.w, opts.h);
	if (not valid_vid(anchor)) then
		return;
	end

	blend_image(anchor, 1.0, priocfg.animation_speed);
	move_image(anchor, opts.x, opts.y);
	link_image(vid, anchor);
	image_inherit_order(vid, true);
	image_mask_set(anchor, MASK_UNPICKABLE);

-- fade in and resize
	show_image(vid);
	resize_image(vid, opts.w, opts.h);

	local wnd = {
		name = "prio_window",
		anchor = anchor,
		canvas = vid,
		aid = aid,
		min_w = 32, -- controlled by the amount of tabs
		min_h = 32,
		width = opts.w,
		height = opts.h,
		created = CLOCK,
		dispmask = 0, -- tracking display state
		event_hooks = {},

-- decorations
		decor = {},
		decor_mh = {},
		margin = {t = 0, l = 0, r = 0, b = 0},

-- tab management
		tabs = {},
		tab_source = {},
		tab_slots = {},
		tab_labelh = 0,

-- input controls
		mscale = {},
		own = vid,
		mouse_btns = {},

-- table methods, normal window maipulation
		resize = window_resize,
		move = window_move,
		select = window_select,
		deselect = window_deselect,
		destroy = window_destroy,
		hide = window_hide,
		show = window_show,
		lost = window_lost,
		border_color = window_bordercolor,
		add_tab = window_tab_add,
		set_tab = window_tab_set,
		step_move = window_step_move,
		step_sz = window_step_sz,
		motion = window_mousemotion,
		button = window_mousebutton,
		over = window_mouseover,
		out = window_mouseout,
		maximize = window_maximize,
		synch_tab_sizes = synch_tab_sizes,
		update_tprops = window_update_tprops,
		paste = window_paste,
		display_changed = window_dispchg,

-- projectable toggles
		delete_protect = opts.delete_protect,
		tab_block = opts.tab_block,
		select_block = opts.select_block,

-- per tab toggles
		force_size = opts.force_size,
		autocrop = opts.autocrop,
		shader = opts.shader,
		flip_y = opts.flip_y
	};

	if (not opts.no_decor) then
		build_decorations(wnd, opts);
	end

	if (not opts.no_mouse) then
		mouse_addlistener(wnd, {"motion", "button", "over", "out"});
	end

-- special treatment, vid might be a color target (popups, ...)
	if (valid_vid(vid, TYPE_FRAMESERVER)) then
		local canvas = null_surface(opts.w, opts.h);
		link_image(canvas, wnd.anchor);
		image_inherit_order(canvas, true);
		show_image(canvas);
		image_sharestorage(vid, canvas);
		order_image(canvas, 1);
		wnd.own = canvas;
		wnd.canvas = canvas;
		wnd.target = vid;
	end

	table.insert(wndlist, wnd);

-- index by supplied vid for event handlers
	priowindows[vid] = wnd;
	return wnd, wnd:add_tab(vid, nil, opts);
end
