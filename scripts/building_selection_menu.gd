extends CanvasLayer

signal building_selected(building_type)

# Gebäudekosten (müssen mit denen im TowerManager übereinstimmen)
var building_costs = {
	"tower": 100,
	"xp_farm": 150,
	"gold_farm": 200,
	"healing_station": 175,
	"catapult": 200,
	"minion_spawner": 225
}

# Gebäudebeschreibungen
var building_descriptions = {
	"tower": "Standardturm - greift Gegner in der Nähe an",
	"xp_farm": "Generiert XP für den Spieler",
	"gold_farm": "Produziert regelmäßig Gold",
	"healing_station": "Heilt Spieler und NPCs in der Nähe",
	"catapult": "Fernkampfturm mit großer Reichweite und Flächenschaden",
	"minion_spawner": "Erzeugt kleine Kampfeinheiten"
}

# UI-Elemente
var menu_panel
var gold_system

func _ready():
	# Füge Menü erst nach der Initialisierung hinzu
	call_deferred("setup_menu")
	
	# Verstecke das Menü beim Start
	visible = false

func setup_menu():
	# Gold-System finden
	await get_tree().process_frame
	gold_system = get_tree().get_first_node_in_group("gold_system")
	
	# Panel erstellen
	menu_panel = Panel.new()
	menu_panel.anchor_right = 1.0
	menu_panel.anchor_bottom = 1.0
	menu_panel.offset_left = 100
	menu_panel.offset_top = 100
	menu_panel.offset_right = -100
	menu_panel.offset_bottom = -100
	add_child(menu_panel)
	
	# Titel
	var title = Label.new()
	title.text = "Gebäudeauswahl"
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 24)
	menu_panel.add_child(title)
	
	# Schließen-Button
	var close_button = Button.new()
	close_button.text = "X"
	close_button.position = Vector2(menu_panel.size.x - 40, 20)
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.pressed.connect(func(): visible = false)
	menu_panel.add_child(close_button)
	
	# Gebäude-Container
	var building_container = GridContainer.new()
	building_container.position = Vector2(50, 80)
	building_container.size = Vector2(menu_panel.size.x - 100, menu_panel.size.y - 120)
	building_container.columns = 3
	building_container.add_theme_constant_override("hseparation", 20)
	building_container.add_theme_constant_override("vseparation", 20)
	menu_panel.add_child(building_container)
	
	# Gebäudeoptionen hinzufügen
	for building_type in building_costs.keys():
		var building_panel = create_building_panel(building_type)
		building_container.add_child(building_panel)

func create_building_panel(building_type):
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(200, 230)
	
	# Titel
	var title = Label.new()
	title.text = format_building_name(building_type)
	title.position = Vector2(10, 10)
	title.custom_minimum_size = Vector2(180, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)
	
	# Symbol
	var icon = TextureRect.new()
	icon.texture = load("res://icon.svg")  # Platzhalter
	icon.position = Vector2(50, 40)
	icon.custom_minimum_size = Vector2(100, 100)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	
	# Farbe je nach Gebäudetyp anpassen
	match building_type:
		"tower":
			icon.modulate = Color(0.2, 0.47, 0.8)  # Blau
		"xp_farm":
			icon.modulate = Color(0.5, 1.0, 0.5)  # Grün
		"gold_farm":
			icon.modulate = Color(1.0, 0.8, 0.2)  # Gold
		"healing_station":
			icon.modulate = Color(0.2, 1.0, 0.7)  # Türkis
		"catapult":
			icon.modulate = Color(0.8, 0.3, 0.1)  # Orange-Braun
		"minion_spawner":
			icon.modulate = Color(0.7, 0.3, 0.7)  # Lila
	
	panel.add_child(icon)
	
	# Beschreibung
	var description = Label.new()
	description.text = building_descriptions[building_type]
	description.position = Vector2(10, 140)
	description.custom_minimum_size = Vector2(180, 50)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(description)
	
	# Kosten
	var cost_label = Label.new()
	cost_label.text = str(building_costs[building_type]) + " Gold"
	cost_label.position = Vector2(10, 190)
	cost_label.custom_minimum_size = Vector2(180, 20)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.modulate = Color(1.0, 0.8, 0.2)  # Gold-Farbe
	panel.add_child(cost_label)
	
	# Auswahlbutton
	var button = Button.new()
	button.text = "Bauen"
	button.position = Vector2(50, 210)
	button.custom_minimum_size = Vector2(100, 30)
	
	# Verbinden mit Auswahlsignal
	button.pressed.connect(func(): _on_building_button_pressed(building_type))
	
	panel.add_child(button)
	
	return panel

func _on_building_button_pressed(building_type):
	# Gold prüfen
	if gold_system and not gold_system.can_afford(building_costs[building_type]):
		show_error_message("Nicht genug Gold!")
		return
	
	# Signal senden und Menü schließen
	emit_signal("building_selected", building_type)
	visible = false

func show_error_message(message):
	# Einfache Fehlermeldung anzeigen
	var error_label = Label.new()
	error_label.text = message
	error_label.modulate = Color(1, 0.3, 0.3)  # Rot
	error_label.position = Vector2(menu_panel.size.x / 2 - 100, menu_panel.size.y - 50)
	error_label.custom_minimum_size = Vector2(200, 30)
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_panel.add_child(error_label)
	
	# Nach 2 Sekunden entfernen
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): error_label.queue_free())

func format_building_name(building_type):
	# Formatiere building_type in einen lesbaren Namen (snake_case zu Title Case)
	var words = building_type.split("_")
	var formatted = ""
	
	for word in words:
		formatted += word.substr(0, 1).to_upper() + word.substr(1) + " "
	
	return formatted.strip_edges()

func _process(delta):
	# Gebäudekosten aktualisieren (nur wenn sichtbar)
	if visible and gold_system:
		update_building_costs()

func update_building_costs():
	# Suche nach allen Kosten-Labels und aktualisiere sie
	for panel in menu_panel.get_children():
		if panel is GridContainer:
			for building_panel in panel.get_children():
				if building_panel is Panel:
					# Finde den Baubutton
					var button = null
					var cost_label = null
					
					for child in building_panel.get_children():
						if child is Button:
							button = child
						if child is Label and "Gold" in child.text:
							cost_label = child
					
					if button and cost_label:
						# Bestimme den Gebäudetyp aus dem Label-Text
						var title_label = building_panel.get_child(0)  # Erste sollte der Titel sein
						var building_type = determine_building_type(title_label.text)
						
						if building_type in building_costs:
							# Aktualisiere Button-Status
							button.disabled = not gold_system.can_afford(building_costs[building_type])
							
							# Ändere Farbe des Kostenlabels
							if button.disabled:
								cost_label.modulate = Color(1.0, 0.3, 0.3)  # Rot wenn nicht genug Gold
							else:
								cost_label.modulate = Color(1.0, 0.8, 0.2)  # Standard-Gold-Farbe

func determine_building_type(formatted_name):
	# Konvertiere formatierten Namen zurück in building_type
	var lower_name = formatted_name.to_lower()
	
	for building_type in building_costs.keys():
		if building_type.replace("_", " ") == lower_name:
			return building_type
	
	return null
