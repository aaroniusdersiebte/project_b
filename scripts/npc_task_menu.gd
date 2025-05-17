extends CanvasLayer

signal tower_placement_requested
signal npc_to_tower_requested(tower)
signal npc_to_position_requested(position)
signal npc_to_follow_requested

@onready var task_panel = $TaskPanel
@onready var tower_button = $TaskPanel/TowerButton
@onready var tower_cost_label = $TaskPanel/TowerCostLabel
@onready var assign_to_tower_button = $TaskPanel/AssignToTowerButton
@onready var position_npc_button = $TaskPanel/PositionNPCButton
@onready var follow_npc_button = $TaskPanel/FollowNPCButton
@onready var close_button = $TaskPanel/CloseButton

# State flags
var placing_tower = false
var positioning_npc = false
var selecting_tower = false
var tower_cost = 100

# References
var gold_system
var npc_manager

func _ready():
	await get_tree().process_frame
	
	# Find references
	gold_system = get_tree().get_first_node_in_group("gold_system")
	npc_manager = get_tree().get_first_node_in_group("npc_manager")
	
	# Connect buttons
	tower_button.pressed.connect(_on_tower_button_pressed)
	assign_to_tower_button.pressed.connect(_on_assign_to_tower_button_pressed)
	position_npc_button.pressed.connect(_on_position_npc_button_pressed)
	follow_npc_button.pressed.connect(_on_follow_npc_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Initially hide panel
	task_panel.visible = false
	
	# Update cost label
	tower_cost_label.text = "Kosten: " + str(tower_cost) + " Gold"
	
	print("NPC Task Menu initialized")

func _process(_delta):
	update_button_states()

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print("NPC TASK MENU: Mouse click - positioning_npc: ", positioning_npc, ", selecting_tower: ", selecting_tower)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if positioning_npc:
				# Get world position from mouse
				var world_pos = get_global_mouse_position()
				print("Positioning NPC at: ", world_pos)
				
				emit_signal("npc_to_position_requested", world_pos)
				positioning_npc = false
			
			elif selecting_tower:
				var selected_tower = get_tower_at_mouse_position()
				if selected_tower:
					print("Tower selected: ", selected_tower)
					emit_signal("npc_to_tower_requested", selected_tower)
				selecting_tower = false
		
		# Cancel with right-click
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if positioning_npc or selecting_tower:
				positioning_npc = false
				selecting_tower = false

# Helper to get global mouse position in world space
func get_global_mouse_position() -> Vector2:
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	if camera:
		return camera.get_global_mouse_position()
	return Vector2.ZERO

func get_tower_at_mouse_position() -> Node:
	var world_pos = get_global_mouse_position()
	
	# Find closest tower
	var closest_tower = null
	var min_distance = 100.0  # Maximum selection distance
	
	for tower in get_tree().get_nodes_in_group("towers"):
		var distance = tower.global_position.distance_to(world_pos)
		if distance < min_distance:
			min_distance = distance
			closest_tower = tower
	
	return closest_tower

func update_button_states():
	# Enable/disable buttons based on available resources
	if gold_system:
		tower_button.disabled = not gold_system.can_afford(tower_cost)
	
	var have_npcs = npc_manager and npc_manager.active_npcs.size() > 0
	assign_to_tower_button.disabled = not have_npcs
	position_npc_button.disabled = not have_npcs
	follow_npc_button.disabled = not have_npcs

func open_menu():
	task_panel.visible = true
	update_button_states()

func close_menu():
	task_panel.visible = false
	# Note: We no longer reset state flags here

func _on_tower_button_pressed():
	if gold_system and gold_system.can_afford(tower_cost):
		task_panel.visible = false
		emit_signal("tower_placement_requested")
	else:
		print("Not enough gold!")

func _on_assign_to_tower_button_pressed():
	print("Select a tower to assign NPC")
	task_panel.visible = false
	selecting_tower = true

func _on_position_npc_button_pressed():
	print("Click to position NPC")
	task_panel.visible = false
	positioning_npc = true

func _on_follow_npc_button_pressed():
	emit_signal("npc_to_follow_requested")
	task_panel.visible = false

func _on_close_button_pressed():
	task_panel.visible = false

func set_tower_cost(cost):
	tower_cost = cost
	tower_cost_label.text = "Kosten: " + str(tower_cost) + " Gold"
