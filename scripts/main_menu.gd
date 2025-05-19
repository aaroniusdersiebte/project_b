# scripts/main_menu.gd
extends Control

func _ready():
	# Buttons verbinden
	if $StartGameButton:
		$StartGameButton.connect("pressed", Callable(self, "_on_start_game_pressed"))
	if $SandboxButton:
		$SandboxButton.connect("pressed", Callable(self, "_on_sandbox_pressed"))
	
	print("Hauptmenü geladen")

func _on_start_game_pressed():
	print("Starte Kampagnenmodus")
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.start_campaign()
	
	get_tree().change_scene_to_file("res://scenes/campaign_world.tscn")

func _on_sandbox_pressed():
	print("Starte Sandboxmodus")
	var game_manager = get_node("/root/GameManager")
	if game_manager:
		game_manager.start_sandbox()
	
	get_tree().change_scene_to_file("res://scenes/World.tscn")
