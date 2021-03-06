class_name LevelLock
"""
Keeps track of whether a level is unlocked, and the requirements to unlock it.
"""

# the requirements to unlock a level
enum LockedUntil {
	ALWAYS_UNLOCKED, # never locked
	UNTIL_LEVEL_FINISHED, # locked until the player finishes a specific level(s)
	UNTIL_GROUP_FINISHED, # locked until the player finishes some levels in a group
}

# the status whether or not a level is locked/unlocked
enum LockStatus {
	NONE, # not locked
	CLEARED, # cleared without any rank; used for tutorials
	KEY, # not locked, and can unlock another level
	CROWN, # not locked, and can unlock another world
	SOFT_LOCK, # locked, but the player can unlock it by clearing more levels
	HARD_LOCK, # locked, and the required levels to unlock it are themselves locked
}

const ALWAYS_UNLOCKED := LockedUntil.ALWAYS_UNLOCKED
const UNTIL_LEVEL_FINISHED := LockedUntil.UNTIL_LEVEL_FINISHED
const UNTIL_GROUP_FINISHED := LockedUntil.UNTIL_GROUP_FINISHED

const STATUS_NONE := LockStatus.NONE
const STATUS_KEY := LockStatus.KEY
const STATUS_CROWN := LockStatus.CROWN
const STATUS_CLEARED := LockStatus.CLEARED
const STATUS_SOFT_LOCK := LockStatus.SOFT_LOCK
const STATUS_HARD_LOCK := LockStatus.HARD_LOCK

var level_id: String

# Some levels activate dialog sequences. This field specifies which character's dialog should activate.
var creature_id: String

# Some levels involve specific customers or a specific chef.
var customer_ids: Array
var chef_id: String

# the requirements to unlock this level
var locked_until_type := ALWAYS_UNLOCKED

"""
An array of strings representing unlock criteria.

For UNTIL_LEVEL_FINISHED locks, this is an array of level IDs.
For UNTIL_GROUP_FINISHED locks, this is a group ID and (optionally) a number of levels which can be skipped.
"""
var locked_until_values := []

# the status whether or not this level is locked/unlocked
var status := STATUS_NONE

# the number of remaining levels the player needs to play to unlock this level
var keys_needed := -1

# array of string group IDs for groups this level belongs to
var groups := []

func from_json_dict(json: Dictionary) -> void:
	level_id = json.get("id", "")
	creature_id = json.get("creature_id", "")
	chef_id = json.get("chef_id", "")
	customer_ids = json.get("customer_ids", [])
	
	var locked_until_string: String = json.get("locked_until", "")
	if locked_until_string:
		var locked_until_array: Array = locked_until_string.split(" ")
		match locked_until_array[0]:
			"level_finished": locked_until_type = UNTIL_LEVEL_FINISHED
			"group_finished": locked_until_type = UNTIL_GROUP_FINISHED
			_: push_warning("Unrecognized locked_until: %s" % [locked_until_string])
		locked_until_values = locked_until_array.slice(1, locked_until_array.size() - 1)
	
	var groups_string: String = json.get("groups", "")
	if groups_string:
		groups = groups_string.split(" ")


func is_locked() -> bool:
	return status in [STATUS_SOFT_LOCK, STATUS_HARD_LOCK]
