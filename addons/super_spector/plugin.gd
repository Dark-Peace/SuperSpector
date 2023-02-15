@tool
extends EditorPlugin

# ******************************************************************************

var inspector_plugin

func _enter_tree():
	inspector_plugin = preload('inspector_plugin.gd').new()
	inspector_plugin.plugin = self
	
	var selection = get_editor_interface().get_selection()
	selection.selection_changed.connect(inspector_plugin.editor_selection_changed)
	add_inspector_plugin(inspector_plugin)

func _exit_tree():
	remove_inspector_plugin(inspector_plugin)
	inspector_plugin = null
