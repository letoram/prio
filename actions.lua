local actions = {};

-- chain window
local function wrun(fun)
	return function()
		if (priowin ~= nil) then
			fun(priowin);
		end
	end
end

-- use a rendertarget indirection for the screenshot to work around some driver
-- bugs for the egl-dri/platform + mesa + ??? when trying to read the front buffer
actions.save_screenshot = function()
	local cp = prio_clock_pulse;
	local ctr = 20;
	prio_clock_pulse = function(...)
		ctr = ctr - 1;
		if (ctr == 0) then
			zap_resource("prio_ss.png");
			local dst = alloc_surface(VRESW, VRESH);
			local nsrf = null_surface(VRESW, VRESH);
			show_image(nsrf);
			image_sharestorage(WORLDID, nsrf);
			define_rendertarget(dst, {nsrf}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, 0);
			rendertarget_forceupdate(dst);
			save_screenshot("prio_ss.png", FORMAT_PNG_FLIP, dst);
			delete_image(dst);
			prio_clock_pulse = cp;
			system_message("screenshot saved to prio_ss.png");
		end
		cp(...);
	end
end

local active_rec;
actions.record = function()
	if (valid_vid(active_rec)) then
		delete_image(active_rec);
		active_rec = nil;
		system_message("stopped recording");
	else
		zap_resource("prio_rec.mkv");
		active_rec = alloc_surface(1280, 720);
		if (valid_vid(active_rec)) then
			local tsrf = null_surface(1280, 720);
			show_image(tsrf);
			image_texfilter(tsrf, FILTER_BILINEAR);
			image_sharestorage(WORLDID, tsrf);
			image_set_txcos_default(tsrf, true);
			define_recordtarget(active_rec, "prio_rec.mkv", "vpreset=8:noaudio:fps=30",
				{tsrf}, {}, RENDERTARGET_DETACH, RENDERTARGET_NOSCALE, -1, function(src, status)
					if (status.kind == "terminated") then
						delete_image(src);
						active_rec = nil;
					end
				end);
		end
	end
end

actions.destroy_active_tab = wrun(function(wnd) wnd:lost(wnd.target); end);
actions.destroy_active_window = wrun(function(wnd) wnd:destroy(); end);
actions.select_tab_1 = wrun(function(wnd) wnd:set_tab(1); end);
actions.select_tab_2 = wrun(function(wnd) wnd:set_tab(2); end);
actions.select_tab_3 = wrun(function(wnd) wnd:set_tab(3); end);
actions.select_tab_4 = wrun(function(wnd) wnd:set_tab(4); end);
actions.select_tab_5 = wrun(function(wnd) wnd:set_tab(5); end);
actions.select_tab_6 = wrun(function(wnd) wnd:set_tab(6); end);
actions.select_tab_7 = wrun(function(wnd) wnd:set_tab(7); end);
actions.select_tab_8 = wrun(function(wnd) wnd:set_tab(8); end);
actions.select_tab_9 = wrun(function(wnd) wnd:set_tab(9); end);
actions.select_tab_10= wrun(function(wnd) wnd:set_tab(10);end);
actions.next_tab     = wrun(function(wnd) wnd:set_tab(-2);end);
actions.prev_tab     = wrun(function(wnd) wnd:set_tab(-1);end);
actions.paste        = wrun(function(wnd) wnd:paste(CLIPBOARD_MESSAGE);end);
actions.select_up    = wrun(function(wnd) prio_sel_nearest(wnd, "t"); end);
actions.select_down  = wrun(function(wnd) prio_sel_nearest(wnd, "b"); end);
actions.select_left  = wrun(function(wnd) prio_sel_nearest(wnd, "l"); end);
actions.select_right = wrun(function(wnd) prio_sel_nearest(wnd, "r"); end);

actions.shrink_h = wrun(function(wnd) wnd:step_sz(1, 0,-1); end);
actions.shrink_w = wrun(function(wnd) wnd:step_sz(1,-1, 0); end);
actions.grow_h   = wrun(function(wnd) wnd:step_sz(1, 0, 1); end);
actions.grow_w   = wrun(function(wnd) wnd:step_sz(1, 1, 0); end);

actions.move_up    = wrun(function(wnd) wnd:step_move(1, 0,-1); end);
actions.move_down  = wrun(function(wnd) wnd:step_move(1, 0, 1); end);
actions.move_left  = wrun(function(wnd) wnd:step_move(1,-1, 0); end);
actions.move_right = wrun(function(wnd) wnd:step_move(1, 1, 0); end);

actions.toggle_maximize = wrun(function(wnd) wnd:maximize("f"); end);
actions.assign_top      = wrun(function(wnd) wnd:maximize("t"); end);
actions.assign_bottom   = wrun(function(wnd) wnd:maximize("b"); end);
actions.assign_left     = wrun(function(wnd) wnd:maximize("l"); end);
actions.assign_right    = wrun(function(wnd) wnd:maximize("r"); end);

actions.set_temp_prefix_1 = function() priosym.prefix = "t1_"; end

actions.hide = wrun(function(wnd) wnd:hide(); end);
actions.copy = wrun(function(wnd)
	if (wnd.clipboard_msg) then
		prioclip = wnd.clipboard_msg;
	end
end);
actions.paste = wrun(function(wnd)
	wnd:paste(CLIPBOARD_MESSAGE);
end);

--
-- others: hide all, copy, paste
--
return actions;
