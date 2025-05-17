extends Node

# NPCMode Enum zur Verfügung stellen
enum NPCMode {FOLLOW, STATIONARY, TOWER}

# Referenz zum originalen NPC-Skript
var original_npc_script
var tower_manager
var gold_system

func _ready():
	# Warten auf die Initialisierung anderer Nodes
	call_deferred("_check_npc_script")

func _check_npc_script():
	print("NPCPatcher: Überprüfe NPC-Skript")

	# Versuche, NPCs direkt zu finden
	var npcs = []
	for node in _find_nodes_by_group("npcs"):
		npcs.append(node)
	
	if npcs.size() > 0:
		print("NPCPatcher: " + str(npcs.size()) + " NPCs gefunden")
		var npc_instance = npcs[0]
		_check_npc_modes(npc_instance)
	else:
		print("NPCPatcher: Keine NPCs gefunden. Prüfe später erneut.")
		# Verzögert erneut prüfen
		await get_tree().create_timer(2.0).timeout
		_check_npc_script()

func _check_npc_modes(npc_instance):
	print("NPCPatcher: Prüfe Modi für NPC: " + str(npc_instance))
	
	# Prüfe, ob der NPC die Modi enthält
	var has_tower_mode = false
	
	# Prüfe ob set_mode existiert
	if npc_instance.has_method("set_mode"):
		print("NPCPatcher: NPC hat die set_mode Methode.")
		
		# Prüfe ob NPCMode.TOWER existiert (indirekt)
		if npc_instance.has_method("set_position_and_mode"):
			print("NPCPatcher: NPC hat die set_position_and_mode Methode.")
			has_tower_mode = true
		
	if not has_tower_mode:
		print("WICHTIG: Das NPC-Skript muss manuell aktualisiert werden!")
		print("Füge bitte folgende Zeilen zum enum NPCMode in scripts/npc.gd hinzu:")
		print("enum NPCMode {FOLLOW, STATIONARY, TOWER}")
		print("")
		print("Und stelle sicher, dass die set_position_and_mode Methode existiert.")

func _find_nodes_by_group(group_name):
	var result = []
	var root = get_tree().get_root()
	_find_nodes_by_group_recursive(root, group_name, result)
	return result

func _find_nodes_by_group_recursive(node, group_name, result):
	if node.is_in_group(group_name):
		result.append(node)
	
	for child in node.get_children():
		_find_nodes_by_group_recursive(child, group_name, result)
