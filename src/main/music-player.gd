extends Node
"""
Plays music.

Ensures only one music track is playing at once. Tries to skip ahead to the parts of the music the player hasn't heard
recently.
"""

# emitted when the currently playing music changes
signal bgm_changed(new_bgm)

# volume to fade out to; once the music reaches this volume, it's stopped
const MIN_VOLUME := -40.0

# volume to fade in to
const MAX_VOLUME := 0.0

# the music currently playing
var _current_bgm: AudioStreamPlayer

"""
Plays a 'chill' song; something suitable for background music when the player's navigating menus or wandering the
overworld.
"""
func play_chill_bgm() -> void:
	play_music($HipHop03, $FreshnessInspector.freshest_start($HipHop03))


func is_playing_chill_bgm() -> bool:
	return _current_bgm in [$HipHop03]


"""
Plays an 'upbeat' song; something suitable when the player's playing a puzzle scenario.
"""
func play_upbeat_bgm() -> void:
	play_music($House01, $FreshnessInspector.freshest_start($House01))


"""
Gradually fades a track in.

Usually it's OK for a track to start abrubtly, but sometimes we want to fade music in more gradually.
"""
func fade_in() -> void:
	_current_bgm.volume_db = -40.0
	$MusicTween.fade_in(_current_bgm)


"""
Abruptly stops the currently playing track.
"""
func stop() -> void:
	if _current_bgm == null:
		return
	
	$MusicTween.fade_out(_current_bgm)
	_current_bgm = null
	emit_signal("bgm_changed", _current_bgm)


"""
Plays a new track.

The currently track is abruptly stopped.
"""
func play_music(new_bgm: AudioStreamPlayer, from_position: float = 0.0) -> void:
	if _current_bgm == new_bgm:
		return
	
	stop()
	_current_bgm = new_bgm
	_current_bgm.volume_db = 0.0
	_current_bgm.play(from_position)
	emit_signal("bgm_changed", _current_bgm)