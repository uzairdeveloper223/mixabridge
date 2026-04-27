@tool
extends EditorPlugin

const PANEL_SCENE := preload("res://addons/mixabridge/mixabridge_panel.tscn")

var _panel_instance: Control = null


func _enter_tree() -> void:
	_panel_instance = PANEL_SCENE.instantiate()
	add_control_to_bottom_panel(_panel_instance, "MixaBridge")


func _exit_tree() -> void:
	if _panel_instance:
		remove_control_from_bottom_panel(_panel_instance)
		_panel_instance.queue_free()
		_panel_instance = null
