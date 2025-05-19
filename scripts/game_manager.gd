# scripts/game_manager.gd
extends Node

signal path_choice_needed # Signal for path choice UI

enum GameMode {SANDBOX, CAMPAIGN}
var current_mode = GameMode.SANDBOX

# Campaign variables
var current_world = 0
var current_wave = 0
var total_waves_completed = 0
var path_choice_available = false

# Constants for campaign mode
const WAVES_PER_WORLD = 5
const WORLD_COUNT = 3

# World information
var worlds = [
	{
		"name": "Start World", 
		"waves": WAVES_PER_WORLD,
		"enemy_multiplier": 1.0,
		"available_npcs": [],  # No NPCs initially
		"available_buildings": ["tower"] # Only basic tower
	},
	{
		"name": "Hard World", 
		"waves": WAVES_PER_WORLD,
		"enemy_multiplier": 1.5,
		"available_npcs": ["basic_npc", "advanced_npc"],
		"available_buildings": ["tower", "gold_farm", "xp_farm", "catapult"]
	},
	{
		"name": "Easy World", 
		"waves": WAVES_PER_WORLD,
		"enemy_multiplier": 0.8,
		"available_npcs": ["basic_npc"],
		"available_buildings": ["tower", "gold_farm", "healing_station"]
	}
]

func _ready():
	print("GameManager initialized")

func start_campaign():
	current_mode = GameMode.CAMPAIGN
	current_world = 0
	current_wave = 0
	total_waves_completed = 0
	path_choice_available = false
	print("Campaign mode started - World: 0, Wave: 0")
	
func start_sandbox():
	current_mode = GameMode.SANDBOX
	print("Sandbox mode started")
	
func is_campaign_mode():
	return current_mode == GameMode.CAMPAIGN
	
func complete_wave():
	current_wave += 1
	total_waves_completed += 1
	
	print("Wave completed: " + str(current_wave) + " of " + str(WAVES_PER_WORLD))
	
	# Check if all waves in this world are completed
	if current_wave >= WAVES_PER_WORLD:
		path_choice_available = true
		print("ALL WAVES COMPLETED! Path choice is now available!")
		
		# Emit signal for path choice - CRITICAL for the UI to appear
		emit_signal("path_choice_needed")
		
		# Debug: Check the path_choice_ui status directly
		var world = get_tree().get_current_scene()
		if world and world.has_node("PathChoiceUI"):
			var ui = world.get_node("PathChoiceUI")
			print("PathChoiceUI found, current visibility: ", ui.visible)
			
			# Force UI to be visible and in the foreground
			ui.visible = true
			if ui is CanvasLayer:
				ui.layer = 10
			else:
				# Make sure it's on top if not a CanvasLayer
				ui.z_index = 100
				
			# Activate pause
			get_tree().paused = true
			print("UI visibility set and game paused")

func make_path_choice(path_index):
	path_choice_available = false
	
	# Load different world based on path choice
	if path_index == 0:
		# Hard path with better loot
		current_world = 1  # ID for next world
		print("Hard path chosen - Switching to world: ", current_world)
	else:
		# Easier path with worse loot
		current_world = 2  # ID for alternative world
		print("Easy path chosen - Switching to world: ", current_world)
		
	current_wave = 0  # Reset waves for new world
	
	# Unpause the game
	get_tree().paused = false
	
	# Switch to the next world via loading screen
	call_deferred("_load_next_world")

func _load_next_world():
	# First go to loading screen, then to next world
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

# Helper functions
func get_allowed_buildings():
	if current_mode == GameMode.SANDBOX:
		return ["tower", "xp_farm", "gold_farm", "healing_station", "catapult", "minion_spawner"]
	else:
		return worlds[current_world].available_buildings

func get_allowed_npcs():
	if current_mode == GameMode.SANDBOX:
		return ["all"]  # Special code for "all allowed"
	else:
		return worlds[current_world].available_npcs

func get_max_waves_for_current_world():
	if current_mode == GameMode.SANDBOX:
		return -1  # Infinite
	else:
		return WAVES_PER_WORLD

# ===== DEBUG FUNCTIONS =====

# Debug: Skip to the last wave
func debug_skip_to_last_wave():
	current_wave = WAVES_PER_WORLD - 1  # Set to wave 4 (fifth wave becomes the last)
	print("DEBUG: Skipped to wave " + str(current_wave + 1))
	
	# Update the wave spawner if it exists
	var wave_spawner = get_tree().get_first_node_in_group("wave_spawner")
	if wave_spawner and "current_wave" in wave_spawner:
		wave_spawner.current_wave = current_wave
		print("DEBUG: Updated wave spawner to wave " + str(current_wave))
	
	return current_wave

# Debug: Force show the path choice UI
func debug_force_path_choice():
	path_choice_available = true
	current_wave = WAVES_PER_WORLD  # Set as if all waves completed
	
	print("DEBUG: Forcing path choice UI to appear")
	emit_signal("path_choice_needed")
	
	# Try to directly find and show the UI
	var world = get_tree().get_current_scene()
	if world and world.has_node("PathChoiceUI"):
		var ui = world.get_node("PathChoiceUI")
		ui.visible = true
		
		# Ensure it's at the front
		if ui is CanvasLayer:
			ui.layer = 10
		else:
			ui.z_index = 100
			
		# Pause the game
		get_tree().paused = true
		print("DEBUG: Path Choice UI forced visible")
	else:
		print("DEBUG: PathChoiceUI not found in scene")

# Debug: Kill all enemies to progress wave
func debug_kill_all_enemies():
	print("DEBUG: Killing all enemies")
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("die"):
			enemy.die()
		else:
			enemy.queue_free()
	
	print("DEBUG: Killed " + str(enemies.size()) + " enemies")
