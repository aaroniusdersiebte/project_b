extends CharacterBody2D

# Signale
signal xp_gained(current_xp, max_xp)
signal level_up(new_level)

# Spielergeschwindigkeit
@export var speed = 300.0
# Entdeckungsradius für Gegner
@export var detection_radius = 300.0
# Schussrate (Sekunden zwischen Schüssen)
@export var fire_rate = 0.5

# Level-System
var level = 1
var current_xp = 0
var xp_to_next_level = 100
var xp_multiplier = 1.5

# Vorgeladene Kugel-Szene
var bullet_scene = preload("res://scenes/bullet.tscn")
# Timer für Schussrate
var fire_timer = 0.0
# Kann schießen?
var can_fire = true
# Aktuelles Ziel
var current_target = null

# Shot upgrade variables
var bullet_damage = 1
var bullet_size = 1.0
var bullet_speed = 500.0
var bullet_lifetime = 2.0
var multi_shot_count = 1
var spread_angle = 0.0
var piercing_count = 0
var is_bouncing = false
var is_homing = false
var is_explosive = false
var slow_effect = 0
var poison_effect = 0
var knockback_force = 0

# UI-Elemente
var level_label

func _ready():
	# Als erstes zur Gruppe hinzufügen
	add_to_group("player")
	print("Player added to 'player' group")
	
	# UI-Elemente erstellen
	create_ui_elements()
	
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
	
	# Verbinden mit dem LevelSystem falls vorhanden
	var level_system = get_tree().get_first_node_in_group("level_system")
	if level_system:
		level_system.level_up.connect(_on_global_level_up)
		
func create_ui_elements():
	# Level-Label erstellen
	level_label = Label.new()
	level_label.position = Vector2(-20, -100)
	level_label.text = "Lv. " + str(level)
	level_label.modulate = Color(1.0, 0.8, 0.2)  # Goldene Farbe
	level_label.add_theme_font_size_override("font_size", 16)
	add_child(level_label)
	
func find_closest_enemy_in_range():
	var min_distance = detection_radius
	var closest_enemy = null
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			closest_enemy = enemy
	
	if closest_enemy:
		current_target = closest_enemy
		print("Player found target: ", closest_enemy.name)

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
	
	# Manuell nach Gegnern suchen, falls die Erkennung versagt
	if current_target == null or not is_instance_valid(current_target):
		find_closest_enemy_in_range()
	
	# Automatisch auf Gegner schießen, wenn in Reichweite
	if current_target != null and can_fire:
		shoot_at_target(current_target)

func shoot_at_target(target):
	# Direction to target
	var direction = (target.global_position - global_position).normalized()
	
	# Reset fire timer
	can_fire = false
	fire_timer = 0.0
	
	# Multiple shots
	for i in range(multi_shot_count):
		# Apply spread if needed
		var shot_direction = direction
		if spread_angle > 0 and multi_shot_count > 1:
			var angle_offset = spread_angle * (i - (multi_shot_count - 1) / 2.0) / (multi_shot_count - 1)
			shot_direction = direction.rotated(deg_to_rad(angle_offset))
		
		# Create bullet
		spawn_bullet(shot_direction)

func spawn_bullet(direction):
	# Instanziere eine neue Kugel
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	
	# Apply upgrades to bullet
	bullet.direction = direction
	bullet.damage = bullet_damage
	bullet.speed = bullet_speed
	bullet.lifetime = bullet_lifetime
	
	# Quelle des Schusses setzen (für XP-Zuweisung)
	bullet.source_player = self
	
	# Apply size upgrade
	if bullet_size != 1.0:
		var sprite = bullet.get_node("Sprite2D")
		var collision = bullet.get_node("CollisionShape2D")
		if sprite:
			sprite.scale *= bullet_size
		if collision:
			# Assuming CircleShape2D for simplicity
			collision.shape.radius *= bullet_size
	
	# Apply special effects
	bullet.piercing_count = piercing_count
	bullet.is_bouncing = is_bouncing
	bullet.is_homing = is_homing
	bullet.is_explosive = is_explosive
	bullet.slow_effect = slow_effect
	bullet.poison_effect = poison_effect
	bullet.knockback_force = knockback_force
	
	# Kugel zur Szene hinzufügen
	get_parent().add_child(bullet)

# XP zum Spieler hinzufügen (von anderen Systemen aufgerufen)
func add_xp(amount):
	current_xp += amount
	
	# Prüfen, ob Level-Up
	if current_xp >= xp_to_next_level:
		perform_level_up()
	
	# XP-Signal senden
	emit_signal("xp_gained", current_xp, xp_to_next_level)
	
	print("Spieler erhielt " + str(amount) + " XP. Gesamt: " + str(current_xp) + "/" + str(xp_to_next_level))

# Level-Up-Funktion
func perform_level_up():
	level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * xp_multiplier)
	
	# Level-Label aktualisieren
	if level_label:
		level_label.text = "Lv. " + str(level)
	
	# Statistiken verbessern
	bullet_damage += 1
	fire_rate *= 0.9  # 10% schneller
	detection_radius += 30
	update_detection_radius()
	
	# Level-Up-Effekt
	var level_up_effect = create_tween()
	level_up_effect.tween_property(self, "modulate", Color(1.5, 1.5, 0.5), 0.3)
	level_up_effect.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
	
	# Level-Up-Signal senden
	emit_signal("level_up", level)
	
	print("Spieler Level-Up! Neues Level: " + str(level))
	
	# Falls noch XP übrig, erneutes Level-Up prüfen
	if current_xp >= xp_to_next_level:
		perform_level_up()

# Erkennungsradius aktualisieren wenn er sich ändert
func update_detection_radius():
	# Erkennungsbereich aktualisieren
	for child in get_children():
		if child is Area2D:
			for shape in child.get_children():
				if shape is CollisionShape2D and shape.shape is CircleShape2D:
					shape.shape.radius = detection_radius
		
		# Auch visuelle Anzeige aktualisieren
		if child.has_method("_draw") and "radius" in child:
			child.radius = detection_radius
			child.queue_redraw()

# Apply shot upgrades from level system
func apply_shot_upgrade(upgrade_name, level):
	match upgrade_name:
		"damage":
			bullet_damage = 1 + level  # 1, 2, 3, 4, 5, 6
		"fire_rate":
			fire_rate = 0.5 * pow(0.9, level)  # Each level reduces cooldown by 10%
		"bullet_size":
			bullet_size = 1.0 + (level * 0.2)  # 1.0, 1.2, 1.4, 1.6
		"bullet_speed":
			bullet_speed = 500.0 * (1.0 + (level * 0.15))  # 500, 575, 660, 760
		"bullet_lifetime":
			bullet_lifetime = 2.0 * (1.0 + (level * 0.2))  # 2.0, 2.4, 2.8, 3.2
		"multi_shot":
			multi_shot_count = 1 + level  # 1, 2, 3, 4
			# Enable spread when multi-shot is active
			if level > 0 and spread_angle == 0:
				spread_angle = 15.0
		"spread_shot":
			spread_angle = 15.0 + (level * 10.0)  # 15, 25, 35, 45 degrees
		"piercing":
			piercing_count = level  # 0, 1, 2, 3
		"bouncing":
			is_bouncing = true
		"homing":
			is_homing = true
		"explosive":
			is_explosive = true
		"slow":
			slow_effect = level * 0.2  # 0.2, 0.4, 0.6 (slow factor)
		"poison":
			poison_effect = level  # 1, 2, 3 (damage per second)
		"knockback":
			knockback_force = level * 100  # 100, 200, 300

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

# Wenn das globale Level-System ein Level-Up hat (z.B. durch UI-Auswahl)
func _on_global_level_up(new_level):
	# Synchronisieren, falls nötig
	if new_level > level:
		level = new_level
		level_label.text = "Lv. " + str(level)

# Schaden nehmen (z.B. durch Gegner)
func take_damage(amount):
	# Hier Gesundheitssystem implementieren
	# Momentan ist der Spieler unverwundbar
	print("Spieler nimmt " + str(amount) + " Schaden")
	
	# Visueller Effekt
	modulate = Color(1, 0.3, 0.3)  # Rote Tönung
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.3)
