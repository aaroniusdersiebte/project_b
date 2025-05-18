extends Node2D

signal building_placed(building)

# Gebäude-Szenen
var tower_scene = preload("res://scenes/tower.tscn")
var xp_farm_scene = preload("res://scenes/xp_farm.tscn")
var gold_farm_scene = preload("res://scenes/gold_farm.tscn")
var healing_station_scene = preload("res://scenes/healing_station.tscn")
var catapult_scene = preload("res://scenes/catapult.tscn")
var minion_spawner_scene = preload("res://scenes/minion_spawner.tscn")

# Gebäude-Kosten
var building_costs = {
	"tower": 100,
	"xp_farm": 150,
	"gold_farm": 200,
	"healing_station": 175,
	"catapult": 200,
	"minion_spawner": 225
}

# UI-Referenzen
var task_menu_scene = preload("res://scenes/npc_task_menu.tscn")
var building_selection_menu_scene = preload("res://scenes/building_selection_menu.tscn")

# System-Referenzen
var gold_system
var npc_manager

# Platzierungsvariablen
var placing_building = false
var building_preview = null
var selected_building_type = "tower"

# UI-Elemente
var task_menu
var building_selection_menu

func _ready():
	add_to_group("tower_manager")
	
	await get_tree().process_frame
	
	gold_system = get_tree().get_first_node_in_group("gold_system")
	npc_manager = get_tree().get_first_node_in_group("npc_manager")
	
	# UI-Menüs erstellen
	task_menu = task_menu_scene.instantiate()
	get_tree().root.add_child(task_menu)
	
	# Bau-Auswahlmenü erstellen (falls verfügbar)
	if ResourceLoader.exists("res://scenes/building_selection_menu.tscn"):
		building_selection_menu = building_selection_menu_scene.instantiate()
		get_tree().root.add_child(building_selection_menu)
		
		# Signale verbinden
		if building_selection_menu:
			building_selection_menu.building_selected.connect(_on_building_selected)
	
	# Signale verbinden
	task_menu.tower_placement_requested.connect(_on_tower_placement_requested)
	task_menu.npc_to_tower_requested.connect(_on_npc_to_tower_requested)
	task_menu.npc_to_position_requested.connect(_on_npc_to_position_requested)
	task_menu.npc_to_follow_requested.connect(_on_npc_to_follow_requested)
	
	# Set tower cost
	task_menu.set_tower_cost(building_costs["tower"])
	
	# Enable input handling
	set_process_input(true)

func _process(delta):
	# Update building preview
	if placing_building and building_preview:
		building_preview.global_position = get_global_mouse_position()
		
		# Visualize placement validity
		var can_place = can_place_building_at(building_preview.global_position)
		building_preview.modulate = Color(0, 1, 0, 0.5) if can_place else Color(1, 0, 0, 0.5)

func _input(event):
	# Toggle task menu with Tab key
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_TAB:
			toggle_task_menu()
		elif event.keycode == KEY_B:
			toggle_building_menu()
	
	# Handle building placement
	if placing_building and building_preview:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var can_place = can_place_building_at(building_preview.global_position)
				if can_place:
					place_building(building_preview.global_position)
				end_building_placement()
			
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				end_building_placement()

func toggle_task_menu():
	if task_menu.task_panel.visible:
		task_menu.close_menu()
	else:
		task_menu.open_menu()

func toggle_building_menu():
	if building_selection_menu and is_instance_valid(building_selection_menu):
		if building_selection_menu.visible:
			building_selection_menu.hide()
		else:
			building_selection_menu.show()

func start_building_placement(building_type="tower"):
	# Aktuellen Gebäudetyp speichern
	selected_building_type = building_type
	
	# Kosten für den gewählten Gebäudetyp abrufen
	var cost = building_costs[building_type]
	
	# Prüfen, ob wir uns das leisten können
	if not gold_system or not gold_system.can_afford(cost):
		print("Nicht genug Gold für " + building_type + "!")
		return
	
	placing_building = true
	
	# Vorschau erstellen
	building_preview = get_building_scene(building_type).instantiate()
	building_preview.modulate = Color(0, 1, 0, 0.5)
	get_parent().add_child(building_preview)

func end_building_placement():
	placing_building = false
	if building_preview:
		building_preview.queue_free()
		building_preview = null

func can_place_building_at(position):
	# Für jetzt einfach überall platzieren lassen
	# In einer echten Implementierung würde man hier Kollisionen prüfen
	return true

func place_building(position):
	# Gold ausgeben
	var cost = building_costs[selected_building_type]
	if not gold_system or not gold_system.can_afford(cost):
		return null
	
	var success = gold_system.spend_gold(cost)
	
	if success:
		# Gebäude erstellen
		var building = get_building_scene(selected_building_type).instantiate()
		building.global_position = position
		get_parent().add_child(building)
		
		emit_signal("building_placed", building)
		return building
	
	return null

func get_building_scene(type):
	match type:
		"tower":
			return tower_scene
		"xp_farm":
			return xp_farm_scene
		"gold_farm":
			return gold_farm_scene
		"healing_station":
			return healing_station_scene
		"catapult":
			return catapult_scene
		"minion_spawner":
			return minion_spawner_scene
		_:
			return tower_scene  # Fallback zum normalen Turm

func _on_tower_placement_requested():
	start_building_placement("tower")

func _on_building_selected(building_type):
	start_building_placement(building_type)

func _on_npc_to_tower_requested(tower):
	if not is_instance_valid(tower):
		print("FEHLER: Ungültiges Gebäude!")
		return
	
	# Get first available NPC
	var available_npc = get_first_available_npc()
	
	if available_npc:
		# Directly move NPC to tower
		available_npc.global_position = tower.global_position
		
		# Set NPC to TOWER mode
		if available_npc.has_method("set_mode"):
			# NPCMode.TOWER is enum value 2
			available_npc.set_mode(2)  # Using direct value for reliability
			print("NPC zum Gebäude zugewiesen!")
		else:
			print("FEHLER: NPC hat keine set_mode-Methode!")
	else:
		print("Keine verfügbaren NPCs gefunden!")

func _on_npc_to_position_requested(position):
	var available_npc = get_first_available_npc()
	
	if available_npc:
		# Move NPC to position
		available_npc.global_position = position
		
		# Set NPC to STATIONARY mode
		if available_npc.has_method("set_mode"):
			# NPCMode.STATIONARY is enum value 1
			available_npc.set_mode(1)  # Using direct value for reliability
			print("NPC positioniert bei: ", position)
		else:
			print("FEHLER: NPC hat keine set_mode-Methode!")
	else:
		print("Keine verfügbaren NPCs gefunden!")

func _on_npc_to_follow_requested():
	if npc_manager:
		# Set all NPCs to FOLLOW mode (enum value 0)
		set_all_npcs_mode(0)
		print("Alle NPCs folgen nun!")

# Helper method to get first available NPC
func get_first_available_npc():
	# Try to get from NPC manager first
	if npc_manager and npc_manager.active_npcs.size() > 0:
		return npc_manager.active_npcs[0]
	
	# Fallback: Try to find NPCs directly
	var npcs = get_tree().get_nodes_in_group("npcs")
	if npcs.size() > 0:
		return npcs[0]
	
	return null

# Set mode for all NPCs
func set_all_npcs_mode(mode):
	# Try via NPC manager
	if npc_manager and npc_manager.has_method("set_all_npcs_mode"):
		npc_manager.set_all_npcs_mode(mode)
		return
	
	# Fallback: Set mode directly
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.has_method("set_mode"):
			npc.set_mode(mode)