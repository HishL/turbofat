extends Label
"""
Displays the player's score.
"""

func _ready() -> void:
	PuzzleScore.connect("score_changed", self, "_on_PuzzleScore_score_changed")
	text = "¥0"


func _on_PuzzleScore_score_changed() -> void:
	text = "¥%s" % StringUtils.comma_sep(PuzzleScore.get_score())
