@tool
extends EditorInspectorPlugin

# ******************************************************************************

var plugin: EditorPlugin
var checks = []
var categories = {}
var sections = {}

# ******************************************************************************

func get_all_children(node, _children=[]):
	for child in node.get_children():
		_children.append(child)

		if child.get_child_count():
			get_all_children(child, _children)

	return _children

func get_inspector_properties():
	var inspector = plugin.get_editor_interface().get_inspector()
	return get_all_children(inspector)

# ------------------------------------------------------------------------------

func _can_handle(object) -> bool:
	return true

var selected_properties = {}

func property_selected(value, source):
	if value:
		selected_properties[source.property_name] = true
	else:
		selected_properties.erase(source.property_name)

func _parse_end(object: Object) -> void:
	checks.clear()
	categories.clear()
	sections.clear()

	var current_category = null
	var current_section = null
	var property = null

	for node in get_inspector_properties():
		var cls = node.get_class()

		if cls == 'EditorInspectorCategory':
			current_category = node
			categories[current_category.name] = []
		if cls == 'EditorInspectorSection':
			current_section = node
			sections[current_section.name] = []

		if ClassDB.get_parent_class(cls) == 'EditorProperty':			
			property = node

			var hbox = HBox.new()
			hbox.gui_input.connect(Callable(self._gui_input).bind(hbox))

			var check = hbox.add(Check.new(node, current_category, current_section))

			if check.category:
				categories[check.category.name].append(check)
			if check.section:
				sections[check.section.name].append(check)

			checks.append(check)
			check.set_pressed_no_signal(node.get_edited_property() in selected_properties)
			check.toggled.connect(Callable(self.property_selected).bind(check))
			check.gui_input.connect(Callable(self._gui_input).bind(check))
			check.mouse_entered.connect(Callable(self.mouse_entered).bind(check))

			var parent = node.get_parent()
			parent.remove_child(node)
			parent.add_child(hbox)

			hbox.add(node)

			node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			node.anchor_right = 1

var ctx = null
var dragging = false
var dragged = false
var click_source = null
var target_state = false

func mouse_entered(source):
	if dragging:
		dragged = true
		if source != click_source:
			source.set_pressed(target_state)

func _gui_input(event, source):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if source is CheckBox:
				if event.pressed:
					dragging = true
					click_source = source
					target_state = !click_source.button_pressed
					click_source.set_pressed_no_signal(!click_source.button_pressed)
				if !event.pressed:
					if dragging:
						if !dragged:
							click_source.button_pressed = !click_source.button_pressed
						dragged = false
					dragging = false

		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if is_instance_valid(ctx):
				ctx.queue_free()

			ctx = ContextMenu.new(source, self.item_selected)

			var root = plugin.get_editor_interface().get_base_control()
			var icon

			icon = root.get_theme_icon('ActionCopy', 'EditorIcons')
			ctx.add_icon_item(icon, 'Copy Selected Properties')
			icon = root.get_theme_icon('ActionPaste', 'EditorIcons')
			ctx.add_icon_item(icon, 'Paste Selected Properties')

			ctx.add_separator()
			icon = root.get_theme_icon('CopyNodePath', 'EditorIcons')
			ctx.add_icon_item(icon, 'Copy Selected Property Paths to Clipboard')
			icon = root.get_theme_icon('CopyNodePath', 'EditorIcons')
			ctx.add_icon_item(icon, 'Copy Selected Properties to Clipboard')
			icon = root.get_theme_icon('CopyNodePath', 'EditorIcons')
			ctx.add_icon_item(icon, 'Copy Selected Properties in PropertyList format')

			ctx.add_separator()
			ctx.add_item('Select All')
			
			if source.category:
				ctx.add_item('Select All in Category')
			if source.section:
				ctx.add_item('Select All in Section')
			icon = root.get_theme_icon('Clear', 'EditorIcons')
			ctx.add_icon_item(icon, 'Clear Selected Properties')

			var pos = root.get_global_mouse_position()
			pos += root.get_screen_position()
			ctx.open(pos)
	
func get_selected_items():
	var selection = []
	for check in checks:
		if check.button_pressed:
			selection.append(check)

	return selection

func get_selected_data():
	var selection = get_selected_items()
	var data = {}
	for check in selection:
		var obj = check.property.get_edited_object()
		var prop = check.property.get_edited_property()
		data[prop] = obj.get(prop)
	return data

var copied_data = null

func paste_data():
	var selection = plugin.get_editor_interface().get_selection()
	var nodes = selection.get_selected_nodes()
	var undo = plugin.get_undo_redo()
	undo.create_action('Set multiple properties')
	for node in nodes:
		for prop_name in copied_data:
			if prop_name in node:
				undo.add_undo_property(node, prop_name, node.get(prop_name))
				undo.add_do_property(node, prop_name, copied_data[prop_name])
	undo.commit_action()

# ******************************************************************************

func item_selected(item):
	var source = ctx.get_parent()
	if ctx.get_parent().get_class() == 'HBoxContainer':
		source = source.get_child(0)

	match item:
		'Copy Selected Properties':
			copied_data = get_selected_data()
		'Paste Selected Properties':
			if copied_data:
				paste_data()
		'Copy Selected Property Paths to Clipboard':
			var out = ''
			for name in get_selected_data():
				out += '%s\n' % [name]
			DisplayServer.clipboard_set(out)
		'Copy Selected Properties to Clipboard':
			var out = ''
			var data = get_selected_data()
			for name in data:
				out += '%s = %s\n' % [name, var_to_str(data[name])]
			DisplayServer.clipboard_set(out)
		'Copy Selected Properties in PropertyList format':
			var out = ''
			var data = get_selected_data()
			for name in data:
				out += 	'{
			name = "%s",
			type = %s,
			usage = PROPERTY_USAGE_DEFAULT
			},' % [name, typeof(data[name])]
			DisplayServer.clipboard_set(out)
		'Select All':
			for check in checks:
				check.button_pressed = true
		'Select All in Category':
			for check in categories[source.category.name]:
				check.button_pressed = true
		'Select All in Section':
			for check in sections[source.section.name]:
				check.button_pressed = true
		'Clear Selected Properties':
			for check in checks:
				check.button_pressed = false

# ******************************************************************************

class Check:
	extends CheckBox

	var property_name = ''
	var property = null
	var category = null
	var section = null

	func _init(_property, _category, _section) -> void:
		property = _property
		property_name = _property.get_edited_property()
		category = _category
		section = _section

		tooltip_text = 'Select this property for multi-copying.'

class HBox:
	extends HBoxContainer

	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		anchor_right = 1

	func add(object):
		add_child(object)

		return object

class ContextMenu:
	extends PopupMenu

	signal item_selected(item)

	func _init(obj=null, cb=null):
		if obj:
			obj.add_child(self)

		if obj and cb:
			item_selected.connect(cb)

		index_pressed.connect(self._on_index_pressed)

	func open(pos=null):
		if pos:
			position = pos
		popup()

	func _on_index_pressed(idx):
		var item = get_item_text(idx)
		item_selected.emit(item)
