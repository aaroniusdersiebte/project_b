extends "res://scripts/building_base.gd"

# XP-Farm: Generiert regelmäßig XP für den Spieler

# Konfiguration
@export var xp_generation_rate = 10.0  # XP pro Minute
@export var xp_generation_interval = 5.0  # Sekunden zwischen XP-Generierung
@export var xp_per_tick = 1  # Generierte XP pro Tick
@export var xp_range = 800.0  # Reichweite zur Verteilung von XP

# Boost-Werte pro Level
@export var rate_boost_per_level = 2.0  # Zusätzliche XP pro Minute pro Level

# Tracking
var xp_timer = 0.0
var level_system
var player

func _post_ready():
	building_type = "XP-Farm"
	
	# Symbol/Textur aktualisieren (anpassen, wenn eine spezifische Textur existiert)
	if $Sprite2D:
		$Sprite2D.modulate = Color(0.5, 1.0, 0.5)  # Grünlich für XP
	
	# XP-Auravisualisierung hinzufügen
	create_xp_aura()
	
	# Referenzen finden
	player = get_tree().get_first_node_in_group("player")
	level_system = get_tree().get_first_node_in_group("level_system")
	
	# XP-Rate basierend auf Level berechnen
	calculate_xp_rate()

func _building_process(delta):
	# XP-Generation
	xp_timer += delta
	
	if xp_timer >= xp_generation_interval:
		xp_timer = 0.0
		generate_xp()

func generate_xp():
	# Aktuelle XP-Menge berechnen
	var xp_amount = xp_per_tick
	
	# Bei NPC-Boost verdoppeln
	if is_boosted:
		xp_amount *= npc_boost_multiplier
	
	# Füge dem Spieler XP hinzu, wenn er in Reichweite ist
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= xp_range:
			if player.has_method("add_xp"):
				player.add_xp(xp_amount)
				spawn_xp_particle(player.global_position, xp_amount)
				print("XP-Farm generierte " + str(xp_amount) + " XP für den Spieler")
	
	# Alternativ füge dem globalen Level-System XP hinzu
	elif level_system and level_system.has_method("add_xp"):
		level_system.add_xp(xp_amount)
		print("XP-Farm generierte " + str(xp_amount) + " XP für das Level-System")

func _on_level_up():
	# Erhöhe die XP-Rate basierend auf Level
	calculate_xp_rate()
	
	# Größere Reichweite mit jedem Level
	xp_range += 50.0
	
	# Aura aktualisieren
	update_xp_aura()

func calculate_xp_rate():
	# Basis-XP-Rate plus Level-Bonus
	var base_rate = xp_generation_rate
	var level_boost = rate_boost_per_level * (level - 1)
	
	# Neue XP-Rate berechnen
	xp_generation_rate = base_rate + level_boost
	
	# XP pro Tick basierend auf Rate und Interval berechnen
	xp_per_tick = max(1, round((xp_generation_rate / 60.0) * xp_generation_interval))

func _on_npc_assigned(npc):
	# XP-Rate neu berechnen, wenn ein NPC zugewiesen wird
	calculate_xp_rate()
	
	# Aura aktualisieren
	update_xp_aura()

func create_xp_aura():
	# Visueller Indikator für die XP-Reichweite
	var aura = Node2D.new()
	aura.name = "XPAura"
	aura.z_index = -1
	
	# Aura-Zeichenskript hinzufügen
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var radius = 800.0
var color = Color(0.3, 1.0, 0.3, 0.1)  # Grün, transparent

func _draw():
	draw_circle(Vector2.ZERO, radius, color)
"""
	aura.set_script(script)
	
	add_child(aura)

func update_xp_aura():
	var aura = get_node_or_null("XPAura")
	if aura:
		aura.radius = xp_range
		
		# Bei NPC-Boost intensivere Farbe
		if is_boosted:
			aura.color = Color(0.3, 1.0, 0.3, 0.2)  # Intensiveres Grün
		else:
			aura.color = Color(0.3, 1.0, 0.3, 0.1)  # Standardgrün
		
		aura.queue_redraw()

func spawn_xp_particle(target_position, amount):
	# Erstelle XP-Partikeleffekt
	var particle = Label.new()
	particle.text = "+" + str(amount) + " XP"
	particle.position = global_position - Vector2(50, 0)
	particle.modulate = Color(0.5, 1.0, 0.5, 1.0)  # Grün
	particle.add_theme_font_size_override("font_size", 20)
	get_parent().add_child(particle)
	
	# Animation
	var tween = create_tween()
	tween.tween_property(particle, "position", target_position, 0.7)
	tween.parallel().tween_property(particle, "modulate", Color(0.5, 1.0, 0.5, 0), 0.8)
	tween.tween_callback(particle.queue_free)
