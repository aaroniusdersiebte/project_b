extends Control

@onready var hire_button = $HireNPCButton
@onready var cost_label = $CostLabel

var npc_manager
var gold_system

func _ready():
	# Find references
	await get_tree().process_frame
	npc_manager = get_tree().get_first_node_in_group("npc_manager")
	gold_system = get_tree().get_first_node_in_group("gold_system")
	
	if npc_manager:
		update_cost_label()
		hire_button.pressed.connect(_on_hire_button_pressed)
	else:
		print("ERROR: NPCManager not found!")
	
	if gold_system:
		gold_system.gold_changed.connect(_on_gold_changed)
	else:
		print("ERROR: GoldSystem not found!")

func _process(delta):
	# Update button state based on whether we can afford an NPC
	if npc_manager and gold_system:
		hire_button.disabled = not gold_system.can_afford(npc_manager.get_current_npc_cost())

func update_cost_label():
	if npc_manager:
		cost_label.text = "Cost: " + str(npc_manager.get_current_npc_cost()) + " Gold"

func _on_hire_button_pressed():
	if npc_manager:
		npc_manager.try_hire_npc()
		update_cost_label()

func _on_gold_changed(amount):
	# Update the button state when gold changes
	if npc_manager:
		hire_button.disabled = not gold_system.can_afford(npc_manager.get_current_npc_cost())
