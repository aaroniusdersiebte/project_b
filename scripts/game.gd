extends Node2D

# Referenz zum Spawner
@onready var spawner = $spawner

# Referenz zum Spieler
@onready var player = $Player

# Referenz zur Kamera
@onready var camera = $Camera2D

func _ready():
	# Null-Prüfungen hinzufügen
	if player == null:
		push_error("Player not found!")
		return
	
	if camera == null:
		# Da die Kamera nicht gefunden wurde, erstellen wir eine neue
		camera = Camera2D.new()
		add_child(camera)
		print("Created new Camera2D node")
	
	# Kamera dem Spieler zuweisen
	camera.position = player.position
	
	# Spieler in die Gruppe "player" hinzufügen für die Gegnererkennung
	player.add_to_group("player")
	print("Game ready, player found: ", player != null)

func _process(_delta):
	# Nur verarbeiten, wenn beide Objekte existieren
	if player != null and camera != null:
		# Kamera dem Spieler folgen lassen
		camera.global_position = player.global_position
