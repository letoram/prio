-- just some tunables for visual effect
local swap_speed = priocfg.animation_speed;
local max_shadow_offset = 20;
local shadow_strength = 0.2;
local icon_strength = 0.6;
local rm_speed = priocfg.animation_speed * 4;
local rh_speed = priocfg.animation_speed;
local hidereg = {0, 0, 1, 1};

local function intersect(x1, y1, x2, y2, x3, y3, x4, y4)
	if (not (x1 < x4 and x2 > x3 and y1 < y4 and y2 > y3)) then
		return;
	end

	local x5 = x1 > x3 and x1 or x3;
	local y5 = y1 > y3 and y1 or y3;
	local x6 = x2 < x4 and x2 or x4;
	local y6 = y2 < y4 and y2 or y4;
	return x5, y5, x6, y6;
end

local function swap_wnd(w1, w2, oldi)
-- don't swap on creation
	if (w1.created == CLOCK) then
		return;
	end

-- cancel pending animations
--	instant_image_transform(w1.anchor);
--	instant_image_transform(w2.anchor);

-- resolve world-space positions and orientations
	local p1 = image_surface_resolve(w1.canvas);
	local x1 = p1.x;
	local x2 = p1.x + w1.width;
	local y1 = p1.y;
	local y2 = p1.y + w1.height;

-- find the shared area of intersecting windows with higher order
	local lst = {};
	local wlist = prio_windows_linear();
	local x5 = VRESW;
	local x6 = 0;
	local y5 = VRESH;
	local y6 = 0;

	for i=oldi, #wlist-1 do
		local props = image_surface_resolve(wlist[i].canvas);
		local px1 = props.x + props.width;
		local py1 = props.y + props.height;
		if (intersect(x1, y1, x2, y2, props.x, props.y, px1, py1)) then
			x5 = x5 > props.x and props.x or x5;
			x6 = x6 < px1 and px1 or x6;
			y5 = y5 > props.y and props.y or y5;
			y6 = y6 < py1 and py1 or y6;
		end
	end

-- if one is found, then calculate the intersection
	if (x5 > x6) then
		return;
	end
	x5, y5, x6, y6 = intersect(x1, y1, x2, y2, x5, y5, x6, y6);
	if (not x5) then
		return;
	end

-- revert- the ordering temporarily, and switch 'half-way'
	order_image(w1.anchor, (oldi+1) * 10 - 10);
	order_image(w2.anchor, (#wlist+1) * 10);

-- pick direction based on intersection width/height and position
	local cp1_x = x5 + (x6 - x5) * 0.5;
	local cp1_y = y5 + (y6 - y5) * 0.5;
	local cp2_x = x1 + (x2 - x1) * 0.5;
	local cp2_y = y1 + (y2 - y1) * 0.5;

-- pick axis based on centerpoint distance
	local speed = 0.5 * swap_speed;
	if (math.abs(cp1_x - cp2_x) > math.abs(cp1_y - cp2_y)) then
		local sign = (cp2_x - cp1_x) < 0 and -1 or 1;
		local w = sign * (x6 - x5);
		move_image(w1.anchor, x1 + w, y1, speed);
	else
		local sign = (cp2_y - cp1_y) < 0 and -1 or 1;
		local h = sign * (y6 - y5);
-- compensate for decoration in positive y direction
		if (sign == 1) then
			if (w1.tabs) then
				h = h + w1.tab_labelh + priocfg.border_width;
			end
		else
			if (w2.tabs) then
				h = h - w2.tab_labelh - priocfg.border_width;
			end
		end
		move_image(w1.anchor, x1, y1 + h, speed);
	end

-- flip the order "half-way", which will align with shadow animations
	tag_image_transform(w1.anchor, MASK_POSITION,
		function()
			order_image(w1.anchor, (#wlist+1) * 10);
			order_image(w2.anchor, (#wlist  ) * 10);
		end);
	move_image(w1.anchor, x1, y1, speed);
end

local function falling(vid, speed, cx, cy, cw, ch, ox, oy, sx, sy, sw, sh)
	local rx = ox - cx;
	local ry = oy - cy;
	local dist = 0.00001 + math.sqrt(rx*rx+ry*ry);

	local mx = sw - ox;
	local my = sw - oy;
	local maxdist = 0.00001 + math.sqrt(sw * sw + sh * sh);

-- initial delay is proportional to the distance from the epicentrum
-- manipulating these transformations and delays really defines the
-- effect, be creative :)
	local fact = dist / maxdist;
	local delay = fact * (0.5 * speed);
	move_image(vid, cx, cy, delay);
	resize_image(vid, cw, ch, delay);
	rotate_image(vid, 0, delay + delay * 0.1);
	blend_image(vid, 1.0, delay);

	local ifun = INTERP_EXPOUT;
-- have each piece travel the same distance so the speed will match
	move_image(vid, cx+8, cy+8, speed, ifun);
	resize_image(vid, 16, 16, speed, ifun);
	rotate_image(vid, math.random(359), speed, ifun);
	blend_image(vid, 0.0, speed, ifun);
end

local function animate_destroy(wnd, evalf)

-- split into cells based on window size
	local props = image_surface_resolve(wnd.canvas);
	local sf_s = wnd.width < 100 and 0.5 or 0.1;
	local sf_t = wnd.height < 100 and 0.5 or 0.1;
	local tile_sz_w = math.floor(wnd.width * sf_s);
	local tile_sz_h = math.floor(wnd.height * sf_t);

	local ct = 0;
	local cp_x = props.x + 0.5 * wnd.width;
	local cp_y = props.y + 0.5 * wnd.height;
	local ul_r = math.ceil(wnd.height / tile_sz_h) - 1;
	local ul_c = math.ceil(wnd.width / tile_sz_w) - 1;

	for row=1,ul_r do
		local cs = 0;
		for col=1,ul_c do

-- skip if we run out of VIDs
			local cell = null_surface(tile_sz_w, tile_sz_h);
			if (not valid_vid(cell)) then
				return;
			end
			image_mask_set(cell, MASK_UNPICKABLE);
			local cx = props.x + (col-1) * tile_sz_w;
			local cy = props.y + (row-1) * tile_sz_h;

-- reference the storage and tune the texture coordinates
			image_sharestorage(wnd.canvas, cell);
			move_image(cell, cx, cy);
			show_image(cell);
			order_image(cell, props.order);

-- slice the texture coordinates
			image_set_txcos(cell, {
				cs, ct,
				cs + sf_s, ct,
				cs + sf_s, ct + sf_t,
				cs, ct + sf_t
			});
			cs = cs + sf_s;

-- clamp to surface
			local origin_x, origin_y = mouse_hotxy();
			origin_x = origin_x < props.x and props.x or origin_x;
			origin_x = origin_x > (props.x + props.width) and (props.x + props.width) or origin_x;
			origin_y = origin_y < props.y and props.y or origin_y;
			origin_y = origin_y > (props.y + props.height) and (props.y + props.height) or origin_y;

-- initial delay/velocity/speed
			evalf(cell, rm_speed, cx, cy, tile_sz_w, tile_sz_h,
				origin_x, origin_y, props.x, props.y, props.width, props.height);

-- automatic cleanup
			expire_image(cell, rm_speed);
		end

		ct = ct + sf_t;
	end
end

local function find_icon_xy(wnd, base)
	if (not wnd.icon_xy) then
		local sx = hidereg[1] * VRESW;
		local sy = hidereg[2] * VRESH;
		local ex = hidereg[3] * VRESW;
		local ey = hidereg[4] * VRESH;
		local cx = sx;
		local cy = sy;
		local step_x = VRESW / (1.1 * base);
		local step_y = VRESH / (1.1 * base);
		while (cy < ey) do
			local lst = pick_items(cx, cy);
			local found = false;
			for i,v in ipairs(lst) do
				if (image_tracetag(v) == "icon") then
					found = true;
					break;
				end
			end
			if (not found) then
				return cx, cy;
			end
			cx = cx + step_x;
			if (cx >= ex) then
				cx = sx;
				cy = cy + step_y;
			end
		end
		return math.random(sx, ex), math.random(sy, ey);
	else
		return wnd.icon_xy[1], wnd.icon_xy[2];
	end
end

local function show_from_icon(wnd)
	nudge_image(wnd.anchor, 0, 0, 2 * rh_speed);
	move_image(wnd.anchor,
		wnd.last_xy[3], wnd.last_xy[4], rh_speed, INTERP_EXPOUT);
	move_image(wnd.anchor,
		wnd.last_xy[1], wnd.last_xy[2], rh_speed, INTERP_EXPOUT);
	resize_image(wnd.desktop_icon,
		0.5 * wnd.width, 0.5 * wnd.height, 2 * rh_speed, INTERP_EXPIN);
	move_image(wnd.desktop_icon,
		wnd.last_xy[3], wnd.last_xy[4], 2 * rh_speed, INTERP_EXPIN);
	expire_image(wnd.desktop_icon, 2 * rh_speed, INTERP_EXPOUT);
	mouse_droplistener(wnd.icon_mh);
	wnd.desktop_icon = nil;
end

local function hide_to_icon(wnd)
	show_image(wnd.anchor);
	local props = image_surface_resolve(wnd.anchor);
-- find the shortest escape axis/dir
	local hw = 0.5*VRESW;
	local hh = 0.5*VRESH;
	local cx = props.x + 0.5*wnd.width;
	local cy = props.y + 0.5*wnd.height;
	local dx = cx > hw and VRESW-cx or cx;
	local dy = cy > hh and VRESH-cy or cy;

	wnd.last_xy = {props.x, props.y};
	if (dx < dy) then
		wnd.last_xy[3] = props.x + (cx > hw and VRESW or -VRESW);
		wnd.last_xy[4] = props.y;
		move_image(wnd.anchor,
			wnd.last_xy[3], wnd.last_xy[4], rh_speed, INTERP_EXPIN);
	else
		wnd.last_xy[3] = props.x;
		wnd.last_xy[4] = props.y + (cy > hh and VRESH or -VRESH);
		move_image(wnd.anchor,
			wnd.last_xy[3], wnd.last_xy[4], rh_speed, INTERP_EXPIN);
	end

-- Create a small desktop icon that can be used to restore the window
	local base = prio_windows_iconsize();
	local icon = null_surface(wnd.width, wnd.height, INTERP_EXPOUT);
	if (not valid_vid(icon)) then
		return;
	end

	image_tracetag(icon, "icon");
	link_image(icon, wnd.anchor);
	image_mask_clear(icon, MASK_POSITION);
	image_mask_clear(icon, MASK_OPACITY);
	image_sharestorage(wnd.target, icon);

-- animate so that it looks like it is "landing"
	blend_image(icon, icon_strength);
	move_image(icon, wnd.last_xy[3], wnd.last_xy[4]);
	move_image(icon, wnd.last_xy[3], wnd.last_xy[4], rh_speed);
	move_image(icon, wnd.last_xy[3], wnd.last_xy[4], rh_speed);
	resize_image(icon, wnd.width, wnd.height, rh_speed);
	order_image(icon, 5);
	local x,y = find_icon_xy(wnd, base);
	wnd.icon_xy = {x, y};
	move_image(icon, x, y, 2 * rh_speed, INTERP_EXPOUT);
	resize_image(icon, base, base, rh_speed);
	image_texfilter(icon, FILTER_BILINEAR);

-- add the option to double-click to restore, or drag- around to reposition
	wnd.icon_mh = {
		name = "iconhandler",
		own = function(ctx, vid)
			return vid == icon;
		end,
		drag = function(ctx, vid, dx, dy)
			nudge_image(vid, dx, dy);
			wnd.icon_xy[1] = wnd.icon_xy[1] + dx;
			wnd.icon_xy[2] = wnd.icon_xy[2] + dy;
		end,
		dblclick = function()
			if (priostate) then
				priostate();
			end

			if (wnd.show) then
				wnd:show();
			end
		end
	};
	mouse_addlistener(wnd.icon_mh, {"dblclick", "drag"});
	wnd.desktop_icon = icon;
end

local function update_shadows()
-- shadow offset is determined by order and number of visible windows
-- for even more bling, this can be biased based on the relative position
-- of the mouse cursor..
	local fact = VPPCM / 28.3687;
	local lst = prio_windows_linear(true);
	local step = 1 + (max_shadow_offset * fact) / #lst;

	for i,v in ipairs(lst) do
		if (lst[i].shadow) then
			local ofs = step * (i-1);
			instant_image_transform(lst[i].shadow);
			move_image(lst[i].shadow, ofs, ofs, priocfg.animation_speed);
			resize_image(lst[i].shadow, lst[i].width, lst[i].height);
		end
	end
end

-- drop the association with the anchor, but keep the current properties
local function disassociate(dv)
	local props = image_surface_resolve_properties(dv);
	link_image(dv, dv);
	move_image(dv, props.x, props.y);
	resize_image(dv, props.width, props.height);
	blend_image(dv, props.opacity);
end

local function drop_tabs(wnd)
	for k,v in pairs(wnd.tabs) do
		if (valid_vid(v.vid)) then
			disassociate(v.vid);
			blend_image(v.vid, 0.0, 0.2 * rm_speed);
			expire_image(v.vid, 0.2 * rm_speed);
		end
	end
end

-- copy the decorations and have them leave in their respective direction
local function drop_border(wnd)
	if (not wnd.decor.l) then
		return;
	end
	local dirs = {"l", "r", "t", "b"};

	for i,v in ipairs(dirs) do
		local dv = wnd.decor[v];
		if (valid_vid(dv)) then
			disassociate(dv);
			blend_image(dv, 0.0, 0.2 * rm_speed);
			expire_image(dv, 0.2 * rm_speed);
		end
	end
end

local selwnd = {-1};
local deselwnd = {-2};

local evhandlers = {
	select = function(wnd, evarg1)
		selwnd = {CLOCK, wnd, evarg1};
		if (selwnd[1] == deselwnd[1]) then
			swap_wnd(selwnd[2], deselwnd[2], selwnd[3]);
		end
		return true;
	end,
  deselect = function(wnd)
		deselwnd = {CLOCK, wnd};
		if (selwnd[1] == deselwnd[1]) then
			swap_wnd(selwnd[2], deselwnd[2], selwnd[3]);
		end
		return true;
	end,
	destroy = function(wnd)
		if (wnd.target) then
			drop_border(wnd);
			drop_tabs(wnd);
			animate_destroy(wnd, falling);
		end
	end,
	show = function(wnd)
		if (wnd.last_xy) then
			if (wnd.desktop_icon) then
				show_from_icon(wnd);
			else
				move_image(wnd.anchor, wnd.last_xy[1], wnd.last_xy[2], rh_speed);
			end
			wnd.last_xy = nil;
		end
	end,
	resize = function(wnd)
		return true;
	end,
	hide = hide_to_icon
};

-- called post-window creation, we use it to create our shadow
-- and add ourselves to the event-hooks of the window
function prio_effect_hook(wnd)
	local ssurf = color_surface(wnd.width, wnd.height, 0, 0, 0);
	link_image(ssurf, wnd.anchor);
	image_mask_set(ssurf, MASK_UNPICKABLE);
	image_inherit_order(ssurf, true);
	order_image(ssurf, -2);
	blend_image(ssurf, shadow_strength);
	wnd.shadow = ssurf;

	table.insert(wnd.event_hooks,
	function(wnd, event, ...)
		if (evhandlers[event] and evhandlers[event](wnd, ...)) then
			update_shadows(wnd);
		end
	end
	);
end
