extends Node2D

# Referenzen mit korrekten Knotenpfaden
@onready var spawner = $spawner
@onready var player = $Player
@onready var camera = $Camera2D

func _ready():
	# Sicherstellen, dass alle Knoten gefunden wurden
	if not player:
		push_error("Player-Knoten nicht gefunden!")
		return
		
	if not camera:
		push_error("Camera-Knoten nicht gefunden!")
		return
		
	# Kamera dem Spieler zuweisen
	camera.position = player.position
	
	# Spieler in die Gruppe "player" hinzufügen für die Gegnererkennung
	player.add_to_group("player")

func _process(delta):
	# Kamera dem Spieler folgen lassen
	if player and camera:
		camera.global_position = player.global_position
