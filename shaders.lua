local shaders = {};

shaders.canvas_normal = {
frag = [[
uniform sampler2D map_tu0;
uniform vec2 obj_output_sz;
uniform vec2 obj_storage_sz;
varying vec2 texco;

void main(){
	vec3 col = texture2D(map_tu0, texco).rgb;
	gl_FragColor = vec4(col, 1.0);
}
]],
};

shaders.luma = {
frag = [[
]]
};

shaders.luma_nored = {

};

shaders.background = {};

shaders.selection = {
frag = [[
uniform sampler2D map_tu0;
uniform vec2 obj_output_sz;
uniform float obj_opacity;
uniform vec3 obj_col;
varying vec2 texco;

void main()
{
	float bstep_x = 1.0 / obj_output_sz.x;
	float bstep_y = 1.0 / obj_output_sz.y;

	bvec2 marg1 = greaterThan(texco, vec2(1.0 - bstep_x, 1.0 - bstep_y));
	bvec2 marg2 = lessThan(texco, vec2(bstep_x, bstep_y));
	float f = float( !(any(marg1) || any(marg2)) );

	gl_FragColor = mix(
		vec4(obj_col.rgb, obj_opacity),
		vec4(vec3(0.7, 0.7, 0.7) * obj_col.rgb,
			obj_opacity - float(obj_opacity < 1.0) *obj_opacity * 0.3),
		f);
}
]],
};

shaders.tab = {
	frag = shaders.selection.frag
};

local decor_l = [[
uniform vec3 obj_col;
uniform float obj_opacity;
varying vec2 texco;
void main(){
	gl_FragColor = vec4((1.0 - 0.2 * texco.s * texco.s) * obj_col, obj_opacity);
}
]];

local decor_r = [[
uniform vec3 obj_col;
uniform float obj_opacity;
varying vec2 texco;
void main(){
	float txco = 1.0 - texco.s;
	gl_FragColor = vec4((1.0 - 0.2 * txco * txco) * obj_col, obj_opacity);
}
]];

local decor_t = [[
uniform vec3 obj_col;
uniform float obj_opacity;
varying vec2 texco;
void main(){
	float txco = 1.0 - texco.t;
	gl_FragColor = vec4((1.0 - 0.2 * txco * txco) * obj_col, obj_opacity);
}
]];

local decor_b = [[
uniform vec3 obj_col;
uniform float obj_opacity;
varying vec2 texco;
void main(){
	gl_FragColor = vec4((1.0 - 0.2 * texco.t * texco.t) * obj_col, obj_opacity);
}
]];

shaders.decor_l = {frag = decor_l};
shaders.decor_r = {frag = decor_r};
shaders.decor_t = {frag = decor_t};
shaders.decor_b = {frag = decor_b};
shaders.maximize_hint = {
frag = shaders.selection.frag
};

shaders.mouse_unpack = { frag =
[[
uniform sampler2D map_tu0;
uniform vec2 obj_storage_sz;

varying vec2 texco;
float median(float r, float g, float b){
	return max(min(r, g), min(max(r, g), b));
}

float linearStep(float a, float b, float x){
	return clamp((x-a)/(b-a),0.0, 1.0);
}

void main(){
	float range = 2.0;
	float thickness = 0.5;
	float border = 0.125;
	vec2 shadow = vec2(0.0625, -0.03125);
	float softness = 0.5;
	float opacity = 0.5;

	vec3 bc = vec3(0.0, 0.0, 0.0);
	vec3 fc = vec3(1.0, 1.0, 1.0);
	vec3 bordc = vec3(0.0);

	float pxsz = min(0.5/range*(fwidth(texco.x) * obj_storage_sz.x +
		fwidth(texco.y) * obj_storage_sz.y), 0.25);

	vec3 msd = texture2D(map_tu0, texco).rgb;
	float sd = 2.0 * median(msd.r, msd.g, msd.b) - 1.0 + thickness;
	float inside = sd; // linearStep(-border-pxsz, -border+pxsz, sd);
	float outside = border > 0.0 ? sd :  1.0; // linearStep(border-pxsz, border+pxsz, sd) : 1.0;
	vec4 fg = vec4(mix(bordc, fc, outside), inside);

	msd = texture2D(map_tu0, texco - shadow).rgb;
	sd = 2.0 * median(msd.r, msd.g, msd.b) - 1.0 + border + thickness;
	float sval = opacity * linearStep(-softness-pxsz, softness+pxsz, sd);
	gl_FragColor = vec4(mix(vec3(0.0), fg.rgb, fg.a), sval-sval*fg.a+fg.a);
}
]] };

function shader_get(key)
	return (key and shaders[key]) and shaders[key].shid or "DEFAULT";
end

function shader_uniforms(static)
	for k,v in pairs(shaders) do
		local tbl = static and v.static_uniform or v.dynamic_uniform;
		if (tbl and v.shid) then
			for i,j in pairs(tbl) do
				shader_uniform(v.shid, i, j() );
			end
		end
	end
end

for k,v in pairs(shaders) do
	v.shid = build_shader(v.vert, v.frag, k);
end

shader_uniforms(true);
