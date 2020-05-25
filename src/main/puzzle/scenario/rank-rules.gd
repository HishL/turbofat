class_name RankRules
"""
Tweaks to rank calculation.
"""

# multiplier for the expected box_points_per_line. '3.0' means the player
# needs 3x the usual box points per line to get a good rank
var box_factor := 1.0

# multiplier for the expected combo_points_per_line. '3.0' means the player
# needs 3x the usual combo points per line to get a good rank
var combo_factor := 1.0

# rank penalty applied each time the player tops out
var top_out_penalty := 4

# 'true' if the results screen should be skipped. Used for tutorials.
var skip_results: bool

func from_json_string_array(json: Array) -> void:
	var rules := RuleParser.new(json)
	if rules.has("combo-factor"): combo_factor = rules.float_value()
	if rules.has("box-factor"): box_factor = rules.float_value()
	if rules.has("top-out-penalty"): top_out_penalty = rules.int_value()
	if rules.has("skip-results"): skip_results = true