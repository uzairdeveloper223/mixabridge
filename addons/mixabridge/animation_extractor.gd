@tool
class_name MixaBridgeAnimationExtractor
extends RefCounted

var extracted_count: int = 0
var failed_paths: PackedStringArray = []


func extract_and_build_library(
	anim_paths: PackedStringArray,
	library_name: String,
) -> AnimationLibrary:
	extracted_count = 0
	failed_paths.clear()

	var library := AnimationLibrary.new()

	for anim_path: String in anim_paths:
		var packed_scene := load(anim_path) as PackedScene
		if not packed_scene:
			push_error("MixaBridge: cannot load animation scene " + anim_path)
			failed_paths.append(anim_path)
			continue

		var instance := packed_scene.instantiate()
		var anim_player := _find_animation_player(instance)

		if not anim_player:
			push_error(
				"MixaBridge: no AnimationPlayer in " + anim_path
			)
			instance.queue_free()
			failed_paths.append(anim_path)
			continue

		var added_from_this_file := false
		for lib_name: StringName in anim_player.get_animation_library_list():
			var lib := anim_player.get_animation_library(lib_name)
			for anim_name: StringName in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				var clean_name := _derive_animation_name(
					anim_path, String(anim_name)
				)
				var duplicate := anim.duplicate(true) as Animation
				var add_err := library.add_animation(clean_name, duplicate)
				if add_err != OK:
					push_error(
						"MixaBridge: failed to add animation '"
						+ clean_name + "' from " + anim_path
					)
					continue
				added_from_this_file = true

		if added_from_this_file:
			extracted_count += 1

		instance.queue_free()

	return library


func extract_and_build_library_named(
	anim_paths: PackedStringArray,
	display_names: PackedStringArray,
	library_name: String,
) -> AnimationLibrary:
	extracted_count = 0
	failed_paths.clear()

	var library := AnimationLibrary.new()

	for i: int in range(anim_paths.size()):
		var anim_path: String = anim_paths[i]
		var user_name: String = display_names[i] if i < display_names.size() else ""

		var packed_scene := load(anim_path) as PackedScene
		if not packed_scene:
			push_error("MixaBridge: cannot load animation scene " + anim_path)
			failed_paths.append(anim_path)
			continue

		var instance := packed_scene.instantiate()
		var anim_player := _find_animation_player(instance)

		if not anim_player:
			push_error(
				"MixaBridge: no AnimationPlayer in " + anim_path
			)
			instance.queue_free()
			failed_paths.append(anim_path)
			continue

		var added_from_this_file := false
		var clip_index := 0
		for lib_name: StringName in anim_player.get_animation_library_list():
			var lib := anim_player.get_animation_library(lib_name)
			for anim_name: StringName in lib.get_animation_list():
				var anim := lib.get_animation(anim_name)
				var final_name: StringName
				if not user_name.is_empty() and clip_index == 0:
					final_name = StringName(user_name)
				elif not user_name.is_empty():
					final_name = StringName(
						user_name + "_" + str(clip_index)
					)
				else:
					final_name = _derive_animation_name(
						anim_path, String(anim_name)
					)
				var duplicate := anim.duplicate(true) as Animation
				var add_err := library.add_animation(final_name, duplicate)
				if add_err != OK:
					push_error(
						"MixaBridge: failed to add animation '"
						+ final_name + "' from " + anim_path
					)
					continue
				added_from_this_file = true
				clip_index += 1

		if added_from_this_file:
			extracted_count += 1

		instance.queue_free()

	return library


func add_library_to_player(
	anim_player: AnimationPlayer,
	library: AnimationLibrary,
	library_name: String,
) -> Error:
	if not anim_player.has_animation_library(library_name):
		return anim_player.add_animation_library(library_name, library)
	var existing_lib := anim_player.get_animation_library(library_name)
	for anim_name: StringName in library.get_animation_list():
		var anim := library.get_animation(anim_name)
		var final_name := _deduplicate_name(anim_name, existing_lib)
		existing_lib.add_animation(final_name, anim)
	return OK


func _deduplicate_name(
	name: StringName, library: AnimationLibrary
) -> StringName:
	if not library.has_animation(name):
		return name
	var base := String(name)
	var i := 2
	while library.has_animation(StringName(base + "_" + str(i))):
		i += 1
	return StringName(base + "_" + str(i))


func save_library(
	library: AnimationLibrary, save_path: String
) -> Error:
	var dir_path := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	return ResourceSaver.save(library, save_path)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child: Node in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null


func _derive_animation_name(
	file_path: String, anim_name: String
) -> StringName:
	var base := file_path.get_file().get_basename()
	base = base.replace("mixamorig_", "").replace("mixamorig:", "")
	base = base.to_snake_case()
	var skip_names := ["", "default", "mixamo.com", "mixamo_com"]
	if anim_name in skip_names:
		return StringName(base)
	var clean_anim := anim_name.to_snake_case()
	if clean_anim in ["mixamo_com", "default"]:
		return StringName(base)
	if clean_anim == base:
		return StringName(base)
	return StringName(base + "_" + clean_anim)
