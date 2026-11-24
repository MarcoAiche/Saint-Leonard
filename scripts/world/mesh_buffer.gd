class_name MeshBuffer
extends RefCounted
## Sammelt flach schattierte Dreiecke mit Vertexfarben und baut daraus ein ArrayMesh.
## Die Wicklung wird anhand der gewünschten Normale automatisch richtig gesetzt.

var verts := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()


func add_tri(a: Vector3, b: Vector3, c: Vector3, color: Color, n := Vector3.ZERO) -> void:
	var face := (b - a).cross(c - a)
	if face.length_squared() < 1e-10:
		return
	if n == Vector3.ZERO:
		n = -face.normalized()  # Godot: Vorderseite im Uhrzeigersinn
	elif face.dot(n) > 0.0:
		var t := b
		b = c
		c = t
	n = n.normalized()
	verts.append_array([a, b, c])
	normals.append_array([n, n, n])
	colors.append_array([color, color, color])


## Viereck a-b-c-d (umlaufend), Normale zeigt nach n.
func add_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, n: Vector3) -> void:
	add_tri(a, b, c, color, n)
	add_tri(a, c, d, color, n)


## Beide Seiten (z.B. Dachüberstand, der von unten sichtbar ist).
func add_quad_2s(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, n: Vector3, back: Color) -> void:
	add_quad(a, b, c, d, color, n)
	add_quad(a, b, c, d, back, -n)


func is_empty() -> bool:
	return verts.is_empty()


func commit(mesh: ArrayMesh, material: Material) -> void:
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


func to_mesh(material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	commit(mesh, material)
	return mesh
