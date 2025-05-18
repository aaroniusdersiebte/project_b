extends "res://scripts/building_base.gd"

# Heilungsstation: Heilt Spieler und NPCs in Reichweite

# Konfiguration
@export var healing_rate = 2.0  # Heilung pro Sekunde
@export var healing_interval = 1.0  # Sekunden zwischen Heilungsimpulsen
@export var healing_range = 300.0  # Reichweite der Heilung
@export var healing_amount = 1  # Heilungsbetrag pro Tick

# Boost-Werte pro Level
@export var healing_boost_per_level = 0.5  # Zusätzliche Heilung pro Sekunde pro Level
@export var range_boost_per_level = 30.0  # Zusätzliche Reichweite pro Level

# Tracking
var healing_timer = 0.0

func _post_ready():
	building_type = "Heilungsstation"
	
	# Symbol/Textur aktualisieren
	if $Sprite2D:
		$Sprite2D.modulate = Color(0.2, 1.0, 0.7)  # Türkis/Heilungsfarbe
	
	# Heilungsaura hinzufügen
	create_healing_aura()
	
	# Heilungsrate basierend auf Level berechnen
	calculate_healing_rate()

func _building_process(delta):
	# Heilungslogik
	healing_timer += delta
	
	if healing_timer >= healing_interval:
		healing_timer = 0.0
		heal_units_in_range()

func heal_units_in_range():
	# Aktuellen Heilungsbetrag berechnen
	var heal_amount = healing_amount
	
	# Bei NPC-Boost verstärken
	if is_boosted:
		heal_amount *= npc_boost_multiplier
	
	# Alle Einheiten finden
	var heal_targets = []
	
	# Spieler hinzufügen, wenn in Reichweite
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		if distance <= healing_range:
			heal_targets.append(player)
	
	# NPCs hinzufügen
	for npc in get_tree().get_nodes_in_group("npcs"):
		if is_instance_valid(npc):
			var distance = global_position.distance_to(npc.global_position)
			if distance <= healing_range:
				heal_targets.append(npc)
	
	# Auch andere Gebäude in Reichweite heilen
	for building in get_tree().get_nodes_in_group("buildings"):
		if building != self and is_instance_valid(building):
			var distance = global_position.distance_to(building.global_position)
			if distance <= healing_range:
				heal_targets.append(building)
	
	# Heilung anwenden
	var healed_something = false
	for target in heal_targets:
		if target.has_method("heal"):
			target.heal(heal_amount)
			spawn_healing_particle(target.global_position)
			healed_something = true
	
	if healed_something:
		print("Heilungsstation heilte " + str(heal_targets.size()) + " Einheiten für je " + str(heal_amount) + " Lebenspunkte")

func _on_level_up():
	# Erhöhe die Heilungsrate und Reichweite basierend auf Level
	calculate_healing_rate()
	healing_range += range_boost_per_level
	
	# Aura aktualisieren
	update_healing_aura()

func calculate_healing_rate():
	# Basis-Heilungsrate plus Level-Bonus
	var base_rate = healing_rate
	var level_boost = healing_boost_per_level * (level - 1)
	
	# Neue Heilungsrate berechnen
	healing_rate = base_rate + level_boost
	
	# Heilungsbetrag pro Tick berechnen
	healing_amount = max(1, round(healing_rate * healing_interval))

func _on_npc_assigned(npc):
	# Heilungsrate neu berechnen, wenn ein NPC zugewiesen wird
	calculate_healing_rate()
	
	# Aura aktualisieren
	update_healing_aura()

func create_healing_aura():
	# Visueller Indikator für die Heilungsreichweite
	var aura = Node2D.new()
	aura.name = "HealingAura"
	aura.z_index = -1
	
	# Heilungsaura-Zeichenskript
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var radius = 300.0
var color = Color(0.2, 1.0, 0.7, 0.15)  # Türkis, transparent
var pulse_speed = 1.5
var time = 0.0

func _process(delta):
	time += delta * pulse_speed
	queue_redraw()

func _draw():
	var inner_radius = radius * (0.85 + 0.15 * sin(time))
	
	# Hauptaura zeichnen
	draw_circle(Vector2.ZERO, radius, color)
	
	# Pulsierende innere Aura zeichnen
	var inner_color = color
	inner_color.a = 0.25 + 0.15 * sin(time)
	draw_circle(Vector2.ZERO, inner_radius, inner_color)
	
	# Konturlinien zeichnen
	var line_color = color
	line_color.a = 0.7
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, line_color, 2.0)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 64, line_color, 1.5)
"""
	aura.set_script(script)
	
	add_child(aura)

func update_healing_aura():
	var aura = get_node_or_null("HealingAura")
	if aura:
		aura.radius = healing_range
		
		# Bei NPC-Boost intensivere Farbe und schnelleres Pulsieren
		if is_boosted:
			aura.color = Color(0.2, 1.0, 0.7, 0.25)  # Intensiveres Türkis
			aura.pulse_speed = 2.5
		else:
			aura.color = Color(0.2, 1.0, 0.7, 0.15)  # Standard-Türkis
			aura.pulse_speed = 1.5

func spawn_healing_particle(target_position):
	# Heilungspartikel erstellen
	var particle = Label.new()
	particle.text = "+" + str(healing_amount)
	particle.position = target_position + Vector2(0, -30)
	particle.modulate = Color(0.2, 1.0, 0.7, 1.0)  # Türkis
	particle.add_theme_font_size_override("font_size", 16)
	get_parent().add_child(particle)
	
	# Animation
	var tween = create_tween()
	tween.tween_property(particle, "position", particle.position + Vector2(0, -20), 1.0)
	tween.parallel().tween_property(particle, "modulate", Color(0.2, 1.0, 0.7, 0), 1.0)
	tween.tween_callback(particle.queue_free)
