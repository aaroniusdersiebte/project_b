extends CanvasLayer

# Signale für NPC-Aktionen
signal npc_selected(npc_index)
signal npc_position_requested(npc_index)
signal npc_follow_requested(npc_index)
signal npc_to_tower_requested(npc_index, tower)

# UI-Elemente
var npc_icons = []
var active_npc_index = -1
var context_menu = null

# Referenzen
var npc_manager = null
var tower_manager = null

func _ready():
	# Gruppe für einfachen Zugriff
	add_to_group("npc_ui")
	
	# Referenzen finden
	await get_tree().process_frame
	npc_manager = get_tree().get_first_node_in_group("npc_manager")
	tower_manager = get_tree().get_first_node_in_group("tower_manager")
	
	# Anfängliches UI erstellen
	create_base_ui()
	
	# Verbinden des NPC-Managers, wenn verfügbar
	if npc_manager:
		if npc_manager.has_signal("npc_hired"):
			npc_manager.npc_hired.connect(_on_npc_hired)
		if npc_manager.has_signal("npc_lost"):
			npc_manager.npc_lost.connect(_on_npc_lost)
		
		# Bestehende NPCs laden
		if "active_npcs" in npc_manager:
			for i in range(npc_manager.active_npcs.size()):
				_add_npc_icon(i)
	
	print("NPC Icon UI initialisiert")

func create_base_ui():
	# Container für NPC-Icons erstellen
	var container = HBoxContainer.new()
	container.name = "NPCIconContainer"
	container.anchor_right = 1.0
	container.anchor_bottom = 0.0
	container.offset_left = -300
	container.offset_top = 10
	container.offset_right = -10
	container.offset_bottom = 70
	container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	container.alignment = BoxContainer.ALIGNMENT_END
	container.add_theme_constant_override("separation", 10)
	add_child(container)

func _add_npc_icon(npc_index):
	var container = get_node("NPCIconContainer")
	if not container:
		print("FEHLER: NPC Icon Container nicht gefunden!")
		return
	
	# Icon-Button erstellen
	var button = Button.new()
	button.custom_minimum_size = Vector2(50, 50)
	button.text = "NPC\n" + str(npc_index + 1)
	button.name = "NPCIcon_" + str(npc_index)
	
	# NPC-Mode mit Farbe anzeigen
	if npc_manager and npc_index < npc_manager.active_npcs.size():
		var npc = npc_manager.active_npcs[npc_index]
		if npc and "current_mode" in npc:
			match npc.current_mode:
				0: # FOLLOW
					button.modulate = Color(1, 1, 1)
				1: # STATIONARY
					button.modulate = Color(0.8, 0.8, 1.0)
				2: # TOWER
					button.modulate = Color(0.5, 0.5, 1.0)
	
	# Signale verbinden
	button.pressed.connect(_on_npc_icon_pressed.bind(npc_index))
	
	# Zum Container hinzufügen
	container.add_child(button)
	npc_icons.append(button)

func _on_npc_hired(npc):
	if npc_manager and "active_npcs" in npc_manager:
		var npc_index = npc_manager.active_npcs.find(npc)
		if npc_index >= 0:
			_add_npc_icon(npc_index)

func _on_npc_lost(npc):
	# NPCs neu laden, da sich Indizes geändert haben
	_refresh_npc_icons()

func _refresh_npc_icons():
	# Bestehende Icons entfernen
	for icon in npc_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	npc_icons.clear()
	
	# Neue Icons erstellen
	if npc_manager and "active_npcs" in npc_manager:
		for i in range(npc_manager.active_npcs.size()):
			_add_npc_icon(i)

func _on_npc_icon_pressed(npc_index):
	active_npc_index = npc_index
	_show_context_menu(npc_index)
	emit_signal("npc_selected", npc_index)

func _show_context_menu(npc_index):
	# Bestehendes Kontextmenü entfernen
	if context_menu:
		context_menu.queue_free()
	
	# Neues Kontextmenü erstellen
	context_menu = Panel.new()
	context_menu.position = Vector2(get_viewport().get_mouse_position())
	context_menu.size = Vector2(180, 200)
	add_child(context_menu)
	
	# Menü-Titel
	var title = Label.new()
	title.text = "NPC " + str(npc_index + 1) + " - Aktionen"
	title.position = Vector2(10, 5)
	title.size = Vector2(160, 30)
	context_menu.add_child(title)
	
	# Folgen-Button
	var follow_button = Button.new()
	follow_button.text = "Folgen"
	follow_button.position = Vector2(10, 40)
	follow_button.size = Vector2(160, 30)
	follow_button.pressed.connect(_on_follow_button_pressed.bind(npc_index))
	context_menu.add_child(follow_button)
	
	# Positionieren-Button
	var position_button = Button.new()
	position_button.text = "Positionieren"
	position_button.position = Vector2(10, 80)
	position_button.size = Vector2(160, 30)
	position_button.pressed.connect(_on_position_button_pressed.bind(npc_index))
	context_menu.add_child(position_button)
	
	# Türme-Untermenü
	var towers_button = Button.new()
	towers_button.text = "Turm zuweisen"
	towers_button.position = Vector2(10, 120)
	towers_button.size = Vector2(160, 30)
	towers_button.pressed.connect(_on_towers_button_pressed.bind(npc_index))
	context_menu.add_child(towers_button)
	
	# Schließen-Button
	var close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(150, 5)
	close_button.size = Vector2(25, 25)
	close_button.pressed.connect(_close_context_menu)
	context_menu.add_child(close_button)

func _on_follow_button_pressed(npc_index):
	if npc_manager and "active_npcs" in npc_manager and npc_index < npc_manager.active_npcs.size():
		var npc = npc_manager.active_npcs[npc_index]
		if npc and npc.has_method("set_mode"):
			npc.set_mode(0) # FOLLOW mode
			_refresh_npc_icons()
	
	emit_signal("npc_follow_requested", npc_index)
	_close_context_menu()

func _on_position_button_pressed(npc_index):
	emit_signal("npc_position_requested", npc_index)
	_close_context_menu()
	
	# Modus für Positionierung aktivieren
	if get_viewport():
		get_viewport().set_input_as_handled()
	
	# Warten auf Mausklick
	await get_tree().create_timer(0.1).timeout
	_wait_for_position_click(npc_index)

func _wait_for_position_click(npc_index):
	# Auf Mausklick warten - ohne InputEvent, da es in älteren Godot-Versionen anders ist
	var waiting_for_click = true
	while waiting_for_click:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			waiting_for_click = false
			var global_pos = get_global_mouse_position()
			
			# NPC an Position setzen
			if npc_manager and "active_npcs" in npc_manager and npc_index < npc_manager.active_npcs.size():
				var npc = npc_manager.active_npcs[npc_index]
				if npc:
					npc.global_position = global_pos
					if npc.has_method("set_mode"):
						npc.set_mode(1) # STATIONARY mode
					_refresh_npc_icons()
			
			print("NPC " + str(npc_index) + " an Position " + str(global_pos) + " gesetzt")
		
		await get_tree().create_timer(0.05).timeout

func _on_towers_button_pressed(npc_index):
	# Bestehende Türme auflisten
	var towers = get_tree().get_nodes_in_group("towers")
	if towers.size() == 0:
		# Keine Türme verfügbar
		var no_towers_label = Label.new()
		no_towers_label.text = "Keine Türme verfügbar"
		no_towers_label.position = Vector2(10, 160)
		no_towers_label.size = Vector2(160, 30)
		context_menu.add_child(no_towers_label)
		return
	
	# Turmmenü anzeigen
	var tower_menu = VBoxContainer.new()
	tower_menu.position = Vector2(10, 160)
	tower_menu.size = Vector2(160, towers.size() * 35)
	context_menu.add_child(tower_menu)
	context_menu.size.y += towers.size() * 35
	
	# Für jeden Turm einen Button erstellen
	for i in range(towers.size()):
		var tower = towers[i]
		var tower_button = Button.new()
		tower_button.text = "Turm " + str(i + 1)
		tower_button.custom_minimum_size = Vector2(160, 30)
		tower_button.pressed.connect(_on_tower_selected.bind(npc_index, tower))
		tower_menu.add_child(tower_button)

func _on_tower_selected(npc_index, tower):
	if npc_manager and "active_npcs" in npc_manager and npc_index < npc_manager.active_npcs.size():
		var npc = npc_manager.active_npcs[npc_index]
		if npc and tower and tower.has_method("assign_npc"):
			# Turm zuordnen
			tower.assign_npc(npc)
			# UI aktualisieren
			_refresh_npc_icons()
	
	emit_signal("npc_to_tower_requested", npc_index, tower)
	_close_context_menu()

func _close_context_menu():
	if context_menu:
		context_menu.queue_free()
		context_menu = null

func get_global_mouse_position():
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	if camera:
		return camera.get_global_mouse_position()
	return Vector2(0, 0)

# Mode-Farben für die Icons aktualisieren
func update_npc_icons():
	_refresh_npc_icons()

# Prozess-Funktion für kontinuierliche Updates
func _process(delta):
	# NPC-Status regelmäßig aktualisieren
	if Engine.get_frames_drawn() % 30 == 0: # Alle ~0.5 Sekunden aktualisieren
		update_npc_icons()
