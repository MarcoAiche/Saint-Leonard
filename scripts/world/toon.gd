class_name Toon
extends RefCounted
## Materialien für den leicht cartoonigen Look: Toon-Licht, keine Glanzlichter,
## Farbe kommt aus den Vertexfarben, optional mit dunkler Umrisslinie.

static var _cache := {}


static func material(outline := false, double_sided := false) -> StandardMaterial3D:
	var key := "%s_%s" % [outline, double_sided]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if outline:
		m.next_pass = outline_material()
	_cache[key] = m
	return m


## Einfarbiges Toon-Material (für Figuren und Fahrzeuge).
static func solid(color: Color, outline := true, outline_width := 0.025) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
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
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.15
	m.emission_enabled = true
	m.emission = Color(0.05, 0.18, 0.3)
	_cache["water"] = m
	return m
