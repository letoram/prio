--
-- User- defined actions to run on startup.
-- Functions:
--
-- prio_terminal(x, y, w, h) - spawn a terminal
-- prio_target_window(target, config, x, y, w, h, opttbl)
-- prio_static_image(resource, x, y, w, h, opttbl)
-- prio_listen(key, keep_offline, x, y, w, h, opttbl)
--
-- constants:
-- VRESW, VRESH (current display canvas dimensions)
-- VPPCM (current display density)
--
-- opttbl fields:
--  no_decor       (boolean) - draw decoration or not
--  tab_block      (boolean) - don't setup / add tabs
--  select_block   (boolean) - prevent the window from being selected for input
--  shader         (string)  - reference to key in shaders.lua
--  order          (number)  - control Z order
--  flip_y         (boolean) - invert Y axis
--  delete_protect (boolean) - prevent delete/hide operations from working
--  no_delete      (boolean) - if the client connection dies, keep the surface
--  effect_hook    (funcref) - override the priocfg.effect_hook(wnd)
--
local w1 = 0.2 * VRESW;
local h1 = 0.2 * VRESH;
local x1 = VRESW-w1;
local y1 = VRESH-h1;

-- custom 'background listener' hack, when we get a connection on key,
-- disable the shader and just show/stretch to background and then revert
-- back on termination
local function listen(key)
	target_alloc(key, function(source, status)
		if (status.kind == "resized") then
			image_sharestorage(source, priobg);
			image_shader(priobg, shader_get("canvas_normal"));
		elseif (status.kind == "terminated") then
			delete_image(source);
			image_shader(priobg, shader_get("background"));
			listen(key);
		end
	end);
end
-- uncomment to enable the background-mapped connection point
-- listen("background");

-- prio_terminal(50, 50, 400, 200,
--	{no_decor = true, tab_block = true, delete_protect = true, no_delete = true});
-- prio_static_image("frame.png", x1, y1, w1, h1);
-- prio_listen("image", true, x1 + 20, y1 + 20, w1 * 0.2, h1 * 0.2, {order = 200});
-- prio_listen("frame", false, x1 + 20, y1 + 20, w1 * 0.2, h1 * 0.2, {order = 3});
-- prio_target_window("Super Nintendo", "Super Mario World", 0.1*VRESW, 0.1*VRESH, 50, 50);
