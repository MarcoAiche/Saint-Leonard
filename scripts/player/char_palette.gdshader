shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
// Färbt die Figur aus dem Farbatlas (8 x 4 Felder) um: Haut, Oberteil, Hose, Haare, Schuhe.
// Die Helligkeit innerhalb eines Feldes (Verlauf oben hell, unten dunkel) bleibt erhalten.

uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform vec3 col_skin : source_color = vec3(0.98, 0.80, 0.66);
uniform vec3 col_shirt : source_color = vec3(0.35, 0.42, 0.25);
uniform vec3 col_pants : source_color = vec3(0.30, 0.26, 0.20);
uniform vec3 col_hair : source_color = vec3(0.30, 0.20, 0.12);
uniform vec3 col_shoes : source_color = vec3(0.22, 0.16, 0.12);
// Atlasfelder (x + y * 8), -1 = nicht vorhanden
uniform int cell_skin = 11;
uniform int cell_shirt = 17;
uniform int cell_pants = 1;
uniform int cell_hair = -1;
uniform int cell_shoes = -1;
uniform bool debug_cells = false;
// Rumpf unterhalb dieser Höhe (Meshraum) ist Hose
uniform float pants_y = -1000.0;
varying float mesh_y;

void vertex() {
	mesh_y = VERTEX.y;
}

void fragment() {
	vec3 base = texture(atlas, UV).rgb;
	ivec2 c = ivec2(clamp(floor(UV * vec2(8.0, 4.0)), vec2(0.0), vec2(7.0, 3.0)));
	int idx = c.x + c.y * 8;
	float shade = mix(1.1, 0.72, fract(UV.y * 4.0));
	vec3 col = base;
	if (idx == cell_skin) { col = col_skin * shade; }
	else if (idx == cell_shirt) { col = (mesh_y < pants_y ? col_pants : col_shirt) * shade; }
	else if (idx == cell_pants) { col = col_pants * shade; }
	else if (idx == cell_hair) { col = col_hair * shade; }
	else if (idx == cell_shoes) { col = col_shoes * shade; }
	if (debug_cells) {
		col = vec3(float(idx % 3) * 0.5, float((idx / 3) % 3) * 0.5, float((idx / 9) % 4) * 0.33);
	}
	ALBEDO = col;
}
