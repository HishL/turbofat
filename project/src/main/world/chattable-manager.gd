extends Node
"""
Tracks the player's location and the location of all chattables. Handles questions like 'which chattable is focused'
and 'which chattables are nearby'.
"""

# emitted when focus changes to a new object, or when all objects are unfocused.
signal focus_changed

# Maximum range for the player to successfully interact with an object
const MAX_INTERACT_DISTANCE := 240.0

# The player's sprite
var player: Player setget set_player

# The sensei's sprite
var sensei: Sensei setget set_sensei

# The overworld object which the player will currently interact with if they hit the button
var focused_chattable: Node2D setget set_focused_chattable

# 'false' if the player is temporarily disallowed from interacting with nearby objects, such as while chatting
var _focus_enabled := true setget set_focus_enabled, is_focus_enabled

# Mapping from creature ids to Creature objects. The player and sensei are omitted from this mapping, as the player
# can set their own name and it could conflict with overworld creatures.
#
# key: creature id as it appears in dialog files
# value: Creature object corresponding to the creature id
var _creatures_by_id := {}

func _ready() -> void:
	Breadcrumb.connect("before_scene_changed", self, "_on_Breadcrumb_before_scene_changed")


func _physics_process(_delta: float) -> void:
	var min_distance := MAX_INTERACT_DISTANCE
	var new_focused_chattable: Node2D

	if _focus_enabled and player:
		# iterate over all chattables and find the nearest one
		for chattable_obj in get_tree().get_nodes_in_group("chattables"):
			if not is_instance_valid(chattable_obj):
				continue
			if player == chattable_obj:
				continue
			var chattable: Node2D = chattable_obj
			
			var chattable_pos: Vector2 = chattable.global_transform.origin
			var player_pos: Vector2 = player.global_transform.origin
			
			if "chat_extents" in chattable:
				# if the chattable object has extents, we measure from its closest point
				var new_chattable_pos := chattable_pos
				new_chattable_pos.x += clamp(player_pos.x - chattable_pos.x,
						-chattable.chat_extents.x, chattable.chat_extents.x)
				new_chattable_pos.y += clamp(player_pos.y - chattable_pos.y,
						-chattable.chat_extents.y, chattable.chat_extents.y)
				chattable_pos = new_chattable_pos
			
			var distance: float = Global.from_iso(chattable_pos).distance_to(Global.from_iso(player_pos))
			if distance <= min_distance:
				min_distance = distance
				new_focused_chattable = chattable
	
	if new_focused_chattable != focused_chattable:
		set_focused_chattable(new_focused_chattable)


"""
Refreshes our state based on the creatures in the scene, and reconnects some signals.
"""
func refresh_creatures() -> void:
	_creatures_by_id.clear()
	for creature_obj in get_tree().get_nodes_in_group("creatures"):
		var creature: Creature = creature_obj
		_refresh_creature_id(creature)


"""
Returns the Creature object corresponding to the specified chatter name.

A name of SENSEI_ID or PLAYER_ID will return the sensei or player object. To avoid
conflicts, the sensei or player cannot be retrieved by their actual name.
"""
func get_creature_by_id(chat_id: String) -> Creature:
	var result: Creature
	match chat_id:
		CreatureLibrary.SENSEI_ID: result = ChattableManager.sensei
		CreatureLibrary.PLAYER_ID: result = ChattableManager.player
		_:
			if _creatures_by_id.has(chat_id):
				result = _creatures_by_id[chat_id]
	return result


"""
Loads the chat events for the currently focused chattable.

Returns an array of ChatEvent objects for the dialog sequence which the player should see.
"""
func load_chat_events() -> ChatTree:
	var chat_tree: ChatTree
	if focused_chattable is Creature:
		chat_tree = ChatLibrary.chat_tree_for_creature(focused_chattable)
	elif focused_chattable.has_meta("chat_path"):
		var chat_path: String = focused_chattable.get_meta("chat_path")
		chat_tree = ChatLibrary.chat_tree_from_file(chat_path)
	else:
		# can't look up chat events without a chat_path; return an empty array
		push_warning("Chattable %s does not define a 'chat_path' property." % focused_chattable)
	return chat_tree


func set_player(new_player: Player) -> void:
	player = new_player
	_remove_from_creatures_by_id(player)


func set_sensei(new_sensei: Sensei) -> void:
	sensei = new_sensei
	_remove_from_creatures_by_id(sensei)


func set_focused_chattable(new_focused_chattable: Node2D) -> void:
	if focused_chattable == new_focused_chattable:
		return
	
	focused_chattable = new_focused_chattable
	emit_signal("focus_changed")


"""
Returns 'true' if the player will currently interact with the specified object if they hit the button.
"""
func is_focused(chattable: Node2D) -> bool:
	return chattable == focused_chattable


"""
Globally enables/disables focus for nearby objects.

Regardless of whether or not the focused object changed, this notifies all listeners with a 'focus_changed' event.
This is because some UI elements render themselves differently during chats when the player can't interact with
anything.
"""
func set_focus_enabled(new_focus_enabled: bool) -> void:
	_focus_enabled = new_focus_enabled
	
	var old_focused_chattable := focused_chattable
	if not _focus_enabled:
		set_focused_chattable(null)
	
	if old_focused_chattable == focused_chattable:
		emit_signal("focus_changed")


"""
Returns 'true' if focus is globally enabled/disabled for all objects.
"""
func is_focus_enabled() -> bool:
	return _focus_enabled


"""
Substitutes variables in player-visible text.

Text variables are pound sign delimited: 'Hello #player#'. This matches the syntax of Tracery.
"""
func substitute_variables(string: String, full_name: bool = false) -> String:
	var result := string
	if full_name:
		result = result.replace(CreatureLibrary.PLAYER_ID, PlayerData.creature_library.player_def.creature_name)
	else:
		result = result.replace(CreatureLibrary.PLAYER_ID, PlayerData.creature_library.player_def.creature_short_name)
	result = result.replace(CreatureLibrary.SENSEI_ID,
			PlayerData.creature_library.sensei_def.creature_short_name)
	return result


"""
Remove the specified creature from the '_creatures_by_id' mapping.
"""
func _remove_from_creatures_by_id(creature: Creature) -> void:
	for key in _creatures_by_id:
		if _creatures_by_id[key] == creature:
			_creatures_by_id.erase(key)


"""
Updates a creature's entry in the '_creatures_by_id' mapping.
"""
func _refresh_creature_id(creature: Creature) -> void:
	if creature.creature_id:
		_creatures_by_id[creature.creature_id] = creature


"""
Purges all node instances from the manager.

Because ChattableManager is a singleton, node instances must be purged before changing scenes. Otherwise it's
possible for an invisible object from a previous scene to receive focus.
"""
func _on_Breadcrumb_before_scene_changed() -> void:
	player = null
	sensei = null
	focused_chattable = null
