extends CharacterBody2D

enum EnemyState {
	FOLLOW_PATH, 
	CHASE_TARGET
}

@export var speed = 150
@export var health = 3
@export var xp_value = 10  # XP awarded when killed
@export var gold_value = 5  # Gold awarded when killed
@export var damage_to_home = 10  # Damage dealt to the home when reaching it
@export var detection_radius = 250  # Radius um Spieler/NPCs zu erkennen
@export var return_to_path_time = 5  # Zeit nach der zum Pfad zurückgekehrt wird (wenn Target weg ist)

var current_state = EnemyState.FOLLOW_PATH

# Path following
var path = []
var current_path_index = 0
var arrived_at_home = false

# Target tracking
var current_target = null
var target_lost_timer = 0

# Status effect variables
var is_slowed = false
var slow_factor = 0
var slow_timer = 0

var is_poisoned = false
var poison_damage = 0
var poison_timer = 0
var poison_tick = 0
var poison_tick_rate = 1  # Damage applied every second

var base_speed = 150  # Store original speed for slow effect

func _ready():
	# Add to enemies group
	add_to_group("enemies")
	print("Enemy spawned at: ", global_position)
	
	# Store base speed
	base_speed = speed
	
	# Set up detection area
	setup_detection_area()

func setup_detection_area():
	# Create an Area2D for player/npc detection
	var detection_area = Area2D.new()
	var collision_shape = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	
	circle_shape.radius = detection_radius
	collision_shape.shape = circle_shape
	detection_area.add_child(collision_shape)
	add_child(detection_area)
	
	# Connect signals
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	
	# Optional: Visualize detection radius (for debugging)
	var detection_visual = Node2D.new()
	detection_visual.set_script(load("res://scripts/detection_visual.gd"))
	detection_visual.radius = detection_radius
	detection_visual.color = Color(1, 0, 0, 0.1)  # Rötlicher Kreis
	add_child(detection_visual)

func _physics_process(delta):
	# Update status effects
	update_status_effects(delta)
	
	# Update state machine
	match current_state:
		EnemyState.FOLLOW_PATH:
			follow_path()
		EnemyState.CHASE_TARGET:
			chase_target(delta)
	
	# Apply the movement
	move_and_slide()

func follow_path():
	if path.size() > 0 and current_path_index < path.size() and not arrived_at_home:
		# Get the current target point
		var target = path[current_path_index]
		
		# Calculate direction to the target
		var direction = (target - global_position).normalized()
		
		# Move towards the target
		velocity = direction * speed
		
		# Check if we've reached the current target point
		var distance_to_target = global_position.distance_to(target)
		if distance_to_target < 20:  # "Close enough" to the point
			current_path_index += 1
			
			# Check if we've reached the home
			if current_path_index >= path.size():
				reach_home()

func chase_target(delta):
	if current_target and is_instance_valid(current_target):
		# Chase the target
		var direction = (current_target.global_position - global_position).normalized()
		velocity = direction * speed
		
		# Keep track if we're still chasing
		target_lost_timer = 0
	else:
		# No valid target, count down until we return to path
		target_lost_timer += delta
		if target_lost_timer >= return_to_path_time:
			return_to_path()
			
func return_to_path():
	# Find the closest point on our path
	if path.size() > 0:
		var closest_dist = INF
		var closest_index = current_path_index
		
		for i in range(current_path_index, path.size()):
			var dist = global_position.distance_to(path[i])
			if dist < closest_dist:
				closest_dist = dist
				closest_index = i
		
		current_path_index = closest_index
		current_state = EnemyState.FOLLOW_PATH
		current_target = null

func set_path(new_path):
	path = new_path
	current_path_index = 0

func reach_home():
	if arrived_at_home:
		return
		
	arrived_at_home = true
	
	# Find the home
	var home = get_tree().get_first_node_in_group("home")
	if home and home.has_method("take_damage"):
		home.take_damage(damage_to_home)
		print("Enemy reached home and dealt " + str(damage_to_home) + " damage!")
	
	# Remove the enemy
	queue_free()

func take_damage(amount):
	health -= amount
	print("Enemy took damage: ", amount, ", health left: ", health)
	
	# Flash effect to indicate damage
	modulate = Color(1, 0.3, 0.3)  # Red tint
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	if health <= 0:
		die()

func die():
	# Award XP to the player through level system
	var level_system = get_tree().get_first_node_in_group("level_system")
	if level_system:
		level_system.add_xp(xp_value)
	
	# Award gold to the player
	var gold_system = get_tree().get_first_node_in_group("gold_system")
	if gold_system:
		gold_system.add_gold(gold_value)
	
	# Visual gold indicator (optional)
	display_gold_earned()
	
	# Death effect
	var death_effect = Sprite2D.new()
	death_effect.texture = $Sprite2D.texture
	death_effect.global_position = global_position
	death_effect.modulate = Color(1, 1, 1, 0.8)
	death_effect.scale = $Sprite2D.scale
	get_parent().add_child(death_effect)
	
	# Fade out effect
	var tween = death_effect.create_tween()
	tween.tween_property(death_effect, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(death_effect.queue_free)
	
	# Remove the enemy
	queue_free()

func display_gold_earned():
	# Create a label to show gold earned
	var gold_label = Label.new()
	gold_label.text = "+" + str(gold_value) + " Gold"
	gold_label.position = Vector2(-40, -50)
	gold_label.modulate = Color(1, 0.84, 0, 1)  # Gold color
	gold_label.add_theme_font_size_override("font_size", 20)
	add_child(gold_label)
	
	# Animate the label
	var tween = create_tween()
	tween.tween_property(gold_label, "position", Vector2(-40, -100), 1.0)
	tween.parallel().tween_property(gold_label, "modulate", Color(1, 0.84, 0, 0), 1.0)
	# Label will be freed when the enemy is freed

func apply_slow(factor, duration):
	# Apply stronger slow if received
	if factor > slow_factor:
		slow_factor = factor
	
	is_slowed = true
	slow_timer = duration
	
	# Immediately apply slow effect
	speed = base_speed * (1.0 - slow_factor)
	
	# Visual indicator (optional)
	modulate = Color(0.5, 0.5, 1.0)  # Blue tint for slowed

func apply_poison(damage_per_second, duration):
	is_poisoned = true
	poison_damage = damage_per_second
	poison_timer = duration
	poison_tick = 0
	
	# Visual indicator (optional)
	modulate = Color(0.5, 1.0, 0.5)  # Green tint for poisoned

func update_status_effects(delta):
	# Update slow effect
	if is_slowed:
		slow_timer -= delta
		if slow_timer <= 0:
			is_slowed = false
			speed = base_speed
			modulate = Color(1, 1, 1)  # Reset color
		else:
			# Keep slow visual indicator
			modulate = Color(0.5, 0.5, 1.0)
	
	# Update poison effect
	if is_poisoned:
		poison_timer -= delta
		poison_tick += delta
		
		# Apply poison damage on tick
		if poison_tick >= poison_tick_rate:
			poison_tick = 0
			take_damage(poison_damage)
		
		if poison_timer <= 0:
			is_poisoned = false
			modulate = Color(1, 1, 1)  # Reset color if not slowed
			if is_slowed:
				modulate = Color(0.5, 0.5, 1.0)  # Keep slow color
		else:
			# Keep poison visual indicator
			modulate = Color(0.5, 1.0, 0.5)  # Green tint
			
			# If both poisoned and slowed, use a mixed color
			if is_slowed:
				modulate = Color(0.5, 0.75, 0.75)  # Teal-ish

func _on_detection_area_body_entered(body):
	# Check if we detected the player or an NPC
	if body.is_in_group("player") or body.is_in_group("npcs"):
		current_target = body
		current_state = EnemyState.CHASE_TARGET
		print("Enemy spotted target: ", body.name)

func _on_detection_area_body_exited(body):
	# If our current target leaves the range
	if body == current_target:
		# Start counting down to return to path
		target_lost_timer = 0
