extends Node2D

signal tower_placed(tower)

# Referenzen
var tower_scene = preload("res://scenes/tower.tscn") 
var task_menu_scene = preload("res://scenes/npc_task_menu.tscn")
var gold_system
var npc_manager
var player

# Aktueller Zustand
var placing_tower = false
var tower_preview = null
var tower_cost = 100  # Standardkosten für einen Turm
var current_tower_position = Vector2.ZERO

# Menüverwaltung
var task_menu

func _ready():
	add_to_group("tower_manager")
	
	# Referenzen finden
	await get_tree().process_frame
	gold_system = get_tree().get_first_node_in_group("gold_system")
	npc_manager = get_tree().get_first_node_in_group("npc_manager")
	player = get_tree().get_first_node_in_group("player")
	
	if not gold_system:
		print("ERROR: GoldSystem nicht gefunden!")
	
	if not npc_manager:
		print("ERROR: NPCManager nicht gefunden!")
	
	# NPC-Aufgabenmenü erstellen - WICHTIG: CanvasLayer muss auf Root-Ebene hinzugefügt werden
	task_menu = task_menu_scene.instantiate()
	get_tree().root.add_child(task_menu)  # Hier zur Root hinzufügen statt als Kind
	
	# Menü-Signale verbinden
	task_menu.tower_placement_requested.connect(_on_tower_placement_requested)
	task_menu.npc_to_tower_requested.connect(_on_npc_to_tower_requested)
	task_menu.npc_to_position_requested.connect(_on_npc_to_position_requested)
	task_menu.npc_to_follow_requested.connect(_on_npc_to_follow_requested)
	
	# Turmkosten setzen
	task_menu.set_tower_cost(tower_cost)
	
	# Tastenbelegung für Menüöffnung hinzufügen
	set_process_input(true)

func _process(delta):
	# Vorschau für Turmplatzierung aktualisieren
	if placing_tower and tower_preview:
		tower_preview.global_position = get_global_mouse_position()
		
		# Platzierungsvalidierung visualisieren
		var can_place = can_place_tower_at(tower_preview.global_position)
		tower_preview.modulate = Color(0, 1, 0, 0.5) if can_place else Color(1, 0, 0, 0.5)
		
		# Mit rechtem Mausklick oder Escape abbrechen
		if Input.is_key_pressed(KEY_ESCAPE):
			print("Escape gedrückt, breche Turmplatzierung ab")
			end_tower_placement()

func _input(event):
	# Menü mit Tab öffnen
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		toggle_task_menu()
		
	# Überprüfung auf direkten Mausklick für Turmplatzierung
	if placing_tower and tower_preview:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("TURM-MANAGER: Mausklick für Turmplatzierung erkannt!")
			var can_place = can_place_tower_at(tower_preview.global_position)
			print("Kann Turm platzieren: ", can_place)
			if can_place:
				place_tower(tower_preview.global_position)
			end_tower_placement()
		
		# Auch mit Leertaste platzieren können
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			print("TURM-MANAGER: Leertaste für Turmplatzierung erkannt!")
			var can_place = can_place_tower_at(tower_preview.global_position)
			if can_place:
				place_tower(tower_preview.global_position)
			end_tower_placement()
		
		# Mit rechtem Mausklick oder Escape abbrechen
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT) or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			print("Abbruch der Turmplatzierung")
			end_tower_placement()
	
	# Für Debugging - Wenn Home gedrückt wird, Mausposition ausgeben
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		print("Mausposition: ", get_global_mouse_position())
		print("Platzierungsmodus: ", placing_tower)
		print("Gold-System gefunden: ", gold_system != null)
		print("NPC-Manager gefunden: ", npc_manager != null)
		if gold_system:
			print("Aktuelles Gold: ", gold_system.current_gold)

func toggle_task_menu():
	if task_menu.task_panel.visible:
		task_menu.close_menu()
	else:
		task_menu.open_menu()

func start_tower_placement():
	print("Starte Turmplatzierung...")
	# Gold-Check
	if not gold_system:
		print("FEHLER: Kein GoldSystem gefunden für Turmplatzierung!")
		return
	
	if not gold_system.can_afford(tower_cost):
		print("Nicht genug Gold, um einen Turm zu platzieren! Benötigt: ", tower_cost, ", Vorhanden: ", gold_system.current_gold)
		return
	
	print("Gold-Check bestanden, platziere Turmvorschau...")
	placing_tower = true
	
	# Vorschau erstellen
	tower_preview = tower_scene.instantiate()
	tower_preview.modulate = Color(0, 1, 0, 0.5)  # Halbtransparent für die Vorschau
	get_parent().add_child(tower_preview)
	
	print("Turmvorschau erstellt, warte auf Platzierung...")

func end_tower_placement():
	placing_tower = false
	if tower_preview:
		tower_preview.queue_free()
		tower_preview = null

func can_place_tower_at(position):
	print("Prüfe, ob Turm platziert werden kann bei: ", position)
	
	# Für Debug-Zwecke hier temporär immer true zurückgeben
	return true
	
	# Der ursprüngliche Code wird auskommentiert:
	# # Zu nahe an anderen Türmen?
	# for tower in get_tree().get_nodes_in_group("towers"):
	#     if position.distance_to(tower.global_position) < 100:  # Mindestabstand von 100 Einheiten
	#         return false
	
	# # Zu nahe an Dekorationen?
	# for decoration in get_tree().get_nodes_in_group("decorations"):
	#     if position.distance_to(decoration.global_position) < 50:  # Mindestabstand von 50 Einheiten
	#         return false
	
	# # Zu nahe am Zuhause oder Spawnpunkten?
	# var home = get_tree().get_first_node_in_group("home")
	# if home and position.distance_to(home.global_position) < 200:  # Nicht zu nahe am Zuhause
	#     return false
	
	# var path_system = get_tree().get_first_node_in_group("path_system")
	# if path_system:
	#     for spawn_point in path_system.spawn_points:
	#         if position.distance_to(spawn_point) < 150:  # Nicht zu nahe an Spawnpunkten
	#             return false
	
	# return true

func place_tower(position):
	print("Versuche Turm zu platzieren bei: ", position)
	# Gold ausgeben
	if not gold_system:
		print("FEHLER: Kein GoldSystem für Turmplatzierung!")
		return null
		
	if not gold_system.can_afford(tower_cost):
		print("Nicht genug Gold, um einen Turm zu platzieren! Benötigt: ", tower_cost, ", Vorhanden: ", gold_system.current_gold)
		return null
	
	# Gold ausgeben
	var success = gold_system.spend_gold(tower_cost)
	print("Gold ausgeben Ergebnis: ", success, ", Kosten: ", tower_cost, ", Verbleibendes Gold: ", gold_system.current_gold)
	
	if success:
		# Neuen Turm erstellen
		var tower = tower_scene.instantiate()
		tower.global_position = position
		get_parent().add_child(tower)
		
		print("Turm platziert bei: ", position, " - Gold übrig: ", gold_system.current_gold)
		emit_signal("tower_placed", tower)
		
		return tower
	else:
		print("Fehler beim Ausgeben von Gold: ", gold_system.current_gold, "/", tower_cost)
		return null

func _on_tower_placement_requested():
	print("Tower-Manager: Turmplatzierung angefordert")
	start_tower_placement()

func _on_npc_to_tower_requested(tower):
	print("Tower-Manager: NPC zu Turm schicken: ", tower)
	
	# ALLE NPCs im Spiel finden (unabhängig vom NPC-Manager)
	var all_npcs = []
	for node in get_tree().get_nodes_in_group("npcs"):
		all_npcs.append(node)
	
	print("Gefundene NPCs in Gruppe 'npcs': ", all_npcs.size())
	
	# Wenn keine NPCs gefunden wurden, versuche über den Manager
	if all_npcs.size() == 0 and npc_manager:
		all_npcs = npc_manager.active_npcs
		print("Verwendung der NPCs vom Manager: ", all_npcs.size())
	
	# Wenn noch keine NPCs gefunden wurden, versuche einen zu erstellen
	if all_npcs.size() == 0 and npc_manager and npc_manager.has_method("try_hire_npc"):
		print("Versuche, einen neuen NPC zu erstellen...")
		npc_manager.try_hire_npc()
		await get_tree().process_frame
		
		# Nach der Erstellung erneut NPCs suchen
		for node in get_tree().get_nodes_in_group("npcs"):
			all_npcs.append(node)
	
	var assigned = false
	
	# Prüfe, ob der Turm gültig ist
	if not is_instance_valid(tower):
		print("FEHLER: Ungültiger Turm wurde übergeben!")
		return
	
	print("Suche nach NPCs, die zum Turm geschickt werden können...")
	
	# Den nächsten verfügbaren NPC zum Turm schicken
	for npc in all_npcs:
		print("Prüfe NPC: ", npc)
		
		# DIREKTE METHODE: Bewege NPC zum Turm
		npc.global_position = tower.global_position
		
		# VERSUCH 1: Turm-Methoden direkt aufrufen
		if tower.has_method("assign_npc"):
			print("Verwende assign_npc Methode des Turms")
			var success = tower.call("assign_npc", npc)
			print("Turm-Zuweisung erfolgreich: ", success)
		
		# VERSUCH 2: NPC in den TOWER-Modus setzen
		if npc.has_method("set_position_and_mode"):
			print("Verwende set_position_and_mode Methode des NPCs")
			npc.call("set_position_and_mode", tower.global_position, 2)  # 2 sollte TOWER sein
		elif npc.has_method("set_mode"):
			print("Verwende set_mode Methode des NPCs")
			npc.global_position = tower.global_position
			npc.call("set_mode", 2)  # 2 sollte TOWER sein
		
		print("NPC erfolgreich zum Turm geschickt!")
		assigned = true
		break
	
	if not assigned:
		print("FEHLER: Kein verfügbarer NPC gefunden oder alle Zuweisungen fehlgeschlagen!")

func _on_npc_to_position_requested(position):
	print("Tower-Manager: NPC zu Position schicken: ", position)
	
	# DIREKTER VERSUCH: Erstelle einen neuen NPC, wenn keiner verfügbar ist
	var npc_manager = get_tree().get_first_node_in_group("npc_manager")
	if npc_manager and npc_manager.has_method("try_hire_npc"):
		print("Versuche, einen neuen NPC zu erstellen...")
		npc_manager.try_hire_npc()
		print("Warte einen Frame...")
		await get_tree().process_frame
	
	# ALLE NPCs im Spiel finden (unabhängig vom NPC-Manager)
	var all_npcs = []
	for node in get_tree().get_nodes_in_group("npcs"):
		all_npcs.append(node)
	
	print("Gefundene NPCs in Gruppe 'npcs': ", all_npcs.size())
	
	# Wenn keine NPCs gefunden wurden, versuche über andere Methoden
	if all_npcs.size() == 0:
		print("NOTFALL: Versuche, NPC direkt zu finden")
		for node in get_tree().get_nodes_in_group("player"):
			print("  > Player gefunden: ", node)
		
		var world = get_tree().current_scene
		print("Aktuelle Szene: ", world.name)
		_print_node_hierarchy(world, 0, 3)  # Nur 3 Ebenen tief anzeigen
		
		# Fallback: Wenn noch keine NPCs gefunden wurden, nehme NPCs vom Manager
		if npc_manager:
			all_npcs = npc_manager.active_npcs
			print("Verwendung der NPCs vom Manager: ", all_npcs.size())
	
	# Den nächsten verfügbaren NPC zur Position schicken
	var npc_found = false
	for npc in all_npcs:
		# Versuche den aktuellen Modus zu erhalten
		var current_mode = -1
		
		# Prüfe, ob wir auf den Modus zugreifen können
		if "current_mode" in npc:
			current_mode = npc.current_mode
			print("NPC gefunden mit current_mode Eigenschaft: ", current_mode)
		
		print("NPC wird zur Position geschickt: ", npc, " (aktueller Modus: ", current_mode, ")")
		
		# DIREKTE METHODE: Globale Position explizit setzen
		npc.global_position = position
		
		# VERSUCH 2: Versuche die Methode set_position_and_mode
		if npc.has_method("set_position_and_mode"):
			print("Verwende set_position_and_mode Methode")
			npc.call("set_position_and_mode", position, 1)  # 1 sollte STATIONARY sein
		
		# VERSUCH 3: Versuche die Methode set_mode
		elif npc.has_method("set_mode"):
			print("Verwende set_mode Methode")
			npc.global_position = position  # Position zuerst setzen
			npc.call("set_mode", 1)  # 1 sollte STATIONARY sein
		
		print("NPC zu Position ", position, " zugewiesen")
		npc_found = true
		break
	
	# Wenn keine NPCs gefunden wurden, eine Fehlermeldung ausgeben
	if not npc_found:
		print("FEHLER: Keine NPCs verfügbar!")
	else:
		print("NPC erfolgreich positioniert")

# Debug-Funktion zum Anzeigen der Node-Hierarchie
func _print_node_hierarchy(node, indent = 0, max_depth = -1):
	if max_depth >= 0 and indent > max_depth:
		return
		
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	
	print(indent_str + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		_print_node_hierarchy(child, indent + 1, max_depth)

func _on_npc_to_follow_requested():
	if npc_manager:
		# Alle NPCs auf Folgen umstellen
		npc_manager.set_all_npcs_mode(0)  # 0 entspricht NPCMode.FOLLOW
		print("Alle NPCs auf Folgen umgestellt!")
