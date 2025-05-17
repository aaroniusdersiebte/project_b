extends Node2D

# Signals
signal wave_started(wave_number, enemy_count)
signal wave_completed(wave_number)
signal enemies_remaining_changed(count)

# Wave properties
@export var current_wave = 0
@export var enemies_per_wave_base = 5
@export var enemies_per_wave_multiplier = 1.5
@export var wave_cooldown = 10.0  # Time between waves in seconds
@export var enemy_spawn_delay = 1.0  # Delay between individual enemy spawns

# Enemy properties 
@export var enemy_health_multiplier = 1.1  # How much health increases per wave
@export var enemy_gold_base = 5  # Base gold dropped by enemies
@export var enemy_gold_multiplier = 1.2  # Gold multiplier per wave

# Path system reference
var path_system
var active_enemies = []
var enemies_remaining_in_wave = 0
var wave_timer = 0
var spawn_timer = 0
var wave_in_progress = false
var auto_start_waves = true
var spawn_markers = []
var spawn_warning_time = 3.0  # Sekunden vor dem Spawnen, um zu warnen

# Enemy scene reference
var enemy_scene = preload("res://scenes/enemy.tscn")
var spawn_marker_scene = load("res://scenes/spawn_marker.tscn")  # Lazy-Load statt Preload

func _ready():
	add_to_group("wave_spawner")
	
	# Find the path system
	path_system = get_tree().get_first_node_in_group("path_system")
	if not path_system:
		print("ERROR: Path system not found!")
		return
	
	# Create spawn markers at all spawn points
	create_spawn_markers()
	
	# Start first wave after a delay
	if auto_start_waves:
		wave_timer = wave_cooldown - 3  # Start first wave a bit sooner

func create_spawn_markers():
	# Clear any existing markers
	for marker in spawn_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	spawn_markers.clear()
	
	# Create new markers at all spawn points
	for i in range(path_system.spawn_points.size()):
		var spawn_point = path_system.spawn_points[i]
		var marker = spawn_marker_scene.instantiate()
		marker.global_position = spawn_point
		# Verzögertes Hinzufügen des Kindes, um Probleme beim Initialisieren zu vermeiden
		get_parent().call_deferred("add_child", marker)
		spawn_markers.append(marker)
	
	print("Created " + str(spawn_markers.size()) + " spawn markers")

func _process(delta):
	if wave_in_progress:
		# Handle spawning enemies within the current wave
		process_wave_spawning(delta)
	else:
		# Countdown to next wave
		wave_timer += delta
		
		# Set warning on markers when about to spawn
		update_spawn_markers_warning(wave_timer >= wave_cooldown - spawn_warning_time)
		
		if wave_timer >= wave_cooldown and auto_start_waves:
			start_next_wave()

func update_spawn_markers_warning(warning_active):
	for marker in spawn_markers:
		if is_instance_valid(marker):
			marker.set_warning(warning_active)

func process_wave_spawning(delta):
	if enemies_remaining_in_wave > 0:
		spawn_timer += delta
		
		if spawn_timer >= enemy_spawn_delay:
			spawn_timer = 0
			spawn_enemy()
			enemies_remaining_in_wave -= 1
			emit_signal("enemies_remaining_changed", enemies_remaining_in_wave + active_enemies.size())
	elif active_enemies.size() == 0:
		# All enemies in the wave have been spawned and defeated
		wave_in_progress = false
		wave_timer = 0
		emit_signal("wave_completed", current_wave)

func start_next_wave():
	current_wave += 1
	
	# Calculate number of enemies for this wave
	var enemy_count = enemies_per_wave_base + int(current_wave * enemies_per_wave_multiplier)
	
	# Start the wave
	wave_in_progress = true
	enemies_remaining_in_wave = enemy_count
	spawn_timer = 0
	
	# Clean up any references to enemies that no longer exist
	clean_up_enemy_references()
	
	emit_signal("wave_started", current_wave, enemy_count)
	emit_signal("enemies_remaining_changed", enemy_count)
	
	print("Wave " + str(current_wave) + " started with " + str(enemy_count) + " enemies")

func spawn_enemy():
	# Get a random path
	var path_index = path_system.get_random_path_index()
	if path_index < 0:
		print("ERROR: No valid paths found!")
		return
	
	var path = path_system.get_enemy_path(path_index)
	if path.size() < 2:
		print("ERROR: Path is too short!")
		return
	
	# Create the enemy
	var enemy = enemy_scene.instantiate()
	enemy.global_position = path[0]  # First point is spawn
	
	# Adjust enemy health based on wave number
	var health_boost = pow(enemy_health_multiplier, current_wave - 1)
	enemy.health = int(enemy.health * health_boost)
	
	# Set gold drop based on wave number
	var gold_amount = enemy_gold_base * pow(enemy_gold_multiplier, current_wave - 1)
	enemy.gold_value = int(max(1, gold_amount))
	
	# Set the path for the enemy to follow
	enemy.set_path(path.duplicate())
	enemy.connect("tree_exited", _on_enemy_defeated)
	
	get_parent().add_child(enemy)
	active_enemies.append(enemy)

func _on_enemy_defeated():
	# The enemy was removed from the scene tree
	clean_up_enemy_references()
	
	# Check if wave is complete
	if enemies_remaining_in_wave == 0 and active_enemies.size() == 0:
		wave_in_progress = false
		wave_timer = 0
		emit_signal("wave_completed", current_wave)
	
	emit_signal("enemies_remaining_changed", enemies_remaining_in_wave + active_enemies.size())

func clean_up_enemy_references():
	# Remove references to enemies that no longer exist
	var i = active_enemies.size() - 1
	while i >= 0:
		if not is_instance_valid(active_enemies[i]):
			active_enemies.remove_at(i)
		i -= 1

func get_current_wave_info():
	return {
		"wave_number": current_wave,
		"enemies_remaining": enemies_remaining_in_wave + active_enemies.size(),
		"in_progress": wave_in_progress,
		"next_wave_time": wave_cooldown - wave_timer if not wave_in_progress else 0
	}

func manually_start_next_wave():
	if not wave_in_progress:
		start_next_wave()
