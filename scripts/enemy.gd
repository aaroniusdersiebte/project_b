extends CharacterBody2D

enum EnemyState {
	FOLLOW_PATH, 
	CHASE_TARGET,
	CHARGE_ATTACK,
	ATTACK_COOLDOWN,
	OBSTACLE_AVOIDANCE
}

@export var speed = 150
@export var health = 3
@export var xp_value = 10
@export var gold_value = 5
@export var damage_to_home = 10
@export var detection_radius = 250
@export var return_to_path_time = 5

# Neue Parameter für intelligentere Bewegung
@export var path_offset_range = 50.0  # Maximale seitliche Verschiebung vom Pfad
@export var personal_space = 70.0  # Abstand zu anderen Gegnern halten
@export var avoidance_force = 0.7  # Stärke der Kollisionsvermeidung
@export var charge_attack_distance = 200.0  # Max. Distanz für Angriffssprung
@export var charge_attack_speed = 350.0  # Geschwindigkeit beim Angriff
@export var charge_attack_cooldown = 3.0  # Sekunden zwischen Angriffen
@export var stun_time = 1.0  # Pausenzeit nach Angriff

var current_state = EnemyState.FOLLOW_PATH

# Path following
var path = []
var current_path_index = 0
var arrived_at_home = false

# Pfadfolgevariablen
var path_offset = Vector2.ZERO  # Individuelle Verschiebung vom Pfad
var next_path_recalculation = 0.0
var path_recalculation_interval = 0.5

# Target tracking
var current_target = null
var target_lost_timer = 0

# Angriffsvariablen
var charge_timer = 0.0
var can_charge = true
var charging = false
var stun_timer = 0.0

# Status effect variables
var is_slowed = false
var slow_factor = 0
var slow_timer = 0

var is_poisoned = false
var poison_damage = 0
var poison_timer = 0
var poison_tick = 0
var poison_tick_rate = 1

var base_speed = 150

# Letzte Schadensquelle für XP-Zuweisung
var last_damage_source = null

func _ready():
	# Add to enemies group
	add_to_group("enemies")
	print("Enemy spawned at: ", global_position)
	
	# Store base speed
	base_speed = speed
	
	# Für jeden Gegner eine leicht unterschiedliche Pfadverschiebung
	path_offset = Vector2(
		randf_range(-path_offset_range, path_offset_range),
		randf_range(-path_offset_range, path_offset_range)
	)
	
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
	
	# Timer für Angriffe aktualisieren
	if not can_charge:
		charge_timer += delta
		if charge_timer >= charge_attack_cooldown:
			can_charge = true
			charge_timer = 0.0
	
	# Timer für Betäubung aktualisieren
	if stun_timer > 0:
		stun_timer -= delta
		if stun_timer <= 0:
			if current_state == EnemyState.ATTACK_COOLDOWN:
				# Zurück zum Pfadfolgen oder Jagen
				if current_target and is_instance_valid(current_target):
					current_state = EnemyState.CHASE_TARGET
				else:
					current_state = EnemyState.FOLLOW_PATH
	
	# Update state machine
	match current_state:
		EnemyState.FOLLOW_PATH:
			follow_path_intelligent(delta)
		EnemyState.CHASE_TARGET:
			chase_target_intelligent(delta)
		EnemyState.CHARGE_ATTACK:
			execute_charge_attack(delta)
		EnemyState.ATTACK_COOLDOWN:
			# Nichts tun, Spieler bleibt stehen
			velocity = Vector2.ZERO
		EnemyState.OBSTACLE_AVOIDANCE:
			avoid_obstacle(delta)
	
	# Apply the movement
	move_and_slide()
	
	# Erkennung von Kollisionen für Hindernisse
	check_collisions()

func follow_path_intelligent(delta):
	if path.size() > 0 and current_path_index < path.size() and not arrived_at_home:
		# Aktuellen Zielpunkt holen
		var target_point = path[current_path_index]
		
		# Richtung zum Ziel berechnen
		var raw_direction = (target_point - global_position).normalized()
		
		# Kollisionsvermeidung mit anderen Gegnern
		var avoidance = calculate_avoidance()
		
		# Finale Richtung mit individueller Verschiebung und Kollisionsvermeidung
		var final_direction = raw_direction + path_offset / 100.0 + avoidance
		final_direction = final_direction.normalized()
		
		# Zum Ziel bewegen
		velocity = final_direction * speed
		
		# Prüfen, ob wir den aktuellen Zielpunkt erreicht haben
		var distance_to_target = global_position.distance_to(target_point)
		if distance_to_target < 20:
			current_path_index += 1
			
			# Prüfen, ob wir das Zuhause erreicht haben
			if current_path_index >= path.size():
				reach_home()

func chase_target_intelligent(delta):
	if current_target and is_instance_valid(current_target):
		var distance_to_target = global_position.distance_to(current_target.global_position)
		
		# Prüfen, ob wir angreifen können
		if can_charge and distance_to_target <= charge_attack_distance and distance_to_target > 60:
			prepare_charge_attack()
			return
		
		# Normale Verfolgungsbewegung
		var direction = (current_target.global_position - global_position).normalized()
		
		# Kollisionsvermeidung hinzufügen
		var avoidance = calculate_avoidance()
		var final_direction = direction + avoidance
		final_direction = final_direction.normalized()
		
		velocity = final_direction * speed
		
		# Ziel wird weiter verfolgt
		target_lost_timer = 0
	else:
		# No valid target, count down until we return to path
		target_lost_timer += delta
		if target_lost_timer >= return_to_path_time:
			return_to_path()

func prepare_charge_attack():
	if not current_target or not is_instance_valid(current_target):
		return
	
	current_state = EnemyState.CHARGE_ATTACK
	can_charge = false
	charge_timer = 0.0
	charging = true
	
	# Visuelles Feedback für Angriffsstart (optional)
	modulate = Color(1.0, 0.5, 0.5)  # Rötlich beim Angriff

func execute_charge_attack(delta):
	if not current_target or not is_instance_valid(current_target):
		# Ziel verloren, zurück zur Pfadverfolgung
		current_state = EnemyState.FOLLOW_PATH
		modulate = Color(1, 1, 1)  # Farbe zurücksetzen
		return
	
	# In Richtung des Ziels angreifen
	var direction = (current_target.global_position - global_position).normalized()
	velocity = direction * charge_attack_speed
	
	# Prüfen, ob wir das Ziel getroffen haben
	var distance_to_target = global_position.distance_to(current_target.global_position)
	if distance_to_target < 30:  # Nahkampfreichweite
		if current_target.has_method("take_damage"):
			current_target.take_damage(1)  # Schaden verursachen
		
		# Angriff abgeschlossen, Abklingzeit starten
		end_charge_attack()

func end_charge_attack():
	current_state = EnemyState.ATTACK_COOLDOWN
	stun_timer = stun_time
	charging = false
	modulate = Color(0.7, 0.7, 1.0)  # Bläulich während Betäubung
	
	# Timing für Übergang zurück zur normalen Farbe
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), stun_time)

func calculate_avoidance():
	var avoidance = Vector2.ZERO
	
	# Ausweichen von anderen Gegnern
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < personal_space:
				var push_vector = global_position - enemy.global_position
				push_vector = push_vector.normalized()
				
				# Stärkeres Ausweichen bei geringerem Abstand
				var push_strength = (personal_space - distance) / personal_space
				avoidance += push_vector * push_strength
	
	# Ausweichen von Dekorationen
	for decoration in get_tree().get_nodes_in_group("decorations"):
		var distance = global_position.distance_to(decoration.global_position)
		if distance < 100:  # Ausweichradius für Dekorationen
			var push_vector = global_position - decoration.global_position
			push_vector = push_vector.normalized()
			
			var push_strength = (100 - distance) / 100
			avoidance += push_vector * push_strength * 1.5  # Stärkeres Ausweichen für feste Hindernisse
	
	# Ausweichen stärker gewichten für einen natürlicheren Effekt
	avoidance = avoidance.normalized() * min(avoidance.length(), 1.0) * avoidance_force
	
	return avoidance

func check_collisions():
	# Kollisionsprüfung
	if get_slide_collision_count() > 0:
		var collision = get_slide_collision(0)
		
		# Wenn wir mit einem statischen Körper kollidieren (Hindernis)
		if collision.get_collider() is StaticBody2D and current_state != EnemyState.OBSTACLE_AVOIDANCE:
			current_state = EnemyState.OBSTACLE_AVOIDANCE
			next_path_recalculation = 0.0  # Sofort neu berechnen

func avoid_obstacle(delta):
	# Aktualisiere Timer für Neuberechnung
	next_path_recalculation -= delta
	
	if next_path_recalculation <= 0:
		next_path_recalculation = path_recalculation_interval
		
		# Aktuellen Kollisionspunkt suchen
		var space_state = get_world_2d().direct_space_state
		var result = null
		
		# Richtungen suchen, wo kein Hindernis ist
		var directions = [
			Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
			Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
			Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()
		]
		
		# Zufällig mischen für unterschiedliche Ausweichpfade
		directions.shuffle()
		
		var avoidance_dir = Vector2.ZERO
		
		# Erste freie Richtung auswählen
		for dir in directions:
			var query = PhysicsRayQueryParameters2D.create(
				global_position,
				global_position + dir * 100,
				collision_mask
			)
			query.exclude = [self]
			result = space_state.intersect_ray(query)
			
			if not result:
				avoidance_dir = dir
				break
		
		# Wenn alle Richtungen blockiert sind, versuche diagonal
		if avoidance_dir == Vector2.ZERO:
			avoidance_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		# Ausweichen in die gewählte Richtung
		velocity = avoidance_dir * speed
		
		# Prüfen, ob wir nicht mehr kollidieren
		if get_slide_collision_count() == 0:
			# Zurück zum vorherigen Zustand
			if current_target and is_instance_valid(current_target):
				current_state = EnemyState.CHASE_TARGET
			else:
				current_state = EnemyState.FOLLOW_PATH

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

func take_damage(amount, source=null):
	health -= amount
	print("Enemy took damage: ", amount, ", health left: ", health)
	
	# Speichere Schadensquelle für XP-Zuweisung
	if source != null:
		last_damage_source = source
	
	# Flash effect to indicate damage
	modulate = Color(1, 0.3, 0.3)  # Red tint
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	if health <= 0:
		die()
		return true  # Signalisiert, dass der Gegner getötet wurde
	
	return false  # Gegner lebt noch

func die():
	# Award XP to the killer through level system
	var level_system = get_tree().get_first_node_in_group("level_system")
	
	# Priorität: Letzte Schadensquelle, sonst Level-System
	if last_damage_source != null and last_damage_source.has_method("add_xp"):
		last_damage_source.add_xp(xp_value)
	elif level_system:
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
	
	# XP-Label hinzufügen
	var xp_label = Label.new()
	xp_label.text = "+" + str(xp_value) + " XP"
	xp_label.position = Vector2(-40, -75)
	xp_label.modulate = Color(0.5, 1, 0.5, 1)  # Grünlich für XP
	xp_label.add_theme_font_size_override("font_size", 20)
	add_child(xp_label)
	
	# Animate the labels
	var tween = create_tween()
	tween.tween_property(gold_label, "position", Vector2(-40, -100), 1.0)
	tween.parallel().tween_property(gold_label, "modulate", Color(1, 0.84, 0, 0), 1.0)
	
	var xp_tween = create_tween()
	xp_tween.tween_property(xp_label, "position", Vector2(-40, -125), 1.0)
	xp_tween.parallel().tween_property(xp_label, "modulate", Color(0.5, 1, 0.5, 0), 1.0)

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
