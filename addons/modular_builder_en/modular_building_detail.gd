@tool
class_name ModularBuilderDetail
extends Node3D

enum DetailType { WINDOW, DOOR, HATCH }
enum DetailMode { OPENING, SEPARATE_OBJECT }
enum WindowStyle { SINGLE_PANE, CROSS_PANE }
enum DoorStyle { FLAT, PANELED }

@export var detail_type: DetailType = DetailType.WINDOW:
	set(value):
		detail_type = value
		_rebuild()
@export var detail_mode: DetailMode = DetailMode.OPENING:
	set(value):
		detail_mode = value
		_rebuild()
@export var window_style: WindowStyle = WindowStyle.SINGLE_PANE:
	set(value):
		window_style = value
		_rebuild()
@export var door_style: DoorStyle = DoorStyle.FLAT:
	set(value):
		door_style = value
		_rebuild()
@export_range(0.2, 5.0, 0.1, "suffix:m") var width: float = 1.0:
	set(value):
		width = value
		_rebuild()
@export_range(0.2, 5.0, 0.1, "suffix:m") var height: float = 1.0:
	set(value):
		height = value
		_rebuild()
@export_range(0.02, 0.5, 0.01, "suffix:m") var frame_depth: float = 0.08:
	set(value):
		frame_depth = value
		_rebuild()
@export_range(0.02, 0.5, 0.01, "suffix:m") var frame_width: float = 0.08:
	set(value):
		frame_width = value
		_rebuild()
@export var follow_host_thickness: bool = true:
	set(value):
		follow_host_thickness = value
		_rebuild()
@export var surface_material: Material:
	set(value):
		surface_material = value
		_rebuild()
@export var frame_material: Material:
	set(value):
		frame_material = value
		_rebuild()
@export var panel_material: Material:
	set(value):
		panel_material = value
		_rebuild()

func _ready() -> void:
	set_notify_transform(true)
	_rebuild()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_inside_tree():
		var host := get_parent()
		if host != null and host.has_method("_rebuild"):
			host.call("_rebuild")

func _on_host_thickness_changed() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.name == "DetailGeometry":
			remove_child(child)
			child.queue_free()
	var host := get_parent()
	if host != null and host.has_method("_rebuild"):
		host.call("_rebuild")
	if detail_mode == DetailMode.OPENING:
		return
	var holder := Node3D.new()
	holder.name = "DetailGeometry"
	add_child(holder)
	var scene_root: Node = null
	if Engine.is_editor_hint() and not has_meta("modular_builder_preview"):
		scene_root = get_tree().edited_scene_root
	if scene_root:
		holder.owner = scene_root
	var effective_depth := _effective_frame_depth()
	var frame := minf(maxf(frame_width, 0.02), minf(width, height) * 0.45)
	if detail_type == DetailType.HATCH:
		_add_box(holder, "LeftFrame", Vector3(frame, effective_depth, height), Vector3(-width * 0.5 + frame * 0.5, 0.0, 0.0), _frame_material())
		_add_box(holder, "RightFrame", Vector3(frame, effective_depth, height), Vector3(width * 0.5 - frame * 0.5, 0.0, 0.0), _frame_material())
		_add_box(holder, "NearFrame", Vector3(width, effective_depth, frame), Vector3(0.0, 0.0, -height * 0.5 + frame * 0.5), _frame_material())
		_add_box(holder, "FarFrame", Vector3(width, effective_depth, frame), Vector3(0.0, 0.0, height * 0.5 - frame * 0.5), _frame_material())
		_add_box(holder, "HatchPanel", Vector3(width - frame * 2.0, effective_depth * 0.35, height - frame * 2.0), Vector3(0.0, effective_depth * 0.4, 0.0), _panel_material())
		return
	_add_box(holder, "LeftFrame", Vector3(frame, height, effective_depth), Vector3(-width * 0.5 + frame * 0.5, 0.0, 0.0), _frame_material())
	_add_box(holder, "RightFrame", Vector3(frame, height, effective_depth), Vector3(width * 0.5 - frame * 0.5, 0.0, 0.0), _frame_material())
	_add_box(holder, "TopFrame", Vector3(width, frame, effective_depth), Vector3(0.0, height * 0.5 - frame * 0.5, 0.0), _frame_material())
	if detail_type != DetailType.DOOR:
		_add_box(holder, "BottomFrame", Vector3(width, frame, effective_depth), Vector3(0.0, -height * 0.5 + frame * 0.5, 0.0), _frame_material())
	if detail_type == DetailType.WINDOW:
		_add_box(holder, "WindowPanel", Vector3(maxf(width - frame * 2.0, 0.02), maxf(height - frame * 2.0, 0.02), effective_depth * 0.35), Vector3.ZERO, _panel_material())
		if window_style == WindowStyle.CROSS_PANE:
			_add_box(holder, "VerticalMullion", Vector3(frame * 0.55, height - frame * 2.0, effective_depth * 0.4), Vector3.ZERO, _frame_material())
			_add_box(holder, "HorizontalMullion", Vector3(width - frame * 2.0, frame * 0.55, effective_depth * 0.4), Vector3.ZERO, _frame_material())
	elif detail_type == DetailType.DOOR:
		_add_box(holder, "DoorPanel", Vector3(width - frame * 2.0, height - frame, effective_depth * 0.45), Vector3(0.0, -frame * 0.5, 0.0), _panel_material())
		if door_style == DoorStyle.PANELED:
			var inset_depth := maxf(effective_depth * 0.04, 0.005)
			var panel_width := (width - frame * 2.0) * 0.82
			var panel_height := maxf((height - frame) * 0.28, 0.05)
			for panel_index in range(2):
				var panel_y := -frame * 0.5 + (panel_index - 0.5) * (panel_height + frame * 0.25)
				_add_box(holder, "DoorInset_%d" % panel_index, Vector3(panel_width, panel_height, inset_depth), Vector3(0.0, panel_y, effective_depth * 0.24), _frame_material())

func _effective_frame_depth() -> float:
	if follow_host_thickness:
		var host := get_parent()
		if host != null:
			var host_thickness = host.get("thickness")
			if host_thickness is float or host_thickness is int:
				var depth := float(host_thickness)
				if detail_type == DetailType.WINDOW or detail_type == DetailType.DOOR:
					depth *= 1.25
				return maxf(depth, 0.02)
	return frame_depth

func _frame_material() -> Material:
	return frame_material if frame_material != null else surface_material

func _panel_material() -> Material:
	return panel_material if panel_material != null else surface_material

func _add_box(holder: Node3D, node_name: String, box_size: Vector3, box_position: Vector3, material: Material = null) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.position = box_position
	mesh_instance.material_override = material if material != null else surface_material
	holder.add_child(mesh_instance)
	if Engine.is_editor_hint() and not has_meta("modular_builder_preview"):
		var scene_root := get_tree().edited_scene_root
		if scene_root:
			mesh_instance.owner = scene_root

