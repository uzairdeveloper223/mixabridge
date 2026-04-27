@tool
class_name MixaBridgeBoneMapper
extends RefCounted

var mapped_bones: Dictionary = {}
var unmapped_bones: PackedStringArray = []
var existing_animations: PackedStringArray = []
var skeleton_bone_count: int = 0
var detected_prefix: String = ""


func create_bone_map_for_scene(scene_path: String) -> BoneMap:
	var packed_scene := load(scene_path) as PackedScene
	if not packed_scene:
		push_error("MixaBridge: cannot load scene at " + scene_path)
		return null

	var instance := packed_scene.instantiate()
	var skeleton := _find_skeleton(instance)
	if not skeleton:
		push_error("MixaBridge: no Skeleton3D found in " + scene_path)
		instance.queue_free()
		return null

	var bone_map := _build_bone_map(skeleton)
	_collect_existing_animations(instance)
	instance.queue_free()
	return bone_map


func create_bone_map_for_skeleton(skeleton: Skeleton3D) -> BoneMap:
	return _build_bone_map(skeleton)


func get_skeleton_from_scene(scene_path: String) -> Skeleton3D:
	var packed_scene := load(scene_path) as PackedScene
	if not packed_scene:
		return null
	var instance := packed_scene.instantiate()
	var skeleton := _find_skeleton(instance)
	return skeleton


func save_bone_map(bone_map: BoneMap, save_path: String) -> Error:
	var dir_path := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	return ResourceSaver.save(bone_map, save_path)


func _build_bone_map(skeleton: Skeleton3D) -> BoneMap:
	mapped_bones.clear()
	unmapped_bones.clear()
	existing_animations.clear()
	skeleton_bone_count = skeleton.get_bone_count()
	detected_prefix = MixamoBoneTable.detect_mixamo_prefix(skeleton)

	var bone_map := BoneMap.new()
	var profile := SkeletonProfileHumanoid.new()
	bone_map.set_profile(profile)

	for bone_idx: int in skeleton_bone_count:
		var original_name: String = skeleton.get_bone_name(bone_idx)
		var profile_name: String = MixamoBoneTable.get_profile_bone_name(
			original_name
		)

		if profile_name.is_empty():
			unmapped_bones.append(original_name)
			continue

		if profile.find_bone(profile_name) == -1:
			unmapped_bones.append(original_name)
			continue

		bone_map.set_skeleton_bone_name(profile_name, original_name)
		mapped_bones[original_name] = profile_name

	return bone_map


func _collect_existing_animations(root: Node) -> void:
	var anim_player := _find_animation_player(root)
	if not anim_player:
		return
	for lib_name: StringName in anim_player.get_animation_library_list():
		var lib := anim_player.get_animation_library(lib_name)
		for anim_name: StringName in lib.get_animation_list():
			var display_name := String(anim_name)
			if not String(lib_name).is_empty():
				display_name = String(lib_name) + "/" + display_name
			existing_animations.append(display_name)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child: Node in node.get_children():
		var result := _find_skeleton(child)
		if result:
			return result
	return null


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child: Node in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null
