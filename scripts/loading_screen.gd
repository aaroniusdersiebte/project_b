# scripts/loading_screen.gd
extends Control

func _ready():
	# Show a brief animation
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(_on_timer_timeout)
	
	# Display loading text based on the world being loaded
	var game_manager = get_node("/root/GameManager")
	if game_manager and game_manager.worlds.size() > game_manager.current_world:
		var world_data = game_manager.worlds[game_manager.current_world]
		if has_node("LoadingLabel"):
			$LoadingLabel.text = "Loading: " + world_data.name
			print("Loading screen showing: " + world_data.name)
	
	# Animate the loading spinner
	if has_node("LoadingSpinner"):
		var tween = create_tween().set_loops()
		tween.tween_property($LoadingSpinner, "rotation", TAU, 2)
	
	print("Loading screen displayed")

func _on_timer_timeout():
	print("Loading complete, changing to campaign world")
	# Switch to the next world
	get_tree().change_scene_to_file("res://scenes/campaign_world.tscn")
