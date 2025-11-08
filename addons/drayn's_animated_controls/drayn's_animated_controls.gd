@tool
extends EditorPlugin


func _enable_plugin() -> void:
	print("HI :>")


func _disable_plugin() -> void:
	print("BYE :<")


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
