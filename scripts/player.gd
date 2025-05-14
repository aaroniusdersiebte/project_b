extends CharacterBody2D

# Spielergeschwindigkeit
@export var speed = 300.0
# Entdeckungsradius für Gegner
@export var detection_radius = 300.0
# Schussrate (Sekunden zwischen Schüssen)
@export var fire_rate = 0.5

# Vorgeladene Kugel-Szene
var bullet_scene = preload("res://scenes/bullet.tscn")
# Timer für Schussrate
var fire_timer = 0.0
# Kann schießen?
var can_fire = true
# Aktuelles Ziel
var current_target = null

func _ready():
	# Als erstes zur Gruppe hinzufügen
	add_to_group("player")
	print("Player added to 'player' group")
	
	# Den Kollisionsbereich für die Gegnererkennung einrichten
	var detection_area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	

	
	circle.radius = detection_radius
	collision_shape.shape = circle
	detection_area.add_child(collision_shape)
	add_child(detection_area)
	
	# Signal für Gegnererkennung verbinden
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# Visuelles Feedback für den Erkennungsradius
	var detection_visual = Node2D.new()
	detection_visual.set_script(load("res://scripts/detection_visual.gd"))
	detection_visual.radius = detection_radius
	add_child(detection_visual)
	

func _physics_process(delta):
	# Bewegungseingaben verarbeiten
	var direction = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.y += 1
	if Input.is_action_pressed("ui_up"):
		direction.y -= 1
	
	# Normalisieren und Geschwindigkeit anwenden
	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO
	
	# Bewegung anwenden
	move_and_slide()
	
	# Schusslogik
	if not can_fire:
		fire_timer += delta
		if fire_timer >= fire_rate:
			can_fire = true
			fire_timer = 0.0
	
	# Automatisch auf Gegner schießen, wenn in Reichweite
	if current_target != null and can_fire:
		shoot_at_target(current_target)

func shoot_at_target(target):
	# Instanziere eine neue Kugel
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	
	# Richtung zum Ziel berechnen
	var direction = (target.global_position - global_position).normalized()
	bullet.direction = direction
	
	# Kugel zur Szene hinzufügen
	get_parent().add_child(bullet)
	
	# Schussrate zurücksetzen
	can_fire = false
	fire_timer = 0.0

func _on_detection_area_body_entered(body):
	# Prüfen, ob es sich um einen Gegner handelt
	if body.is_in_group("enemies") and current_target == null:
		current_target = body

func _on_detection_area_body_exited(body):
	# Gegner aus dem Zielbereich entfernt
	if body == current_target:
		current_target = null
		
		# Neues Ziel suchen, falls vorhanden
		var potential_targets = get_tree().get_nodes_in_group("enemies")
		for target in potential_targets:
			var distance = global_position.distance_to(target.global_position)
			if distance <= detection_radius:
				current_target = target
				break
				
				
				add_to_group("player")
