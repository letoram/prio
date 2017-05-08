-- animated bonfire
local bonfire = launch_decode("wallpaper/kindling.mp4", "loop",
	function(source, status)
		if (status.kind == "resized") then
			show_image(source);
			resize_image(source, status.width, status.height);
			move_image(source, VRESW - 0.8 * status.width, VRESH - status.height);
		end
	end
);
image_mask_set(bonfire, MASK_UNPICKABLE);
image_texfilter(bonfire, FILTER_BILINEAR);
suspend_target(bonfire);
image_shader(bonfire, shader_get("luma_nored"));

-- bonfire double-click capture, will pause/supend animation
local dblclick = null_surface(64, 64);
show_image(dblclick);
KINDLED = false;

mouse_addlistener(dblclick, {
	dblclick = function()
		print("doubleclick the fire!");
		if (not KINDLED) then
			resume_target(bonfire);
			image_shader(bonfire, shader_get("canvas_normal"));
			KINDLED = true;
--FIXME: light up all the windows as well
--FIXME: sample bonfire into window decorations
--FIXME: set slight translucency on terminals
		else
			suspend_target(bonfire);
			image_shader(bonfire, shader_get("luma_nored"));
			KINDLED = false;
--FIXME: grey all the windows as well
-- disable terminal translucency
		end
	end
},

-- for delete, grey + you-die fade
-- for spawn, darker popup border, different font, ...
-- for hide, fade -> animate to pedistal

local autores = VRES_AUTORES;
VRES_AUTORES = function(w, h, vppcm, flags, source)
	autores(w, h, vppcm, flags, source);
	local status = image_surface_resolve(bonfire);
	move_image(bonfire, VRESW - 0.8 * status.width, VRESH - status.height);
end

