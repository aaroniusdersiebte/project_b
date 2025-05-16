extends Node2D

signal npc_hired(npc)
signal npc_lost(npc)

@export var max_npcs = 10
@export var npc_cost = 50
@export var npc_cost_multiplier = 1.2  # Each NPC costs more than the last

var npc_scene = preload("res://scenes/npc.tscn")
var active_npcs = []
var gold_system
var current_npc_cost

# Mode for placing NPCs
var placement_mode = false
var placement_preview = null

func _ready():
	add_to_group("npc_manager")
	
	# Find the gold system
	await get_tree().process_frame
	gold_system = get_tree().get_first_node_in_group("gold_system")
	
	if not gold_system:
		print("ERROR: GoldSystem not found!")
	
	current_npc_cost = npc_cost

func _process(delta):
	# Handle placement preview if in placement mode
	if placement_mode and placement_preview:
		placement_preview.global_position = get_global_mouse_position()
		
		# Check if player clicked to place
		if Input.is_action_just_pressed("ui_select"):  # Left mouse click
			place_npc_at_current_position()
		
		# Cancel placement with right click
		if Input.is_action_just_pressed("ui_cancel"):  # Right mouse click or escape key
			cancel_placement()

func try_hire_npc():
	if active_npcs.size() >= max_npcs:
		print("Maximum number of NPCs reached!")
		return false
	
	if gold_system and gold_system.can_afford(current_npc_cost):
		start_npc_placement()
		return true
	else:
		print("Not enough gold to hire NPC!")
		return false

func start_npc_placement():
	placement_mode = true
	
	# Create a preview NPC
	placement_preview = npc_scene.instantiate()
	placement_preview.modulate.a = 0.5  # Make it semi-transparent
	get_parent().add_child(placement_preview)
	
	# Disable collision and detection for the preview
	var collision = placement_preview.get_node("CollisionShape2D")
	if collision:
		collision.disabled = true

func place_npc_at_current_position():
	# Spend the gold
	if gold_system.spend_gold(current_npc_cost):
		# Create the actual NPC
		var npc = npc_scene.instantiate()
		npc.global_position = placement_preview.global_position
		npc.npc_destroyed.connect(_on_npc_destroyed.bind(npc))
		get_parent().add_child(npc)
		
		# Add to active NPCs
		active_npcs.append(npc)
		
		# Calculate the cost for the next NPC
		current_npc_cost = int(npc_cost * pow(npc_cost_multiplier, active_npcs.size()))
		
		# Reset placement mode
		cancel_placement()
		
		emit_signal("npc_hired", npc)
		print("NPC hired! Total NPCs: " + str(active_npcs.size()))
		return true
	else:
		cancel_placement()
		return false

func cancel_placement():
	placement_mode = false
	if placement_preview:
		placement_preview.queue_free()
		placement_preview = null

func _on_npc_destroyed(npc):
	# Remove from active NPCs
	var index = active_npcs.find(npc)
	if index >= 0:
		active_npcs.remove_at(index)
	
	emit_signal("npc_lost", npc)
	print("NPC destroyed! Remaining NPCs: " + str(active_npcs.size()))

func get_current_npc_cost():
	return current_npc_cost

func get_npc_count():
	return active_npcs.size()

# Set all NPCs to a specific mode
func set_all_npcs_mode(mode):
	for npc in active_npcs:
		npc.set_mode(mode)
