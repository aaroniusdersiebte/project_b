extends "res://scripts/building_base.gd"

# Katapult: Turm mit sehr großer Reichweite und hohem Schaden

# Konfiguration
@export var fire_rate = 3.0  # Sekunden zwischen Schüssen (langsamer als normaler Turm)
@export var damage = 5  # Hoher Basisschaden
@export var detection_radius = 800.0  # Sehr große Reichweite
@export var projectile_speed = 350.0  # Projektilgeschwindigkeit
@export var splash_radius = 100.0  # Flächenschaden-Radius

# Boost-Werte pro Level
@export var damage_per_level = 2  # Zusätzlicher Schaden pro Level
@export var range_per_level = 50.0  # Zusätzliche Reichweite pro Level
@export var splash_per_level = 10.0  # Zusätzlicher Splash-Radius pro Level

# Tracking variables
var fire_timer = 0.0
var can_fire = true
var current_target = null

# Projektil-Szene
var projectile_scene

func _post_ready():
	building_type = "Katapult"
	
	# Symbol/Textur anpassen
	if $Sprite2D:
		$Sprite2D.modulate = Color(0.8, 0.3, 0.1)  # Rötlich-braun für Katapult
	
	# Erkennungsbereich einrichten
	setup_detection_area()
	
	# Projektil vorbereiten (Fallback auf Bullet, wenn keine spezialisierte Szene existiert)
	projectile_scene = load_projectile_scene()

func _building_process(delta):
	# Timer für Schießen aktualisieren
	if not can_fire:
		fire_timer += delta
		var effective_fire_rate = fire_rate
		if is_boosted:
			effective_fire_rate /= npc_boost_multiplier
			
		if fire_timer >= effective_fire_rate:
			can_fire = true
			fire_timer = 0.0
	
	# Wenn ein Ziel existiert und wir schießen können
	if current_target != null and is_instance_valid(current_target) and can_fire:
		shoot_at_target(current_target)
	
	# Suche nach neuen Zielen, wenn kein aktuelles Ziel vorhanden ist
	if current_target == null or not is_instance_valid(current_target):
		find_closest_enemy()

func setup_detection_area():
	# Erkennungsbereich erstellen
	var detection_area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	
	circle.radius = detection_radius
	collision_shape.shape = circle
	detection_area.add_child(collision_shape)
	add_child(detection_area)
	
	# Signale verbinden
	detection_area.connect("body_entered", _on_detection_area_body_entered)
	detection_area.connect("body_exited", _on_detection_area_body_exited)
	
	# Visueller Indikator
	var detection_visual = Node2D.new()
	detection_visual.set_script(load("res://scripts/detection_visual.gd"))
	detection_visual.radius = detection_radius
	detection_visual.color = Color(0.8, 0.4, 0.1, 0.1)  # Rötlich-braun transparent
	add_child(detection_visual)

func _on_detection_area_body_entered(body):
	# Prüfen, ob es sich um einen Gegner handelt
	if body.is_in_group("enemies") and current_target == null:
		current_target = body

func _on_detection_area_body_exited(body):
	# Gegner hat den Erkennungsbereich verlassen
	if body == current_target:
		current_target = null
		
		# Neues Ziel suchen, falls vorhanden
		find_closest_enemy()

func find_closest_enemy():
	var min_distance = INF
	var closest_enemy = null
	
	# Alle Gegner durchgehen
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance and distance <= detection_radius:
			min_distance = distance
			closest_enemy = enemy
	
	current_target = closest_enemy

func shoot_at_target(target):
	# Ausrichtung zum Ziel (visuell)
	if $Sprite2D:
		var direction = (target.global_position - global_position).normalized()
		$Sprite2D.rotation = direction.angle() + PI/2  # +90 Grad für korrekte Ausrichtung
	
	# Feuer-Timer zurücksetzen
	can_fire = false
	fire_timer = 0.0
	
	# Projektil erstellen
	spawn_projectile(target)
	
	# Schussanimation
	var recoil_effect = create_tween()
	recoil_effect.tween_property($Sprite2D, "position", Vector2(0, 0) - Vector2(0, 10), 0.1)
	recoil_effect.tween_property($Sprite2D, "position", Vector2(0, 0), 0.2)

func spawn_projectile(target):
	# Neue Projektilinstanz erstellen
	var projectile = projectile_scene.instantiate()
	projectile.global_position = global_position
	
	# Ziel-Vorausberechnung (führende Schüsse)
	var target_pos = predict_target_position(target)
	var direction = (target_pos - global_position).normalized()
	
	# Projektileigenschaften setzen
	projectile.direction = direction
	projectile.damage = calculate_damage()
	projectile.speed = projectile_speed
	projectile.tower_source = self  # Referenz für XP-Zuweisung
	
	# Splash-Schaden konfigurieren
	projectile.is_explosive = true
	projectile.explosion_radius = splash_radius + (level - 1) * splash_per_level
	projectile.explosion_damage = calculate_damage() / 2  # Splash-Schaden ist halb so hoch
	
	# Visuelle Anpassungen
	projectile.get_node("Sprite2D").modulate = Color(0.9, 0.4, 0.1)  # Projektilfarbe
	projectile.get_node("Sprite2D").scale = Vector2(1.5, 1.5)  # Größeres Projektil
	
	# Zum Baum hinzufügen
	get_parent().add_child(projectile)

func predict_target_position(target):
	# Einfache Vorhersage, wohin sich das Ziel bewegt (für führende Schüsse)
	if target is CharacterBody2D and "velocity" in target:
		var distance = global_position.distance_to(target.global_position)
		var time_to_target = distance / projectile_speed
		return target.global_position + target.velocity * time_to_target
	
	return target.global_position

func calculate_damage():
	var base_damage = damage + (level - 1) * damage_per_level
	if is_boosted:
		base_damage *= npc_boost_multiplier
	return base_damage

func _on_level_up():
	# Statistiken verbessern
	damage += damage_per_level
	detection_radius += range_per_level
	splash_radius += splash_per_level
	
	# Erkennungsbereich aktualisieren
	update_detection_area()

func update_detection_area():
	# Kollisionsform aktualisieren
	for child in get_children():
		if child is Area2D:
			for shape in child.get_children():
				if shape is CollisionShape2D and shape.shape is CircleShape2D:
					shape.shape.radius = detection_radius
		
		# Auch visuelle Anzeige aktualisieren
		if child.has_method("_draw") and "radius" in child:
			child.radius = detection_radius
			child.queue_redraw()

func load_projectile_scene():
	# Versuche, Projektil-Szene zu laden
	var catapult_projectile = load("res://scenes/catapult_projectile.tscn")
	if catapult_projectile:
		return catapult_projectile
	
	# Fallback: Normales Bullet verwenden
	return load("res://scenes/bullet.tscn")