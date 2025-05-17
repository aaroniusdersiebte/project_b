
extends Node2D

signal tower_placed(tower)

var tower_scene = preload("res://scenes/tower.tscn")
var task_menu_scene = preload("res://scenes/npc_task_menu.tscn")
var gold_system
var npc_manager

var placing_tower = false
var tower_preview = null
var tower_cost = 100

# Task menu
var task_menu

func _ready():
	add_to_group("tower_manager")
	
	await get_tree().process_frame
	
	gold_system = get_tree().get_first_node_in_group("gold_system")
	npc_manager = get_tree().get_first_node_in_group("npc_manager")
	
	# Create task menu - IMPORTANT: Add to root
	task_menu = task_menu_scene.instantiate()
	get_tree().root.add_child(task_menu)
	
	# Connect signals
	task_menu.tower_placement_requested.connect(_on_tower_placement_requested)
	task_menu.npc_to_tower_requested.connect(_on_npc_to_tower_requested)
	task_menu.npc_to_position_requested.connect(_on_npc_to_position_requested)
	task_menu.npc_to_follow_requested.connect(_on_npc_to_follow_requested)
	
	# Set tower cost
	task_menu.set_tower_cost(tower_cost)
	
	# Enable input handling
	set_process_input(true)

func _process(delta):
	# Update tower preview
	if placing_tower and tower_preview:
		tower_preview.global_position = get_global_mouse_position()
		
		# Visualize placement validity
		var can_place = can_place_tower_at(tower_preview.global_position)
		tower_preview.modulate = Color(0, 1, 0, 0.5) if can_place else Color(1, 0, 0, 0.5)

func _input(event):
	# Toggle task menu with Tab key
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		toggle_task_menu()
	
	# Handle tower placement
	if placing_tower and tower_preview:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var can_place = can_place_tower_at(tower_preview.global_position)
				if can_place:
					place_tower(tower_preview.global_position)
				end_tower_placement()
			
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				end_tower_placement()

func toggle_task_menu():
	if task_menu.task_panel.visible:
		task_menu.close_menu()
	else:
		task_menu.open_menu()

func start_tower_placement():
	# Check if we can afford it
	if not gold_system or not gold_system.can_afford(tower_cost):
		print("Not enough gold to place tower!")
		return
	
	placing_tower = true
	
	# Create preview
	tower_preview = tower_scene.instantiate()
	tower_preview.modulate = Color(0, 1, 0, 0.5)
	get_parent().add_child(tower_preview)

func end_tower_placement():
	placing_tower = false
	if tower_preview:
		tower_preview.queue_free()
		tower_preview = null

func can_place_tower_at(position):
	# For now, allow placement anywhere
	return true

func place_tower(position):
	# Spend gold
	if not gold_system or not gold_system.can_afford(tower_cost):
		return null
	
	var success = gold_system.spend_gold(tower_cost)
	
	if success:
		# Create tower
		var tower = tower_scene.instantiate()
		tower.global_position = position
		get_parent().add_child(tower)
		
		emit_signal("tower_placed", tower)
		return tower
	
	return null

func _on_tower_placement_requested():
	start_tower_placement()

func _on_npc_to_tower_requested(tower):
	if not is_instance_valid(tower):
		print("ERROR: Invalid tower!")
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
			print("NPC assigned to tower!")
		else:
			print("ERROR: NPC doesn't have set_mode method!")
	else:
		print("No available NPCs found!")

func _on_npc_to_position_requested(position):
	var available_npc = get_first_available_npc()
	
	if available_npc:
		# Move NPC to position
		available_npc.global_position = position
		
		# Set NPC to STATIONARY mode
		if available_npc.has_method("set_mode"):
			# NPCMode.STATIONARY is enum value 1
			available_npc.set_mode(1)  # Using direct value for reliability
			print("NPC positioned at: ", position)
		else:
			print("ERROR: NPC doesn't have set_mode method!")
	else:
		print("No available NPCs found!")

func _on_npc_to_follow_requested():
	if npc_manager:
		# Set all NPCs to FOLLOW mode (enum value 0)
		set_all_npcs_mode(0)
		print("All NPCs set to follow mode!")

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
