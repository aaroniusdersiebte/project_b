extends Node2D

@onready var player = $Player
@onready var camera = $Camera2D
@onready var world_generator = $WorldGenerator

func _ready():
	# Warten auf die vollständige Initialisierung
	await get_tree().process_frame
	
	# Spieler zur Gruppe hinzufügen und Position setzen
	if player:
		player.add_to_group("player")
		player.global_position = Vector2.ZERO
		print("Player initialized at position: ", player.global_position)
	
	# Kamera initial positionieren
	if camera and player:
		camera.global_position = player.global_position

func _process(delta):
	# Kamera dem Spieler folgen lassen
	if player and camera:
		camera.global_position = player.global_position
