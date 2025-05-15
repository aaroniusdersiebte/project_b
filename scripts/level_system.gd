extends Node

signal level_up(level)
signal xp_gained(current_xp, max_xp)

# Experience and level variables
var current_level = 1
var current_xp = 0
var xp_to_next_level = 100  # Base XP needed for first level
var level_xp_multiplier = 1.5  # Each level requires more XP

# Shot upgrade tracking
var upgrades = {
	"damage": 0,
	"fire_rate": 0,
	"bullet_size": 0,
	"bullet_speed": 0,
	"bullet_lifetime": 0,
	"multi_shot": 0,
	"spread_shot": 0,
	"piercing": 0,
	"bouncing": 0,
	"homing": 0,
	"explosive": 0,
	"slow": 0,
	"poison": 0,
	"knockback": 0
}

# Maximum upgrade levels
var max_upgrade_levels = {
	"damage": 5,
	"fire_rate": 5,
	"bullet_size": 3,
	"bullet_speed": 3,
	"bullet_lifetime": 3,
	"multi_shot": 3,
	"spread_shot": 3,
	"piercing": 3,
	"bouncing": 1,
	"homing": 1,
	"explosive": 1,
	"slow": 3,
	"poison": 3,
	"knockback": 3
}

# Upgrade requirements - some upgrades need prerequisites
var upgrade_requirements = {
	"multi_shot": {"level": 3},
	"spread_shot": {"level": 3},
	"piercing": {"level": 5, "damage": 2},
	"bouncing": {"level": 7, "bullet_speed": 2},
	"homing": {"level": 10, "bullet_speed": 1},
	"explosive": {"level": 12, "damage": 3},
	"slow": {"level": 6},
	"poison": {"level": 8, "damage": 2},
	"knockback": {"level": 5, "bullet_size": 1}
}

# Description of each upgrade
var upgrade_descriptions = {
	"damage": "Increases bullet damage by 1",
	"fire_rate": "Decreases time between shots by 10%",
	"bullet_size": "Increases bullet size by 20%",
	"bullet_speed": "Increases bullet speed by 15%",
	"bullet_lifetime": "Increases bullet lifetime by 20%",
	"multi_shot": "Fire an additional bullet with each shot",
	"spread_shot": "Fire bullets in a spread pattern",
	"piercing": "Bullets can pierce through enemies",
	"bouncing": "Bullets bounce off walls",
	"homing": "Bullets slightly home in on enemies",
	"explosive": "Bullets explode on impact",
	"slow": "Bullets slow enemies for a short time",
	"poison": "Bullets poison enemies, dealing damage over time",
	"knockback": "Bullets knock enemies back"
}

func _ready():
	pass

# Add experience points
func add_xp(amount):
	current_xp += amount
	
	# Check if level up
	if current_xp >= xp_to_next_level:
		perform_level_up()
	
	# Emit signal for UI update
	emit_signal("xp_gained", current_xp, xp_to_next_level)

# Level up function - renamed to avoid conflict with signal
func perform_level_up():
	current_level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * level_xp_multiplier)
	
	# Emit level up signal
	emit_signal("level_up", current_level)
	
	# Check if there's still excess XP for another level up
	if current_xp >= xp_to_next_level:
		perform_level_up()
	else:
		emit_signal("xp_gained", current_xp, xp_to_next_level)

# Check if an upgrade is available based on requirements
func is_upgrade_available(upgrade_name):
	# Check if the upgrade is already at max level
	if upgrades[upgrade_name] >= max_upgrade_levels[upgrade_name]:
		return false
	
	# If there are requirements, check them
	if upgrade_name in upgrade_requirements:
		var reqs = upgrade_requirements[upgrade_name]
		
		# Check level requirement
		if "level" in reqs and current_level < reqs["level"]:
			return false
		
		# Check other upgrade prerequisites
		for req_upgrade in reqs:
			if req_upgrade != "level" and upgrades[req_upgrade] < reqs[req_upgrade]:
				return false
	
	return true

# Get available upgrades for selection
func get_available_upgrades(count=3):
	var available = []
	
	# Create list of all available upgrades
	for upgrade in upgrades.keys():
		if is_upgrade_available(upgrade):
			available.append(upgrade)
	
	# Shuffle the list
	available.shuffle()
	
	# Return requested number of upgrades (or less if not enough available)
	return available.slice(0, min(count, available.size()))

# Apply an upgrade
func apply_upgrade(upgrade_name):
	if is_upgrade_available(upgrade_name):
		upgrades[upgrade_name] += 1
		return true
	return false

# Get current value for a specific upgrade stat
func get_upgrade_value(upgrade_name):
	return upgrades[upgrade_name]

# Get upgrade description
func get_upgrade_description(upgrade_name):
	return upgrade_descriptions[upgrade_name]
