@tool
extends EditorPlugin

# ******************************************************************************

var inspector_plugin

func _enter_tree():
	inspector_plugin = preload('inspector_plugin.gd').new()
	inspector_plugin.plugin = self
	add_inspector_plugin(inspector_plugin)

func _exit_tree():
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
