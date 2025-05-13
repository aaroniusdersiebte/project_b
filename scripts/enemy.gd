extends CharacterBody2D

@export var speed = 150.0
@export var health = 3

var player = null

func _ready():
	# Wichtig: Zur enemies-Gruppe hinzufügen
	add_to_group("enemies")
	print("Enemy spawned at: ", global_position)
	
	# Spieler finden
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta):
	# Prüfen, ob Player existiert
	if player == null:
		# Versuchen, Player zu finden
		player = get_tree().get_first_node_in_group("player")
		return
		
	# Richtung zum Spieler berechnen
	var direction = (player.global_position - global_position).normalized()
	
	# Geschwindigkeit setzen und bewegen
	velocity = direction * speed
	move_and_slide()

func take_damage(amount):
	health -= amount
	print("Enemy took damage: ", amount, ", health left: ", health)
	if health <= 0:
		queue_free()
