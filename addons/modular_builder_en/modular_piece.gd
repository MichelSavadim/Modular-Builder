@tool
class_name ModularBuilderPiece
extends Node3D

const DETAIL_SCRIPT_PATH := "res://addons/modular_builder_en/modular_building_detail.gd"
const DETAIL_TYPE_HATCH := 2

enum PieceType { FOUNDATION_SQUARE, FOUNDATION_TRIANGLE, FLOOR, WALL, BUILDING }

@export var piece_type: PieceType = PieceType.FOUNDATION_SQUARE:
	set(value):
		piece_type = value
		_rebuild()
@export_range(0.5, 8.0, 0.5, "suffix:m") var unit_size: float = 2.0:
	set(value):
		unit_size = value
		_rebuild()
@export_range(0.05, 1.0, 0.05, "suffix:m") var thickness: float = 0.2:
	set(value):
		thickness = value
		_rebuild()
		for child in get_children():
			if child.has_method("_on_host_thickness_changed"):
				child.call("_on_host_thickness_changed")
@export var surface_material: Material:
	set(value):
		surface_material = value
		_rebuild()
@export var custom_points: PackedVector3Array = PackedVector3Array():
	set(value):
		custom_points = value
		_rebuild()
@export var centered_origin: bool = false:
	set(value):
		centered_origin = value
		_rebuild()

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	var old_collision := get_node_or_null("Collision")
	if old_collision != null:
		remove_child(old_collision)
		old_collision.queue_free()
	var mesh_instance := get_node_or_null("Geometry") as MeshInstance3D
	if piece_type == PieceType.BUILDING:
		if mesh_instance != null:
			remove_child(mesh_instance)
			mesh_instance.queue_free()
		return
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Geometry"
		add_child(mesh_instance)
		_set_scene_owner(mesh_instance)
	mesh_instance.mesh = _make_mesh()
	mesh_instance.material_override = surface_material

func _set_scene_owner(node: Node) -> void:
	if Engine.is_editor_hint():
		var scene_root := get_tree().edited_scene_root
		if scene_root:
			node.owner = scene_root

func _make_mesh() -> ArrayMesh:
	if custom_points.size() >= 2 and piece_type == PieceType.WALL:
		return _make_custom_wall_mesh()
	if custom_points.size() >= 3 and piece_type == PieceType.FLOOR:
		return _make_custom_floor_mesh()
	if custom_points.size() >= 3 and (piece_type == PieceType.FOUNDATION_SQUARE or piece_type == PieceType.FOUNDATION_TRIANGLE):
		return _make_custom_foundation_mesh()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var s := unit_size
	var polygon: Array[Vector2]
	match piece_type:
		PieceType.FOUNDATION_TRIANGLE:
			polygon = [Vector2(-s * 0.5, -s * 0.5), Vector2(s * 0.5, -s * 0.5), Vector2(-s * 0.5, s * 0.5)]
		_:
			polygon = [Vector2(-s * 0.5, -s * 0.5), Vector2(s * 0.5, -s * 0.5), Vector2(s * 0.5, s * 0.5), Vector2(-s * 0.5, s * 0.5)]
	var y0 := -thickness * 0.5 if centered_origin else 0.0
	var y1 := thickness * 0.5 if centered_origin else thickness
	if piece_type == PieceType.WALL:
		polygon = [Vector2(-s * 0.5, -thickness * 0.5), Vector2(s * 0.5, -thickness * 0.5), Vector2(s * 0.5, thickness * 0.5), Vector2(-s * 0.5, thickness * 0.5)]
		y0 = -s * 0.5 if centered_origin else 0.0
		y1 = s * 0.5 if centered_origin else s
	if piece_type == PieceType.FOUNDATION_SQUARE or piece_type == PieceType.FOUNDATION_TRIANGLE:
		var hatch_mesh := _make_hatch_surface_mesh(polygon, y1, y0)
		if hatch_mesh != null:
			return hatch_mesh
	for i in range(1, polygon.size() - 1):
		_add_tri(vertices, normals, Vector3(polygon[0].x, y1, polygon[0].y), Vector3(polygon[i + 1].x, y1, polygon[i + 1].y), Vector3(polygon[i].x, y1, polygon[i].y))
		_add_tri(vertices, normals, Vector3(polygon[0].x, y0, polygon[0].y), Vector3(polygon[i].x, y0, polygon[i].y), Vector3(polygon[i + 1].x, y0, polygon[i + 1].y))
	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		var a := polygon[i]
		var b := polygon[j]
		_add_tri(vertices, normals, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y))
		_add_tri(vertices, normals, Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _make_custom_wall_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var a: Vector3 = custom_points[0]
	var b: Vector3 = custom_points[1]
	var direction := (b - a).normalized()
	var length := a.distance_to(b)
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * thickness * 0.5
	var height := Vector3.UP * unit_size
	var openings: Array[PackedVector2Array] = []
	for child in get_children():
		if _is_detail_node(child) and int(child.get("detail_type")) != DETAIL_TYPE_HATCH:
			var detail := child as Node3D
			var center := Vector2((detail.position - a).dot(direction), detail.position.y - a.y)
			var axis_x := Vector2(detail.transform.basis.x.dot(direction), detail.transform.basis.x.y).normalized()
			var axis_y := Vector2(detail.transform.basis.y.dot(direction), detail.transform.basis.y.y).normalized()
			var opening := PackedVector2Array([
				center - axis_x * float(detail.get("width")) * 0.5 - axis_y * float(detail.get("height")) * 0.5,
				center + axis_x * float(detail.get("width")) * 0.5 - axis_y * float(detail.get("height")) * 0.5,
				center + axis_x * float(detail.get("width")) * 0.5 + axis_y * float(detail.get("height")) * 0.5,
				center - axis_x * float(detail.get("width")) * 0.5 + axis_y * float(detail.get("height")) * 0.5
			])
			var wall_rect := PackedVector2Array([Vector2(0.0, 0.0), Vector2(length, 0.0), Vector2(length, unit_size), Vector2(0.0, unit_size)])
			for clipped_opening in Geometry2D.intersect_polygons(opening, wall_rect):
				if clipped_opening.size() >= 3:
					openings.append(clipped_opening)
	var xs: Array[float] = [0.0, length]
	var ys: Array[float] = [0.0, unit_size]
	for opening in openings:
		for point in opening:
			xs.append(clampf(point.x, 0.0, length))
			ys.append(clampf(point.y, 0.0, unit_size))
	xs.sort()
	ys.sort()
	for xi in range(xs.size() - 1):
		for yi in range(ys.size() - 1):
			var u0: float = xs[xi]
			var u1: float = xs[xi + 1]
			var v0: float = ys[yi]
			var v1: float = ys[yi + 1]
			var mid := Vector2((u0 + u1) * 0.5, (v0 + v1) * 0.5)
			var cell := PackedVector2Array([Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
			var remaining: Array[PackedVector2Array] = [cell]
			for opening in openings:
				var next_remaining: Array[PackedVector2Array] = []
				for polygon in remaining:
					for clipped in Geometry2D.clip_polygons(polygon, opening):
						if clipped.size() >= 3:
							next_remaining.append(clipped)
				remaining = next_remaining
			for polygon in remaining:
				var indices := Geometry2D.triangulate_polygon(polygon)
				for ti in range(0, indices.size(), 3):
					var p0: Vector2 = polygon[indices[ti]]
					var p1: Vector2 = polygon[indices[ti + 1]]
					var p2: Vector2 = polygon[indices[ti + 2]]
					var f0 := a + direction * p0.x + Vector3.UP * p0.y
					var f1 := a + direction * p1.x + Vector3.UP * p1.y
					var f2 := a + direction * p2.x + Vector3.UP * p2.y
					_add_tri(vertices, normals, f0 + side, f1 + side, f2 + side)
					_add_tri(vertices, normals, f2 - side, f1 - side, f0 - side)
	# The two ends plus top and bottom close the wall body.
	_add_quad(vertices, normals, a - side, a + side, a + side + height, a - side + height)
	_add_quad(vertices, normals, b + side, b - side, b - side + height, b + side + height)
	_add_quad(vertices, normals, a + side + height, b + side + height, b - side + height, a - side + height)
	_add_quad(vertices, normals, a - side, b - side, b + side, a + side)
	for opening in openings:
		for edge_index in range(opening.size()):
			var p0 := opening[edge_index]
			var p1 := opening[(edge_index + 1) % opening.size()]
			var a0 := a + direction * p0.x + Vector3.UP * p0.y
			var a1 := a + direction * p1.x + Vector3.UP * p1.y
			_add_quad(vertices, normals, a0 + side, a0 - side, a1 - side, a1 + side)
	return _array_mesh(vertices, normals)

func _make_custom_floor_mesh() -> ArrayMesh:
	var polygon: Array[Vector2] = []
	for point in custom_points:
		polygon.append(Vector2(point.x, point.z))
	var hatch_mesh := _make_hatch_surface_mesh(polygon, custom_points[0].y, custom_points[0].y - thickness)
	if hatch_mesh != null:
		return hatch_mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var points := custom_points
	var bottom: Array[Vector3] = []
	for point in points:
		bottom.append(point - Vector3.UP * thickness)
	for i in range(1, points.size() - 1):
		_add_tri(vertices, normals, points[0], points[i + 1], points[i])
		_add_tri(vertices, normals, bottom[0], bottom[i], bottom[i + 1])
	for i in range(points.size()):
		var j := (i + 1) % points.size()
		_add_quad(vertices, normals, bottom[i], bottom[j], points[j], points[i])
	return _array_mesh(vertices, normals)

func _make_hatch_surface_mesh(polygon: Array[Vector2], top_y: float, bottom_y: float) -> ArrayMesh:
	var openings: Array[PackedVector2Array] = []
	for child in get_children():
		if _is_detail_node(child) and int(child.get("detail_type")) == DETAIL_TYPE_HATCH:
			var detail := child as Node3D
			var center := Vector2(detail.position.x, detail.position.z)
			var axis_x := Vector2(detail.transform.basis.x.x, detail.transform.basis.x.z).normalized()
			var axis_y := Vector2(detail.transform.basis.z.x, detail.transform.basis.z.z).normalized()
			var opening := PackedVector2Array([
				center - axis_x * float(detail.get("width")) * 0.5 - axis_y * float(detail.get("height")) * 0.5,
				center + axis_x * float(detail.get("width")) * 0.5 - axis_y * float(detail.get("height")) * 0.5,
				center + axis_x * float(detail.get("width")) * 0.5 + axis_y * float(detail.get("height")) * 0.5,
				center - axis_x * float(detail.get("width")) * 0.5 + axis_y * float(detail.get("height")) * 0.5
			])
			openings.append(opening)
	if openings.is_empty() or polygon.size() < 3:
		return null
	var min_x := polygon[0].x
	var max_x := polygon[0].x
	var min_z := polygon[0].y
	var max_z := polygon[0].y
	var xs: Array[float] = []
	var zs: Array[float] = []
	for point in polygon:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.y)
		max_z = maxf(max_z, point.y)
		xs.append(point.x)
		zs.append(point.y)
	for opening in openings:
		for point in opening:
			xs.append(clampf(point.x, min_x, max_x))
			zs.append(clampf(point.y, min_z, max_z))
	xs.sort()
	zs.sort()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var source_polygon := PackedVector2Array()
	for point in polygon:
		source_polygon.append(point)
	for xi in range(xs.size() - 1):
		for zi in range(zs.size() - 1):
			var x0: float = xs[xi]
			var x1: float = xs[xi + 1]
			var z0: float = zs[zi]
			var z1: float = zs[zi + 1]
			if x1 - x0 < 0.0001 or z1 - z0 < 0.0001:
				continue
			var cell := PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])
			var remaining: Array[PackedVector2Array] = []
			for clipped_surface in Geometry2D.intersect_polygons(source_polygon, cell):
				remaining.append(clipped_surface)
			for opening in openings:
				var next_remaining: Array[PackedVector2Array] = []
				for surface_polygon in remaining:
					for clipped_surface in Geometry2D.clip_polygons(surface_polygon, opening):
						if clipped_surface.size() >= 3:
							next_remaining.append(clipped_surface)
				remaining = next_remaining
			for clipped_surface in remaining:
				var triangulated := Geometry2D.triangulate_polygon(clipped_surface)
				for ti in range(0, triangulated.size(), 3):
					var a: Vector2 = clipped_surface[triangulated[ti]]
					var b: Vector2 = clipped_surface[triangulated[ti + 1]]
					var c: Vector2 = clipped_surface[triangulated[ti + 2]]
					_add_tri(vertices, normals, Vector3(a.x, top_y, a.y), Vector3(c.x, top_y, c.y), Vector3(b.x, top_y, b.y))
					_add_tri(vertices, normals, Vector3(a.x, bottom_y, a.y), Vector3(b.x, bottom_y, b.y), Vector3(c.x, bottom_y, c.y))
	for i in range(polygon.size()):
		var j := (i + 1) % polygon.size()
		var a := polygon[i]
		var b := polygon[j]
		_add_quad(vertices, normals, Vector3(a.x, bottom_y, a.y), Vector3(b.x, bottom_y, b.y), Vector3(b.x, top_y, b.y), Vector3(a.x, top_y, a.y))
	for opening in openings:
		var visible_edges := Geometry2D.intersect_polygons(opening, source_polygon)
		for visible_opening in visible_edges:
			for edge_index in range(visible_opening.size()):
				var p0 := visible_opening[edge_index]
				var p1 := visible_opening[(edge_index + 1) % visible_opening.size()]
				_add_quad(vertices, normals, Vector3(p0.x, bottom_y, p0.y), Vector3(p0.x, top_y, p0.y), Vector3(p1.x, top_y, p1.y), Vector3(p1.x, bottom_y, p1.y))
	return _array_mesh(vertices, normals)

func _is_detail_node(node: Node) -> bool:
	if not node is Node3D or node.get_script() == null:
		return false
	return node.get_script().resource_path == DETAIL_SCRIPT_PATH

func _make_custom_foundation_mesh() -> ArrayMesh:
	var polygon: Array[Vector2] = []
	for point in custom_points:
		polygon.append(Vector2(point.x, point.z))
	var bottom_y := -thickness * 0.5 if centered_origin else 0.0
	var top_y := thickness * 0.5 if centered_origin else thickness
	var hatch_mesh := _make_hatch_surface_mesh(polygon, top_y, bottom_y)
	if hatch_mesh != null:
		return hatch_mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(1, custom_points.size() - 1):
		var a := custom_points[0]
		var b := custom_points[i]
		var c := custom_points[i + 1]
		_add_tri(vertices, normals, Vector3(a.x, top_y, a.z), Vector3(c.x, top_y, c.z), Vector3(b.x, top_y, b.z))
		_add_tri(vertices, normals, Vector3(a.x, bottom_y, a.z), Vector3(b.x, bottom_y, b.z), Vector3(c.x, bottom_y, c.z))
	for i in range(custom_points.size()):
		var j := (i + 1) % custom_points.size()
		var a := custom_points[i]
		var b := custom_points[j]
		_add_quad(vertices, normals, Vector3(a.x, bottom_y, a.z), Vector3(b.x, bottom_y, b.z), Vector3(b.x, top_y, b.z), Vector3(a.x, top_y, a.z))
	return _array_mesh(vertices, normals)

func _add_quad(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_tri(v, n, a, b, c)
	_add_tri(v, n, a, c, d)

func _array_mesh(v: PackedVector3Array, n: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _add_tri(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	v.append_array(PackedVector3Array([a, b, c]))
	n.append_array(PackedVector3Array([normal, normal, normal]))
	# Emit the reverse winding too, so every face renders from either side. This is
	# important for thin floors/foundations viewed from below and avoids relying on
	# the cull mode of a user-provided material.
	v.append_array(PackedVector3Array([c, b, a]))
	n.append_array(PackedVector3Array([-normal, -normal, -normal]))

