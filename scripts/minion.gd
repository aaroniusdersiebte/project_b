extends CharacterBody2D

var spawner = null  # Referenz zum Spawner
var max_range = 400.0  # Maximale Entfernung vom Spawner
var damage = 1  # Schaden
var speed = 150.0  # Bewegungsgeschwindigkeit
var detection_radius = 150.0  # Erkennungsreichweite für Gegner
var attack_cooldown = 1.0  # Sekunden zwischen Angriffen
var attack_timer = 0.0
var can_attack = true

var current_target = null
var health = 3  # Einfache Gesundheitsverwaltung
var lifetime = 0.0  # Wie lange der Minion schon existiert

func _ready():
	add_to_group("minions")
	
	# Stelle sicher, dass wir einen Spawner haben
	if not spawner:
		print("FEHLER: Minion ohne Spawner erzeugt!")
		queue_free()
		return
	
	# Erkennungsbereich erstellen
	setup_detection_area()
	
	# Skalierung anpassen, damit er kleiner ist
	scale = Vector2(0.7, 0.7)

func _physics_process(delta):
	# Lebenszeit aktualisieren
	lifetime += delta
	
	# Timer für Angriffe aktualisieren
	if not can_attack:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			can_attack = true
			attack_timer = 0.0
	
	# Prüfe, ob wir zu weit vom Spawner entfernt sind
	if spawner and is_instance_valid(spawner):
		var distance_to_spawner = global_position.distance_to(spawner.global_position)
		if distance_to_spawner > max_range:
			# Zurück zum Spawner bewegen
			var direction = (spawner.global_position - global_position).normalized()
			velocity = direction * speed * 1.5  # Schneller zurückkehren
		elif current_target and is_instance_valid(current_target):
			# Gegner verfolgen
			var direction = (current_target.global_position - global_position).normalized()
			velocity = direction * speed
			
			# Angreifen, wenn nah genug
			var distance_to_target = global_position.distance_to(current_target.global_position)
			if distance_to_target < 40 and can_attack:
				attack(current_target)
		else:
			# In der Nähe des Spawners patrouillieren
			patrol_around_spawner(delta)
	else:
		# Spawner existiert nicht mehr, selbst zerstören
		queue_free()
	
	# Bewegung anwenden
	move_and_slide()
	
	# Neues Ziel suchen, wenn keines vorhanden
	if not current_target or not is_instance_valid(current_target):
		find_closest_enemy()

func patrol_around_spawner(delta):
	# Simuliert ein Patrouillierverhalten mit sanften Bewegungen
	var patrol_radius = max_range * 0.5
	var patrol_speed = speed * 0.5
	
	# Sinuswellen für X und Y mit unterschiedlichen Frequenzen
	var x_offset = sin(lifetime * 0.5) * patrol_radius
	var y_offset = cos(lifetime * 0.7) * patrol_radius
	
	var target_pos = spawner.global_position + Vector2(x_offset, y_offset)
	var direction = (target_pos - global_position).normalized()
	
	velocity = direction * patrol_speed
	
	# Zufällig die Bewegung ändern
	if randf() < 0.01:  # 1% Chance pro Frame
		velocity = Vector2.ZERO

func setup_detection_area():
	var detection_area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	
	circle.radius = detection_radius
	collision_shape.shape = circle
	detection_area.add_child(collision_shape)
	add_child(detection_area)
	
	detection_area.connect("body_entered", _on_detection_area_body_entered)
	detection_area.connect("body_exited", _on_detection_area_body_exited)
	
	# Visueller Indikator im Debug-Modus
	var visual = Node2D.new()
	visual.z_index = -1
	visual.set_script(load("res://scripts/detection_visual.gd"))
	visual.radius = detection_radius
	visual.color = Color(0.7, 0.3, 0.7, 0.1)  # Lila, transparent
	add_child(visual)

func _on_detection_area_body_entered(body):
	if body.is_in_group("enemies") and current_target == null:
		current_target = body

func _on_detection_area_body_exited(body):
	if body == current_target:
		current_target = null

func find_closest_enemy():
	var min_distance = INF
	var closest_enemy = null
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			var distance = global_position.distance_to(enemy.global_position)
			if distance < min_distance and distance <= detection_radius:
				min_distance = distance
				closest_enemy = enemy
	
	current_target = closest_enemy

func attack(target):
	if not is_instance_valid(target):
		return
		
	if target.has_method("take_damage"):
		var was_killed = target.take_damage(damage)
		
		# XP dem Spawner zuweisen, wenn er existiert
		if was_killed and spawner and spawner.has_method("add_xp"):
			spawner.add_xp(10)  # Einfacher XP-Wert
	
	# Angriffstimer zurücksetzen
	can_attack = false
	attack_timer = 0.0
	
	# Angriffsanimation
	var attack_effect = create_tween()
	attack_effect.tween_property(self, "modulate", Color(1.5, 0.7, 1.5), 0.1)
	attack_effect.tween_property(self, "modulate", Color(0.7, 0.3, 0.7), 0.2)
	
	# Sprungeffekt
	attack_effect.parallel().tween_property(self, "scale", Vector2(0.9, 0.9), 0.1)
	attack_effect.tween_property(self, "scale", Vector2(0.7, 0.7), 0.2)

func take_damage(amount):
	health -= amount
	
	# Visuelle Rückmeldung
	modulate = Color(1.5, 0.5, 1.5)  # Heller werden
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.7, 0.3, 0.7), 0.3)
	
	if health <= 0:
		die()
		return true
	return false

func die():
	# Einfacher Sterbe-Effekt
	var death_effect = Sprite2D.new()
	death_effect.texture = $Sprite2D.texture
	death_effect.global_position = global_position
	death_effect.modulate = Color(0.7, 0.3, 0.7, 0.8)
	death_effect.scale = Vector2(0.4, 0.4)
	get_parent().add_child(death_effect)
	
	# Animation
	var tween = death_effect.create_tween()
	tween.tween_property(death_effect, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(death_effect, "modulate", Color(0.7, 0.3, 0.7, 0), 0.3)
	tween.tween_callback(death_effect.queue_free)
	
	queue_free()