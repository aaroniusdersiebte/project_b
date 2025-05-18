extends "res://scripts/bullet.gd"

# Spezialisiertes Projektil für das Katapult
# Hat zusätzliche visuelle Effekte und verbesserten Flächenschaden

@export var projectile_scale = 1.5  # Größeres Projektil
@export var gravity_effect = 200.0  # Leichte Gravitationssimulation
@export var trail_effect = true  # Spur hinterlassen?

# Überrides aus der Basisklasse
func _ready():
	super._ready()  # Basisklassen-Initialisierung
	
	# Visuelle Anpassungen
	modulate = Color(0.9, 0.4, 0.1)  # Orangefarben für Katapultprojektil
	
	# Größere Kollision
	var collision = get_node("CollisionShape2D")
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius *= projectile_scale
	
	# Größeres Sprite
	var sprite = get_node("Sprite2D")
	if sprite:
		sprite.scale *= projectile_scale
	
	# Spur-Effekt hinzufügen, wenn aktiviert
	if trail_effect:
		add_trail_effect()

func _physics_process(delta):
	# Standard-Bewegung aus der Basisklasse
	super._physics_process(delta)
	
	# Leichte Gravitationssimulation hinzufügen
	direction.y += gravity_effect * delta / speed  # Normalisiert basierend auf Geschwindigkeit
	direction = direction.normalized()
	
	# Rotation anpassen, damit Projektil in Flugrichtung zeigt
	rotation = direction.angle() + PI/2  # +90° für korrekte Ausrichtung

func add_trail_effect():
	# Einfaches Trail-System mit Line2D
	var trail = Line2D.new()
	trail.name = "Trail"
	trail.default_color = Color(0.9, 0.4, 0.1, 0.5)  # Halbtransparente Spur
	trail.width = 10.0
	trail.z_index = -1  # Hinter dem Projektil
	add_child(trail)
	
	# Trail-Skript
	var script = GDScript.new()
	script.source_code = """
extends Line2D

var MAX_POINTS = 20
var point_age = []
var trail_length = 0.5  # Sekunden
var position_history = []

func _ready():
	clear_points()
	set_as_top_level(true)  # Im globalen Raum bleiben
	
func _process(delta):
	var point = get_parent().global_position
	
	# Punkt hinzufügen
	add_point(point)
	point_age.append(0.0)
	
	# Alte Punkte aktualisieren und entfernen
	for i in range(get_point_count() - 1, -1, -1):
		point_age[i] += delta
		
		if point_age[i] > trail_length:
			remove_point(i)
			point_age.remove_at(i)
			
	# Limitiere die Anzahl der Punkte
	if get_point_count() > MAX_POINTS:
		remove_point(0)
		point_age.remove_at(0)
"""
	trail.set_script(script)

# Überschrieben, um angepasste Explosion zu erstellen
func create_explosion():
	# Modifizierte Explosion mit zusätzlichen visuellen Effekten
	var explosion = Area2D.new()
	explosion.global_position = global_position
	
	# Visueller Indikator
	var sprite = Sprite2D.new()
	sprite.texture = load("res://icon.svg")  # Platzhalter, in echtem Projekt besser ein Explosionsbild
	sprite.modulate = Color(1, 0.5, 0, 0.7)  # Orange halbtransparent
	sprite.scale = Vector2(explosion_radius / 50.0, explosion_radius / 50.0) * 2
	explosion.add_child(sprite)
	
	# Kollisionsform für die Explosion
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	collision.shape = circle
	explosion.add_child(collision)
	
	# Partikeleffekt für die Explosion
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 50
	particles.lifetime = 1.0
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(1, 0.5, 0, 1)
	
	explosion.add_child(particles)
	
	# Kameraschütteln (falls möglich)
	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 15, 8)
	
	# Zur Szene hinzufügen
	get_parent().add_child(explosion)
	
	# Schaden an Gegnern in der Explosionsreichweite verursachen
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.global_position.distance_to(global_position) <= explosion_radius:
			if enemy.has_method("take_damage"):
				var was_killed = false
				if "last_damage_source" in enemy:
					enemy.last_damage_source = get_damage_source()
				was_killed = enemy.take_damage(explosion_damage)
				
				# XP-Zuweisung für Explosion-Kills
				if was_killed:
					assign_kill_xp(enemy)
	
	# Animation für Explosionseffekt
	var tween = explosion.create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0, 0), 0.5)
	tween.tween_callback(explosion.queue_free)