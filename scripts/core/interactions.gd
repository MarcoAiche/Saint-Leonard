class_name Interactions
extends RefCounted
## Liste aller Stellen, an denen man mit [F] etwas tun kann (Laden, Zapfsäule, Brennkessel ...).
## Jeder Eintrag: {pos, radius, text (String oder Callable), action (Callable), when (Callable oder null), node}
## Hängt ein Eintrag an einem Node, wandert die Position mit und der Eintrag verschwindet mit dem Node.

var entries: Array = []


func add(pos: Vector3, radius: float, text, action: Callable, when = null, node: Node3D = null) -> Dictionary:
	var e := {pos = pos, radius = radius, text = text, action = action, when = when, node = node}
	entries.append(e)
	return e


func remove(e: Dictionary) -> void:
	entries.erase(e)


func remove_node(node: Node) -> void:
	entries = entries.filter(func(e): return e.node != node)


## Nächster gültiger Eintrag für eine Position
func nearest(p: Vector3) -> Dictionary:
	var best := {}
	var best_d := INF
	var dead := []
	for e in entries:
		var pos: Vector3 = e.pos
		if e.node != null:
			if not is_instance_valid(e.node) or not e.node.is_inside_tree():
				dead.append(e)
				continue
			pos = e.node.global_transform * e.pos
		var d := pos.distance_to(p)
		if d > e.radius or d >= best_d:
			continue
		if e.when != null and not (e.when as Callable).call():
			continue
		best = e
		best_d = d
	for e in dead:
		entries.erase(e)
	return best


static func text_of(e: Dictionary) -> String:
	if e.is_empty():
		return ""
	return (e.text as Callable).call() if e.text is Callable else str(e.text)
