extends "res://scripts/building_base.gd"

# Minion-Spawner: Erzeugt kleine Kampfeinheiten, die in der Nähe kämpfen

# Konfiguration
@export var spawn_interval = 15.0  # Sekunden zwischen Minion-Spawns
@export var max_minions = 3  # Maximale Anzahl an Minions pro Spawner
@export var minion_lifetime = 30.0  # Lebensdauer eines Minions in Sekunden
@export var minion_range = 400.0  # Maximale Entfernung, in der Minions kämpfen
@export var minion_damage = 1  # Basis-Schaden der Minions

# Boost-Werte pro Level
@export var max_minions_per_level = 1  # Zusätzliche Minions pro Level
@export var damage_per_level = 0.5  # Zusätzlicher Schaden pro Level
@export var lifetime_per_level = 5.0  # Zusätzliche Lebensdauer pro Level

# Tracking
var spawn_timer = 0.0
var active_minions = []
var minion_scene

func _post_ready():
	building_type = "Minion-Spawner"
	
	# Symbol/Textur anpassen
	if $Sprite2D:
		$Sprite2D.modulate = Color(0.7, 0.3, 0.7)  # Lila für Spawner
	
	# Reichweitenanzeige erstellen
	create_range_indicator()
	
	# Minion-Szene laden oder erstellen
	minion_scene = load_minion_scene()

func _building_process(delta):
	# Spawn-Logic
	spawn_timer += delta
	
	# Bereinige nicht mehr existierende Minions
	clean_up_minion_references()
	
	# Minions spawnen, wenn Timer abgelaufen und Platz ist
	if spawn_timer >= spawn_interval and active_minions.size() < calculate_max_minions():
		spawn_timer = 0.0
		spawn_minion()

func spawn_minion():
	# Minion-Instanz erstellen
	var minion = minion_scene.instantiate()
	
	# Position um den Spawner herum (zufälliger Offset)
	var spawn_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
	minion.global_position = global_position + spawn_offset
	
	# Minion-Eigenschaften einrichten
	configure_minion(minion)
	
	# Lebensdauer-Timer erstellen
	var lifetime_timer = Timer.new()
	lifetime_timer.wait_time = calculate_minion_lifetime()
	lifetime_timer.one_shot = true
	lifetime_timer.connect("timeout", minion_lifetime_expired.bind(minion))
	minion.add_child(lifetime_timer)
	lifetime_timer.start()
	
	# Zum Spiel hinzufügen
	get_parent().add_child(minion)
	active_minions.append(minion)
	
	# Visuelle Effekte
	spawn_effect(minion.global_position)
	
	print("Minion-Spawner erzeugte einen neuen Minion. Aktive Minions: " + str(active_minions.size()))

func configure_minion(minion):
	# Gemeinsame Eigenschaften für alle Minion-Typen
	minion.add_to_group("minions")
	
	# Verbindung zum Spawner
	minion.spawner = self
	minion.max_range = minion_range
	
	# Kampfeigenschaften
	minion.damage = calculate_minion_damage()
	
	# NPC-Boost anwenden
	if is_boosted:
		minion.damage *= npc_boost_multiplier
		minion.get_node("Sprite2D").modulate = Color(1.0, 0.7, 1.0)  # Helleres Lila bei Boost
	else:
		minion.get_node("Sprite2D").modulate = Color(0.7, 0.3, 0.7)  # Standard-Lila

func minion_lifetime_expired(minion):
	# Prüfe, ob der Minion noch existiert
	if is_instance_valid(minion):
		# Sterbe-Effekt
		spawn_death_effect(minion.global_position)
		
		# Entferne Minion
		minion.queue_free()
		active_minions.erase(minion)

func clean_up_minion_references():
	# Entferne Referenzen zu nicht mehr existierenden Minions
	var i = active_minions.size() - 1
	while i >= 0:
		if not is_instance_valid(active_minions[i]):
			active_minions.remove_at(i)
		i -= 1

func _on_level_up():
	# Aktualisiere die Minion-Statistiken und Limit
	
	# Für alle aktiven Minions: Eigenschaften aktualisieren
	for minion in active_minions:
		if is_instance_valid(minion):
			configure_minion(minion)
	
	# Reichweitenanzeige aktualisieren
	update_range_indicator()

func _on_npc_assigned(npc):
	# Für alle aktiven Minions: Eigenschaften aktualisieren
	for minion in active_minions:
		if is_instance_valid(minion):
			configure_minion(minion)
	
	# Reichweitenanzeige aktualisieren
	update_range_indicator()

func _on_npc_removed(npc):
	# Für alle aktiven Minions: Eigenschaften aktualisieren
	for minion in active_minions:
		if is_instance_valid(minion):
			configure_minion(minion)
	
	# Reichweitenanzeige aktualisieren
	update_range_indicator()

func calculate_max_minions():
	var max = max_minions + (level - 1) * max_minions_per_level
	if is_boosted:
		max = int(max * 1.5)  # 50% mehr Minions bei NPC-Boost
	return max

func calculate_minion_damage():
	return minion_damage + (level - 1) * damage_per_level

func calculate_minion_lifetime():
	return minion_lifetime + (level - 1) * lifetime_per_level

func create_range_indicator():
	# Visueller Indikator für die Minion-Reichweite
	var indicator = Node2D.new()
	indicator.name = "RangeIndicator"
	indicator.z_index = -1
	
	# Skript zum Zeichnen der Reichweite
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var radius = 400.0
var color = Color(0.7, 0.3, 0.7, 0.1)  # Lila, transparent
var dash_count = 32
var dash_length = 10

func _draw():
	# Gefüllter Kreis mit niedriger Transparenz
	draw_circle(Vector2.ZERO, radius, color)
	
	# Gestrichelte Linie für den Umriss
	var line_color = color
	line_color.a = 0.5
	
	var angle_step = TAU / dash_count
	for i in range(dash_count):
		var start_angle = i * angle_step
		var end_angle = start_angle + angle_step / 2.0
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 32, line_color, 2.0)
"""
	indicator.set_script(script)
	
	add_child(indicator)

func update_range_indicator():
	var indicator = get_node_or_null("RangeIndicator")
	if indicator:
		indicator.radius = minion_range
		
		# Bei NPC-Boost intensivere Farbe
		if is_boosted:
			indicator.color = Color(0.8, 0.4, 0.8, 0.15)  # Intensiveres Lila
		else:
			indicator.color = Color(0.7, 0.3, 0.7, 0.1)  # Standard-Lila
		
		indicator.queue_redraw()

func spawn_effect(pos):
	# Spawn-Effekt erstellen
	var effect = Sprite2D.new()
	effect.texture = load("res://icon.svg")  # Einfacher Platzhalter
	effect.global_position = pos
	effect.modulate = Color(0.7, 0.3, 0.7, 0.8)  # Lila, transparent
	effect.scale = Vector2(0.2, 0.2)
	get_parent().add_child(effect)
	
	# Animation
	var tween = create_tween()
	tween.tween_property(effect, "scale", Vector2(0.5, 0.5), 0.2)
	tween.tween_property(effect, "modulate", Color(0.7, 0.3, 0.7, 0), 0.3)
	tween.tween_callback(effect.queue_free)

func spawn_death_effect(pos):
	# Tod-Effekt erstellen
	var effect = Sprite2D.new()
	effect.texture = load("res://icon.svg")  # Einfacher Platzhalter
	effect.global_position = pos
	effect.modulate = Color(0.7, 0.3, 0.7, 0.8)  # Lila, transparent
	effect.scale = Vector2(0.4, 0.4)
	get_parent().add_child(effect)
	
	# Animation
	var tween = create_tween()
	tween.tween_property(effect, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(effect, "modulate", Color(0.7, 0.3, 0.7, 0), 0.3)
	tween.tween_callback(effect.queue_free)

func load_minion_scene():
	# Versuche, spezialisierte Minion-Szene zu laden
	var specialized_minion = load("res://scenes/minion.tscn")
	if specialized_minion:
		return specialized_minion
	
	# Wenn keine spezialisierte Szene existiert, erstelle eine einfache Minion-Szene
	var simple_minion = create_simple_minion_scene()
	return simple_minion

func create_simple_minion_scene():
	# Dies ist nur ein Beispiel, wie wir dynamisch eine einfache Szene erstellen könnten
	# In einem richtigen Spiel würde man normalerweise eine vollständige Szene im Editor erstellen
	
	var scene = PackedScene.new()
	var minion = CharacterBody2D.new()
	minion.set_script(create_minion_script())
	
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")  # Einfacher Platzhalter
	sprite.scale = Vector2(0.2, 0.2)
	minion.add_child(sprite)
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	minion.add_child(collision)
	
	var root = Node.new()
	root.add_child(minion)
	
	return scene

func create_minion_script():
	var script = GDScript.new()
	script.source_code = """
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

func _ready():
	add_to_group("minions")
	
	# Stelle sicher, dass wir einen Spawner haben
	if not spawner:
		print("FEHLER: Minion ohne Spawner erzeugt!")
		queue_free()
		return
	
	# Erkennungsbereich erstellen
	setup_detection_area()

func _physics_process(delta):
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
			# Zufällig in der Nähe des Spawners bewegen
			if randf() < 0.02:  # Selten Richtung ändern
				var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				velocity = random_direction * speed * 0.5  # Langsamer bewegen
	else:
		# Spawner existiert nicht mehr, selbst zerstören
		queue_free()
	
	# Bewegung anwenden
	move_and_slide()
	
	# Neues Ziel suchen, wenn keines vorhanden
	if not current_target or not is_instance_valid(current_target):
		find_closest_enemy()

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
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance and distance <= detection_radius:
			min_distance = distance
			closest_enemy = enemy
	
	current_target = closest_enemy

func attack(target):
	if not is_instance_valid(target):
		return
		
	if target.has_method("take_damage"):
		target.take_damage(damage)
		
	# Angriffstimer zurücksetzen
	can_attack = false
	attack_timer = 0.0
	
	# Angriffsanimation
	var attack_effect = create_tween()
	attack_effect.tween_property(self, "modulate", Color(1.5, 0.7, 1.5), 0.1)
	attack_effect.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
"""
	return script
