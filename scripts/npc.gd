# scripts/npc.gd - Improved mode functionality
extends CharacterBody2D

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

# State tracking - IMPORTANT ENUM
enum NPCMode {FOLLOW, STATIONARY, TOWER}
@export var current_mode = NPCMode.FOLLOW

var target_position = Vector2.ZERO
var current_target = null
var player = null
var fire_timer = 0.0
var can_fire = true

# Bullet properties
var bullet_scene = preload("res://scenes/bullet.tscn")

@onready var health_bar = $HealthBar

func _ready():
	add_to_group("npcs")
	
	health_bar.max_value = max_health
	health_bar.value = health
	
	setup_detection_area()
	
	# Find player reference
	player = get_tree().get_first_node_in_group("player")
	
	print("NPC initialized in FOLLOW mode")

func _physics_process(delta):
	# Update fire timer
	if not can_fire:
		fire_timer += delta
		if fire_timer >= fire_rate:
			can_fire = true
			fire_timer = 0.0
	
	# Handle behavior based on current mode
	match current_mode:
		NPCMode.FOLLOW:
			follow_player(delta)
		NPCMode.STATIONARY:
			# Stay in place
			velocity = Vector2.ZERO
		NPCMode.TOWER:
			# Stay at tower
			velocity = Vector2.ZERO
	
	# Apply movement
	move_and_slide()
	
	# Handle combat if not in TOWER mode
	if current_mode != NPCMode.TOWER and current_target != null and can_fire:
		shoot_at_target(current_target)

func follow_player(delta):
	if player and is_instance_valid(player):
		# Calculate direction to player
		var direction = (player.global_position - global_position).normalized()
		
		# Only follow if we're too far away
		if global_position.distance_to(player.global_position) > 100:
			velocity = direction * speed
		else:
			velocity = Vector2.ZERO
	else:
		# Try to find player again
		player = get_tree().get_first_node_in_group("player")
		velocity = Vector2.ZERO

func setup_detection_area():
	# Create detection area
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
	
	# Visual indicator
	var detection_visual = Node2D.new()
	detection_visual.set_script(load("res://scripts/detection_visual.gd"))
	detection_visual.radius = detection_radius
	detection_visual.color = Color(0.0, 0.5, 1.0, 0.1)
	add_child(detection_visual)

func _on_detection_area_body_entered(body):
	# Only target enemies when not in TOWER mode
	if current_mode != NPCMode.TOWER and body.is_in_group("enemies") and current_target == null:
		current_target = body

func _on_detection_area_body_exited(body):
	if body == current_target:
		current_target = null
		
		# Find another target if available
		if current_mode != NPCMode.TOWER:
			find_new_target()

func find_new_target():
	var potential_targets = get_tree().get_nodes_in_group("enemies")
	for target in potential_targets:
		if is_instance_valid(target) and global_position.distance_to(target.global_position) <= detection_radius:
			current_target = target
			break

func shoot_at_target(target):
	if not is_instance_valid(target):
		current_target = null
		return
		
	# Direction to target
	var direction = (target.global_position - global_position).normalized()
	
	# Reset fire timer
	can_fire = false
	fire_timer = 0.0
	
	# Create bullet
	spawn_bullet(direction)

func spawn_bullet(direction):
	# Create bullet
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	
	# Set bullet properties
	bullet.direction = direction
	bullet.damage = damage
	
	# Add to scene
	get_parent().add_child(bullet)

func take_damage(amount):
	health -= amount
	health_bar.value = health
	
	# Flash effect
	modulate = Color(1, 0.3, 0.3)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	if health <= 0:
		die()

func die():
	emit_signal("npc_destroyed")
	queue_free()

func set_mode(mode):
	# Convert int to enum if needed
	if typeof(mode) == TYPE_INT:
		if mode >= 0 and mode < 3:  # Valid mode range
			mode = mode as NPCMode
	
	print("NPC mode changed from ", current_mode, " to ", mode)
	
	# Store previous mode for visual changes
	var prev_mode = current_mode
	current_mode = mode
	
	# Apply visual changes based on mode
	match mode:
		NPCMode.FOLLOW:
			modulate = Color(1, 1, 1)  # Normal color
			print("NPC is now following player")
			
		NPCMode.STATIONARY:
			modulate = Color(0.8, 0.8, 1.0)  # Light blue for stationary
			print("NPC is now stationary")
			
		NPCMode.TOWER:
			modulate = Color(0.5, 0.5, 1.0)  # Darker blue for tower
			print("NPC is now working in tower")

# Helper function to set both position and mode
func set_position_and_mode(pos, mode):
	global_position = pos
	set_mode(mode)
