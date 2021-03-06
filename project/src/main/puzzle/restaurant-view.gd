extends Control
"""
Showing the chef character and active customer in a restaurant scene.

As the player drops blocks and scores points, the characters animate and react.
"""

# virtual property; value is only exposed through getters/setters
var current_creature_index: int setget set_current_creature_index, get_current_creature_index

# bonus points scored for recent lines; used for determining when the chef should smile
var _recent_bonuses := []

func _ready() -> void:
	# Godot doesn't like when ViewportContainers have a different size from their Viewport, so we can't set
	# these values in the editor. Otherwise it keeps changing the values back.
	$CustomerView/Viewport.size = $CustomerView.rect_size * 4
	$ChefView/Viewport.size = $ChefView.rect_size * 4
	
	PuzzleScore.connect("game_ended", self, "_on_PuzzleScore_game_ended")
	PuzzleScore.connect("game_prepared", self, "_on_PuzzleScore_game_prepared")
	PuzzleScore.connect("combo_changed", self, "_on_PuzzleScore_combo_changed")
	PuzzleScore.connect("topped_out", self, "_on_PuzzleScore_topped_out")
	PuzzleScore.connect("added_line_score", self, "_on_PuzzleScore_added_line_score")
	
	get_chef().connect("creature_name_changed", self, "_on_Chef_creature_name_changed")
	for customer in get_customers():
		customer.connect("creature_name_changed", self, "_on_Customer_creature_name_changed")
	_refresh_chef_name()
	_refresh_customer_name()


"""
Pans the camera to a new creature. This also changes which creature will be fed.
"""
func set_current_creature_index(new_index: int) -> void:
	$RestaurantViewport/Scene.current_creature_index = new_index


func get_current_creature_index() -> int:
	return $RestaurantViewport/Scene.current_creature_index


func get_customer(creature_index: int = -1) -> Creature:
	return $RestaurantViewport/Scene.get_customer(creature_index)


func get_chef() -> Creature:
	return $RestaurantViewport/Scene.get_chef()


"""
Returns an array of Creature objects representing customers in the scene.
"""
func get_customers() -> Array:
	return $RestaurantViewport/Scene.get_customers()


"""
Recolors the creature according to the specified creature definition. This involves updating shaders and sprite
properties.
"""
func summon_creature(creature_index: int = -1) -> void:
	var creature_def := CreatureDef.new()
	if PlayerData.creature_queue.has_primary_creature():
		creature_def = PlayerData.creature_queue.pop_primary_creature()
	else:
		creature_def = CreatureLoader.random_def()
	$RestaurantViewport/Scene.summon_creature(creature_def, creature_index)


"""
Scroll to a new creature and replace the old creature.
"""
func scroll_to_new_creature(new_creature_index: int = -1) -> void:
	var old_creature_index: int = get_current_creature_index()
	if new_creature_index == -1:
		new_creature_index = (old_creature_index + randi() % 2 + 1) % 3
	set_current_creature_index(new_creature_index)
	$RestaurantViewport/Scene.get_customer().restart_idle_timer()
	yield(get_tree().create_timer(0.5), "timeout")
	summon_creature(old_creature_index)


"""
Temporarily suppresses 'hello' and 'door chime' sounds.
"""
func start_suppress_sfx_timer() -> void:
	for customer in get_customers():
		customer.start_suppress_sfx_timer()
	$RestaurantViewport/Scene.start_suppress_sfx_timer()


func _refresh_customer_name() -> void:
	$CustomerNametag/Panel.refresh_creature(get_customer())


func _refresh_chef_name() -> void:
	$RestaurantNametag/Panel.refresh_creature(get_chef())


func _on_Chef_creature_name_changed() -> void:
	_refresh_chef_name()


"""
If they ended the previous game while serving a creature, we scroll to a new one
"""
func _on_PuzzleScore_game_prepared() -> void:
	if get_customer().feed_count > 0:
		scroll_to_new_creature()


"""
Cycle out the customer when the combo resets to 0.
"""
func _on_PuzzleScore_combo_changed(value: int) -> void:
	if value > 0:
		# if the combo is not resetting, we ignore the change
		return
	
	if PuzzleScore.no_more_customers:
		pass
	elif PuzzleScore.game_active:
		get_customer().play_goodbye_voice()
		scroll_to_new_creature()
	
	# losing your combo doesn't erase the 'recent bonus' value, but decreases it a lot
	_recent_bonuses = _recent_bonuses.slice(3, _recent_bonuses.size() - 1)
	if PuzzleScore.game_active:
		get_chef().play_mood(ChatEvent.Mood.DEFAULT)


func _on_PuzzleScore_topped_out() -> void:
	get_chef().play_mood(ChatEvent.Mood.CRY0)


"""
When clearing lines, the chef smiles if they're scoring a lot of bonuses.
"""
func _on_PuzzleScore_added_line_score(combo_score: int, box_score: int) -> void:
	_recent_bonuses.append(combo_score + box_score)
	if _recent_bonuses.size() >= 6:
		_recent_bonuses = _recent_bonuses.slice(_recent_bonuses.size() - 6, _recent_bonuses.size() - 1)
	var total_bonus := 0
	for bonus in _recent_bonuses:
		total_bonus += bonus
	
	if total_bonus >= 15 * 6:
		get_chef().play_mood(ChatEvent.Mood.SMILE0)


"""
When the game ends, the chef smiles/cries/rages based on how they did.
"""
func _on_PuzzleScore_game_ended() -> void:
	var mood: int = ChatEvent.Mood.NONE
	match PuzzleScore.end_result():
		PuzzleScore.Result.NONE:
			pass
		PuzzleScore.Result.LOST:
			mood = Utils.rand_value([ChatEvent.Mood.RAGE1, ChatEvent.Mood.RAGE2,
					ChatEvent.Mood.CRY1, ChatEvent.Mood.THINK1])
		PuzzleScore.Result.FINISHED:
			mood = ChatEvent.Mood.SMILE0
		PuzzleScore.Result.WON:
			mood = ChatEvent.Mood.LAUGH1
	if mood != ChatEvent.Mood.NONE:
		get_chef().play_mood(mood)
		_recent_bonuses = []


func _on_Customer_creature_name_changed() -> void:
	_refresh_customer_name()


func _on_RestaurantScene_current_creature_index_changed(_value: int) -> void:
	_refresh_customer_name()
