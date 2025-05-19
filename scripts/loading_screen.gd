# scripts/loading_screen.gd
extends Control

func _ready():
	# Kurze Animation zeigen
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(Callable(self, "_on_timer_timeout"))
	
	# Ladetext anzeigen
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		var world_data = game_manager.worlds[game_manager.current_world]
		if $LoadingLabel:
			$LoadingLabel.text = "Laden: " + world_data.name
	
	print("Ladebildschirm angezeigt")

func _on_timer_timeout():
	# Zur nächsten Welt wechseln
	get_tree().change_scene_to_file("res://scenes/campaign_world.tscn")
