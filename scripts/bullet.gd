extends Area2D

# Geschossgeschwindigkeit
@export var speed = 500.0
# Schadensbereich
@export var damage = 1
# Lebensdauer in Sekunden
@export var lifetime = 2.0

# Bewegungsrichtung
var direction = Vector2.RIGHT

# Timer für Lebensdauer
var timer = 0.0

func _ready():
	# Signal für Kollision verbinden
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Bewegung in die gegebene Richtung
	position += direction * speed * delta
	
	# Rotation zum Ziel
	rotation = direction.angle()
	
	# Lebensdauer verringern
	timer += delta
	if timer >= lifetime:
		queue_free()

func _on_body_entered(body):
	# Prüfen, ob es sich um einen Gegner handelt
	if body.is_in_group("enemies"):
		# Schaden zufügen
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		# Projektil zerstören
		queue_free()
