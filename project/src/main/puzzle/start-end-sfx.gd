extends Node
"""
Plays sound effects at the start and end of a puzzle.
"""

onready var _go_voices := [$GoVoice0, $GoVoice1, $GoVoice2]

func _ready() -> void:
	PuzzleScore.connect("game_prepared", self, "_on_PuzzleScore_game_prepared")
	PuzzleScore.connect("game_started", self, "_on_PuzzleScore_game_started")
	PuzzleScore.connect("before_level_changed", self, "_on_PuzzleScore_before_level_changed")
	PuzzleScore.connect("after_level_changed", self, "_on_PuzzleScore_after_level_changed")
	PuzzleScore.connect("game_ended", self, "_on_PuzzleScore_game_ended")


func play_ready_sound() -> void:
	$ReadySound.play()


func play_go_sound() -> void:
	$GoSound.play()
	Utils.rand_value(_go_voices).play()


func _on_PuzzleScore_game_prepared() -> void:
	if Level.settings.other.skip_intro:
		# when skipping the intro, we don't play startup sounds
		return
	
	play_ready_sound()


func _on_PuzzleScore_game_started() -> void:
	if Level.settings.other.skip_intro:
		# when skipping the intro, we don't play startup sounds
		return
	
	play_go_sound()


func _on_PuzzleScore_before_level_changed(new_level_id: String) -> void:
	if Level.settings.other.non_interactive or not Level.settings.input_replay.empty():
		# no sound effect or fanfare for non-interactive levels
		return
	
	if new_level_id == Level.settings.id:
		$SectionFailSound.play()
	else:
		$SectionCompleteSound.play()


func _on_PuzzleScore_after_level_changed() -> void:
	$LevelChangeSound.play()


func _on_PuzzleScore_game_ended() -> void:
	var sound: AudioStreamPlayer
	match PuzzleScore.end_result():
		PuzzleScore.Result.LOST:
			sound = $GameOverSound
		PuzzleScore.Result.FINISHED:
			sound = $MatchEndSound
		PuzzleScore.Result.WON:
			sound = $ExcellentSound
	if sound:
		sound.play()
