extends Node2D

# Signals
signal wave_started(wave_number, enemy_count)
signal wave_completed(wave_number)
signal enemies_remaining_changed(count)
signal enemy_spawned_at(spawn_index)  # Neues Signal für SpawnDirectionUI

# Wave properties
@export var current_wave = 0
@export var enemies_per_wave_base = 5
@export var enemies_per_wave_multiplier = 1.5
@export var wave_cooldown = 10.0  # Zeit zwischen Wellen
@export var enemy_spawn_delay = 1.0  # Verzögerung zwischen einzelnen Gegnern

# Enemy properties 
@export var enemy_health_multiplier = 1.1
@export var enemy_gold_base = 5
@export var enemy_gold_multiplier = 1.2

# Path system reference
var path_system
var active_enemies = []
var enemies_remaining_in_wave = 0
var wave_timer = 0
var spawn_timer = 0
var wave_in_progress = false
var auto_start_waves = true
var spawn_markers = []
var spawn_warning_time = 3.0
var used_paths = []  # Um zu verfolgen, welche Pfade bereits verwendet wurden

# Enemy scene reference
var enemy_scene = preload("res://scenes/enemy.tscn")
var spawn_marker_scene = load("res://scenes/spawn_marker.tscn")

func _ready():
	add_to_group("wave_spawner")
	
	# Path system finden
	await get_tree().process_frame
	await get_tree().process_frame  # Zusätzlicher Frame-Wait
	
	path_system = get_tree().get_first_node_in_group("path_system")
	if not path_system:
		print("ERROR: Path system not found!")
		return
	
	# Überprüfen, ob Pfade existieren
	print("WaveSpawner found path_system with " + str(path_system.paths.size()) + " paths")
	
	if path_system.paths.size() < 4:
		print("WARNING: Weniger als 4 Pfade gefunden, erneutes Generieren...")
		path_system.path_count = 4
		path_system.paths.clear()
		path_system.spawn_points.clear()
		path_system.generate_paths(4)
		print("Nach Regenerierung: " + str(path_system.paths.size()) + " Pfade")
	
	# Spawn-Marker erstellen
	create_spawn_markers()
	
	# Erste Welle nach Verzögerung starten
	if auto_start_waves:
		wave_timer = wave_cooldown - 3  # Erste Welle etwas früher starten

func create_spawn_markers():
	# Bestehende Marker löschen
	for marker in spawn_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	spawn_markers.clear()
	
	# Neue Marker an allen Spawnpunkten erstellen
	for i in range(path_system.spawn_points.size()):
		var spawn_point = path_system.spawn_points[i]
		var marker = spawn_marker_scene.instantiate()
		marker.global_position = spawn_point
		get_parent().call_deferred("add_child", marker)
		spawn_markers.append(marker)
	
	print("Created " + str(spawn_markers.size()) + " spawn markers")

func _process(delta):
	if wave_in_progress:
		# Gegner innerhalb der aktuellen Welle spawnen
		process_wave_spawning(delta)
	else:
		# Countdown zur nächsten Welle
		wave_timer += delta
		
		# Marker-Warnung wenn Spawn kurz bevorsteht
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
	else:
		# Alle Gegner der Welle wurden gespawnt
		# Prüfen, ob noch Gegner übrig sind
		clean_up_enemy_references()
		
		if active_enemies.size() == 0:
			# Alle Gegner besiegt - Welle beenden
			wave_in_progress = false
			wave_timer = 0
			used_paths.clear()  # Zurücksetzen für die nächste Welle
			emit_signal("wave_completed", current_wave)
			emit_signal("enemies_remaining_changed", 0)  # Explizit auf 0 setzen

func start_next_wave():
	current_wave += 1
	used_paths.clear()  # Pfade für neue Welle zurücksetzen
	
	# Anzahl der Gegner für diese Welle berechnen
	var enemy_count = enemies_per_wave_base + int(current_wave * enemies_per_wave_multiplier)
	
	# Welle starten
	wave_in_progress = true
	enemies_remaining_in_wave = enemy_count
	spawn_timer = 0
	
	# Gegnerreferenzen aufräumen
	clean_up_enemy_references()
	
	emit_signal("wave_started", current_wave, enemy_count)
	emit_signal("enemies_remaining_changed", enemy_count)
	
	print("Wave " + str(current_wave) + " started with " + str(enemy_count) + " enemies")

func spawn_enemy():
	# Pfad wählen (bevorzugt einen noch nicht verwendeten Pfad)
	var path_index = get_next_path_index()
	if path_index < 0:
		print("ERROR: No valid paths found!")
		return
	
	# Den verwendeten Pfad markieren und ausgeben
	if not used_paths.has(path_index):
		used_paths.append(path_index)
	
	print("Spawning enemy on path " + str(path_index) + " of " + str(path_system.paths.size()) + " available paths")
	
	var path = path_system.get_enemy_path(path_index)
	if path.size() < 2:
		print("ERROR: Path is too short!")
		return
	
	# Spawn-Position ausgeben
	print("Spawn position: " + str(path[0]))
	
	# Rest des Codes wie vorher...
	var enemy = enemy_scene.instantiate()
	enemy.global_position = path[0]
	
	# Gegner-Gesundheit basierend auf Wellennummer anpassen
	var health_boost = pow(enemy_health_multiplier, current_wave - 1)
	enemy.health = int(enemy.health * health_boost)
	
	# Gold-Drop basierend auf Wellennummer setzen
	var gold_amount = enemy_gold_base * pow(enemy_gold_multiplier, current_wave - 1)
	enemy.gold_value = int(max(1, gold_amount))
	
	# Pfad für den Gegner setzen
	enemy.set_path(path.duplicate())
	enemy.connect("tree_exited", _on_enemy_defeated)
	
	get_parent().add_child(enemy)
	active_enemies.append(enemy)
	
	# Signal senden, dass an diesem Index ein Feind gespawnt wurde
	emit_signal("enemy_spawned_at", path_index)

func get_next_path_index():
	# Wenn möglich, einen noch nicht verwendeten Pfad wählen
	var available_paths = []
	
	for i in range(path_system.paths.size()):
		if not used_paths.has(i):
			available_paths.append(i)
	
	# Wenn alle Pfade verwendet wurden, einen zufälligen wählen
	if available_paths.size() == 0:
		return path_system.get_random_path_index()
	else:
		# Einen zufälligen aus den verfügbaren Pfaden wählen
		return available_paths[randi() % available_paths.size()]

func _on_enemy_defeated():
	# Der Gegner wurde aus dem Szenenbaum entfernt
	clean_up_enemy_references()
	
	# Prüfen, ob die Welle abgeschlossen ist
	if enemies_remaining_in_wave == 0 and active_enemies.size() == 0:
		wave_in_progress = false
		wave_timer = 0
		emit_signal("wave_completed", current_wave)
	
	# UI aktualisieren
	emit_signal("enemies_remaining_changed", enemies_remaining_in_wave + active_enemies.size())
	print("Enemy defeated - remaining: ", enemies_remaining_in_wave + active_enemies.size())

func clean_up_enemy_references():
	# Referenzen zu nicht mehr existierenden Gegnern entfernen
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
