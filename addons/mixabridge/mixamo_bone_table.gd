@tool
class_name MixamoBoneTable
extends RefCounted

const MIXAMO_PREFIX_COLON := "mixamorig:"
const MIXAMO_PREFIX_UNDERSCORE := "mixamorig_"

const BONE_MAP: Dictionary = {
	"Hips": "Hips",
	"Spine": "Spine",
	"Spine1": "Chest",
	"Spine2": "UpperChest",
	"Neck": "Neck",
	"Head": "Head",
	"HeadTop_End": "",

	"LeftShoulder": "LeftShoulder",
	"LeftArm": "LeftUpperArm",
	"LeftForeArm": "LeftLowerArm",
	"LeftHand": "LeftHand",

	"RightShoulder": "RightShoulder",
	"RightArm": "RightUpperArm",
	"RightForeArm": "RightLowerArm",
	"RightHand": "RightHand",

	"LeftUpLeg": "LeftUpperLeg",
	"LeftLeg": "LeftLowerLeg",
	"LeftFoot": "LeftFoot",
	"LeftToeBase": "LeftToes",
	"LeftToe_End": "",

	"RightUpLeg": "RightUpperLeg",
	"RightLeg": "RightLowerLeg",
	"RightFoot": "RightFoot",
	"RightToeBase": "RightToes",
	"RightToe_End": "",

	"LeftHandThumb1": "LeftThumbMetacarpal",
	"LeftHandThumb2": "LeftThumbProximal",
	"LeftHandThumb3": "LeftThumbDistal",
	"LeftHandThumb4": "",
	"LeftHandIndex1": "LeftIndexProximal",
	"LeftHandIndex2": "LeftIndexIntermediate",
	"LeftHandIndex3": "LeftIndexDistal",
	"LeftHandIndex4": "",
	"LeftHandMiddle1": "LeftMiddleProximal",
	"LeftHandMiddle2": "LeftMiddleIntermediate",
	"LeftHandMiddle3": "LeftMiddleDistal",
	"LeftHandMiddle4": "",
	"LeftHandRing1": "LeftRingProximal",
	"LeftHandRing2": "LeftRingIntermediate",
	"LeftHandRing3": "LeftRingDistal",
	"LeftHandRing4": "",
	"LeftHandPinky1": "LeftLittleProximal",
	"LeftHandPinky2": "LeftLittleIntermediate",
	"LeftHandPinky3": "LeftLittleDistal",
	"LeftHandPinky4": "",

	"RightHandThumb1": "RightThumbMetacarpal",
	"RightHandThumb2": "RightThumbProximal",
	"RightHandThumb3": "RightThumbDistal",
	"RightHandThumb4": "",
	"RightHandIndex1": "RightIndexProximal",
	"RightHandIndex2": "RightIndexIntermediate",
	"RightHandIndex3": "RightIndexDistal",
	"RightHandIndex4": "",
	"RightHandMiddle1": "RightMiddleProximal",
	"RightHandMiddle2": "RightMiddleIntermediate",
	"RightHandMiddle3": "RightMiddleDistal",
	"RightHandMiddle4": "",
	"RightHandRing1": "RightRingProximal",
	"RightHandRing2": "RightRingIntermediate",
	"RightHandRing3": "RightRingDistal",
	"RightHandRing4": "",
	"RightHandPinky1": "RightLittleProximal",
	"RightHandPinky2": "RightLittleIntermediate",
	"RightHandPinky3": "RightLittleDistal",
	"RightHandPinky4": "",
}


static func strip_mixamo_prefix(bone_name: String) -> String:
	if bone_name.begins_with(MIXAMO_PREFIX_COLON):
		return bone_name.substr(MIXAMO_PREFIX_COLON.length())
	if bone_name.begins_with(MIXAMO_PREFIX_UNDERSCORE):
		return bone_name.substr(MIXAMO_PREFIX_UNDERSCORE.length())
	return bone_name


static func get_profile_bone_name(mixamo_name: String) -> String:
	var stripped := strip_mixamo_prefix(mixamo_name)
	if BONE_MAP.has(stripped):
		return BONE_MAP[stripped]
	return ""


static func detect_mixamo_prefix(skeleton: Skeleton3D) -> String:
	for bone_idx: int in skeleton.get_bone_count():
		var bone_name: String = skeleton.get_bone_name(bone_idx)
		if bone_name.begins_with(MIXAMO_PREFIX_COLON):
			return MIXAMO_PREFIX_COLON
		if bone_name.begins_with(MIXAMO_PREFIX_UNDERSCORE):
			return MIXAMO_PREFIX_UNDERSCORE
	return ""
