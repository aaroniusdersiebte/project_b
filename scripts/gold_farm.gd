extends "res://scripts/building_base.gd"

# Gold-Farm: Generiert regelmäßig Gold für den Spieler

# Konfiguration
@export var gold_generation_rate = 5.0  # Gold pro Minute
@export var gold_generation_interval = 10.0  # Sekunden zwischen Gold-Generierung
@export var gold_per_tick = 1  # Generiertes Gold pro Tick

# Boost-Werte pro Level
@export var rate_boost_per_level = 1.0  # Zusätzliches Gold pro Minute pro Level

# Tracking
var gold_timer = 0.0
var gold_system

func _post_ready():
	building_type = "Gold-Farm"
	
	# Symbol/Textur aktualisieren (anpassen, wenn eine spezifische Textur existiert)
	if $Sprite2D:
		$Sprite2D.modulate = Color(1.0, 0.8, 0.2)  # Gold-Farbe
	
	# Gold-Partikeleffekt hinzufügen
	create_gold_particles()
	
	# Gold-System-Referenz finden
	gold_system = get_tree().get_first_node_in_group("gold_system")
	
	# Gold-Rate basierend auf Level berechnen
	calculate_gold_rate()

func _building_process(delta):
	# Gold-Generation
	gold_timer += delta
	
	if gold_timer >= gold_generation_interval:
		gold_timer = 0.0
		generate_gold()

func generate_gold():
	if not gold_system or not gold_system.has_method("add_gold"):
		print("FEHLER: Gold-System nicht gefunden!")
		return
	
	# Aktuelle Gold-Menge berechnen
	var gold_amount = gold_per_tick
	
	# Bei NPC-Boost verdoppeln
	if is_boosted:
		gold_amount *= npc_boost_multiplier
	
	# Gold zum System hinzufügen
	gold_system.add_gold(gold_amount)
	
	# Visuelle Effekte
	spawn_gold_effect(gold_amount)
	
	print("Gold-Farm generierte " + str(gold_amount) + " Gold")

func _on_level_up():
	# Erhöhe die Gold-Rate basierend auf Level
	calculate_gold_rate()
	
	# Aktualisiere Partikeleffekte
	update_gold_particles()

func calculate_gold_rate():
	# Basis-Gold-Rate plus Level-Bonus
	var base_rate = gold_generation_rate
	var level_boost = rate_boost_per_level * (level - 1)
	
	# Neue Gold-Rate berechnen
	gold_generation_rate = base_rate + level_boost
	
	# Gold pro Tick basierend auf Rate und Interval berechnen
	gold_per_tick = max(1, round((gold_generation_rate / 60.0) * gold_generation_interval))

func _on_npc_assigned(npc):
	# Gold-Rate neu berechnen, wenn ein NPC zugewiesen wird
	calculate_gold_rate()
	
	# Partikeleffekte aktualisieren
	update_gold_particles()

func create_gold_particles():
	# Erstelle einfachen Partikeleffekt für Gold
	var particles = Node2D.new()
	particles.name = "GoldParticles"
	
	# Einfaches Skript zum Zeichnen von Partikeln
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var particle_count = 5
var particles = []
var active = true
var boost_active = false

func _ready():
	# Initialisiere Partikel
	for i in range(particle_count):
		particles.append({
			"position": Vector2(randf_range(-20, 20), randf_range(-40, 0)),
			"speed": randf_range(0.5, 1.5),
			"size": randf_range(2, 4),
			"alpha": randf_range(0.5, 1.0),
			"cycle": randf() * TAU  # Zufällige Startphase
		})

func _process(delta):
	if not active:
		return
		
	# Aktualisiere Partikel
	for particle in particles:
		particle.cycle += delta * particle.speed
		particle.position.y = -20 - 10 * sin(particle.cycle)
		
		# Zurücksetzen, wenn Zyklus abgeschlossen
		if particle.cycle > TAU:
			particle.cycle = 0
			particle.position.x = randf_range(-20, 20)
			particle.alpha = randf_range(0.5, 1.0)
			
	# Neu zeichnen
	queue_redraw()

func _draw():
	if not active:
		return
		
	for particle in particles:
		var color = Color(1.0, 0.8, 0.2, particle.alpha)  # Gold-Farbe
		if boost_active:
			color = Color(1.0, 0.9, 0.3, particle.alpha)  # Helleres Gold bei Boost
			
		draw_circle(particle.position, particle.size, color)
"""
	particles.set_script(script)
	
	add_child(particles)

func update_gold_particles():
	var particles = get_node_or_null("GoldParticles")
	if particles:
		# Aktualisiere Boost-Status
		particles.boost_active = is_boosted
		
		# Aktualisiere Partikelanzahl basierend auf Level
		particles.particle_count = 5 + (level - 1) * 2

func spawn_gold_effect(amount):
	# Erstelle Gold-Texteffekt
	var gold_text = Label.new()
	gold_text.text = "+" + str(amount) + " Gold"
	gold_text.position = global_position + Vector2(0, -120)
	gold_text.modulate = Color(1.0, 0.8, 0.2, 1.0)  # Gold-Farbe
	gold_text.add_theme_font_size_override("font_size", 20)
	get_parent().add_child(gold_text)
	
	# Animation
	var tween = create_tween()
	tween.tween_property(gold_text, "position", gold_text.position + Vector2(0, -30), 1.0)
	tween.parallel().tween_property(gold_text, "modulate", Color(1.0, 0.8, 0.2, 0), 1.0)
	tween.tween_callback(gold_text.queue_free)
