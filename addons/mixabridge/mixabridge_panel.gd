@tool
extends VBoxContainer

const GENERATED_DIR := "res://addons/mixabridge/generated/"
const NEW_LIBRARY_LABEL := "[ Create New Library ]"

var _bone_mapper := MixaBridgeBoneMapper.new()
var _import_configurator := MixaBridgeImportConfigurator.new()
var _animation_extractor := MixaBridgeAnimationExtractor.new()

var _model_path := ""
var _bone_map: BoneMap = null
var _bone_map_save_path := ""
var _animation_paths: PackedStringArray = []
var _animation_display_names: PackedStringArray = []
var _animation_loop: Array[bool] = []
var _animation_rm_root: Array[bool] = []
var _linked_player: AnimationPlayer = null
var _linked_player_path: NodePath = NodePath()
var _has_processed := false
var _renaming_index := -1
var _existing_anim_count := 0

@onready var _select_model_button: Button = %SelectModelButton
@onready var _model_status_label: RichTextLabel = %ModelStatusLabel
@onready var _link_player_button: Button = %LinkPlayerButton
@onready var _player_status_label: Label = %PlayerStatusLabel
@onready var _select_anims_button: Button = %SelectAnimsButton
@onready var _remove_anim_button: Button = %RemoveAnimButton
@onready var _anim_file_list: Tree = %AnimFileList
@onready var _lib_selector: OptionButton = %LibSelector
@onready var _lib_name_edit: LineEdit = %LibNameEdit
@onready var _process_button: Button = %ProcessButton
@onready var _reprocess_button: Button = %ReprocessButton
@onready var _bone_tree: Tree = %BoneTree
@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _status_label: Label = %StatusLabel
@onready var _model_file_dialog: FileDialog = %ModelFileDialog
@onready var _anim_file_dialog: FileDialog = %AnimFileDialog
@onready var _reset_button: Button = %ResetButton
@onready var _rename_dialog: AcceptDialog = %RenameDialog
@onready var _rename_edit: LineEdit = %RenameEdit


func _ready() -> void:
	_select_model_button.pressed.connect(_on_select_model_pressed)
	_link_player_button.pressed.connect(_on_link_player_pressed)
	_select_anims_button.pressed.connect(_on_select_anims_pressed)
	_remove_anim_button.pressed.connect(_on_remove_anim_pressed)
	_process_button.pressed.connect(_on_process_pressed)
	_reprocess_button.pressed.connect(_on_reprocess_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)
	_model_file_dialog.file_selected.connect(_on_model_selected)
	_anim_file_dialog.files_selected.connect(_on_anims_selected)
	_lib_selector.item_selected.connect(_on_lib_selector_changed)
	_anim_file_list.item_selected.connect(_on_anim_tree_item_selected)
	_anim_file_list.item_activated.connect(_on_anim_tree_item_activated)
	_anim_file_list.item_edited.connect(_on_anim_tree_item_edited)

	_anim_file_list.set_column_title(0, "Animation")
	_anim_file_list.set_column_title(1, "Loop")
	_anim_file_list.set_column_title(2, "Remove Root")
	_anim_file_list.set_column_expand(0, true)
	_anim_file_list.set_column_expand(1, false)
	_anim_file_list.set_column_expand(2, false)
	_anim_file_list.set_column_custom_minimum_width(1, 50)
	_anim_file_list.set_column_custom_minimum_width(2, 100)
	_rename_dialog.confirmed.connect(_on_rename_confirmed)

	_bone_tree.set_column_title(0, "Mixamo Bone")
	_bone_tree.set_column_title(1, "Godot Profile")
	_bone_tree.set_column_expand(0, true)
	_bone_tree.set_column_expand(1, true)

	_lib_name_edit.visible = true
	_lib_selector.visible = false

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

	var config_err := _import_configurator.configure_model(
		path, _bone_map_save_path
	)
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
		_set_player_status(
			"No node selected — click an AnimationPlayer in the Scene dock",
			false,
		)
		return

	for node: Node in selected:
		if node is AnimationPlayer:
			_link_animation_player(node)
			return
		var player := _find_animation_player_in_tree(node)
		if player:
			_link_animation_player(player)
			return

	_set_player_status(
		"No AnimationPlayer found in selection — select the right node",
		false,
	)


func _link_animation_player(player: AnimationPlayer) -> void:
	_linked_player = player
	_linked_player_path = player.get_path()
	_set_player_status("Linked: " + player.name, true)
	_select_anims_button.disabled = false
	_populate_library_selector()
	_update_process_button_state()
	_set_status("AnimationPlayer linked — add animation files")


func _on_select_anims_pressed() -> void:
	_anim_file_dialog.popup_centered()


func _on_anims_selected(paths: PackedStringArray) -> void:
	for path: String in paths:
		if path not in _animation_paths:
			_animation_paths.append(path)
			var display_name := path.get_file().get_basename().to_snake_case()
			_animation_display_names.append(display_name)
			_animation_loop.append(false)
			_animation_rm_root.append(false)
	_rebuild_anim_tree()
	_update_process_button_state()
	_set_status(str(_animation_paths.size()) + " animation file(s) queued")


func _on_anim_tree_item_selected() -> void:
	var item := _anim_file_list.get_selected()
	if not item:
		_remove_anim_button.disabled = true
		return
	_remove_anim_button.disabled = false


func _on_anim_tree_item_activated() -> void:
	var item := _anim_file_list.get_selected()
	if not item: return
	var idx: int = item.get_metadata(0)
	_renaming_index = idx
	_rename_edit.text = _animation_display_names[idx]
	_rename_dialog.popup_centered()
	_rename_edit.select_all()
	_rename_edit.grab_focus()


func _on_rename_confirmed() -> void:
	if _renaming_index < 0 or _renaming_index >= _animation_display_names.size():
		return
	var new_name := _rename_edit.text.strip_edges().to_snake_case()
	if new_name.is_empty():
		return
	if _renaming_index < _existing_anim_count:
		var old_name := _animation_display_names[_renaming_index]
		if old_name != new_name:
			var lib := _get_selected_library()
			if lib and lib.has_animation(old_name) and not lib.has_animation(new_name):
				lib.rename_animation(old_name, new_name)
				_save_current_library(lib)
				_animation_display_names[_renaming_index] = new_name
				_rebuild_anim_tree()
	else:
		_animation_display_names[_renaming_index] = new_name
		_rebuild_anim_tree()
	_renaming_index = -1


func _on_remove_anim_pressed() -> void:
	var item := _anim_file_list.get_selected()
	if not item: return
	var idx: int = item.get_metadata(0)

	if idx < _existing_anim_count:
		var name_to_remove := _animation_display_names[idx]
		var lib := _get_selected_library()
		if lib and lib.has_animation(name_to_remove):
			lib.remove_animation(name_to_remove)
			_save_current_library(lib)
		_animation_display_names.remove_at(idx)
		_existing_anim_count -= 1
		_remove_anim_button.disabled = true
		_rebuild_anim_tree()
		_update_process_button_state()
		_set_status("Removed '" + name_to_remove + "' from library.")
	else:
		_animation_paths.remove_at(idx - _existing_anim_count)
		_animation_loop.remove_at(idx - _existing_anim_count)
		_animation_rm_root.remove_at(idx - _existing_anim_count)
		_animation_display_names.remove_at(idx)
		_remove_anim_button.disabled = true
		_rebuild_anim_tree()
		_update_process_button_state()
		_set_status(str(_animation_paths.size()) + " new animation file(s) queued")


func _on_lib_selector_changed(index: int) -> void:
	var is_new := _lib_selector.get_item_text(index) == NEW_LIBRARY_LABEL
	_lib_name_edit.visible = is_new
	_load_existing_library_anims()
	_update_process_button_state()


func _on_process_pressed() -> void:
	_run_process()


func _on_reprocess_pressed() -> void:
	_run_process()


func _on_anim_tree_item_edited() -> void:
	var item := _anim_file_list.get_edited()
	if not item: return
	var column := _anim_file_list.get_edited_column()
	var idx: int = item.get_metadata(0)
	var is_checked := item.is_checked(column)

	if idx < _existing_anim_count:
		var anim_name := _animation_display_names[idx]
		var lib := _get_selected_library()
		if lib and lib.has_animation(anim_name):
			var anim := lib.get_animation(anim_name)
			if column == 1:
				anim.loop_mode = Animation.LOOP_LINEAR if is_checked else Animation.LOOP_NONE
				_save_current_library(lib)
			elif column == 2:
				if is_checked:
					_animation_extractor.remove_root_track(anim)
					_save_current_library(lib)
					item.set_checked(2, false)
					_set_status("Root motion removed from '" + anim_name + "'")
	else:
		var new_idx := idx - _existing_anim_count
		if column == 1:
			_animation_loop[new_idx] = is_checked
		elif column == 2:
			_animation_rm_root[new_idx] = is_checked


func _get_selected_library() -> AnimationLibrary:
	if not is_instance_valid(_linked_player): return null
	var lib_name := _resolve_library_name()
	if lib_name == "(default)": lib_name = ""
	if lib_name == NEW_LIBRARY_LABEL: return null
	if _linked_player.has_animation_library(lib_name):
		return _linked_player.get_animation_library(lib_name)
	return null


func _save_current_library(lib: AnimationLibrary) -> void:
	var lib_name := _resolve_library_name()
	if lib_name == "(default)": lib_name = ""
	var save_path := "res://animations/" + lib_name + ".tres"
	_animation_extractor.save_library(lib, save_path)


func _run_process() -> void:
	if not _linked_player:
		return
	if _animation_paths.is_empty():
		_set_status("Existing animations are saved instantly. No new files to process.")
		return
	if not _bone_map:
		return

	if not is_instance_valid(_linked_player):
		_set_player_status("AnimationPlayer was removed — re-link it", false)
		_linked_player = null
		_select_anims_button.disabled = true
		_update_process_button_state()
		return

	var library_name := _resolve_library_name()
	if library_name.is_empty():
		_set_status("Enter a library name")
		return

	var root := _anim_file_list.get_root()
	var child := root.get_child(0) if root else null
	var loops: Array[bool] = []
	var rms: Array[bool] = []
	while child:
		var idx: int = child.get_metadata(0)
		var loop := child.is_checked(1)
		var rm := child.is_checked(2)
		if idx >= _existing_anim_count:
			loops.append(loop)
			rms.append(rm)
		child = child.get_next()

	_process_button.disabled = true
	_reprocess_button.disabled = true
	_select_anims_button.disabled = true
	_select_model_button.disabled = true
	_link_player_button.disabled = true

	_progress_bar.value = 65.0
	_set_status("Configuring animation imports...")

	var config_err := _import_configurator.configure_animations(
		_animation_paths, _bone_map_save_path
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

	var new_display_names: PackedStringArray = []
	for i: int in range(_existing_anim_count, _animation_display_names.size()):
		new_display_names.append(_animation_display_names[i])

	var library := _animation_extractor.extract_and_build_library_named(
		_animation_paths, new_display_names, loops, rms, library_name
	)

	var save_path := "res://animations/" + library_name + ".tres"
	var save_err := _animation_extractor.save_library(library, save_path)

	_progress_bar.value = 95.0

	_animation_extractor.add_library_to_player(
		_linked_player, library, library_name
	)

	_has_processed = true
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
	_populate_library_selector()


func _on_reset_pressed() -> void:
	_model_path = ""
	_bone_map = null
	_bone_map_save_path = ""
	_animation_paths.clear()
	_animation_display_names.clear()
	_animation_loop.clear()
	_animation_rm_root.clear()
	_linked_player = null
	_linked_player_path = NodePath()
	_has_processed = false
	_renaming_index = -1
	_existing_anim_count = 0
	_anim_file_list.clear()
	_bone_tree.clear()
	_lib_name_edit.text = ""
	_lib_name_edit.visible = true
	_lib_selector.visible = false
	_lib_selector.clear()
	_link_player_button.disabled = true
	_select_anims_button.disabled = true
	_remove_anim_button.disabled = true
	_process_button.disabled = true
	_reprocess_button.disabled = true
	_model_status_label.text = ""
	_set_player_status("No AnimationPlayer linked", false)
	_progress_bar.value = 0.0
	_set_status("Ready")


func _resolve_library_name() -> String:
	if _lib_selector.visible and _lib_selector.selected >= 0:
		var selected_text := _lib_selector.get_item_text(_lib_selector.selected)
		if selected_text != NEW_LIBRARY_LABEL:
			return selected_text

	var name := _lib_name_edit.text.strip_edges()
	if name.is_empty():
		name = _lib_name_edit.placeholder_text
	return name


func _populate_library_selector() -> void:
	_lib_selector.clear()

	if not _linked_player or not is_instance_valid(_linked_player):
		_lib_selector.visible = false
		_lib_name_edit.visible = true
		return

	var lib_names := _linked_player.get_animation_library_list()
	if lib_names.is_empty():
		_lib_selector.visible = false
		_lib_name_edit.visible = true
		return

	_lib_selector.visible = true

	for lib_name: StringName in lib_names:
		var display := String(lib_name)
		if display.is_empty():
			display = "(default)"
		_lib_selector.add_item(display)

	_lib_selector.add_item(NEW_LIBRARY_LABEL)
	_lib_selector.select(_lib_selector.item_count - 1)
	_lib_name_edit.visible = true


func _load_existing_library_anims() -> void:
	for i: int in range(_existing_anim_count - 1, -1, -1):
		_animation_display_names.remove_at(i)
	_existing_anim_count = 0

	if not _lib_selector.visible or not _linked_player or not is_instance_valid(_linked_player):
		_rebuild_anim_tree()
		return

	var lib_name := _resolve_library_name()
	if lib_name == "(default)": lib_name = ""
	if lib_name == NEW_LIBRARY_LABEL or not _linked_player.has_animation_library(lib_name):
		_rebuild_anim_tree()
		return

	var lib := _linked_player.get_animation_library(lib_name)
	var anim_names := lib.get_animation_list()

	var new_names: PackedStringArray = []
	for name_str: String in _animation_display_names:
		new_names.append(name_str)
	_animation_display_names.clear()

	for anim_name: StringName in anim_names:
		_animation_display_names.append(String(anim_name))

	_existing_anim_count = anim_names.size()

	for name_str: String in new_names:
		_animation_display_names.append(name_str)

	_rebuild_anim_tree()

	if _existing_anim_count > 0:
		_set_status(str(_existing_anim_count) + " existing + " + str(_animation_paths.size()) + " new animation(s)")


func _rebuild_anim_tree() -> void:
	_anim_file_list.clear()
	var root := _anim_file_list.create_item()

	var lib: AnimationLibrary = null
	if _lib_selector.visible and is_instance_valid(_linked_player):
		var lib_name := _resolve_library_name()
		if lib_name == "(default)": lib_name = ""
		if lib_name != NEW_LIBRARY_LABEL and _linked_player.has_animation_library(lib_name):
			lib = _linked_player.get_animation_library(lib_name)

	for i: int in range(_animation_display_names.size()):
		var name_str: String = _animation_display_names[i]
		var is_existing := i < _existing_anim_count
		var item := _anim_file_list.create_item(root)
		item.set_metadata(0, i)
		item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		item.set_editable(1, true)
		item.set_cell_mode(2, TreeItem.CELL_MODE_CHECK)
		item.set_editable(2, true)

		if is_existing:
			item.set_text(0, "[existing] " + name_str)
			item.set_custom_color(0, Color(0.54, 0.54, 0.6))
			if lib and lib.has_animation(name_str):
				var anim := lib.get_animation(name_str)
				item.set_checked(1, anim.loop_mode != Animation.LOOP_NONE)
		else:
			item.set_text(0, name_str)
			var new_idx := i - _existing_anim_count
			item.set_checked(1, _animation_loop[new_idx])
			item.set_checked(2, _animation_rm_root[new_idx])


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
	var ready_for_new := (
		not _model_path.is_empty()
		and _linked_player != null
		and not _animation_paths.is_empty()
	)
	var has_existing := _existing_anim_count > 0 and _linked_player != null
	_process_button.disabled = not (ready_for_new or has_existing)
	_reprocess_button.disabled = not _has_processed


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
