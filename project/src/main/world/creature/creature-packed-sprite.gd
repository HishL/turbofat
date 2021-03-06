#tool #uncomment to view creature in editor
class_name CreaturePackedSprite
extends PackedSprite
"""
Sprites which toggles between a single 'toward the camera' and 'away from the camera' frame
"""

export (bool) var invisible_while_sprinting := false

func update_orientation(orientation: int) -> void:
	if orientation in [CreatureVisuals.SOUTHWEST, CreatureVisuals.SOUTHEAST]:
		# facing south; initialize textures to forward-facing frame
		set_frame(1)
	else:
		# facing north; initialize textures to backward-facing frame
		set_frame(2)


func _on_CreatureVisuals_orientation_changed(old_orientation: int, new_orientation: int) -> void:
	if new_orientation in [CreatureVisuals.SOUTHWEST, CreatureVisuals.SOUTHEAST] \
		and old_orientation in [CreatureVisuals.SOUTHWEST, CreatureVisuals.SOUTHEAST]:
			# still facing south, just like before
			pass
	elif new_orientation in [CreatureVisuals.NORTHWEST, CreatureVisuals.NORTHEAST] \
		and old_orientation in [CreatureVisuals.NORTHWEST, CreatureVisuals.NORTHEAST]:
			# still facing north, just like before
			pass
	else:
		update_orientation(new_orientation)


func _on_CreatureVisuals_movement_mode_changed(_old_mode: int, new_mode: int) -> void:
	if invisible_while_sprinting:
		visible = new_mode != CreatureVisuals.SPRINT
