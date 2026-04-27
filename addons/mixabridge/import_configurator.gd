@tool
class_name MixaBridgeImportConfigurator
extends RefCounted

const SKELETON_NAME := "GeneralSkeleton"

const RETARGET_PARAMS: Dictionary = {
	"retarget/bone_renamer/rename_bones": true,
	"retarget/bone_renamer/unique_node/make_unique": true,
	"retarget/bone_renamer/unique_node/skeleton_name": SKELETON_NAME,
	"retarget/rest_fixer/apply_node_transforms": true,
	"retarget/rest_fixer/normalize_position_tracks": true,
	"retarget/rest_fixer/reset_all_bone_poses_after_import": true,
	"retarget/rest_fixer/retarget_method": 1,
}


func configure_model(model_path: String, bone_map: BoneMap) -> Error:
	return _apply_retarget_settings(model_path, bone_map)


func configure_animations(
	anim_paths: PackedStringArray, bone_map: BoneMap
) -> Error:
	for anim_path: String in anim_paths:
		var err := _apply_retarget_settings(anim_path, bone_map)
		if err != OK:
			push_error(
				"MixaBridge: failed to configure import for " + anim_path
			)
			return err
	return OK


func reimport_model(model_path: String) -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.reimport_files(PackedStringArray([model_path]))


func reimport_animations(anim_paths: PackedStringArray) -> void:
	if anim_paths.is_empty():
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.reimport_files(anim_paths)


func _apply_retarget_settings(
	file_path: String, bone_map: BoneMap
) -> Error:
	var import_path := file_path + ".import"
	var global_import_path := ProjectSettings.globalize_path(import_path)

	if not FileAccess.file_exists(import_path):
		push_error("MixaBridge: .import file not found at " + import_path)
		return ERR_FILE_NOT_FOUND

	var config := ConfigFile.new()
	var err := config.load(global_import_path)
	if err != OK:
		push_error(
			"MixaBridge: cannot parse .import file at " + import_path
		)
		return err

	config.set_value("params", "retarget/bone_map", bone_map)

	for key: String in RETARGET_PARAMS:
		config.set_value("params", key, RETARGET_PARAMS[key])

	err = config.save(global_import_path)
	if err != OK:
		push_error(
			"MixaBridge: cannot save .import file at " + import_path
		)
	return err
