@tool
extends EditorPlugin

const PIECE_SCRIPT = preload("res://addons/modular_builder_en/modular_piece.gd")
const DETAIL_SCRIPT = preload("res://addons/modular_builder_en/modular_building_detail.gd")
const TOOL_NONE := ""
const TOOL_FOUNDATION := "foundation"
const TOOL_FOUNDATION_SQUARE := "foundation_square"
const TOOL_FOUNDATION_TRIANGLE := "foundation_triangle"
const TOOL_WALL := "wall"
const TOOL_FLOOR_SQUARE := "floor_square"
const TOOL_FLOOR_TRIANGLE := "floor_triangle"
const TOOL_WINDOW := "detail_window"
const TOOL_DOOR := "detail_door"
const TOOL_HATCH := "detail_hatch"
const METERS_TO_GODOT_UNITS := 1.0
const DOOR_DEFAULT_SCALE := 0.8
const DOOR_DEFAULT_WIDTH_METERS := 0.87 * DOOR_DEFAULT_SCALE
const DOOR_DEFAULT_HEIGHT_METERS := 2.15 * DOOR_DEFAULT_SCALE
const MARKER_RADIUS := 8.0
const MARKER_HIT_RADIUS := 18.0

var dock: VBoxContainer
var _creation_row: HFlowContainer
var _tool_row: HFlowContainer
var _detail_options_row: HFlowContainer
var _foundation_type_selected := ModularBuilderPiece.PieceType.FOUNDATION_SQUARE
var size_spin: SpinBox
var detail_width_spin: SpinBox
var detail_height_spin: SpinBox
var detail_height_offset_spin: SpinBox
var _detail_height_offset_label: Label
var detail_mode_option: OptionButton
var detail_style_option: OptionButton
var status_label: Label
var active_tool := TOOL_NONE
var pending_points: Array[Vector3] = []
var _redirecting_selection := false
var _marker_container: Node3D
var _marker_root: ModularBuilderPiece
var _marker_point_nodes: Array[Label3D] = []
var _side_button_nodes: Array[Label3D] = []
var _side_material: StandardMaterial3D
var _tool_button_group: ButtonGroup
var _tool_buttons: Dictionary = {}
var _active_button_key := ""
var _last_created_piece: ModularBuilderPiece
var _detail_preview: ModularBuilderDetail
var _preview_material: StandardMaterial3D
var _preview_camera: Camera3D
var _preview_screen_position := Vector2.ZERO
var _save_module_dialog: FileDialog
var _load_module_dialog: FileDialog
var _selected_window_style := ModularBuilderDetail.WindowStyle.SINGLE_PANE
var _selected_door_style := ModularBuilderDetail.DoorStyle.FLAT

func _ready() -> void:
	set_process(true)
	_side_material = StandardMaterial3D.new()
	_side_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_side_material.albedo_color = Color(0.18, 0.95, 0.52)
	_side_material.no_depth_test = true
	_side_material.cull_mode = BaseMaterial3D.CULL_DISABLED

func _process(_delta: float) -> void:
	_sync_vertex_markers()

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "Modular Builder"
	dock.custom_minimum_size = Vector2(0, 110)
	_creation_row = HFlowContainer.new()
	dock.add_child(_creation_row)
	_creation_row.add_child(_label("Size:"))
	size_spin = SpinBox.new()
	size_spin.min_value = 0.5
	size_spin.max_value = 8.0
	size_spin.step = 0.5
	size_spin.value = 2.0
	size_spin.suffix = " m"
	size_spin.custom_minimum_size = Vector2(100, 0)
	_creation_row.add_child(size_spin)
	var create_button := _make_icon_button("res://addons/modular_builder_en/icons/add_building.svg", "Add ModularBuilderPiece", Color(0.22, 0.30, 0.38))
	create_button.pressed.connect(_add_piece)
	_creation_row.add_child(create_button)
	var rotate_button := _make_icon_button("res://addons/modular_builder_en/icons/rotate.svg", "Rotate selected piece by 90°", Color(0.22, 0.30, 0.38))
	rotate_button.pressed.connect(_rotate_selected_piece)
	_creation_row.add_child(rotate_button)
	var collision_button := _make_icon_button("res://addons/modular_builder_en/icons/collision.svg", "Generate general collision for the selected piece", Color(0.22, 0.30, 0.38))
	collision_button.pressed.connect(_add_general_collision)
	_creation_row.add_child(collision_button)
	var save_module_button := _make_icon_button("res://addons/modular_builder_en/icons/save_module.svg", "Save the selected structure as a .tscn module", Color(0.22, 0.30, 0.38))
	save_module_button.pressed.connect(_show_save_module_dialog)
	_creation_row.add_child(save_module_button)
	var load_module_button := _make_icon_button("res://addons/modular_builder_en/icons/load_module.svg", "Insert a saved module into the scene", Color(0.22, 0.30, 0.38))
	load_module_button.pressed.connect(_show_load_module_dialog)
	_creation_row.add_child(load_module_button)
	_tool_row = HFlowContainer.new()
	dock.add_child(_tool_row)
	_tool_button_group = ButtonGroup.new()
	_tool_button_group.allow_unpress = true
	_add_tool_button("res://addons/modular_builder_en/icons/foundation_square.svg", "Square foundation", TOOL_FOUNDATION_SQUARE, Color(0.08, 0.48, 0.22))
	_add_tool_button("res://addons/modular_builder_en/icons/foundation_triangle.svg", "Triangular foundation", TOOL_FOUNDATION_TRIANGLE, Color(0.08, 0.48, 0.22))
	_add_tool_button("res://addons/modular_builder_en/icons/wall.svg", "Wall", TOOL_WALL, Color(0.65, 0.12, 0.12))
	_add_tool_button("res://addons/modular_builder_en/icons/floor_square.svg", "Square floor", TOOL_FLOOR_SQUARE, Color(0.68, 0.48, 0.06))
	_add_tool_button("res://addons/modular_builder_en/icons/floor_triangle.svg", "Triangular floor", TOOL_FLOOR_TRIANGLE, Color(0.68, 0.48, 0.06))
	_add_tool_button("res://addons/modular_builder_en/icons/window.svg", "Detail: window", TOOL_WINDOW, Color(0.88, 0.22, 0.55))
	_add_tool_button("res://addons/modular_builder_en/icons/door.svg", "Detail: door", TOOL_DOOR, Color(0.88, 0.22, 0.55))
	_add_tool_button("res://addons/modular_builder_en/icons/hatch.svg", "Detail: hatch", TOOL_HATCH, Color(0.88, 0.22, 0.55))
	var cancel_button := _make_icon_button("res://addons/modular_builder_en/icons/cancel.svg", "Deactivate tool", Color(0.34, 0.20, 0.20))
	cancel_button.pressed.connect(_set_tool.bind(TOOL_NONE))
	_tool_row.add_child(cancel_button)
	_detail_options_row = HFlowContainer.new()
	dock.add_child(_detail_options_row)
	_detail_options_row.add_child(_label("Width:"))
	detail_width_spin = _detail_spin(1.0, 0.2, 5.0, 0.05)
	_detail_options_row.add_child(detail_width_spin)
	_detail_options_row.add_child(_label("Height:"))
	detail_height_spin = _detail_spin(1.0, 0.2, 5.0, 0.05)
	_detail_options_row.add_child(detail_height_spin)
	_detail_height_offset_label = _label("Bottom offset:")
	_detail_options_row.add_child(_detail_height_offset_label)
	detail_height_offset_spin = _detail_spin(0.0, -2.0, 2.0, 0.05)
	detail_height_offset_spin.suffix = " m"
	_detail_options_row.add_child(detail_height_offset_spin)
	detail_mode_option = OptionButton.new()
	detail_mode_option.add_item("Opening", ModularBuilderDetail.DetailMode.OPENING)
	detail_mode_option.add_item("Opening + object", ModularBuilderDetail.DetailMode.SEPARATE_OBJECT)
	detail_mode_option.select(0)
	detail_mode_option.tooltip_text = "Choose whether the detail should be an opening only or a separate object that can receive a material."
	_detail_options_row.add_child(detail_mode_option)
	detail_style_option = OptionButton.new()
	detail_style_option.tooltip_text = "Window or door style."
	detail_style_option.item_selected.connect(_on_detail_style_selected)
	_detail_options_row.add_child(detail_style_option)
	detail_width_spin.value_changed.connect(_refresh_detail_preview)
	detail_height_spin.value_changed.connect(_refresh_detail_preview)
	detail_height_offset_spin.value_changed.connect(_refresh_detail_preview)
	detail_mode_option.item_selected.connect(_on_detail_mode_selected)
	_detail_options_row.visible = false
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.albedo_color = Color(1.0, 0.35, 0.72, 0.48)
	_save_module_dialog = FileDialog.new()
	_save_module_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_save_module_dialog.access = FileDialog.ACCESS_RESOURCES
	_save_module_dialog.add_filter("*.tscn", "Godot Scene")
	_save_module_dialog.file_selected.connect(_save_module_to_path)
	add_child(_save_module_dialog)
	_load_module_dialog = FileDialog.new()
	_load_module_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_load_module_dialog.access = FileDialog.ACCESS_RESOURCES
	_load_module_dialog.add_filter("*.tscn", "Godot Scene")
	_load_module_dialog.file_selected.connect(_load_module_from_path)
	add_child(_load_module_dialog)
	status_label = _label("Select a tool to show the available vertices.")
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(status_label)
	add_control_to_bottom_panel(dock, "Modular Builder (English)")
	set_input_event_forwarding_always_enabled()
	get_editor_interface().get_selection().selection_changed.connect(_on_editor_selection_changed)

func _exit_tree() -> void:
	set_process(false)
	var editor_selection := get_editor_interface().get_selection()
	if editor_selection.selection_changed.is_connected(_on_editor_selection_changed):
		editor_selection.selection_changed.disconnect(_on_editor_selection_changed)
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
	_clear_marker_container()
	_clear_detail_preview()
	update_overlays()

func _handles(object: Object) -> bool:
	return object is ModularBuilderPiece

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label

func _detail_spin(value: float, minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.suffix = " m"
	spin.custom_minimum_size = Vector2(84, 0)
	return spin

func _make_icon_button(icon_path: String, tooltip: String, color: Color) -> Button:
	var button := Button.new()
	button.icon = load(icon_path) as Texture2D
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(48, 48)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 30)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(4)
	normal.set_border_width_all(1)
	normal.border_color = Color(0.02, 0.02, 0.02)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.16)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.lightened(0.28)
	pressed.border_width_bottom = 3
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func _add_tool_button(icon_path: String, tooltip: String, tool: String, color: Color) -> void:
	var button := _make_icon_button(icon_path, tooltip, color)
	button.toggle_mode = true
	button.button_group = _tool_button_group
	button.toggled.connect(_on_tool_button_toggled.bind(tool))
	_tool_row.add_child(button)
	_tool_buttons[tool] = button

func _on_tool_button_toggled(pressed: bool, tool: String) -> void:
	var is_foundation := tool == TOOL_FOUNDATION_SQUARE or tool == TOOL_FOUNDATION_TRIANGLE
	if pressed:
		_active_button_key = tool
		if is_foundation:
			_foundation_type_selected = ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE if tool == TOOL_FOUNDATION_TRIANGLE else ModularBuilderPiece.PieceType.FOUNDATION_SQUARE
			_set_tool(TOOL_FOUNDATION)
		else:
			_set_tool(tool)
			_update_detail_options(tool)
	else:
		call_deferred("_finish_tool_button_toggle_off", tool)

func _finish_tool_button_toggle_off(tool: String) -> void:
	var button := _tool_buttons.get(tool) as Button
	if button != null and not button.button_pressed and _active_button_key == tool:
		_set_tool(TOOL_NONE)

func _update_detail_options(tool: String) -> void:
	var is_detail := tool == TOOL_WINDOW or tool == TOOL_DOOR or tool == TOOL_HATCH
	_detail_options_row.visible = is_detail
	detail_height_offset_spin.visible = tool != TOOL_HATCH
	_detail_height_offset_label.visible = tool != TOOL_HATCH
	if not is_detail:
		return
	var width := 1.0
	var height := 1.0
	var bottom_offset := 0.5
	if tool == TOOL_DOOR:
		width = DOOR_DEFAULT_WIDTH_METERS
		height = DOOR_DEFAULT_HEIGHT_METERS
		bottom_offset = 0.0
	elif tool == TOOL_HATCH:
		bottom_offset = 0.0
	detail_width_spin.set_value_no_signal(width)
	detail_height_spin.set_value_no_signal(height)
	detail_height_offset_spin.set_value_no_signal(bottom_offset)
	detail_style_option.clear()
	detail_style_option.visible = tool != TOOL_HATCH
	if tool == TOOL_WINDOW:
		detail_style_option.add_item("Single pane", ModularBuilderDetail.WindowStyle.SINGLE_PANE)
		detail_style_option.add_item("Cross panes", ModularBuilderDetail.WindowStyle.CROSS_PANE)
		detail_style_option.select(_selected_window_style)
	elif tool == TOOL_DOOR:
		detail_style_option.add_item("Flat", ModularBuilderDetail.DoorStyle.FLAT)
		detail_style_option.add_item("Paneled", ModularBuilderDetail.DoorStyle.PANELED)
		detail_style_option.select(_selected_door_style)
	_refresh_detail_preview()

func _on_detail_style_selected(index: int) -> void:
	if active_tool == TOOL_WINDOW:
		_selected_window_style = index
		if is_instance_valid(_detail_preview):
			_detail_preview.window_style = index
	elif active_tool == TOOL_DOOR:
		_selected_door_style = index
		if is_instance_valid(_detail_preview):
			_detail_preview.door_style = index
	_refresh_detail_preview()

func _on_detail_mode_selected(_index: int) -> void:
	_refresh_detail_preview()

func _is_detail_tool(tool: String) -> bool:
	return tool == TOOL_WINDOW or tool == TOOL_DOOR or tool == TOOL_HATCH

func _add_piece() -> void:
	var root := get_editor_interface().get_edited_scene_root()
	if root == null or not root is Node3D:
		status_label.text = "Open a 3D scene before adding a piece."
		return
	var piece := Node3D.new()
	piece.name = "ModularBuilderPiece"
	piece.set_script(PIECE_SCRIPT)
	piece.set("piece_type", ModularBuilderPiece.PieceType.BUILDING)
	var module_size_units := _meters_to_godot_units(size_spin.value)
	piece.set("unit_size", module_size_units)
	var foundation := Node3D.new()
	foundation.name = "Foundation"
	foundation.set_script(PIECE_SCRIPT)
	var chosen_type := _foundation_type_selected
	if chosen_type == 1:
		foundation.set("piece_type", ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE)
	else:
		foundation.set("piece_type", ModularBuilderPiece.PieceType.FOUNDATION_SQUARE)
	foundation.set("unit_size", module_size_units)
	foundation.set("centered_origin", true)
	foundation.position.y = foundation.thickness * 0.5
	piece.add_child(foundation, true)
	foundation.owner = root
	var undo := get_undo_redo()
	undo.create_action("Add ModularBuilderPiece")
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "owner", root)
	undo.add_do_property(foundation, "owner", root)
	undo.add_undo_method(root, "remove_child", piece)
	undo.add_do_method(get_editor_interface().get_selection(), "clear")
	undo.add_do_method(get_editor_interface().get_selection(), "add_node", piece)
	undo.commit_action()
	_last_created_piece = foundation
	_active_button_key = TOOL_FOUNDATION_TRIANGLE if _foundation_type_selected == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE else TOOL_FOUNDATION_SQUARE
	_set_tool(TOOL_FOUNDATION)

func _meters_to_godot_units(meters: float) -> float:
	return meters * METERS_TO_GODOT_UNITS

func _show_save_module_dialog() -> void:
	var building := _get_selected_piece()
	if building == null:
		status_label.text = "Select a ModularBuilderPiece structure to save as a module."
		return
	_save_module_dialog.current_file = "%s.tscn" % building.name
	_save_module_dialog.popup_centered_ratio(0.7)

func _show_load_module_dialog() -> void:
	_load_module_dialog.popup_centered_ratio(0.7)

func _save_module_to_path(path: String) -> void:
	var building := _get_selected_piece()
	if building == null:
		status_label.text = "Select a ModularBuilderPiece structure to save as a module."
		return
	var descendants: Array[Node] = []
	_collect_module_nodes(building, descendants)
	var original_owners: Dictionary = {}
	for node in descendants:
		original_owners[node] = node.owner
		node.owner = building
	var packed := PackedScene.new()
	var pack_error := packed.pack(building)
	for node in descendants:
		node.owner = original_owners[node]
	if pack_error != OK:
		status_label.text = "Could not pack the structure as a scene (%s)." % error_string(pack_error)
		return
	var save_error := ResourceSaver.save(packed, path)
	if save_error != OK:
		status_label.text = "Could not save the module (%s)." % error_string(save_error)
		return
	status_label.text = "Module saved: %s" % path

func _collect_module_nodes(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child.name == "ModularBuilderMarkers" or child.has_meta("modular_builder_preview"):
			continue
		result.append(child)
		_collect_module_nodes(child, result)

func _load_module_from_path(path: String) -> void:
	var packed := ResourceLoader.load(path) as PackedScene
	if packed == null:
		status_label.text = "The selected file is not a valid Godot scene."
		return
	var instance := packed.instantiate()
	if not instance is Node3D:
		instance.free()
		status_label.text = "The module scene must have a Node3D as its root."
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		instance.free()
		status_label.text = "Open a scene before inserting a module."
		return
	var anchor := _get_selected_piece()
	if anchor != null:
		var target_world := anchor.global_position + anchor.global_transform.basis.x * maxf(anchor.unit_size, 1.0)
		instance.position = scene_root.to_local(target_world)
	var undo := get_undo_redo()
	undo.create_action("Insert module %s" % instance.name)
	undo.add_do_method(self, "_attach_module", scene_root, instance)
	undo.add_undo_method(self, "_detach_module", scene_root, instance)
	undo.commit_action()
	status_label.text = "Module inserted. Move the piece to the desired location."

func _attach_module(scene_root: Node, instance: Node) -> void:
	if instance.get_parent() != scene_root:
		scene_root.add_child(instance, true)
	instance.owner = scene_root
	var editor_selection := get_editor_interface().get_selection()
	editor_selection.clear()
	editor_selection.add_node(instance)

func _detach_module(scene_root: Node, instance: Node) -> void:
	if instance.get_parent() == scene_root:
		scene_root.remove_child(instance)

func _rotate_selected_piece() -> void:
	var selected_piece := _raw_selected_piece()
	var target := selected_piece
	if selected_piece == null:
		target = _last_created_piece if is_instance_valid(_last_created_piece) and _last_created_piece.is_inside_tree() else null
	elif selected_piece.piece_type == ModularBuilderPiece.PieceType.BUILDING:
		target = null
		if is_instance_valid(_last_created_piece) and _last_created_piece.is_inside_tree() and _is_descendant_of(_last_created_piece, selected_piece):
			target = _last_created_piece
	if target == null:
		status_label.text = "Select a piece or create one to rotate it."
		return
	var old_rotation := target.rotation_degrees
	var undo := get_undo_redo()
	undo.create_action("Rotate piece by 90 degrees")
	undo.add_do_property(target, "rotation_degrees", old_rotation + Vector3(0.0, 90.0, 0.0))
	undo.add_undo_property(target, "rotation_degrees", old_rotation)
	undo.commit_action()
	_last_created_piece = target
	status_label.text = "%s girada em 90°." % target.name
	update_overlays()

func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false

func _raw_selected_piece() -> ModularBuilderPiece:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() == 1 and selected[0] is ModularBuilderPiece:
		return selected[0] as ModularBuilderPiece
	return null

func _add_general_collision() -> void:
	var piece := _get_selected_piece()
	if piece == null:
		status_label.text = "Select a piece to generate general collision."
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	var faces := PackedVector3Array()
	var structure_pieces: Array[ModularBuilderPiece] = []
	_collect_structure_pieces(piece, structure_pieces)
	_collect_scene_pieces(scene_root, structure_pieces)
	_collect_collision_faces(piece, piece, faces, {}, structure_pieces)
	if faces.is_empty():
		status_label.text = "The selected piece has no geometry to collide with."
		return
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	var body := piece.find_child("GeneralCollision", true, false) as StaticBody3D
	var undo := get_undo_redo()
	if body != null:
		var shape_node := body.get_node_or_null("Shape") as CollisionShape3D
		if shape_node == null:
			shape_node = CollisionShape3D.new()
			shape_node.name = "Shape"
			shape_node.shape = concave
			undo.create_action("Add shape to general collision")
			undo.add_do_method(body, "add_child", shape_node, true)
			undo.add_do_property(shape_node, "owner", scene_root)
			undo.add_undo_method(body, "remove_child", shape_node)
		else:
			var old_shape: Shape3D = shape_node.shape
			undo.create_action("Update general collision")
			undo.add_do_property(shape_node, "shape", concave)
			undo.add_undo_property(shape_node, "shape", old_shape)
	else:
		body = StaticBody3D.new()
		body.name = "GeneralCollision"
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape"
		shape_node.shape = concave
		body.add_child(shape_node)
		undo.create_action("Add general collision")
		undo.add_do_method(piece, "add_child", body, true)
		undo.add_do_property(body, "owner", scene_root)
		undo.add_do_property(shape_node, "owner", scene_root)
		undo.add_undo_method(piece, "remove_child", body)
	undo.commit_action()
	status_label.text = "General collision added or updated. Snap markers are excluded."

func _collect_structure_pieces(node: Node, pieces: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece:
		pieces.append(node)
	for child in node.get_children():
		if child.name == "ModularBuilderMarkers" or child.name == "GeneralCollision":
			continue
		_collect_structure_pieces(child, pieces)

func _collect_scene_pieces(node: Node, pieces: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and not pieces.has(node):
		pieces.append(node)
	for child in node.get_children():
		if child.name == "ModularBuilderMarkers" or child.name == "GeneralCollision":
			continue
		_collect_scene_pieces(child, pieces)

func _collect_collision_faces(node: Node, piece_root: ModularBuilderPiece, faces: PackedVector3Array, seen_faces: Dictionary, structure_pieces: Array[ModularBuilderPiece]) -> void:
	if node is MeshInstance3D and node.name == "Geometry" and node.mesh != null:
		var relative_transform: Transform3D = piece_root.global_transform.affine_inverse() * node.global_transform
		var mesh_faces: PackedVector3Array = node.mesh.get_faces()
		var owner_piece := node.get_parent() as ModularBuilderPiece
		for i in range(0, mesh_faces.size(), 3):
			if i + 2 >= mesh_faces.size():
				break
			var local_a: Vector3 = mesh_faces[i]
			var local_b: Vector3 = mesh_faces[i + 1]
			var local_c: Vector3 = mesh_faces[i + 2]
			if _is_connection_face(owner_piece, local_a, local_b, local_c, structure_pieces):
				continue
			# Procedural meshes are emitted double-sided. Deduplicating by unordered
			# vertices below can keep either winding, so normalize walkable top faces
			# before deduplication or some custom foundations bake as non-walkable.
			if _is_piece_top_face(owner_piece, local_a, local_b, local_c):
				if (local_b - local_a).cross(local_c - local_a).y < 0.0:
					var swap := local_b
					local_b = local_c
					local_c = swap
			var a: Vector3 = relative_transform * local_a
			var b: Vector3 = relative_transform * local_b
			var c: Vector3 = relative_transform * local_c
			var key_parts := [_collision_vertex_key(a), _collision_vertex_key(b), _collision_vertex_key(c)]
			key_parts.sort()
			var face_key := "%s|%s|%s" % key_parts
			if seen_faces.has(face_key):
				continue
			seen_faces[face_key] = true
			faces.append_array(PackedVector3Array([a, b, c]))
	for child in node.get_children():
		if child.name == "ModularBuilderMarkers" or child.name == "GeneralCollision":
			continue
		_collect_collision_faces(child, piece_root, faces, seen_faces, structure_pieces)

func _is_piece_top_face(piece: ModularBuilderPiece, a: Vector3, b: Vector3, c: Vector3) -> bool:
	if piece == null:
		return false
	if piece.piece_type != ModularBuilderPiece.PieceType.FLOOR and piece.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_SQUARE and piece.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
		return false
	if absf(a.y - b.y) > 0.002 or absf(a.y - c.y) > 0.002:
		return false
	var top_y := piece.thickness * 0.5 if piece.centered_origin else piece.thickness
	if piece.piece_type == ModularBuilderPiece.PieceType.FLOOR and piece.custom_points.size() >= 3:
		top_y = piece.custom_points[0].y
	return absf(a.y - top_y) < 0.002 and absf(b.y - top_y) < 0.002 and absf(c.y - top_y) < 0.002

func _is_connection_face(piece: ModularBuilderPiece, a: Vector3, b: Vector3, c: Vector3, structure_pieces: Array[ModularBuilderPiece]) -> bool:
	if piece == null:
		return false
	if (piece.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or piece.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE) and _foundation_edge_is_shared(piece, a, b, c, structure_pieces):
		return true
	if piece.piece_type == ModularBuilderPiece.PieceType.FLOOR and piece.custom_points.size() >= 3:
		var bottom_point := piece.custom_points[0] - Vector3.UP * piece.thickness
		return _triangle_on_plane(a, b, c, bottom_point, Vector3.UP)
	if piece.piece_type != ModularBuilderPiece.PieceType.WALL or piece.custom_points.size() < 2:
		return false
	var start: Vector3 = piece.custom_points[0]
	var finish: Vector3 = piece.custom_points[1]
	var direction := (finish - start).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * piece.thickness * 0.5
	var base_normal := (finish - start).cross(side).normalized()
	if _triangle_on_plane(a, b, c, start, base_normal):
		return true
	if _wall_has_floor_contact(piece, structure_pieces):
		if _triangle_on_plane(a, b, c, start + Vector3.UP * piece.unit_size, base_normal):
			return true
	for other in structure_pieces:
		if other == piece or other.piece_type != ModularBuilderPiece.PieceType.WALL or other.custom_points.size() < 2:
			continue
		for endpoint in piece.custom_points:
			var endpoint_world := piece.to_global(endpoint)
			for other_endpoint in other.custom_points:
				if endpoint_world.distance_to(other.to_global(other_endpoint)) < 0.02:
					var local_endpoint := piece.to_local(endpoint_world)
					if _triangle_on_plane(a, b, c, local_endpoint, direction):
						return true
	return false

func _wall_has_floor_contact(wall: ModularBuilderPiece, structure_pieces: Array[ModularBuilderPiece]) -> bool:
	var endpoints: PackedVector3Array = wall.custom_points
	var direction := (endpoints[1] - endpoints[0]).normalized()
	var side := Vector3(-direction.z, 0.0, direction.x).normalized() * wall.thickness * 0.5
	for endpoint in endpoints:
		var top := endpoint + Vector3.UP * wall.unit_size
		for wall_corner in [wall.to_global(top + side), wall.to_global(top - side)]:
			for other in structure_pieces:
				if other.piece_type != ModularBuilderPiece.PieceType.FLOOR or other.custom_points.size() < 3:
					continue
				for floor_point in other.custom_points:
					if wall_corner.distance_to(other.to_global(floor_point)) < 0.02:
						return true
	return false

func _foundation_edge_is_shared(piece: ModularBuilderPiece, a: Vector3, b: Vector3, c: Vector3, structure_pieces: Array[ModularBuilderPiece]) -> bool:
	var polygon := _foundation_polygon(piece)
	for other in structure_pieces:
		if other == piece or (other.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_SQUARE and other.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE):
			continue
		var other_polygon := _foundation_polygon(other)
		for i in range(polygon.size()):
			var p0: Vector2 = polygon[i]
			var p1: Vector2 = polygon[(i + 1) % polygon.size()]
			for j in range(other_polygon.size()):
				var q0: Vector2 = other_polygon[j]
				var q1: Vector2 = other_polygon[(j + 1) % other_polygon.size()]
				var other_base_y := -other.thickness * 0.5 if other.centered_origin else 0.0
				var q0_local := piece.to_local(other.to_global(Vector3(q0.x, other_base_y, q0.y)))
				var q1_local := piece.to_local(other.to_global(Vector3(q1.x, other_base_y, q1.y)))
				var shared := _segments_overlap(p0, p1, Vector2(q0_local.x, q0_local.z), Vector2(q1_local.x, q1_local.z))
				var piece_base_y := -piece.thickness * 0.5 if piece.centered_origin else 0.0
				if shared and absf(q0_local.y - piece_base_y) < 0.02 and absf(q1_local.y - piece_base_y) < 0.02 and _triangle_on_edge(a, b, c, p0, p1):
					return true
	return false

func _triangle_on_edge(a: Vector3, b: Vector3, c: Vector3, edge_a: Vector2, edge_b: Vector2) -> bool:
	return _point_on_edge(Vector2(a.x, a.z), edge_a, edge_b) and _point_on_edge(Vector2(b.x, b.z), edge_a, edge_b) and _point_on_edge(Vector2(c.x, c.z), edge_a, edge_b)

func _point_on_edge(point: Vector2, edge_a: Vector2, edge_b: Vector2) -> bool:
	var edge := edge_b - edge_a
	var length_squared := edge.length_squared()
	if length_squared < 0.000001:
		return false
	var t := (point - edge_a).dot(edge) / length_squared
	var closest := edge_a + edge * clampf(t, 0.0, 1.0)
	return t >= -0.002 and t <= 1.002 and point.distance_to(closest) < 0.002

func _segments_overlap(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var direction := b - a
	var length := direction.length()
	if length < 0.0001:
		return false
	var unit := direction / length
	if absf(unit.x * (c - a).y - unit.y * (c - a).x) > 0.02 or absf(unit.x * (d - a).y - unit.y * (d - a).x) > 0.02:
		return false
	var c_proj := (c - a).dot(unit)
	var d_proj := (d - a).dot(unit)
	var overlap := minf(length, maxf(c_proj, d_proj)) - maxf(0.0, minf(c_proj, d_proj))
	return overlap > 0.02

func _triangle_on_plane(a: Vector3, b: Vector3, c: Vector3, plane_point: Vector3, plane_normal: Vector3) -> bool:
	if plane_normal.length_squared() < 0.000001:
		return false
	var normal := plane_normal.normalized()
	return absf((a - plane_point).dot(normal)) < 0.002 and absf((b - plane_point).dot(normal)) < 0.002 and absf((c - plane_point).dot(normal)) < 0.002

func _collision_vertex_key(point: Vector3) -> String:
	return "%.4f,%.4f,%.4f" % [point.x, point.y, point.z]

func _set_tool(tool: String) -> void:
	active_tool = tool
	_detail_options_row.visible = _is_detail_tool(tool)
	if not _is_detail_tool(tool):
		_clear_detail_preview()
	if tool == TOOL_NONE:
		_active_button_key = ""
	pending_points.clear()
	for button_tool in _tool_buttons:
		_tool_buttons[button_tool].set_pressed_no_signal(button_tool == _active_button_key)
	if tool == TOOL_NONE:
		status_label.text = "Tool deactivated."
	elif _get_selected_piece() == null:
		status_label.text = "Select the corresponding piece in the scene tree."
	elif tool == TOOL_FOUNDATION:
		status_label.text = "Click a + button next to any foundation. Click the tool again to deactivate it."
	elif tool == TOOL_WINDOW or tool == TOOL_DOOR:
		status_label.text = "Click a wall face to place the detail. Edit its mode and dimensions in the Inspector."
	elif tool == TOOL_HATCH:
		status_label.text = "Click a foundation or floor face to place a hatch. Edit it in the Inspector."
	else:
		status_label.text = "Click the blue vertices on the structure. Click the tool again to deactivate it."
	update_overlays()

func _get_selected_piece() -> ModularBuilderPiece:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() != 1:
		return null
	var selected_node := selected[0]
	var selected_piece := selected_node as ModularBuilderPiece
	if selected_piece == null and selected_node is ModularBuilderDetail:
		var parent := selected_node.get_parent()
		while parent != null and not parent is ModularBuilderPiece:
			parent = parent.get_parent()
		selected_piece = parent as ModularBuilderPiece
	if selected_piece == null:
		return null
	var ancestor := selected_piece.get_parent()
	while ancestor != null:
		if ancestor is ModularBuilderPiece and ancestor.piece_type == ModularBuilderPiece.PieceType.BUILDING:
			return ancestor
		ancestor = ancestor.get_parent()
	return selected_piece

func _on_editor_selection_changed() -> void:
	if _redirecting_selection:
		return
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	var redirected_selection: Array[Node] = []
	var needs_redirect := false
	for selected_node in selected:
		var target_node: Node = selected_node
		if selected_node is MeshInstance3D:
			var ancestor := selected_node.get_parent()
			while ancestor != null and not (ancestor is ModularBuilderPiece or ancestor is ModularBuilderDetail):
				ancestor = ancestor.get_parent()
			if ancestor != null:
				target_node = ancestor
				needs_redirect = true
		if not redirected_selection.has(target_node):
			redirected_selection.append(target_node)
	if needs_redirect:
		_redirecting_selection = true
		var editor_selection := get_editor_interface().get_selection()
		editor_selection.clear()
		for target_node in redirected_selection:
			editor_selection.add_node(target_node)
		_redirecting_selection = false
	if active_tool != TOOL_NONE:
		pending_points.clear()
		update_overlays()

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if active_tool != TOOL_NONE and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pending_points.clear()
		status_label.text = "Current points cleared."
		update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if _is_detail_tool(active_tool) and event is InputEventMouseMotion:
		_preview_camera = camera
		_preview_screen_position = event.position
		_update_detail_preview()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var root := _get_selected_piece()
	if root == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if active_tool == TOOL_FOUNDATION:
		var side := _nearest_side_button(camera, event.position)
		if side >= 0:
			_add_foundation_at_side(root, side)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if active_tool == TOOL_NONE:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if active_tool == TOOL_WINDOW or active_tool == TOOL_DOOR or active_tool == TOOL_HATCH:
		if _create_detail_from_click(camera, event.position):
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		status_label.text = "Select or click a wall for a window or door, or a foundation or floor for a hatch."
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	var point := _nearest_vertex(camera, event.position, _get_tool_vertices(root))
	if point == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	for previous_point in pending_points:
		if previous_point.distance_to(point) < 0.02:
			status_label.text = "Choose a different vertex."
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	if active_tool == TOOL_FLOOR_SQUARE and pending_points.size() == 1:
		var first_local := root.to_local(pending_points[0])
		var second_local := root.to_local(point)
		if absf(first_local.x - second_local.x) < 0.02 or absf(first_local.z - second_local.z) < 0.02:
			status_label.text = "To close a square floor, choose the diagonally opposite vertex."
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	pending_points.append(point)
	var needed := _required_clicks()
	if pending_points.size() >= needed:
		_finish_shape(root)
	else:
		status_label.text = "Point %d of %d selected. Click the next vertex." % [pending_points.size(), needed]
	update_overlays()
	return EditorPlugin.AFTER_GUI_INPUT_STOP

func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	pass

func _required_clicks() -> int:
	if active_tool == TOOL_WALL or active_tool == TOOL_FLOOR_SQUARE:
		return 2
	return 3

func _create_detail_from_click(camera: Camera3D, screen_position: Vector2) -> bool:
	var placement := _find_detail_placement(camera, screen_position)
	if placement.is_empty():
		return false
	var detail := _new_detail(placement, false)
	var best_piece := placement.host as ModularBuilderPiece
	if best_piece == null:
		return false
	var undo := get_undo_redo()
	undo.create_action("Add %s" % detail.name)
	undo.add_do_method(self, "_attach_detail", best_piece, detail, get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(self, "_detach_detail", best_piece, detail)
	undo.commit_action()
	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(detail)
	_set_tool(TOOL_NONE)
	status_label.text = "%s created. Edit its style, materials, and dimensions in the Inspector." % detail.name
	return true

func _find_detail_placement(camera: Camera3D, screen_position: Vector2) -> Dictionary:
	var root := _get_selected_piece()
	if root == null or not _is_detail_tool(active_tool):
		return {}
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var candidates: Array[ModularBuilderPiece] = []
	if active_tool == TOOL_HATCH:
		_collect_surface_pieces(root, candidates)
	else:
		_collect_wall_pieces(root, candidates)
	var best_distance := INF
	var best_piece: ModularBuilderPiece
	var best_local := Vector3.ZERO
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.piece_type == ModularBuilderPiece.PieceType.BUILDING:
			continue
		var local_origin := candidate.to_local(ray_origin)
		var local_direction := candidate.to_local(ray_origin + ray_direction) - local_origin
		if active_tool != TOOL_HATCH and candidate.custom_points.size() < 2:
			continue
		var plane_normal := Vector3.UP if active_tool == TOOL_HATCH else Vector3(-candidate.custom_points[1].z + candidate.custom_points[0].z, 0.0, candidate.custom_points[1].x - candidate.custom_points[0].x).normalized()
		if active_tool == TOOL_HATCH and candidate.custom_points.size() >= 3:
			plane_normal = Vector3.UP
		if absf(local_direction.dot(plane_normal)) < 0.0001:
			continue
		var plane_y := 0.0
		var plane_point := Vector3.ZERO
		if active_tool == TOOL_HATCH:
			plane_y = candidate.thickness * 0.5 if candidate.centered_origin else candidate.thickness
			plane_point.y = plane_y
		var distance := (plane_point - local_origin).dot(plane_normal) / local_direction.dot(plane_normal)
		if distance < 0.0 or distance >= best_distance:
			continue
		var hit := local_origin + local_direction * distance
		if active_tool == TOOL_HATCH:
			if candidate.piece_type != ModularBuilderPiece.PieceType.FLOOR and candidate.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_SQUARE and candidate.piece_type != ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
				continue
			if not _point_inside_surface(candidate, Vector2(hit.x, hit.z)):
				continue
		else:
			if candidate.piece_type != ModularBuilderPiece.PieceType.WALL or candidate.custom_points.size() < 2:
				continue
			var a: Vector3 = candidate.custom_points[0]
			var b: Vector3 = candidate.custom_points[1]
			var wall_dir := (b - a).normalized()
			var along := (hit - a).dot(wall_dir)
			var vertical := hit.y - a.y
			if along < 0.0 or along > a.distance_to(b) or vertical < 0.0 or vertical > candidate.unit_size:
				continue
		best_distance = distance
		best_piece = candidate
		best_local = hit
	if best_piece == null:
		return {}
	# best_local was calculated in the candidate piece's own local coordinates.
	# Keep that space for the child detail's transform (especially on attached foundations).
	var host_local := best_local
	var detail_position: Vector3
	var detail_rotation := Vector3.ZERO
	if active_tool == TOOL_HATCH:
		detail_position = Vector3(host_local.x, 0.0, host_local.z)
	else:
		var wall_a: Vector3 = best_piece.custom_points[0]
		var wall_b: Vector3 = best_piece.custom_points[1]
		var direction := (wall_b - wall_a).normalized()
		var n := Vector3(-direction.z, 0.0, direction.x)
		detail_rotation.y = atan2(n.x, n.z)
		var opening_center_y := wall_a.y + detail_height_spin.value * 0.5 + detail_height_offset_spin.value
		detail_position = Vector3((wall_a.x + wall_b.x) * 0.5, opening_center_y, (wall_a.z + wall_b.z) * 0.5)
	return {"host": best_piece, "position": detail_position, "rotation": detail_rotation}

func _new_detail(placement: Dictionary, preview: bool) -> ModularBuilderDetail:
	var detail := Node3D.new()
	detail.set_script(DETAIL_SCRIPT)
	detail.name = "Window" if active_tool == TOOL_WINDOW else ("Door" if active_tool == TOOL_DOOR else "Hatch")
	if active_tool == TOOL_WINDOW:
		detail.set("detail_type", ModularBuilderDetail.DetailType.WINDOW)
	elif active_tool == TOOL_DOOR:
		detail.set("detail_type", ModularBuilderDetail.DetailType.DOOR)
	else:
		detail.set("detail_type", ModularBuilderDetail.DetailType.HATCH)
	detail.set("width", detail_width_spin.value * METERS_TO_GODOT_UNITS)
	detail.set("height", detail_height_spin.value * METERS_TO_GODOT_UNITS)
	detail.set("detail_mode", ModularBuilderDetail.DetailMode.SEPARATE_OBJECT if preview else detail_mode_option.get_selected_id())
	detail.set("surface_material", _preview_material if preview else null)
	if preview:
		var host := placement.host as ModularBuilderPiece
		var preview_depth := host.thickness if host != null else 0.08
		if active_tool == TOOL_WINDOW or active_tool == TOOL_DOOR:
			preview_depth *= 1.25
		detail.set("follow_host_thickness", false)
		detail.set("frame_depth", preview_depth)
	if active_tool == TOOL_WINDOW:
		detail.set("window_style", _selected_window_style)
	elif active_tool == TOOL_DOOR:
		detail.set("door_style", _selected_door_style)
	if preview:
		detail.name = "ModularBuilderPreview"
		detail.set_meta("modular_builder_preview", true)
	detail.position = placement.position
	detail.rotation = placement.rotation
	return detail as ModularBuilderDetail

func _update_detail_preview() -> void:
	if not _is_detail_tool(active_tool) or _preview_camera == null:
		return
	var placement := _find_detail_placement(_preview_camera, _preview_screen_position)
	if placement.is_empty():
		if is_instance_valid(_detail_preview):
			_detail_preview.visible = false
		return
	if not is_instance_valid(_detail_preview) or _detail_preview.detail_type != _detail_type_for_tool(active_tool):
		_clear_detail_preview()
		_detail_preview = _new_detail(placement, true)
		var scene_root := get_editor_interface().get_edited_scene_root()
		if scene_root == null:
			_detail_preview = null
			return
		scene_root.add_child(_detail_preview, true)
	_detail_preview.visible = true
	if not is_equal_approx(_detail_preview.width, detail_width_spin.value):
		_detail_preview.width = detail_width_spin.value
	if not is_equal_approx(_detail_preview.height, detail_height_spin.value):
		_detail_preview.height = detail_height_spin.value
	var host := placement.host as ModularBuilderPiece
	if host != null:
		_detail_preview.global_transform = host.global_transform * Transform3D(Basis.from_euler(placement.rotation), placement.position)

func _detail_type_for_tool(tool: String) -> int:
	if tool == TOOL_DOOR:
		return ModularBuilderDetail.DetailType.DOOR
	if tool == TOOL_HATCH:
		return ModularBuilderDetail.DetailType.HATCH
	return ModularBuilderDetail.DetailType.WINDOW

func _refresh_detail_preview(_value: float = 0.0) -> void:
	if _preview_camera != null:
		_update_detail_preview()

func _clear_detail_preview() -> void:
	if is_instance_valid(_detail_preview):
		_detail_preview.queue_free()
	_detail_preview = null

func _attach_detail(host: ModularBuilderPiece, detail: Node, scene_root: Node) -> void:
	if detail.get_parent() != host:
		host.add_child(detail, true)
	detail.owner = scene_root
	host._rebuild()

func _detach_detail(host: ModularBuilderPiece, detail: Node) -> void:
	if detail.get_parent() == host:
		host.remove_child(detail)
	host._rebuild()

func _collect_surface_pieces(node: Node, pieces: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and (node.piece_type == ModularBuilderPiece.PieceType.FLOOR or node.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or node.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE):
		pieces.append(node)
	for child in node.get_children():
		_collect_surface_pieces(child, pieces)

func _collect_wall_pieces(node: Node, pieces: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and node.piece_type == ModularBuilderPiece.PieceType.WALL:
		pieces.append(node)
	for child in node.get_children():
		_collect_wall_pieces(child, pieces)

func _point_inside_surface(piece: ModularBuilderPiece, point: Vector2) -> bool:
	var polygon := _foundation_polygon(piece) if piece.piece_type != ModularBuilderPiece.PieceType.FLOOR else _piece_polygon_xz(piece)
	if polygon.size() < 3:
		return false
	var inside := false
	var j := polygon.size() - 1
	for i in range(polygon.size()):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[j]
		if (a.y > point.y) != (b.y > point.y) and point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside

func _piece_polygon_xz(piece: ModularBuilderPiece) -> Array[Vector2]:
	var polygon: Array[Vector2] = []
	for point in piece.custom_points:
		polygon.append(Vector2(point.x, point.z))
	return polygon

func _nearest_vertex(camera: Camera3D, screen_position: Vector2, vertices: Array[Vector3]) -> Variant:
	var nearest: Variant = null
	var nearest_distance := MARKER_HIT_RADIUS
	for world_point in vertices:
		if camera.is_position_behind(world_point):
			continue
		var distance := camera.unproject_position(world_point).distance_to(screen_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = world_point
	return nearest

func _sync_vertex_markers() -> void:
	var root := _get_selected_piece()
	var vertex_points: Array[Vector3] = []
	var side_points: Array[Dictionary] = []
	if root != null:
		if active_tool == TOOL_WALL or active_tool == TOOL_FLOOR_SQUARE or active_tool == TOOL_FLOOR_TRIANGLE:
			vertex_points = _get_tool_vertices(root)
		elif active_tool == TOOL_FOUNDATION:
			side_points = _get_side_button_points(root)
	if root != _marker_root or (root == null and _marker_container != null) or vertex_points.size() != _marker_point_nodes.size() or side_points.size() != _side_button_nodes.size():
		_clear_marker_container()
		_marker_root = root
		if root == null:
			return
		_marker_container = Node3D.new()
		_marker_container.name = "ModularBuilderMarkers"
		root.add_child(_marker_container)
		for _point in vertex_points:
			var marker := Label3D.new()
			marker.text = "●"
			marker.font_size = 56
			marker.pixel_size = 0.004
			marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.no_depth_test = true
			marker.modulate = Color(0.05, 0.58, 1.0)
			marker.outline_size = 8
			marker.outline_modulate = Color.BLACK
			_marker_container.add_child(marker)
			_marker_point_nodes.append(marker)
		for _button in side_points:
			var label := Label3D.new()
			label.text = "+"
			label.font_size = 56
			label.outline_size = 8
			label.outline_modulate = Color.BLACK
			label.pixel_size = 0.01
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.modulate = Color(0.2, 1.0, 0.55)
			_marker_container.add_child(label)
			_side_button_nodes.append(label)
	for i in range(vertex_points.size()):
		_marker_point_nodes[i].position = root.to_local(vertex_points[i])
	for i in range(side_points.size()):
		_side_button_nodes[i].position = root.to_local(side_points[i].position)
	if _marker_container:
		_marker_container.visible = active_tool != TOOL_NONE or not side_points.is_empty()

func _clear_marker_container() -> void:
	if is_instance_valid(_marker_container):
		_marker_container.queue_free()
	_marker_container = null
	_marker_root = null
	_marker_point_nodes.clear()
	_side_button_nodes.clear()

func _get_side_button_points(root: ModularBuilderPiece) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for foundation in _get_foundations(root):
		var top_y := foundation.thickness * 0.5 if foundation.centered_origin else foundation.thickness
		var y := top_y + 0.22
		var points := _foundation_polygon(foundation)
		var centroid := Vector2.ZERO
		for point in points:
			centroid += point
		centroid /= points.size()
		for i in range(points.size()):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			if _foundation_edge_is_occupied(root, foundation, a, b):
				continue
			var midpoint := (a + b) * 0.5
			var outward := (midpoint - centroid).normalized()
			var edge_length := a.distance_to(b)
			var neighbor_polygon: Array[Vector2] = []
			if _foundation_type_selected == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE:
				var square_side := minf(foundation.unit_size, edge_length)
				var edge_direction := (b - a).normalized()
				var square_a := midpoint - edge_direction * square_side * 0.5
				var square_b := midpoint + edge_direction * square_side * 0.5
				neighbor_polygon = [square_a, square_b, square_b + outward * square_side, square_a + outward * square_side]
			elif points.size() == 3:
				for source_point in points:
					neighbor_polygon.append(_reflect_point_across_edge(source_point, a, b))
			else:
				neighbor_polygon = [a, b, a + outward * edge_length]
			var custom_points := PackedVector3Array()
			for neighbor_point in neighbor_polygon:
				var base_y := -foundation.thickness * 0.5 if foundation.centered_origin else 0.0
				var foundation_local := Vector3(neighbor_point.x, base_y, neighbor_point.y)
				custom_points.append(root.to_local(foundation.to_global(foundation_local)))
			result.append({
				"position": foundation.to_global(Vector3(midpoint.x + outward.x * 0.55, y, midpoint.y + outward.y * 0.55)),
				"custom_points": custom_points,
				"foundation": foundation
			})
	return result

func _foundation_edge_is_occupied(root: ModularBuilderPiece, foundation: ModularBuilderPiece, edge_a: Vector2, edge_b: Vector2) -> bool:
	var foundation_base_y := -foundation.thickness * 0.5 if foundation.centered_origin else 0.0
	var edge_a_3d := root.to_local(foundation.to_global(Vector3(edge_a.x, foundation_base_y, edge_a.y)))
	var edge_b_3d := root.to_local(foundation.to_global(Vector3(edge_b.x, foundation_base_y, edge_b.y)))
	var target_a := Vector2(edge_a_3d.x, edge_a_3d.z)
	var target_b := Vector2(edge_b_3d.x, edge_b_3d.z)
	for other in _get_foundations(root):
		if other == foundation:
			continue
		var other_polygon := _foundation_polygon(other)
		for i in range(other_polygon.size()):
			var a := other_polygon[i]
			var b := other_polygon[(i + 1) % other_polygon.size()]
			var other_base_y := -other.thickness * 0.5 if other.centered_origin else 0.0
			var a_in_root := root.to_local(other.to_global(Vector3(a.x, other_base_y, a.y)))
			var b_in_root := root.to_local(other.to_global(Vector3(b.x, other_base_y, b.y)))
			var other_a := Vector2(a_in_root.x, a_in_root.z)
			var other_b := Vector2(b_in_root.x, b_in_root.z)
			if absf(a_in_root.y - edge_a_3d.y) < 0.02 and absf(b_in_root.y - edge_b_3d.y) < 0.02 and _segments_overlap(target_a, target_b, other_a, other_b):
				return true
	return false

func _get_foundations(root: ModularBuilderPiece) -> Array[ModularBuilderPiece]:
	var result: Array[ModularBuilderPiece] = []
	if root.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or root.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
		result.append(root)
	for child in root.get_children():
		_collect_foundations(child, result)
	return result

func _collect_foundations(node: Node, result: Array[ModularBuilderPiece]) -> void:
	if node is ModularBuilderPiece and (node.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_SQUARE or node.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE):
		result.append(node)
	for child in node.get_children():
		_collect_foundations(child, result)

func _foundation_polygon(root: ModularBuilderPiece) -> Array[Vector2]:
	if root.custom_points.size() >= 3:
		var custom: Array[Vector2] = []
		for point in root.custom_points:
			custom.append(Vector2(point.x, point.z))
		return custom
	var half := root.unit_size * 0.5
	if root.piece_type == ModularBuilderPiece.PieceType.FOUNDATION_TRIANGLE:
		return [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half)]
	return [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]

func _reflect_point_across_edge(point: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var edge := b - a
	var projection := a + edge * ((point - a).dot(edge) / edge.length_squared())
	return projection * 2.0 - point

func _nearest_side_button(camera: Camera3D, screen_position: Vector2) -> int:
	var root := _get_selected_piece()
	if root == null:
		return -1
	var buttons := _get_side_button_points(root)
	var closest := MARKER_HIT_RADIUS + 5.0
	var result := -1
	for i in range(buttons.size()):
		var point: Vector3 = buttons[i].position
		if camera.is_position_behind(point):
			continue
		var distance := camera.unproject_position(point).distance_to(screen_position)
		if distance < closest:
			closest = distance
			result = i
	return result

func _add_foundation_at_side(root: ModularBuilderPiece, side: int) -> void:
	var buttons := _get_side_button_points(root)
	if side < 0 or side >= buttons.size():
		return
	var scene_root := get_editor_interface().get_edited_scene_root() as Node3D
	var piece := Node3D.new()
	piece.name = "Foundation"
	piece.set_script(PIECE_SCRIPT)
	var source_foundation: ModularBuilderPiece = buttons[side].foundation
	piece.set("unit_size", source_foundation.unit_size)
	piece.set("thickness", source_foundation.thickness)
	piece.set("centered_origin", true)
	piece.set("piece_type", _foundation_type_selected)
	var points_in_root: PackedVector3Array = buttons[side].custom_points
	var pivot := _packed_points_bounds_center(points_in_root)
	pivot.y += source_foundation.thickness * 0.5
	var custom_points := PackedVector3Array()
	for point in points_in_root:
		custom_points.append(point - pivot)
	piece.position = pivot
	var undo := get_undo_redo()
	undo.create_action("Add foundation next to selected edge")
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "custom_points", custom_points)
	undo.add_do_property(piece, "owner", scene_root)
	undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = piece
	status_label.text = "Foundation added to the structure."

func _packed_points_bounds_center(points: PackedVector3Array) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	var minimum := points[0]
	var maximum := points[0]
	for point in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return (minimum + maximum) * 0.5

func _get_tool_vertices(root: ModularBuilderPiece) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if active_tool == TOOL_WALL:
		for foundation in _get_foundations(root):
			var base_y := -foundation.thickness * 0.5 if foundation.centered_origin else 0.0
			var top_y := foundation.thickness * 0.5 if foundation.centered_origin else foundation.thickness
			for point in _foundation_polygon(foundation):
				_add_unique_vertex(result, foundation.to_global(Vector3(point.x, base_y, point.y)))
				_add_unique_vertex(result, foundation.to_global(Vector3(point.x, top_y, point.y)))
	else:
		var walls: Array[Node] = []
		_collect_walls(root, walls)
		for wall_node in walls:
			var wall := wall_node as ModularBuilderPiece
			var endpoints: PackedVector3Array = wall.get("custom_points")
			if endpoints.size() < 2:
				continue
			var direction := (endpoints[1] - endpoints[0]).normalized()
			var side := Vector3(-direction.z, 0.0, direction.x).normalized() * float(wall.get("thickness")) * 0.5
			for endpoint in endpoints:
				var top := endpoint + Vector3.UP * float(wall.get("unit_size"))
				_add_unique_vertex(result, wall.to_global(top + side))
				_add_unique_vertex(result, wall.to_global(top - side))
	return result

func _collect_walls(node: Node, walls: Array[Node]) -> void:
	if node is ModularBuilderPiece and node.piece_type == ModularBuilderPiece.PieceType.WALL and not walls.has(node):
		walls.append(node)
	for child in node.get_children():
		if child is ModularBuilderPiece and child.piece_type == ModularBuilderPiece.PieceType.WALL:
			if not walls.has(child):
				walls.append(child)
		_collect_walls(child, walls)

func _add_unique_vertex(vertices: Array[Vector3], point: Vector3) -> void:
	for existing in vertices:
		if existing.distance_to(point) < 0.02:
			return
	vertices.append(point)

func _finish_shape(root: ModularBuilderPiece) -> void:
	if active_tool == TOOL_WALL:
		_finish_wall_segments(root)
		return
	var local_points := PackedVector3Array()
	for world_point in pending_points:
		local_points.append(root.to_local(world_point))
	var piece := Node3D.new()
	piece.set_script(PIECE_SCRIPT)
	piece.set("centered_origin", true)
	piece.name = "FloorTriangle" if active_tool == TOOL_FLOOR_TRIANGLE else "FloorSquare"
	piece.set("piece_type", ModularBuilderPiece.PieceType.FLOOR)
	piece.set("thickness", root.thickness)
	if active_tool == TOOL_FLOOR_SQUARE:
		var a := local_points[0]
		var b := local_points[1]
		var left := minf(a.x, b.x)
		var right := maxf(a.x, b.x)
		var near_z := minf(a.z, b.z)
		var far_z := maxf(a.z, b.z)
		var y := (a.y + b.y) * 0.5
		local_points = PackedVector3Array([
			Vector3(left, y, near_z), Vector3(right, y, near_z),
			Vector3(right, y, far_z), Vector3(left, y, far_z)
		])
	var floor_pivot := _packed_points_bounds_center(local_points)
	floor_pivot.y -= piece.thickness * 0.5
	piece.position = floor_pivot
	for i in range(local_points.size()):
		local_points[i] -= floor_pivot
	piece.set("custom_points", local_points)
	var undo := get_undo_redo()
	undo.create_action("Create %s from vertices" % piece.name)
	undo.add_do_method(root, "add_child", piece, true)
	undo.add_do_property(piece, "owner", get_editor_interface().get_edited_scene_root())
	undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = piece
	pending_points.clear()
	status_label.text = "%s created inside ModularBuilderPiece. The tool remains active." % piece.name
	update_overlays()

func _finish_wall_segments(root: ModularBuilderPiece) -> void:
	var start_world := pending_points[0]
	var finish_world := pending_points[1]
	var path := finish_world - start_world
	var path_length_squared := path.length_squared()
	if path_length_squared < 0.0001:
		pending_points.clear()
		status_label.text = "The wall endpoints are too close together."
		update_overlays()
		return
	var parameters: Array[float] = [0.0, 1.0]
	for vertex in _get_tool_vertices(root):
		var t := (vertex - start_world).dot(path) / path_length_squared
		if t <= 0.001 or t >= 0.999:
			continue
		var projected := start_world + path * t
		if vertex.distance_to(projected) > 0.02:
			continue
		var already_added := false
		for existing_t in parameters:
			if absf(existing_t - t) < 0.005:
				already_added = true
				break
		if not already_added:
			parameters.append(t)
	parameters.sort()
	var pieces: Array[ModularBuilderPiece] = []
	for i in range(parameters.size() - 1):
		var a_world := start_world.lerp(finish_world, parameters[i])
		var b_world := start_world.lerp(finish_world, parameters[i + 1])
		pieces.append(_make_wall_segment(root, a_world, b_world, i + 1))
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo := get_undo_redo()
	undo.create_action("Create wall in %d segments" % pieces.size())
	for piece in pieces:
		undo.add_do_method(root, "add_child", piece, true)
		undo.add_do_property(piece, "owner", scene_root)
		undo.add_undo_method(root, "remove_child", piece)
	undo.commit_action()
	_last_created_piece = pieces[-1]
	pending_points.clear()
	status_label.text = "Wall split into %d segments at foundation vertices." % pieces.size()
	update_overlays()

func _make_wall_segment(root: ModularBuilderPiece, start_world: Vector3, finish_world: Vector3, index: int) -> ModularBuilderPiece:
	var start := root.to_local(start_world)
	var finish := root.to_local(finish_world)
	var piece_node := Node3D.new()
	piece_node.set_script(PIECE_SCRIPT)
	var piece := piece_node as ModularBuilderPiece
	piece.name = "Wall_%02d" % index
	piece.set("piece_type", ModularBuilderPiece.PieceType.WALL)
	piece.set("unit_size", root.unit_size)
	piece.set("thickness", root.thickness)
	piece.set("centered_origin", true)
	var pivot := (start + finish) * 0.5 + Vector3.UP * root.unit_size * 0.5
	piece.position = pivot
	piece.set("custom_points", PackedVector3Array([start - pivot, finish - pivot]))
	return piece

