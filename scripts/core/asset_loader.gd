class_name AssetLoader
extends RefCounted
## Lädt optionale .glb-Modelle aus res://assets/models/, skaliert sie per AABB automatisch
## auf die Zielhöhe (y = 0.0 am Boden) und fällt sauber auf prozedurale Meshes zurück,
## solange das jeweilige .glb noch nicht vorhanden ist.


static func load_model(
	glb_path: String,
	target_height: float,
	fallback_callable: Callable,
	apply_stylized_shading: bool = false,
	render_layer: int = 1
) -> Node3D:
	if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
		var fb: Variant = fallback_callable.call()
		return fb as Node3D if fb is Node3D else Node3D.new()

	var scene := ResourceLoader.load(glb_path) as PackedScene
	if scene == null:
		var fb: Variant = fallback_callable.call()
		return fb as Node3D if fb is Node3D else Node3D.new()

	var inst := scene.instantiate() as Node3D
	if inst == null:
		var fb: Variant = fallback_callable.call()
		return fb as Node3D if fb is Node3D else Node3D.new()

	var wrapper := Node3D.new()
	wrapper.add_child(inst)

	var bounds := _compute_visual_aabb(inst)
	if bounds.size.y > 0.001 and target_height > 0.0:
		var sc: float = target_height / bounds.size.y
		inst.scale = Vector3.ONE * sc
		inst.position.y = -bounds.position.y * sc
	elif bounds.size != Vector3.ZERO:
		inst.position.y = -bounds.position.y

	_configure_meshes(inst, apply_stylized_shading, render_layer)
	var anim := _find_animation_player(inst)
	if anim != null:
		wrapper.set_meta("animation_player", anim)
	return wrapper


static func load_mesh(glb_path: String, target_height: float, fallback_callable: Callable, foliage_alpha: bool = false) -> Mesh:
	if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
		var fb: Variant = fallback_callable.call()
		return fb as Mesh

	var scene := ResourceLoader.load(glb_path) as PackedScene
	if scene == null:
		var fb: Variant = fallback_callable.call()
		return fb as Mesh

	var inst := scene.instantiate() as Node3D
	if inst == null:
		var fb: Variant = fallback_callable.call()
		return fb as Mesh

	var meshes := _collect_mesh_instances(inst)
	if meshes.is_empty():
		inst.free()
		var fb: Variant = fallback_callable.call()
		return fb as Mesh

	var bounds := _compute_visual_aabb(inst)
	var sc := 1.0
	var y_off := 0.0
	if bounds.size.y > 0.001 and target_height > 0.0:
		sc = target_height / bounds.size.y
		y_off = -bounds.position.y * sc
	elif bounds.size != Vector3.ZERO:
		y_off = -bounds.position.y

	var st := SurfaceTool.new()
	var out_mesh := ArrayMesh.new()
	var out_surf := 0
	for mi in meshes:
		var src_mesh: Mesh = mi.mesh
		if src_mesh == null:
			continue
		var rel_xf := _relative_transform(inst, mi)
		var norm_basis := rel_xf.basis.inverse().transposed()
		for s in src_mesh.get_surface_count():
			st.clear()
			st.create_from(src_mesh, s)
			var arrays := st.commit_to_arrays()
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = (rel_xf * verts[i]) * sc + Vector3(0.0, y_off, 0.0)
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in norms.size():
					norms[i] = (norm_basis * norms[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = norms
			out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat := mi.get_active_material(s)
			if mat != null:
				out_mesh.surface_set_material(out_surf, _prepare_foliage_material(mat, foliage_alpha))
			out_surf += 1
	inst.free()
	return out_mesh


static func load_first_existing_mesh(paths: Array[String], target_height: float, fallback_callable: Callable, foliage_alpha: bool = false) -> Mesh:
	for p in paths:
		if ResourceLoader.exists(p):
			return load_mesh(p, target_height, fallback_callable, foliage_alpha)
	var fb: Variant = fallback_callable.call()
	return fb as Mesh


static func get_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node.has_meta("animation_player"):
		var cached: Variant = node.get_meta("animation_player")
		if cached is AnimationPlayer:
			return cached as AnimationPlayer
	return _find_animation_player(node)


static func _compute_visual_aabb(root: Node3D) -> AABB:
	var has_bounds := false
	var combined := AABB()
	var inv_root := root.global_transform.affine_inverse() if root.is_inside_tree() else Transform3D.IDENTITY
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var local_aabb := mi.get_aabb()
			if local_aabb.size.length_squared() > 0.00001:
				var xf := _relative_transform(root, mi)
				var transformed := xf * local_aabb
				if not has_bounds:
					combined = transformed
					has_bounds = true
				else:
					combined = combined.merge(transformed)
		for child in n.get_children():
			stack.append(child)
	return combined if has_bounds else AABB()


static func _relative_transform(ancestor: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _configure_meshes(root: Node, apply_stylized_shading: bool, render_layer: int) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			mi.layers = render_layer
			if apply_stylized_shading and mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					var mat := mi.get_active_material(s)
					if mat is StandardMaterial3D:
						var sm := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
						sm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
						mi.set_surface_override_material(s, sm)
		for child in n.get_children():
			stack.append(child)


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


static func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			out.append(n as MeshInstance3D)
		for child in n.get_children():
			stack.append(child)
	return out


static func _prepare_foliage_material(mat: Material, force_foliage_alpha: bool) -> Material:
	if not (mat is StandardMaterial3D):
		return mat
	var src := mat as StandardMaterial3D
	var mat_name := src.resource_name.to_lower()
	var is_foliage := force_foliage_alpha or mat_name.contains("leaf") or mat_name.contains("leaves") or mat_name.contains("grass") or mat_name.contains("flower") or mat_name.contains("bush") or mat_name.contains("fern")
	if not is_foliage and src.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		return src
	var sm := src.duplicate() as StandardMaterial3D
	if src.albedo_texture != null or is_foliage:
		if sm.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED or sm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		sm.alpha_scissor_threshold = 0.45
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	return sm
