@tool
extends VBoxContainer

const GENERATED_DIR := "res://addons/mixabridge/generated/"

var _bone_mapper := MixaBridgeBoneMapper.new()
var _import_configurator := MixaBridgeImportConfigurator.new()
var _animation_extractor := MixaBridgeAnimationExtractor.new()

var _model_path := ""
var _bone_map: BoneMap = null
var _bone_map_save_path := ""
var _animation_paths: PackedStringArray = []
var _linked_player: AnimationPlayer = null
var _linked_player_path: NodePath = NodePath()

@onready var _select_model_button: Button = %SelectModelButton
@onready var _model_status_label: RichTextLabel = %ModelStatusLabel
@onready var _link_player_button: Button = %LinkPlayerButton
@onready var _player_status_label: Label = %PlayerStatusLabel
@onready var _select_anims_button: Button = %SelectAnimsButton
@onready var _anim_file_list: ItemList = %AnimFileList
@onready var _lib_name_edit: LineEdit = %LibNameEdit
@onready var _process_button: Button = %ProcessButton
@onready var _bone_tree: Tree = %BoneTree
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _status_label: Label = %StatusLabel
@onready var _model_file_dialog: FileDialog = %ModelFileDialog
@onready var _anim_file_dialog: FileDialog = %AnimFileDialog
@onready var _reset_button: Button = %ResetButton


func _ready() -> void:
	_select_model_button.pressed.connect(_on_select_model_pressed)
	_link_player_button.pressed.connect(_on_link_player_pressed)
	_select_anims_button.pressed.connect(_on_select_anims_pressed)
	_process_button.pressed.connect(_on_process_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_model_file_dialog.file_selected.connect(_on_model_selected)
	_anim_file_dialog.files_selected.connect(_on_anims_selected)
	_lib_name_edit.text_changed.connect(_on_lib_name_changed)

	_bone_tree.set_column_title(0, "Mixamo Bone")
	_bone_tree.set_column_title(1, "Godot Profile")
	_bone_tree.set_column_expand(0, true)
	_bone_tree.set_column_expand(1, true)

	_set_status("Ready")


func _on_select_model_pressed() -> void:
	_model_file_dialog.popup_centered()


func _on_model_selected(path: String) -> void:
	_model_path = path
	_set_status("Analyzing model...")
	_progress_bar.value = 10.0

	_bone_map = _bone_mapper.create_bone_map_for_scene(path)
	if not _bone_map:
		_set_model_status("[color=red]Failed to analyze model.[/color]")
		_set_status("Error analyzing model")
		_progress_bar.value = 0.0
		return

	var model_name := path.get_file().get_basename()
	_bone_map_save_path = GENERATED_DIR + "bonemap_" + model_name + ".tres"
	var save_err := _bone_mapper.save_bone_map(_bone_map, _bone_map_save_path)
	if save_err != OK:
		_set_model_status("[color=red]Failed to save BoneMap.[/color]")
		_set_status("Error saving BoneMap")
		_progress_bar.value = 0.0
		return

	_progress_bar.value = 30.0
	_set_status("Configuring model import...")

	var config_err := _import_configurator.configure_model(path, _bone_map)
	if config_err != OK:
		_set_model_status(
			"[color=red]Failed to configure import settings.[/color]"
		)
		_set_status("Error configuring import")
		_progress_bar.value = 0.0
		return

	_progress_bar.value = 50.0
	_set_status("Reimporting model...")
	_import_configurator.reimport_model(path)

	_populate_bone_tree()

	var mapped_count := _bone_mapper.mapped_bones.size()
	var total_count := _bone_mapper.skeleton_bone_count
	var prefix_info := ""
	if not _bone_mapper.detected_prefix.is_empty():
		prefix_info = " (prefix: " + _bone_mapper.detected_prefix + ")"

	var anim_info := ""
	if not _bone_mapper.existing_animations.is_empty():
		anim_info = (
			"\nExisting animations: "
			+ ", ".join(_bone_mapper.existing_animations)
		)
	else:
		anim_info = "\nNo existing animations found"

	_set_model_status(
		"[color=green]" + path.get_file() + "[/color]\n"
		+ str(mapped_count) + "/" + str(total_count)
		+ " bones mapped" + prefix_info + anim_info
	)

	_link_player_button.disabled = false
	_progress_bar.value = 60.0
	_set_status("Model processed — now link the AnimationPlayer from your scene")


func _on_link_player_pressed() -> void:
	var selected := EditorInterface.get_selection().get_selected_nodes()
	if selected.is_empty():
		_set_player_status("No node selected — click an AnimationPlayer in the Scene dock", false)
		return

	for node: Node in selected:
		if node is AnimationPlayer:
			_linked_player = node
			_linked_player_path = node.get_path()
			_set_player_status("Linked: " + node.name, true)
			_select_anims_button.disabled = false
			_update_process_button_state()
			_set_status("AnimationPlayer linked — add animation files")
			return

		var player := _find_animation_player_in_tree(node)
		if player:
			_linked_player = player
			_linked_player_path = player.get_path()
			_set_player_status("Linked: " + player.name + " (found under " + node.name + ")", true)
			_select_anims_button.disabled = false
			_update_process_button_state()
			_set_status("AnimationPlayer linked — add animation files")
			return

	_set_player_status("No AnimationPlayer found in selection — select the right node", false)


func _on_select_anims_pressed() -> void:
	_anim_file_dialog.popup_centered()


func _on_anims_selected(paths: PackedStringArray) -> void:
	for path: String in paths:
		if path not in _animation_paths:
			_animation_paths.append(path)
			_anim_file_list.add_item(path.get_file())

	_update_process_button_state()
	_set_status(str(_animation_paths.size()) + " animation file(s) queued")


func _on_process_pressed() -> void:
	if _animation_paths.is_empty() or not _bone_map or not _linked_player:
		return

	if not is_instance_valid(_linked_player):
		_set_player_status("AnimationPlayer was removed — re-link it", false)
		_linked_player = null
		_select_anims_button.disabled = true
		_update_process_button_state()
		return

	var library_name := _lib_name_edit.text.strip_edges()
	if library_name.is_empty():
		library_name = _lib_name_edit.placeholder_text

	_process_button.disabled = true
	_select_anims_button.disabled = true
	_select_model_button.disabled = true
	_link_player_button.disabled = true

	_progress_bar.value = 65.0
	_set_status("Configuring animation imports...")

	var config_err := _import_configurator.configure_animations(
		_animation_paths, _bone_map
	)
	if config_err != OK:
		_set_status("Error configuring animation imports")
		_restore_buttons()
		return

	_progress_bar.value = 75.0
	_set_status("Reimporting animations...")
	_import_configurator.reimport_animations(_animation_paths)

	_progress_bar.value = 85.0
	_set_status("Extracting animations...")

	var library := _animation_extractor.extract_and_build_library(
		_animation_paths, library_name
	)

	var save_path := "res://animations/" + library_name + ".tres"
	var save_err := _animation_extractor.save_library(library, save_path)

	_progress_bar.value = 95.0

	_animation_extractor.add_library_to_player(
		_linked_player, library, library_name
	)

	var result_msg := (
		"Done — " + str(_animation_extractor.extracted_count)
		+ " animation(s) added to " + _linked_player.name
		+ " as '" + library_name + "'"
	)

	if not _animation_extractor.failed_paths.is_empty():
		result_msg += (
			" | " + str(_animation_extractor.failed_paths.size()) + " failed"
		)

	if save_err != OK:
		result_msg += " | Warning: .tres save failed"

	_set_status(result_msg)
	_progress_bar.value = 100.0
	_restore_buttons()


func _on_reset_pressed() -> void:
	_model_path = ""
	_bone_map = null
	_bone_map_save_path = ""
	_animation_paths.clear()
	_linked_player = null
	_linked_player_path = NodePath()
	_anim_file_list.clear()
	_bone_tree.clear()
	_lib_name_edit.text = ""
	_link_player_button.disabled = true
	_select_anims_button.disabled = true
	_process_button.disabled = true
	_model_status_label.text = ""
	_set_player_status("No AnimationPlayer linked", false)
	_progress_bar.value = 0.0
	_set_status("Ready")


func _on_lib_name_changed(_new_text: String) -> void:
	_update_process_button_state()


func _populate_bone_tree() -> void:
	_bone_tree.clear()
	var root := _bone_tree.create_item()

	for original_name: String in _bone_mapper.mapped_bones:
		var profile_name: String = _bone_mapper.mapped_bones[original_name]
		var item := _bone_tree.create_item(root)
		item.set_text(0, original_name)
		item.set_text(1, profile_name)
		item.set_custom_color(0, Color(0.6, 0.9, 0.6))
		item.set_custom_color(1, Color(0.6, 0.9, 0.6))

	for unmapped_name: String in _bone_mapper.unmapped_bones:
		var item := _bone_tree.create_item(root)
		item.set_text(0, unmapped_name)
		item.set_text(1, "(unmapped)")
		item.set_custom_color(0, Color(0.9, 0.6, 0.4))
		item.set_custom_color(1, Color(0.5, 0.5, 0.5))


func _set_model_status(bbcode_text: String) -> void:
	_model_status_label.text = bbcode_text


func _set_player_status(text: String, is_linked: bool) -> void:
	_player_status_label.text = text
	if is_linked:
		_player_status_label.add_theme_color_override(
			"font_color", Color(0.4, 0.8, 0.4)
		)
	else:
		_player_status_label.add_theme_color_override(
			"font_color", Color(0.7, 0.4, 0.4)
		)


func _set_status(text: String) -> void:
	_status_label.text = text


func _update_process_button_state() -> void:
	var ready := (
		not _model_path.is_empty()
		and _linked_player != null
		and not _animation_paths.is_empty()
	)
	_process_button.disabled = not ready


func _restore_buttons() -> void:
	_select_model_button.disabled = false
	_link_player_button.disabled = _model_path.is_empty()
	_select_anims_button.disabled = _linked_player == null
	_update_process_button_state()


func _find_animation_player_in_tree(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child: Node in node.get_children():
		var result := _find_animation_player_in_tree(child)
		if result:
			return result
	return null
