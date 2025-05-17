extends CanvasLayer

signal tower_placement_requested
signal npc_to_tower_requested(tower)
signal npc_to_position_requested(position)
signal npc_to_follow_requested

# Referenzen zu UI-Elementen
@onready var task_panel = $TaskPanel
@onready var tower_button = $TaskPanel/TowerButton
@onready var tower_cost_label = $TaskPanel/TowerCostLabel
@onready var assign_to_tower_button = $TaskPanel/AssignToTowerButton
@onready var position_npc_button = $TaskPanel/PositionNPCButton
@onready var follow_npc_button = $TaskPanel/FollowNPCButton
@onready var close_button = $TaskPanel/CloseButton

# Platzierungsstatus
var placing_tower = false
var positioning_npc = false
var selecting_tower = false
var tower_cost = 100  # Standard-Turmkosten

# Referenzen
var gold_system
var npc_manager

func _ready():
	# Auf Initialisierung warten
	await get_tree().process_frame
	
	# Referenzen finden
	gold_system = get_tree().get_first_node_in_group("gold_system")
	npc_manager = get_tree().get_first_node_in_group("npc_manager")
	
	if not gold_system:
		print("FEHLER: NPC-TaskMenu - GoldSystem nicht gefunden!")
	else:
		print("NPC-TaskMenu - GoldSystem gefunden, Gold: ", gold_system.current_gold)
	
	if not npc_manager:
		print("FEHLER: NPC-TaskMenu - NPCManager nicht gefunden!")
	else:
		print("NPC-TaskMenu - NPCManager gefunden, NPCs: ", npc_manager.active_npcs.size())
	
	# Buttons verbinden
	tower_button.pressed.connect(_on_tower_button_pressed)
	assign_to_tower_button.pressed.connect(_on_assign_to_tower_button_pressed)
	position_npc_button.pressed.connect(_on_position_npc_button_pressed)
	follow_npc_button.pressed.connect(_on_follow_npc_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Standardmäßig Panel ausblenden
	task_panel.visible = false
	
	# Turmkosten-Label aktualisieren
	tower_cost_label.text = "Kosten: " + str(tower_cost) + " Gold"
	
	print("NPC-TaskMenu initialisiert")

func _process(delta):
	update_button_states()

func _input(event):
	# Debug-Ausgabe für Mausklicks
	if event is InputEventMouseButton and event.pressed:
		print("NPC-MENU: Mausklick erkannt, Button: ", event.button_index, ", positioning_npc=", positioning_npc, ", selecting_tower=", selecting_tower)
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Status der NPC-Positionierung prüfen
			if positioning_npc:
				# Direkt die Mausposition aus dem Event verwenden
				var camera = get_viewport().get_camera_2d()
				var world_pos = camera.get_global_mouse_position()
				
				print("NPC wird positioniert bei WORLD POS: ", world_pos)
				emit_signal("npc_to_position_requested", world_pos)
				positioning_npc = false
				
				# DEBUG: Alle NPCs auflisten, um Verfügbarkeit zu prüfen
				print("Verfügbare NPCs: ", _debug_list_npcs())
			
			# Status der Turmauswahl prüfen
			elif selecting_tower:
				var selected_tower = get_tower_at_mouse_position()
				if selected_tower:
					print("Turm ausgewählt: ", selected_tower)
					emit_signal("npc_to_tower_requested", selected_tower)
				else:
					print("Kein Turm in der Nähe gefunden.")
				selecting_tower = false
				
		# Mit rechtem Mausklick abbrechen
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if positioning_npc or selecting_tower:
				print("Rechtsklick - Breche NPC-Positionierung/Turmauswahl ab")
				positioning_npc = false
				selecting_tower = false

# Debug-Funktion, um alle verfügbaren NPCs aufzulisten
func _debug_list_npcs() -> String:
	var result = ""
	if npc_manager:
		result = str(npc_manager.active_npcs.size()) + " NPCs gefunden: ["
		
		for i in range(npc_manager.active_npcs.size()):
			var npc = npc_manager.active_npcs[i]
			if i > 0:
				result += ", "
			result += str(npc) + " (mode: " + str(npc.current_mode) + ")"
		
		result += "]"
	else:
		result = "Kein NPC-Manager gefunden!"
	
	return result

func _get_world_position_from_event(event: InputEvent) -> Vector2:
	# Sichere Methode, um die Weltposition zu bekommen
	var mouse_pos = event.position
	var camera = get_viewport().get_camera_2d()
	if camera:
		return camera.get_screen_to_world(mouse_pos)
	return mouse_pos  # Fallback, wenn keine Kamera existiert

func get_tower_at_mouse_position() -> Node:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_2d()
	if not camera:
		print("FEHLER: Keine Kamera gefunden!")
		return null
		
	var world_pos = camera.get_screen_to_world(mouse_pos)
	
	print("Suche Turm bei Position: ", world_pos)
	
	# Alle Türme durchlaufen und prüfen, ob der Mausklick in der Nähe ist
	for tower in get_tree().get_nodes_in_group("towers"):
		var distance = tower.global_position.distance_to(world_pos)
		print("Gefundener Turm bei: ", tower.global_position, " - Entfernung: ", distance)
		if distance < 100:  # 100 Pixel Toleranz
			return tower
	
	print("Kein Turm in der Nähe gefunden.")
	return null

func update_button_states():
	# Turmbutton aktivieren/deaktivieren basierend auf Gold
	if gold_system:
		tower_button.disabled = not gold_system.can_afford(tower_cost)
	
	# Andere Buttons basierend auf NPC-Verfügbarkeit aktivieren/deaktivieren
	var have_npcs = npc_manager and npc_manager.active_npcs.size() > 0
	assign_to_tower_button.disabled = not have_npcs
	position_npc_button.disabled = not have_npcs
	follow_npc_button.disabled = not have_npcs

func open_menu():
	task_panel.visible = true
	update_button_states()

func close_menu():
	task_panel.visible = false
	placing_tower = false
	positioning_npc = false
	selecting_tower = false

func _on_tower_button_pressed():
	print("Turm-Button gedrückt")
	if gold_system and gold_system.can_afford(tower_cost):
		print("Gold vorhanden: ", gold_system.current_gold, " Gold, kostet: ", tower_cost)
		placing_tower = true
		close_menu()
		emit_signal("tower_placement_requested")
	else:
		var current_gold = 0
		if gold_system:
			current_gold = gold_system.current_gold
		print("Nicht genug Gold: ", current_gold, "/", tower_cost)

func _on_assign_to_tower_button_pressed():
	print("NPC zu Turm zuweisen gedrückt")
	selecting_tower = true
	close_menu()

func _on_position_npc_button_pressed():
	print("NPC positionieren gedrückt - Debug Status")
	print("Vorher: positioning_npc =", positioning_npc)
	
	# Status explizit setzen
	positioning_npc = true
	selecting_tower = false
	
	print("Nachher: positioning_npc =", positioning_npc)
	print("WAITING FOR MOUSE CLICK TO POSITION NPC...")
	
	# Menü schließen, damit der Spieler klicken kann
	close_menu()

func _on_follow_npc_button_pressed():
	print("NPC folgen lassen gedrückt")
	emit_signal("npc_to_follow_requested")
	close_menu()

func _on_close_button_pressed():
	close_menu()

func set_tower_cost(cost):
	tower_cost = cost
	tower_cost_label.text = "Kosten: " + str(tower_cost) + " Gold"
