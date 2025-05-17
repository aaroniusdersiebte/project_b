extends CharacterBody2D

# Signals
signal npc_destroyed

# Basic properties
@export var health = 20
@export var max_health = 20
@export var speed = 250.0
@export var cost = 50

# Combat properties
@export var detection_radius = 300.0
@export var fire_rate = 0.7
@export var damage = 1

# State tracking
enum NPCMode {FOLLOW, STATIONARY, TOWER}
@export var current_mode = NPCMode.FOLLOW
var target_position = Vector2.ZERO
var current_target = null
var player = null
var fire_timer = 0.0
var can_fire = true


# Bullet properties
var bullet_scene = preload("res://scenes/bullet.tscn")

# References
@onready var health_bar = $HealthBar

func _ready():
	add_to_group("npcs")
	
	# Initialize health bar
	health_bar.max_value = max_health
	health_bar.value = health
	
	# Create detection area
	setup_detection_area()
	
	# Find player reference
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	# Update fire timer
	if not can_fire:
		fire_timer += delta
		if fire_timer >= fire_rate:
			can_fire = true
			fire_timer = 0.0
	
	# Handle movement based on current mode
	match current_mode:
		NPCMode.FOLLOW:
			follow_player(delta)
		NPCMode.STATIONARY:
			# Don't move, just stay in place
			velocity = Vector2.ZERO
		NPCMode.TOWER:
			# Don't move, just stay in tower
			velocity = Vector2.ZERO
	
	# Apply movement
	move_and_slide()
	
	# Handle combat
	if current_target != null and can_fire:
		shoot_at_target(current_target)

func follow_player(delta):
	if player:
		# Calculate direction to player
		var direction = (player.global_position - global_position).normalized()
		
		# Only follow if we're too far away
		if global_position.distance_to(player.global_position) > 100:
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO

func setup_detection_area():
	# Create the detection area
	var detection_area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	
	circle.radius = detection_radius
	collision_shape.shape = circle
	detection_area.add_child(collision_shape)
	add_child(detection_area)
	
	# Connect signals
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# Add visual indicator
	var detection_visual = Node2D.new()
	detection_visual.set_script(load("res://scripts/detection_visual.gd"))
	detection_visual.radius = detection_radius
	detection_visual.color = Color(0.0, 0.5, 1.0, 0.1)  # Lighter blue for NPCs
	add_child(detection_visual)

func _on_detection_area_body_entered(body):
	# Check if it's an enemy
	if body.is_in_group("enemies") and current_target == null:
		current_target = body

func _on_detection_area_body_exited(body):
	# Enemy left detection range
	if body == current_target:
		current_target = null
		
		# Find another target if available
		var potential_targets = get_tree().get_nodes_in_group("enemies")
		for target in potential_targets:
			var distance = global_position.distance_to(target.global_position)
			if distance <= detection_radius:
				current_target = target
				break

func shoot_at_target(target):
	# Direction to target
	var direction = (target.global_position - global_position).normalized()
	
	# Reset fire timer
	can_fire = false
	fire_timer = 0.0
	
	# Create bullet
	spawn_bullet(direction)

func spawn_bullet(direction):
	# Create a new bullet
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	
	# Set bullet properties
	bullet.direction = direction
	bullet.damage = damage
	
	# Add bullet to scene
	get_parent().add_child(bullet)

func take_damage(amount):
	health -= amount
	health_bar.value = health
	
	# Flash effect
	modulate = Color(1, 0.3, 0.3)  # Red tint
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	if health <= 0:
		die()

func die():
	emit_signal("npc_destroyed")
	queue_free()

func set_mode(mode):
	print("NPC mode set to: ", mode)
	current_mode = mode
	
	# Je nach Modus unterschiedliches Verhalten
	match mode:
		NPCMode.FOLLOW:
			print("NPC folgt jetzt dem Spieler")
			# Modus-spezifische Einstellungen hier
			modulate = Color(1, 1, 1)  # Weiß für normalen Modus
			
		NPCMode.STATIONARY:
			print("NPC bleibt stationär")
			# Modus-spezifische Einstellungen hier
			modulate = Color(0.8, 0.8, 1.0)  # Leichtes Blau für stationären Modus
			
		NPCMode.TOWER:
			print("NPC arbeitet im Turm")
			# Modus-spezifische Einstellungen hier
			modulate = Color(0.5, 0.5, 1.0)  # Stärkeres Blau für Tower-Modus

# Diese Funktion setzt sowohl Position als auch Modus
func set_position_and_mode(pos, mode):
	print("NPC position set to ", pos, " and mode to ", mode)
	global_position = pos
	set_mode(mode)
	
	
