class_name Toon
extends RefCounted
## Materialien für den Look (Mischung aus Cartoon und semi-realistisch): weiches Licht, keine Glanzlichter,
## Farbe kommt aus den Vertexfarben, optional mit dunkler Umrisslinie.

static var _cache := {}

const TERRAIN_SHADER := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

varying vec3 v_world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv_macro = v_world_pos.xz * 0.08;
	vec2 uv_mid = v_world_pos.xz * 0.55;
	vec2 uv_micro = v_world_pos.xz * 3.2;
	float n_macro = value_noise(uv_macro);
	float n_mid = value_noise(uv_mid);
	float n_micro = value_noise(uv_micro);
	float detail = 0.84 + n_macro * 0.14 + n_mid * 0.10 + n_micro * 0.08;
	ALBEDO = clamp(COLOR.rgb * detail, vec3(0.0), vec3(1.0));
	ROUGHNESS = 0.88;
	SPECULAR = 0.15;
}
"""


static func terrain_material() -> ShaderMaterial:
	if _cache.has("terrain"):
		return _cache["terrain"]
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	_cache["terrain"] = sm
	return sm


static func material(outline := false, double_sided := false) -> StandardMaterial3D:
	var key := "%s_%s" % [outline, double_sided]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.roughness = 0.85
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if outline:
		m.next_pass = outline_material()
	_cache[key] = m
	return m


## Einfarbiges Stylized Low-Poly Material (Matte-to-Satin, ohne schwere schwarze Outlines).
static func solid(color: Color, outline := false, outline_width := 0.025) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.roughness = 0.82
	if outline:
		m.next_pass = outline_material(outline_width)
	return m


static func outline_material(width := 0.07) -> StandardMaterial3D:
	var o := StandardMaterial3D.new()
	o.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o.albedo_color = Color(0.13, 0.11, 0.12)
	o.cull_mode = BaseMaterial3D.CULL_FRONT
	o.grow = true
	o.grow_amount = width
	return o


static func water() -> StandardMaterial3D:
	if _cache.has("water"):
		return _cache["water"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 1.0, 1.0, 0.82)
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.roughness = 0.14
	m.emission_enabled = true
	m.emission = Color(0.06, 0.22, 0.34)
	_cache["water"] = m
	return m
