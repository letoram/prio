--
-- simplified version of the menu system used in durden:
--
-- table of tables with:
-- handler = function called on menu selection,
-- label = static string or function returning dynamic string
-- name = binding path keybindings
-- hidden = don't show in UI menus
--

local system = {
{
	label = "Exit",
	name = "exit",
	handler = function()
		shutdown();
	end
},
{
	label = "Reset",
	name = "reset",
	handler = function()
		system_collapse();
	end
},
{
	label = "Screenshot",
	name = "screenshot",
	eval = function() return false; end,
	handler = function()
		prioactions.save_screenshot();
	end
},
{
	label = "Record",
	name = "record",
	eval = function() return false; end,
	handler = function()
		prioactions.record();
	end
}
};

local function gen_show_menu()
	local res = {};

	for k,v in ipairs(priohidden) do
		table.insert(res, {
			label = string.format("%d%s", k, (":") ..
				(v.ident and v.ident() or "")),
			name = "show_" .. tonumber(k),
			handler = function()
				v:show();
			end
		});
	end

	return res;
end

local global = {
{
	label = "New",
	name = "new",
	handler = function()
		prio_input = prio_region_input;
	end
},
{
	label = function()
		local cnt = 0;
		for k,v in pairs(priowindows) do cnt = cnt + 1; end
		return cnt > 0 and "Delete" or nil;
	end,
	name = "delete",
	handler = function()
		mouse_switch_cursor("destroy");
		priostate = function(wnd)
			priostate = nil;
			mouse_switch_cursor();
			if (wnd and not wnd.delete_protect) then
				wnd:destroy();
				return true;
			end
		end
	end
},
{
	label = function()
		local cnt = 0;
		for k,v in pairs(priowindows) do cnt = cnt + 1; end
		cnt = cnt - #priohidden;
		return cnt > 0 and "Hide" or nil;
	end,
	name = "hide",
	handler = function()
		mouse_switch_cursor("hide");
		priostate = function(wnd)
			priostate = nil;
			mouse_switch_cursor();
			if (wnd and not wnd.delete_protect) then
				wnd:hide();
				return true;
			end
		end
	end
},
{
	label = function()
		return #priohidden > 0 and "Show" or nil;
	end,
	name = "show",
	handler = function()
		local mx, my = mouse_xy();
		prio_menu_spawn(gen_show_menu(), mx, my);
	end
},
{
	label = "System",
	name = "system",
	handler = function()
		local mx, my = mouse_xy();
		prio_menu_spawn(system, mx, my);
	end
}
};

local context = {
{
	name = "paste",
	label = function(ctx) return "Paste(" ..
			string.sub(CLIPBOARD_MESSAGE, 1, 10) .. ")"; end,
	eval = function(ctx)
		return string.len(CLIPBOARD_MESSAGE) > 0;
	end,
	handler = function(ctx)
		ctx[1]:paste(CLIPBOARD_MESSAGE);
	end
},
{
	label = function(ctx)
		local props = image_storage_properties(ctx[2].source);
		return (props.width ~= ctx[1].width or props.height ~= ctx[1].height)
			and "Set Source Size" or nil;
	end,
	name = "source_size",
	handler = function(ctx)
		local props = image_storage_properties(ctx[2].source);
		ctx[1]:resize(props.width, props.height);
		ctx[1]:synch_tab_sizes();
	end
},
{
	name = "toggle_force_size",
	label = function(ctx)
		return ctx[1].force_size and "Dynamic Size" or "Force Size"
	end,
	handler = function(ctx)
		ctx[1].force_size = not ctx[1].force_size;
		ctx[1]:resize(ctx[1].width, ctx[1].height);
	end
},
{
	name = "toggle_mute",
	label = function(ctx)
		if (ctx[1].aid == nil or ctx[1].aid == BADID) then
			return;
		end
		return (ctx[1].mute and "Unmute" or "Mute");
	end,
	handler = function(ctx)
	end
},
{
	name = "close_tab",
	label = "Close",
	handler = function(ctx)
		ctx[1].lost(ctx[1], ctx[2].source);
	end
},
{
	name = "save_img",
	label = "Output Image",
	eval = function() return false; end,
	handler = function(ctx)
		save_screenshot("prio_imgss.png", FORMAT_PNG, ctx[2].source);
	end
},
};

function tab_menu(wnd, tab)
	local mx, my = mouse_xy();
	prio_menu_spawn(context, mx, my, {wnd, tab});
end

function cancel_menu()
	if (priomenu) then
		priomenu:destroy();
	end
	mouse_switch_cursor();
end

function prio_menu()
	local mx, my = mouse_xy();
	mouse_switch_cursor();
	prio_menu_spawn(global, mx, my);
end
