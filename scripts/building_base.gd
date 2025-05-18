extends StaticBody2D

# Basisklasse für alle Gebäude im Spiel
# Bietet grundlegende Funktionalität für Leben, Level, NPC-Zuweisung usw.

signal building_destroyed
signal building_damaged(current_health, max_health)
signal building_gained_xp(amount)
signal building_leveled_up(new_level)

# Grundlegende Eigenschaften
@export var max_health = 50
@export var current_health = 50
@export var cost = 100
@export var building_type = "Base" # Typ-String für einfachere Identifikation
@export var building_icon = preload("res://icon.svg") # Standardsymbol

# Verfallssystem (nur optional aktivieren)
@export var enable_decay = false  # Standard: Deaktiviert
@export var decay_rate = 0.005  # Wie schnell das Gebäude verfällt, wenn kein NPC drinnen ist

# NPC-Management
@export var max_npc_slots = 1
@export var npc_boost_multiplier = 2.0  # Verstärkungsfaktor, wenn ein NPC drin ist
var occupied_slots = 0
var assigned_npcs = []
var is_boosted = false

# Level-System
var level = 1
var current_xp = 0
var xp_to_next_level = 100
var xp_multiplier = 1.5

# Tracking variables
var decay_timer = 0.0

# UI-Elemente
@onready var health_bar = $HealthBar
@onready var level_label = $LevelLabel

func _ready():
	# Zur Gruppe hinzufügen
	add_to_group("buildings")
	add_to_group("towers") # Für Kompatibilität mit bestehendem Tower-System
	
	# Gesundheitsleiste initialisieren
	health_bar.max_value = max_health
	health_bar.value = current_health
	
	# Level-Label initialisieren
	if not level_label and building_type != "Base":
		level_label = Label.new()
		level_label.position = Vector2(-15, -160)
		level_label.text = "Lv. " + str(level)
		level_label.modulate = Color(1, 0.8, 0.2)  # Goldene Farbe
		level_label.add_theme_font_size_override("font_size", 14)
		add_child(level_label)
	
	# Ursprünglich kein NPC im Gebäude
	is_boosted = false
	
	_post_ready() # Hook für abgeleitete Klassen
	
	print("Gebäude initialisiert - Typ: " + building_type + ", Level: " + str(level) + ", Gesundheit: " + str(current_health))

# Hook für abgeleitete Klassen
func _post_ready():
	pass

func _process(delta):
	# Gebäude-Verfall, wenn aktiviert und kein NPC drin ist
	if enable_decay and occupied_slots == 0:
		decay_timer += delta
		if decay_timer >= 1.0:  # Jede Sekunde Verfall
			decay_timer = 0.0
			current_health -= max_health * decay_rate
			health_bar.value = current_health
			
			if current_health <= 0:
				die()
	
	# Hook für prozessbasierte Logik in abgeleiteten Klassen
	_building_process(delta)

# Hook für abgeleitete Klassen
func _building_process(delta):
	pass

func take_damage(amount):
	current_health -= amount
	health_bar.value = current_health
	
	# Blitz-Effekt
	modulate = Color(1, 0.3, 0.3)  # Rötliche Tönung
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	emit_signal("building_damaged", current_health, max_health)
	
	if current_health <= 0:
		die()

func die():
	emit_signal("building_destroyed")
	
	# Alle zugewiesenen NPCs freigeben
	for npc in assigned_npcs:
		if is_instance_valid(npc):
			npc.set_mode(0)  # Zurück zum Folgen-Modus
	
	# Tod-Effekt
	var death_effect = Sprite2D.new()
	death_effect.texture = $Sprite2D.texture
	death_effect.global_position = global_position
	death_effect.modulate = Color(1, 1, 1, 0.8)
	death_effect.scale = $Sprite2D.scale
	get_parent().add_child(death_effect)
	
	# Ausblenden
	var tween = death_effect.create_tween()
	tween.tween_property(death_effect, "modulate", Color(1, 1, 1, 0), 0.5)
	tween.tween_callback(death_effect.queue_free)
	
	queue_free()

func assign_npc(npc):
	if occupied_slots < max_npc_slots and not assigned_npcs.has(npc):
		assigned_npcs.append(npc)
		occupied_slots += 1
		is_boosted = true
		
		# NPC-Position aktualisieren
		if npc.has_method("set_position_and_mode"):
			npc.set_position_and_mode(global_position, 2)  # 2 = TOWER mode
		else:
			# Fallback: Direktes Setzen
			npc.global_position = global_position
			if npc.has_method("set_mode"):
				npc.set_mode(2)  # 2 = TOWER mode
		
		# Visuelle Aktualisierung
		modulate = Color(0.7, 0.8, 1.0)  # Bläulich für verstärktes Gebäude
		
		# Hook für abgeleitete Klassen
		_on_npc_assigned(npc)
		
		print("NPC dem " + building_type + " zugewiesen - Gebäude ist nun verstärkt!")
		return true
	return false

# Hook für abgeleitete Klassen
func _on_npc_assigned(npc):
	pass

func remove_npc(npc):
	if assigned_npcs.has(npc):
		assigned_npcs.erase(npc)
		occupied_slots -= 1
		
		if occupied_slots == 0:
			is_boosted = false
			modulate = Color(1, 1, 1)  # Zurück zur normalen Farbe
		
		# Hook für abgeleitete Klassen
		_on_npc_removed(npc)
		
		return true
	return false

# Hook für abgeleitete Klassen
func _on_npc_removed(npc):
	pass

# XP hinzufügen
func add_xp(amount):
	current_xp += amount
	emit_signal("building_gained_xp", amount)
	
	# Prüfen, ob Level-Up
	if current_xp >= xp_to_next_level:
		level_up()
	
	print(building_type + " erhielt " + str(amount) + " XP, gesamt: " + str(current_xp) + "/" + str(xp_to_next_level))

func level_up():
	level += 1
	current_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * xp_multiplier)
	
	# Level-Label aktualisieren
	if level_label:
		level_label.text = "Lv. " + str(level)
	
	# Visuelle Effekte für Level-Up
	var level_up_effect = create_tween()
	level_up_effect.tween_property(self, "modulate", Color(1.5, 1.5, 0.5), 0.3)
	level_up_effect.tween_property(self, "modulate", Color(0.7, 0.8, 1.0) if is_boosted else Color(1, 1, 1), 0.3)
	
	# Hook für abgeleitete Klassen
	_on_level_up()
	
	emit_signal("building_leveled_up", level)
	print(building_type + " Level-Up! Neues Level: " + str(level))
	
	# Falls noch XP übrig, erneut prüfen
	if current_xp >= xp_to_next_level:
		level_up()

# Hook für abgeleitete Klassen
func _on_level_up():
	pass

# Gesundheit wiederherstellen
func heal(amount):
	current_health = min(current_health + amount, max_health)
	health_bar.value = current_health
