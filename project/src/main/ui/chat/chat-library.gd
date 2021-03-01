extends Node
"""
Loads dialog from files.

Dialog is stored as a set of json resources. This class parses those json resources into ChatEvents so they can be fed
into the UI.
"""

const PREROLL_SUFFIX := "000"
const POSTROLL_SUFFIX := "100"

"""
Loads a conversation for the specified creature.

Each creature has a sequence of conversations defined by their 'chat selectors'. This method goes through a creature's
chat selectors until it finds one suitable for the current game state.

Parameters:
	'creature': The creature whose conversation should be returned

	'forced_level_id': (Optional) The current level being chosen. If omitted, the level_id will be calculated based on
			the first unfinished unlocked level available.
"""
func chat_tree_for_creature(creature: Creature, forced_level_id: String = "") -> ChatTree:
	var state := _creature_chat_state(creature.creature_id, forced_level_id)
	var level_id: String = state["level_id"]
	var chat_tree := chat_tree_for_creature_def(creature.creature_def, state)

	if level_id:
		# schedule a level to launch when the dialog completes
		Level.set_launched_level(level_id)

	return chat_tree


"""
Returns the chat tree for the specified creature.

Returns null if the chat tree cannot be found.
"""
func chat_tree_for_creature_id(creature_id: String, forced_level_id: String = "") -> ChatTree:
	var creature_def: CreatureDef = PlayerData.creature_library.get_creature_def(creature_id)
	var state := _creature_chat_state(creature_id, forced_level_id)

	return chat_tree_for_creature_def(creature_def, state)


"""
Returns the chat tree for the specified creature.

Returns null if the chat tree cannot be found.
"""
func chat_tree_for_creature_def(creature_def: CreatureDef, state: Dictionary) -> ChatTree:
	var creature_id := creature_def.creature_id
	var filler_ids := filler_ids_for_creature(creature_id, creature_def.dialog)
	var chosen_dialog := choose_dialog_from_chat_selectors(creature_def.chat_selectors, state, filler_ids)

	var chat_tree := chat_tree_for_chat_id(creature_def, chosen_dialog)
	if not chat_tree and has_preroll(chosen_dialog):
	    chat_tree = chat_tree_for_preroll(chosen_dialog)
	if not chat_tree:
		push_warning("Failed to load chat tree '%s' for creature '%s'.\nCould not find file '%s' or '%s'" % \
				[chosen_dialog, creature_id,
				creature_dialog_path(creature_id, chosen_dialog),
				_preroll_path(chosen_dialog)])

	return chat_tree


"""
Returns the chat tree for the specified creature and chat id.

Returns null if the chat tree cannot be found.
"""
func chat_tree_for_chat_id(creature_def: CreatureDef, chat_id: String) -> ChatTree:
	var chat_tree: ChatTree
	if creature_def.dialog.has(chat_id):
		chat_tree = ChatTree.new()
		chat_tree.from_json_dict(creature_def.dialog[chat_id])
		chat_tree.history_key = "dialog/%s/%s" % [creature_def.creature_id, chat_id]
	elif FileUtils.file_exists(creature_dialog_path(creature_def.creature_id, chat_id)):
		chat_tree = chat_tree_from_file(creature_dialog_path(creature_def.creature_id, chat_id))
	
	return chat_tree


func chat_tree_for_preroll(level_id: String) -> ChatTree:
	return chat_tree_for_level_cutscene(level_id, _preroll_path(level_id))


"""
Returns the chat tree for the cutscene which plays after the current level.

Returns null if the chat tree cannot be found.
"""
func chat_tree_for_postroll(level_id: String) -> ChatTree:
	return chat_tree_for_level_cutscene(level_id, _postroll_path(level_id))


func chat_tree_for_level_cutscene(level_id: String, cutscene_path: String) -> ChatTree:
	var chat_tree: ChatTree
	if FileUtils.file_exists(cutscene_path):
		chat_tree = chat_tree_from_file(cutscene_path)

	return chat_tree


func has_preroll(level_id: String) -> bool:
	return FileUtils.file_exists(_preroll_path(level_id))


func has_postroll(level_id: String) -> bool:
	return FileUtils.file_exists(_postroll_path(level_id))


func creature_dialog_path(creature_id: String, chat_id: String) -> String:
	return "res://assets/main/creatures/primary/%s/%s.json" % [creature_id, chat_id.replace("_", "-")]


"""
Returns a ChatIcon enum representing the creature's next conversation.
"""
func chat_icon_for_creature(creature: Creature) -> int:
	var result := ChatIcon.NONE
	if creature == ChattableManager.sensei or creature == ChattableManager.player:
		# no chat icon for player or sensei
		pass
	elif LevelLibrary.first_unfinished_level_id_for_creature(creature.creature_id):
		# food chat icon if the chat will launch a puzzle
		result = ChatIcon.FOOD
	else:
		# filler/speech icon for normal conversations
		var state := _creature_chat_state(creature.creature_id)
		var filler_ids := filler_ids_for_creature(creature.creature_id, creature.dialog)
		var chosen_dialog := choose_dialog_from_chat_selectors(creature.chat_selectors, state, filler_ids)
		result = ChatIcon.FILLER if filler_ids.has(chosen_dialog) else ChatIcon.SPEECH
	
	return result


"""
Loads the chat events from the specified json file.
"""
func chat_tree_from_file(path: String) -> ChatTree:
	var chat_tree := ChatTree.new()
	var history_key := path
	history_key = StringUtils.remove_end(history_key, ".json")
	history_key = StringUtils.remove_start(history_key, "res://assets/main/")
	history_key = history_key.replace("creatures/primary", "dialog")
	history_key = history_key.replace("-", "_")
	chat_tree.history_key = history_key
	
	if not FileUtils.file_exists(path):
		push_error("File not found: %s" % path)
	else:
		var tree_text: String = FileUtils.get_file_as_text(path)
		var json_tree := _parse_json_tree(tree_text)
		chat_tree.from_json_dict(json_tree)
	
	return chat_tree


"""
Calculates the dialog id for the current conversation.

This method goes through a creature's chat selectors until it finds one suitable for the current game state. If none
are found, it returns a filler conversation instead.
"""
func choose_dialog_from_chat_selectors(chat_selectors: Array, state: Dictionary, filler_ids: Array) -> String:
	var creature_id: String = state.get("creature_id", "")
	var result: String
	
	var level_id: String = state.get("level_id", "")
	if not level_id:
		level_id = LevelLibrary.first_unfinished_level_id_for_creature(creature_id)
	if level_id:
		result = level_id

	if not result:
		# no level available; find a suitable conversation
		for chat_selector_obj in chat_selectors:
			var chat_selector: Dictionary = chat_selector_obj

			var repeat_age: int = chat_selector.get("repeat", 25)
			var history_key := "dialog/%s/%s" % [creature_id, chat_selector["dialog"]]
			var chat_age: int = PlayerData.chat_history.get_chat_age(history_key)
			if chat_age < repeat_age:
				# skip; we've had this conversation too recently
				continue

			var if_conditions: Array = chat_selector.get("if_conditions", [])
			var if_conditions_met := true
			for if_condition in if_conditions:
				if not _if_condition_met(if_condition, state):
					if_conditions_met = false
					break
			if not if_conditions_met:
				# skip; one or more if conditions weren't met
				continue

			# success; return the current chat selector's dialog
			result = chat_selector["dialog"]
			break
	
	if not result:
		# no suitable conversation was found; find a suitable filler conversation instead
		var result_chat_age: int
		
		for filler_id in filler_ids:
			var history_key := "dialog/%s/%s" % [creature_id, filler_id]
			var chat_age: int = PlayerData.chat_history.get_chat_age(history_key)
			if not result or chat_age > result_chat_age:
				# found an older filler conversation; replace the current result
				result = filler_id
				result_chat_age = chat_age
			
			if result and result_chat_age == -1:
				break
	
	return result


"""
Returns the dialog filler IDs for the specified creature.

Examines the creature's dialog and resource files, and returns any dialog ids with names like 'filler_014'.
"""
func filler_ids_for_creature(creature_id: String, creature_dialog: Dictionary) -> Array:
	var filler_ids := []
	for i in range(0, 1000):
		var filler_id := "filler_%03d" % i
		var path := "res://assets/main/creatures/primary/%s/%s.json" % \
				[creature_id, filler_id.replace("_", "-")]
		if creature_dialog.has(filler_id) or FileUtils.file_exists(path):
			filler_ids.append(filler_id)
		else:
			break
	return filler_ids


"""
Add lull characters to the specified string.

Lull characters make the chat UI briefly pause at parts of the dialog. We add these after periods, commas and other
punctuation.
"""
func add_lull_characters(s: String) -> String:
	if "/" in s:
		# if the sentence already contains lull characters, we leave it alone
		return s
	
	var transformer := StringTransformer.new(s)
	
	# add pauses after certain kinds of punctuation
	transformer.sub("([!.?,])", "$1/")
	
	# add pauses after dashes, but not in hyphenated words
	transformer.sub("(-)(?=[/!.?,\\- ])", "$1/")
	
	# strip pauses from ellipses which conclude a line, unless the entire sentence is an ellipsis
	if transformer.search("[^/!.?,\\- ]"):
		for _i in range(0, 10):
			var old_transformed := transformer.transformed
			transformer.sub("/([/!.?,\\-]*)$", "$1")
			if old_transformed == transformer.transformed:
				break
	
	# remove lull character from the end of the line
	transformer.transformed = transformer.transformed.trim_suffix("/")
	
	return transformer.transformed


"""
Add many lull characters to the specified string to make it pause after every character.

This can be used for very short sentences like 'OH, MY!!!'
"""
func add_mega_lull_characters(s: String) -> String:
	var transformer := StringTransformer.new(s)
	
	# long pause between words
	transformer.sub(" ", "// ")
	
	# short pause between letters, punctuation
	transformer.sub("([^/ ])", "$1/")
	
	# remove lull character from the end of the line
	transformer.transformed = transformer.transformed.trim_suffix("/")
	return transformer.transformed


"""
Returns 'true' if the specified if condition is met by the current game state.
"""
func _if_condition_met(if_condition: String, state: Dictionary) -> bool:
	return state.get(if_condition, false)


"""
Parses a json dialog tree from the specified json string.

Our dialog parser needs a dictionary wrapped in an array wrapped in a dictionary. We parse simpler json structures by
wrapping the parsed objects ourselves. This prevents trivial dialog sequences such as 'Tweet!' from requiring
two extra json wrapper objects.
"""
func _parse_json_tree(json: String) -> Dictionary:
	var json_tree: Dictionary
	var parsed = parse_json(json)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has(""):
		json_tree = parsed
	elif typeof(parsed) == TYPE_DICTIONARY:
		# We were given a dictionary corresponding to a dialog line. Wrap it into a tree.
		var parsed_dict: Dictionary = parsed
		json_tree = {"" : [parsed]}
		
		# move the version to the root
		if parsed_dict.has("version"):
			json_tree["version"] = parsed_dict.get("version")
			parsed_dict.erase("version")
	elif typeof(parsed) == TYPE_ARRAY:
		var parsed_array: Array = parsed
		# We were given an array corresponding to a dialog branch. Wrap it into a tree.
		json_tree = {"" : parsed}
		
		# move the version to the root
		for item_obj in parsed_array:
			var item_dict: Dictionary = item_obj
			if item_dict.has("version"):
				json_tree["version"] = item_dict.get("version")
				item_dict.erase("version")
	else:
		push_error("Invalid json type: %s" % typeof(parsed))
	return json_tree


"""
Returns metadata about a creature's recent chats, and whether they're due for an interesting chat.
"""
func _creature_chat_state(creature_id: String, forced_level_id: String = "") -> Dictionary:
	var result := {
		"creature_id": creature_id,
		"notable_chat": PlayerData.chat_history.get_filler_count(creature_id) > 0,
		"level_id": forced_level_id
	}
	
	return result


func _preroll_path(level_id: String) -> String:
	return "res://assets/main/puzzle/levels/cutscenes/%s-%s.json" % \
			[level_id.replace("_", "-"), PREROLL_SUFFIX]


func _postroll_path(level_id: String) -> String:
	return "res://assets/main/puzzle/levels/cutscenes/%s-%s.json" % \
			[level_id.replace("_", "-"), POSTROLL_SUFFIX]
