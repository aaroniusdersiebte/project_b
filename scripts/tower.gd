extends StaticBody2D

signal tower_destroyed
signal tower_damaged(current_health, max_health)
signal tower_gained_xp(amount)
signal tower_leveled_up(new_level)

# Grundlegende Turmeigenschaften
@export var max_health = 50
@export var current_health = 50
@export var cost = 100
@export var damage = 2
@export var fire_rate = 2.0  # Sekunden zwischen Schüssen
@export var detection_radius = 400.0
@export var npc_boost_multiplier = 2.0  # Multiplikator für Feuerrate und Schaden mit NPC

# Verfallssystem (nur optional aktivieren)
@export var enable_decay = false  # Standard: Deaktiviert
@export var decay_rate = 0.005  # Wie schnell der Turm verfällt, wenn kein NPC drinnen ist

# Level-System
var level = 1
var current_xp = 0
var xp_to_next_level = 100
var xp_multiplier = 1.5

# Verfügbare NPC-Slots
@export var max_npc_slots = 1
var occupied_slots = 0
var assigned_npcs = []

# Bullet properties
var bullet_scene = preload("res://scenes/bullet.tscn")

# Tracking variables
var fire_timer = 0.0
var can_fire = true
var current_target = null
var is_boosted = false
var decay_timer = 0.0

# Stat-Boosts pro Level
var damage_per_level = 1
var range_per_level = 30.0
var fire_rate_improvement_per_level = 0.1  # 10% schneller

# References
@onready var health_bar = $HealthBar
@onready var level_label = $LevelLabel  # Neues Label für Level-Anzeige

func _ready():
	# Zur Gruppe hinzufügen
	add_to_group("towers")
	
	# Gesundheitsleiste initialisieren
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Level-Label initialisieren
	if not level_label:
		level_label = Label.new()
		level_label.position = Vector2(-15, -160)
		level_label.text = "Lv. " + str(level)
		level_label.modulate = Color(1, 0.8, 0.2)  # Goldene Farbe
		level_label.add_theme_font_size_override("font_size", 14)
		add_child(level_label)
	
	# Erkennungsbereich erstellen
	setup_detection_area()
	
	# Ursprünglich kein NPC im Turm
	is_boosted = false
	
	print("Turm initialisiert - Level: " + str(level) + ", Gesundheit: " + str(current_health))

func _physics_process(delta):
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
	
	# Turm-Verfall, wenn aktiviert und kein NPC drin ist
	if enable_decay and occupied_slots == 0:
		decay_timer += delta
		if decay_timer >= 1.0:  # Jede Sekunde Verfall
			decay_timer = 0.0
			current_health -= max_health * decay_rate
			health_bar.value = current_health
			
			if current_health <= 0:
				die()

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
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# Visueller Indikator
	var detection_visual = Node2D.new()
	detection_visual.set_script(load("res://scripts/detection_visual.gd"))
	detection_visual.radius = detection_radius
	detection_visual.color = Color(0.2, 0.3, 0.8, 0.1)  # Bläulich für Türme
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
	# Richtung zum Ziel
	var direction = (target.global_position - global_position).normalized()
	
	# Feuer-Timer zurücksetzen
	can_fire = false
	fire_timer = 0.0
	
	# Kugel erstellen
	spawn_bullet(direction)

func spawn_bullet(direction):
	# Neue Kugel erstellen
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	
	# Kugeleigenschaften setzen
	bullet.direction = direction
	bullet.damage = calculate_damage()
	bullet.tower_source = self  # Referenz hinzufügen, um XP zurückzuverfolgen
	
	# Kugel zur Szene hinzufügen
	get_parent().add_child(bullet)

# Schaden basierend auf Level und Boost berechnen
func calculate_damage():
	var base_damage = damage + (level - 1) * damage_per_level
	if is_boosted:
		base_damage *= npc_boost_multiplier
	return base_damage

func take_damage(amount):
	current_health -= amount
	health_bar.value = current_health
	
	# Blitz-Effekt
	modulate = Color(1, 0.3, 0.3)  # Rötliche Tönung
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	emit_signal("tower_damaged", current_health, max_health)
	
	if current_health <= 0:
		die()

func die():
	emit_signal("tower_destroyed")
	
	# Alle zugewiesenen NPCs freigeben
	for npc in assigned_npcs:
		if is_instance_valid(npc):
			npc.set_mode(0)  # Zurück zum Folgen-Modus
	
	# Tod-Effekt (optional)
	var death_effect = Sprite2D.new()
	death_effect.texture = $Sprite2D.texture
	death_effect.global_position = global_position
	death_effect.modulate = Color(1, 1, 1, 0.8)
	death_effect.scale = $Sprite2D.scale
	get_parent().add_child(death_effect)
	
	# Ausblenden
	var tween = death_effect.create_tween()
	tween.tween_property(death_effect, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(death_effect.queue_free)
	
	queue_free()

func assign_npc(npc):
	if occupied_slots < max_npc_slots and not assigned_npcs.has(npc):
		assigned_npcs.append(npc)
		occupied_slots += 1
		is_boosted = true
		
		# NPC-Position aktualisieren
		if npc.has_method("set_position_and_mode"):
			npc.set_position_and_mode(global_position, 2)  # 2 = TOWER mode
		else:
			# Fallback: Direktes Setzen
			npc.global_position = global_position
			if npc.has_method("set_mode"):
				npc.set_mode(2)  # 2 = TOWER mode
		
		# Visuelle Aktualisierung
		modulate = Color(0.7, 0.8, 1.0)  # Bläulich für verstärkten Turm
		
		print("NPC dem Turm zugewiesen - Turm ist nun verstärkt!")
		return true
	return false

func remove_npc(npc):
	if assigned_npcs.has(npc):
		assigned_npcs.erase(npc)
		occupied_slots -= 1
		
		if occupied_slots == 0:
			is_boosted = false
			modulate = Color(1, 1, 1)  # Zurück zur normalen Farbe
		
		return true
	return false

# XP hinzufügen, wenn ein Gegner durch eine Kugel dieses Turms getötet wird
func add_xp(amount):
	current_xp += amount
	emit_signal("tower_gained_xp", amount)
	
	# Prüfen, ob Level-Up
	if current_xp >= xp_to_next_level:
		level_up()
	
	print("Turm erhielt " + str(amount) + " XP, gesamt: " + str(current_xp) + "/" + str(xp_to_next_level))

func level_up():
	level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * xp_multiplier)
	
	# Statistiken verbessern
	damage += damage_per_level
	detection_radius += range_per_level
	fire_rate *= (1.0 - fire_rate_improvement_per_level)  # Schneller schießen
	
	# Erkennungsbereich aktualisieren
	update_detection_area()
	
	# Level-Label aktualisieren
	if level_label:
		level_label.text = "Lv. " + str(level)
	
	# Visuelle Effekte für Level-Up
	var level_up_effect = create_tween()
	level_up_effect.tween_property(self, "modulate", Color(1.5, 1.5, 0.5), 0.3)
	level_up_effect.tween_property(self, "modulate", Color(0.7, 0.8, 1.0) if is_boosted else Color(1, 1, 1), 0.3)
	
	emit_signal("tower_leveled_up", level)
	print("Turm Level-Up! Neues Level: " + str(level))
	
	# Falls noch XP übrig, erneut prüfen
	if current_xp >= xp_to_next_level:
		level_up()

func update_detection_area():
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

# Gesundheit wiederherstellen (z.B. durch Reparatur)
func heal(amount):
	current_health = min(current_health + amount, max_health)
	health_bar.value = current_health
