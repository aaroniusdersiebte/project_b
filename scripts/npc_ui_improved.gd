extends CanvasLayer

# Signale für NPC-Aktionen
signal npc_selected(npc_index)
signal npc_position_requested(npc_index)
signal npc_follow_requested(npc_index)
signal npc_to_tower_requested(npc_index, tower)

# UI-Elemente
var npc_icons = []
var npc_buttons = []
var active_npc_index = -1

# Referenzen
var npc_manager = null

func _ready():
	# Layer anpassen, um mit vorhandenen UIs nicht zu kollidieren
	self.layer = 5
	
	# Gruppe für einfachen Zugriff
	add_to_group("npc_ui")
	
	# Referenzen finden
	await get_tree().process_frame
	npc_manager = get_tree().get_first_node_in_group("npc_manager")
	
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
				_add_npc_button(i)
	else:
		# Test-NPCs hinzufügen, wenn kein NPC-Manager gefunden wurde
		for i in range(2):
			_add_npc_button(i)
	
	print("NPC UI initialisiert")

func create_base_ui():
	# Hauptcontainer erstellen (rechts oben, aber niedriger platziert)
	var panel = Panel.new()
	panel.name = "NPCPanel"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -160  # Schmaler
	panel.offset_top = 60     # Niedriger, um nicht mit Gold-Anzeige zu kollidieren
	panel.offset_right = -10
	panel.offset_bottom = 150
	add_child(panel)
	
	# Überschrift
	var title = Label.new()
	title.text = "NPCs"
	title.position = Vector2(65, 10)  # Angepasst für schmaleres Panel
	title.size = Vector2(100, 30)
	panel.add_child(title)
	
	# Container für NPC-Buttons
	var button_container = GridContainer.new()
	button_container.name = "ButtonContainer"
	button_container.position = Vector2(10, 40)
	button_container.size = Vector2(140, 100)  # Angepasst für schmaleres Panel
	button_container.columns = 2  # Nur 2 Spalten
	button_container.add_theme_constant_override("h_separation", 10)
	button_container.add_theme_constant_override("v_separation", 10)
	panel.add_child(button_container)

func _add_npc_button(npc_index):
	var container = get_node("NPCPanel/ButtonContainer")
	if not container:
		print("FEHLER: NPC Button Container nicht gefunden!")
		return
	
	# NPC-Button erstellen
	var button = Button.new()
	button.custom_minimum_size = Vector2(60, 40)
	button.text = "NPC " + str(npc_index + 1)
	button.name = "NPCButton_" + str(npc_index)
	
	# NPC-Mode mit Farbe anzeigen
	if npc_manager and "active_npcs" in npc_manager and npc_index < npc_manager.active_npcs.size():
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
	button.pressed.connect(_on_npc_button_pressed.bind(npc_index))
	
	# Zum Container hinzufügen
	container.add_child(button)
	npc_buttons.append(button)

func _on_npc_hired(npc):
	if npc_manager and "active_npcs" in npc_manager:
		var npc_index = npc_manager.active_npcs.find(npc)
		if npc_index >= 0:
			_add_npc_button(npc_index)

func _on_npc_lost(npc):
	# NPCs neu laden, da sich Indizes geändert haben
	_refresh_npc_buttons()

func _refresh_npc_buttons():
	# Bestehende Buttons entfernen
	for button in npc_buttons:
		if is_instance_valid(button):
			button.queue_free()
	npc_buttons.clear()
	
	# Neue Buttons erstellen
	if npc_manager and "active_npcs" in npc_manager:
		for i in range(npc_manager.active_npcs.size()):
			_add_npc_button(i)
	else:
		# Test-NPCs hinzufügen, wenn kein NPC-Manager gefunden wurde
		for i in range(2):
			_add_npc_button(i)

func _on_npc_button_pressed(npc_index):
	active_npc_index = npc_index
	_show_npc_actions(npc_index)
	emit_signal("npc_selected", npc_index)

func _show_npc_actions(npc_index):
	# Bestehende Aktionsbuttons entfernen
	var panel = get_node("NPCPanel")
	var actions_container = panel.get_node_or_null("ActionsContainer")
	if actions_container:
		actions_container.queue_free()
	
	# Aktionsmenü erstellen
	actions_container = VBoxContainer.new()
	actions_container.name = "ActionsContainer"
	actions_container.position = Vector2(10, 150)
	actions_container.size = Vector2(140, 120)  # Angepasst für schmaleres Panel
	actions_container.add_theme_constant_override("separation", 5)
	panel.add_child(actions_container)
	panel.offset_bottom = 280  # Panel vergrößern
	
	# Titel
	var title = Label.new()
	title.text = "NPC " + str(npc_index + 1) + " - Aktionen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions_container.add_child(title)
	
	# Folgen-Button
	var follow_button = Button.new()
	follow_button.text = "Folgen"
	follow_button.pressed.connect(_on_follow_button_pressed.bind(npc_index))
	actions_container.add_child(follow_button)
	
	# Positionieren-Button
	var position_button = Button.new()
	position_button.text = "Positionieren"
	position_button.pressed.connect(_on_position_button_pressed.bind(npc_index))
	actions_container.add_child(position_button)
	
	# Turm zuweisen-Button
	var tower_button = Button.new()
	tower_button.text = "Turm zuweisen"
	tower_button.pressed.connect(_on_tower_button_pressed.bind(npc_index))
	actions_container.add_child(tower_button)

func _on_follow_button_pressed(npc_index):
	if npc_manager and "active_npcs" in npc_manager and npc_index < npc_manager.active_npcs.size():
		var npc = npc_manager.active_npcs[npc_index]
		if npc and npc.has_method("set_mode"):
			npc.set_mode(0) # FOLLOW mode
			_refresh_npc_buttons()
	
	emit_signal("npc_follow_requested", npc_index)
	# Aktionsmenü verbergen
	_hide_actions_menu()

func _on_position_button_pressed(npc_index):
	emit_signal("npc_position_requested", npc_index)
	
	# Aktionsmenü verbergen
	_hide_actions_menu()
	
	# Warten auf Mausklick
	await get_tree().create_timer(0.1).timeout
	_wait_for_position_click(npc_index)

func _wait_for_position_click(npc_index):
	# Warten auf Mausklick
	print("Warte auf Klick für NPC-Positionierung...")
	var position_label = Label.new()
	position_label.text = "Klicke auf eine Position für NPC " + str(npc_index + 1)
	position_label.position = Vector2(400, 300)
	position_label.modulate = Color(1, 0.8, 0, 1)
	add_child(position_label)
	
	# Auf Mausklick warten
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
					_refresh_npc_buttons()
			
			print("NPC " + str(npc_index) + " an Position " + str(global_pos) + " gesetzt")
		
		await get_tree().create_timer(0.05).timeout
	
	# Label entfernen
	position_label.queue_free()

func _on_tower_button_pressed(npc_index):
	# Aktionsmenü verbergen
	_hide_actions_menu()
	
	# Türme suchen
	var towers = get_tree().get_nodes_in_group("towers")
	if towers.size() == 0:
		# Keine Türme verfügbar
		var message = Label.new()
		message.text = "Keine Türme verfügbar"
		message.position = Vector2(400, 300)
		message.modulate = Color(1, 0, 0, 1)
		add_child(message)
		
		# Nach 2 Sekunden entfernen
		await get_tree().create_timer(2.0).timeout
		message.queue_free()
		return
	
	# Warte auf Turmauswahl
	print("Wähle einen Turm für NPC " + str(npc_index + 1))
	var tower_select_label = Label.new()
	tower_select_label.text = "Klicke auf einen Turm für NPC " + str(npc_index + 1)
	tower_select_label.position = Vector2(400, 300)
	tower_select_label.modulate = Color(0.5, 0.5, 1.0, 1)
	add_child(tower_select_label)
	
	# Auf Mausklick warten
	var waiting_for_tower = true
	while waiting_for_tower:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mouse_pos = get_global_mouse_position()
			var closest_tower = null
			var min_distance = 100.0  # Maximale Auswahldistanz
			
			# Nächsten Turm finden
			for tower in towers:
				var distance = tower.global_position.distance_to(mouse_pos)
				if distance < min_distance:
					min_distance = distance
					closest_tower = tower
			
			if closest_tower:
				waiting_for_tower = false
				
				# NPC dem Turm zuweisen
				if npc_manager and "active_npcs" in npc_manager and npc_index < npc_manager.active_npcs.size():
					var npc = npc_manager.active_npcs[npc_index]
					if npc and closest_tower.has_method("assign_npc"):
						closest_tower.assign_npc(npc)
						_refresh_npc_buttons()
				
				print("NPC " + str(npc_index) + " Turm zugewiesen")
			
		await get_tree().create_timer(0.05).timeout
	
	# Label entfernen
	tower_select_label.queue_free()

func _hide_actions_menu():
	var panel = get_node("NPCPanel")
	var actions_container = panel.get_node_or_null("ActionsContainer")
	if actions_container:
		actions_container.queue_free()
	panel.offset_bottom = 150  # Panel verkleinern

func get_global_mouse_position():
	var viewport = get_viewport()
	var camera = viewport.get_camera_2d()
	if camera:
		return camera.get_global_mouse_position()
	return Vector2(0, 0)

# Mode-Farben für die Icons aktualisieren
func update_npc_status():
	_refresh_npc_buttons()

# Prozess-Funktion für kontinuierliche Updates
func _process(delta):
	# NPC-Status regelmäßig aktualisieren (alle 30 Frames)
	if Engine.get_frames_drawn() % 30 == 0:
		update_npc_status()
