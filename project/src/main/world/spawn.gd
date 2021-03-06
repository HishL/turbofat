class_name Spawn
extends Node2D
"""
A spawn point where a creature can appear on the overworld.
"""

# the direction the creature will face
export (CreatureVisuals.Orientation) var orientation := CreatureVisuals.SOUTHEAST

# a unique id for this spawn point
export (String) var id: String

"""
Relocates the specified creature to this spawn point.
"""
func move_creature(creature: Creature) -> void:
	creature.position = position
	creature.orientation = orientation
