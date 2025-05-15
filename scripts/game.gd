extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D
@onready var level_system_scene = preload("res://scenes/level_system.tscn")
@onready var level_ui_scene = preload("res://scenes/level_ui.tscn")

func _ready():
	# Wait for the complete initialization
	await get_tree().process_frame
	
	# Add player to group and set position
	if player:
		player.add_to_group("player")
		player.global_position = Vector2.ZERO
		print("Player initialized at position: ", player.global_position)
	
	# Initialize camera
	if camera and player:
		camera.global_position = player.global_position
	
	# Create the level system
	var level_system = Node.new()
	level_system.set_script(load("res://scripts/level_system.gd"))
	level_system.name = "LevelSystem"
	level_system.add_to_group("level_system")
	add_child(level_system)
	
	# Create the level UI
	var level_ui = level_ui_scene.instantiate()
	add_child(level_ui)
	
	print("Game initialized with level system and UI")

func _process(delta):
	# Make camera follow player
	if player and camera:
		camera.global_position = player.global_position
