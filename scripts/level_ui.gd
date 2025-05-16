extends CanvasLayer

# References to UI elements
@onready var xp_bar = $XPBar
@onready var level_label = $LevelLabel
@onready var upgrade_panel = $UpgradePanel
@onready var upgrade_options = $UpgradePanel/UpgradeOptions

var level_system = null

func _ready():
	# Initially hide the upgrade panel
	upgrade_panel.visible = false
	
	# Find the level system (could be a singleton or attached to game manager)
	await get_tree().process_frame
	level_system = get_tree().get_first_node_in_group("level_system")
	
	if level_system:
		# Connect signals
		level_system.connect("level_up", Callable(self, "_on_level_up"))
		level_system.connect("xp_gained", Callable(self, "_on_xp_gained"))
		
		# Initial UI update
		_on_xp_gained(level_system.current_xp, level_system.xp_to_next_level)
		level_label.text = "Level: " + str(level_system.current_level)
	else:
		print("ERROR: LevelSystem node not found!")

# Update XP bar when XP is gained
func _on_xp_gained(current_xp, max_xp):
	var percentage = float(current_xp) / float(max_xp)
	xp_bar.value = percentage * 100  # Assuming ProgressBar max value is 100

# Show upgrade options on level up
func _on_level_up(new_level):
	level_label.text = "Level: " + str(new_level)
	show_upgrade_options()
	
	# Pause the game while selecting upgrades (optional)
	get_tree().paused = true

# Display available upgrades
func show_upgrade_options():
	# Clear existing options
	for child in upgrade_options.get_children():
		child.queue_free()
	
	# Get available upgrades
	var available_upgrades = level_system.get_available_upgrades(3)
	
	# Create buttons for each upgrade option
	for upgrade in available_upgrades:
		var button = Button.new()
		button.text = _format_upgrade_name(upgrade) + " (Level " + str(level_system.get_upgrade_value(upgrade) + 1) + ")"
		button.tooltip_text = level_system.get_upgrade_description(upgrade)
		button.custom_minimum_size = Vector2(300, 60)
		button.connect("pressed", Callable(self, "_on_upgrade_selected").bind(upgrade))
		
		upgrade_options.add_child(button)
	
	# Show the upgrade panel
	upgrade_panel.visible = true

# Format upgrade name for display (convert snake_case to Title Case)
func _format_upgrade_name(upgrade_name):
	var words = upgrade_name.split("_")
	var formatted = ""
	
	for word in words:
		formatted += word.substr(0, 1).to_upper() + word.substr(1) + " "
	
	return formatted.strip_edges()

# Handle upgrade selection
func _on_upgrade_selected(upgrade):
	if level_system.apply_upgrade(upgrade):
		upgrade_panel.visible = false
		
		# Apply the upgrade effects to the player
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.apply_shot_upgrade(upgrade, level_system.get_upgrade_value(upgrade))
		
		# Resume game
		get_tree().paused = false
