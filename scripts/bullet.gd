extends Area2D

# Base properties
@export var speed = 500.0
@export var damage = 1
@export var lifetime = 2.0

# Quelle des Schusses (für XP-Zuweisung)
var source_player = null  # Spieler-Referenz
var tower_source = null   # Turm-Referenz
var npc_source = null     # NPC-Referenz

# Upgrade-related properties
var piercing_count = 0
var is_bouncing = false
var is_homing = false
var is_explosive = false
var slow_effect = 0  # 0-1 slow factor
var poison_effect = 0  # Damage per second
var knockback_force = 0  # Force applied
var direction = Vector2.RIGHT

# Tracking variables
var timer = 0.0
var enemies_hit = []
var target_enemy = null

# Explosion properties
var explosion_radius = 100
var explosion_damage = 2

func _ready():
	# Connect signal for collision
	connect("body_entered", _on_body_entered)
	
	# Set up homing behavior if enabled
	if is_homing:
		find_closest_enemy()

func _physics_process(delta):
	# Update lifetime timer
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	
	# Handle homing behavior
	if is_homing and target_enemy != null and is_instance_valid(target_enemy):
		var target_dir = (target_enemy.global_position - global_position).normalized()
		# Gradually adjust direction for smooth homing
		direction = direction.lerp(target_dir, 0.1).normalized()
	
	# Move bullet
	position += direction * speed * delta
	
	# Rotation to match direction
	rotation = direction.angle()

func _on_body_entered(body):
	# Check if colliding with an enemy
	if body.is_in_group("enemies") and not enemies_hit.has(body):
		handle_enemy_hit(body)
	
	# Check if colliding with a wall and should bounce
	elif body is StaticBody2D and is_bouncing:
		handle_bounce(body)
	elif body is StaticBody2D and not is_bouncing:
		# Destroy if hit wall and not bouncing
		queue_free()

func handle_enemy_hit(enemy):
	# Add to hit list for piercing
	enemies_hit.append(enemy)
	
	# Apply damage
	var was_killed = false
	if enemy.has_method("take_damage"):
		# GDScript ternary operator: value_if_true if condition else value_if_false
		# Hier vermeiden wir den ternären Operator und verwenden eine explizite Zuweisung
		if "last_damage_source" in enemy:
			enemy.last_damage_source = get_damage_source()
		was_killed = enemy.take_damage(damage)
		
		# XP-Zuweisung bei erfolgreichem Kill
		if was_killed:
			assign_kill_xp(enemy)
	
	# Apply slow effect
	if slow_effect > 0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_effect, 3.0)  # Slow for 3 seconds
	
	# Apply poison effect
	if poison_effect > 0 and enemy.has_method("apply_poison"):
		enemy.apply_poison(poison_effect, 5.0)  # Poison for 5 seconds
	
	# Apply knockback
	if knockback_force > 0:
		var knockback_dir = direction.normalized()
		if enemy is CharacterBody2D:
			enemy.velocity += knockback_dir * knockback_force
	
	# Handle explosion on impact
	if is_explosive:
		create_explosion()
		queue_free()
		return
	
	# Handle piercing (destroy bullet if hit limit reached)
	if piercing_count <= 0:
		queue_free()
	else:
		piercing_count -= 1

# Quelle des Schadens ermitteln
func get_damage_source():
	if source_player != null:
		return source_player
	elif tower_source != null:
		return tower_source
	elif npc_source != null:
		return npc_source
	return null

# XP dem Verursacher zuweisen
func assign_kill_xp(enemy):
	var xp_amount = 10  # Standard XP-Wert
	if "xp_value" in enemy:
		xp_amount = enemy.xp_value
	
	# XP basierend auf der Quelle zuweisen
	if source_player and source_player.has_method("add_xp"):
		print("Spieler erhält " + str(xp_amount) + " XP für Kill")
		source_player.add_xp(xp_amount)
	elif tower_source and tower_source.has_method("add_xp"):
		print("Turm erhält " + str(xp_amount) + " XP für Kill")
		tower_source.add_xp(xp_amount)
	elif npc_source and npc_source.has_method("add_xp"):
		print("NPC erhält " + str(xp_amount) + " XP für Kill")
		npc_source.add_xp(xp_amount)
	else:
		# Fallback: XP dem Level-System zuweisen
		var level_system = get_tree().get_first_node_in_group("level_system")
		if level_system and level_system.has_method("add_xp"):
			level_system.add_xp(xp_amount)

func handle_bounce(wall):
	# Get normal vector of the collision
	var collision_normal = Vector2.ZERO
	
	# This is a simple approximation - would be better with proper reflection
	# Cast a ray to find the wall normal
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position - direction * 10, 
		global_position + direction * 10
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		collision_normal = result.normal
	else:
		# If ray failed, use a simplified approximation
		# Try to guess the normal based on position relative to the center
		var to_center = (get_viewport_rect().size / 2 - global_position).normalized()
		collision_normal = to_center
	
	# Calculate reflection
	direction = direction.bounce(collision_normal)
	rotation = direction.angle()

func create_explosion():
	# Create explosion effect
	var explosion = Area2D.new()
	explosion.global_position = global_position
	
	# Visual indicator (temporary sprite)
	var sprite = Sprite2D.new()
	sprite.texture = PlaceholderTexture2D.new()
	sprite.modulate = Color(1, 0.5, 0, 0.7)  # Orange semi-transparent
	sprite.scale = Vector2(explosion_radius / 50.0, explosion_radius / 50.0) * 2
	explosion.add_child(sprite)
	
	# Collision shape for the explosion
	var collision = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	collision.shape = circle
	explosion.add_child(collision)
	
	# Add to scene
	get_parent().add_child(explosion)
	
	# Deal damage to enemies in the explosion radius
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
	
	# Create animation for explosion effect
	var tween = explosion.create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0.5, 0, 0), 0.5)
	tween.tween_callback(explosion.queue_free)

func find_closest_enemy():
	var min_distance = INF
	target_enemy = null
	
	# Find the closest enemy
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var distance = global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			target_enemy = enemy
