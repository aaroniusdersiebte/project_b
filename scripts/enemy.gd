extends CharacterBody2D

@export var speed = 150.0
@export var health = 3
@export var xp_value = 10  # XP awarded when killed

var player = null
var base_speed = 150.0  # Store original speed for slow effect

# Status effect variables
var is_slowed = false
var slow_factor = 0.0
var slow_timer = 0.0

var is_poisoned = false
var poison_damage = 0.0
var poison_timer = 0.0
var poison_tick = 0.0
var poison_tick_rate = 1.0  # Damage applied every second

func _ready():
	# Wichtig: Zur enemies-Gruppe hinzufügen
	add_to_group("enemies")
	print("Enemy spawned at: ", global_position)
	
	# Store base speed
	base_speed = speed
	
	# Spieler finden
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	# Update status effects
	update_status_effects(delta)
	
	# Prüfen, ob Player existiert
	if player == null:
		# Versuchen, Player zu finden
		player = get_tree().get_first_node_in_group("player")
		return
		
	# Richtung zum Spieler berechnen
	var direction = (player.global_position - global_position).normalized()
	
	# Apply current speed (may be affected by slow)
	velocity = direction * speed
	move_and_slide()

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
	
	# Optional: Death effect
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
	poison_tick = 0.0
	
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
			poison_tick = 0.0
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
