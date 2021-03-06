extends Node
"""
List of paths representing the current scene and its ancestors, leading back to the main menu.

This breadcrumb trail is used for navigation. It keeps track of which scene the user should go back to when they press
the various 'Quit' buttons throughout the game.
"""

"""
Emitted when the user goes back, popping the front item off of the breadcrumb trail

Parameters:
	'prev_path': The path item which was just popped from the breadcrumb trail
"""
signal trail_popped(prev_path)

# Emitted before this class changes the running scene.
signal before_scene_changed

var trail := []

"""
Navigates back one level in the breadcrumb trail.

Pops the front path off of the breadcrumb trail. Emits a signal and changes the current scene.
"""
func pop_trail() -> void:
	var prev_path: String
	if trail:
		prev_path = trail.pop_front()
	emit_signal("trail_popped", prev_path)
	if not "::" in prev_path:
		# '::' is used as a separator for breadcrumb items which do not result in a scene change
		_change_scene()


"""
Navigates forward one level, appending the new path to the breadcrumb trail.

Parameters:
	'path': The path to append to the breadcrumb trail. This is usually a scene path such as 'res://MyScene.tscn', but
		it can also include a '::foo' suffix for navigation paths which do not result in a scene change.
"""
func push_trail(path: String) -> void:
	trail.push_front(path)
	if not "::" in path:
		_change_scene()


"""
Stays at the current level in the breadcrumb trail, but replaces the current navigation path.

Parameters:
	'path': The path to append to the breadcrumb trail. This is usually a scene path such as 'res://MyScene.tscn', but
		it can also include a '::foo' suffix for navigation paths which do not result in a scene change.
"""
func replace_trail(path: String) -> void:
	trail.pop_front()
	trail.push_front(path)
	if not "::" in path:
		_change_scene()


"""
Changes the running scene to the one at the front of the breadcrumb trail.
"""
func _change_scene() -> void:
	emit_signal("before_scene_changed")
	if trail:
		if ResourceCache.has_cached_resource(trail.front()):
			get_tree().change_scene_to(ResourceCache.get_cached_resource(trail.front()))
		else:
			get_tree().change_scene(trail.front())
	else:
		# player popped the top item off the breadcrumb trail (possibly from something like a demo)
		# exit to loading screen and load all resources
		ResourceCache.minimal_resources = false
		get_tree().change_scene("res://src/main/ui/menu/LoadingScreen.tscn")
