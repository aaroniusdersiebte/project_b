# scripts/campaign_world.gd
extends Node2D

var wave_manager
var path_choice_ui
var game_manager
var player
var camera

func _ready():
	# CRITICAL: Ensure game is not paused on start
	get_tree().paused = false
	
	# Wait for everything to be initialized
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Find references to key nodes
	player = get_tree().get_first_node_in_group("player")
	camera = $Camera2D
	wave_manager = get_tree().get_first_node_in_group("wave_spawner")
	path_choice_ui = $PathChoiceUI
	game_manager = get_node("/root/GameManager")
	
	print("Campaign world initialization - found components:")
	print("- Player: ", player != null)
	print("- Camera: ", camera != null) 
	print("- Wave Manager: ", wave_manager != null)
	print("- Path Choice UI: ", path_choice_ui != null)
	print("- Game Manager: ", game_manager != null)
	
	# Hide the path choice UI initially
	if path_choice_ui:
		path_choice_ui.visible = false
		print("Path choice UI hidden initially")
		
		# Ensure UI properties for visibility
		if path_choice_ui is Control:
			path_choice_ui.z_index = 100
			path_choice_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect to game manager signals
	if game_manager:
		if game_manager.has_signal("path_choice_needed"):
			game_manager.connect("path_choice_needed", show_path_choice)
			print("Connected to GameManager path_choice_needed signal")
		else:
			print("WARNING: GameManager does not have path_choice_needed signal")
	
	# Connect to wave manager signals
	if wave_manager:
		if wave_manager.has_signal("wave_completed"):
			wave_manager.connect("wave_completed", _on_wave_completed)
			print("Connected to wave_completed signal")
		
		# Set max waves for campaign mode
		if "max_waves" in wave_manager:
			wave_manager.max_waves = 5
			print("Set max_waves to 5 for campaign mode")
	
	# Make one more check that game is unpaused
	if get_tree().paused:
		print("WARNING: Game still paused after initialization, forcing unpause")
		get_tree().paused = false
	
	print("Campaign world initialization complete")
	print("DEBUG CONTROLS:")
	print("- Press F5: Skip to last wave")
	print("- Press F6: Force path choice UI")
	print("- Press F7: Kill all enemies")
	print("- Press F8: Force unpause game (if frozen)")

func _process(delta):
	# Camera follows player
	if player and is_instance_valid(player) and camera:
		camera.global_position = player.global_position
	
	# Debug keyboard shortcuts
	if Input.is_key_pressed(KEY_F5):
		_debug_skip_to_last_wave()
	
	if Input.is_key_pressed(KEY_F6):
		_debug_force_path_choice()
	
	if Input.is_key_pressed(KEY_F7):
		_debug_kill_all_enemies()
	
	# Emergency unpause key
	if Input.is_key_pressed(KEY_F8):
		get_tree().paused = false
		print("DEBUG: Force unpaused game")

func _on_wave_completed(wave_number):
	print("Wave " + str(wave_number) + " completed")
	
	if game_manager:
		# Notify the game manager that a wave was completed
		game_manager.complete_wave()
		print("Notified game manager of wave completion")
		
		# Check if path choice should be shown
		if game_manager.path_choice_available:
			print("Path choice is available, showing UI")
			call_deferred("show_path_choice")
		else:
			print("Path choice not available yet")

func show_path_choice():
	print("Showing path choice UI")
	
	# Pause the game
	get_tree().paused = true
	
	# Show the path choice UI
	if path_choice_ui:
		path_choice_ui.visible = true
		print("Path choice UI set to visible")
		
		# Make sure it's in front of everything
		if path_choice_ui is Control:
			path_choice_ui.z_index = 100
		elif path_choice_ui is CanvasLayer:
			path_choice_ui.layer = 10
			
		print("UI z-order adjusted for visibility")
	else:
		print("ERROR: Path choice UI not found!")

# ===== DEBUG FUNCTIONS =====

func _debug_skip_to_last_wave():
	if game_manager:
		var current_wave = game_manager.debug_skip_to_last_wave()
		print("DEBUG: Skipped to wave " + str(current_wave + 1))
	else:
		print("DEBUG: GameManager not found, can't skip waves")

func _debug_force_path_choice():
	if game_manager:
		game_manager.debug_force_path_choice()
		print("DEBUG: Forced path choice UI")
	else:
		print("DEBUG: GameManager not found, can't show path choice")

func _debug_kill_all_enemies():
	if game_manager:
		game_manager.debug_kill_all_enemies()
		print("DEBUG: Killed all enemies")
	else:
		print("DEBUG: GameManager not found, can't kill enemies")
