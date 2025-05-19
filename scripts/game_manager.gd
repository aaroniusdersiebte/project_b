# scripts/game_manager.gd
extends Node

signal path_choice_needed # Neues Signal für Pfadwahl

enum GameMode {SANDBOX, CAMPAIGN}
var current_mode = GameMode.SANDBOX

# Kampagnenvariablen
var current_world = 0
var current_wave = 0
var total_waves_completed = 0
var path_choice_available = false

# Konstanten für Kampagnenmodus
const WAVES_PER_WORLD = 5
const WORLD_COUNT = 3

# Weltinformationen
var worlds = [
	{
		"name": "Start World", 
		"waves": WAVES_PER_WORLD,
		"enemy_multiplier": 1.0,
		"available_npcs": [],  # Anfangs keine NPCs
		"available_buildings": ["tower"] # Nur Basisturm
	},
	{
		"name": "Schwierige Welt", 
		"waves": WAVES_PER_WORLD,
		"enemy_multiplier": 1.5,
		"available_npcs": ["basic_npc", "advanced_npc"],
		"available_buildings": ["tower", "gold_farm", "xp_farm", "catapult"]
	},
	{
		"name": "Leichte Welt", 
		"waves": WAVES_PER_WORLD,
		"enemy_multiplier": 0.8,
		"available_npcs": ["basic_npc"],
		"available_buildings": ["tower", "gold_farm", "healing_station"]
	}
]

func _ready():
	print("GameManager initialisiert")

func start_campaign():
	current_mode = GameMode.CAMPAIGN
	current_world = 0
	current_wave = 0
	total_waves_completed = 0
	path_choice_available = false
	print("Kampagnenmodus gestartet - Welt: 0, Welle: 0")
	
func start_sandbox():
	current_mode = GameMode.SANDBOX
	print("Sandboxmodus gestartet")
	
func is_campaign_mode():
	return current_mode == GameMode.CAMPAIGN
	
func complete_wave():
	current_wave += 1
	total_waves_completed += 1
	
	print("Welle abgeschlossen: ", current_wave, " von ", WAVES_PER_WORLD)
	
	# Prüfen, ob alle Wellen in dieser Welt abgeschlossen wurden
	if current_wave >= WAVES_PER_WORLD:
		path_choice_available = true
		print("ALLE WELLEN ABGESCHLOSSEN! Pfadwahl ist jetzt verfügbar!")
		# Signal für Pfadwahl emittieren
		emit_signal("path_choice_needed")
		
		# Debug: Direkt den path_choice_ui Status überprüfen
		var world = get_tree().get_current_scene()
		if world and world.has_node("PathChoiceUI"):
			var ui = world.get_node("PathChoiceUI")
			print("PathChoiceUI gefunden, aktuelle Sichtbarkeit: ", ui.visible)
			
			# Sicherstellen, dass die UI sichtbar ist und im Vordergrund
			ui.visible = true
			if ui is CanvasLayer:
				ui.layer = 10
			# Pause aktivieren
			get_tree().paused = true
			print("UI sichtbar gesetzt und Spiel pausiert")

func make_path_choice(path_index):
	path_choice_available = false
	
	# Je nach Pfad unterschiedliche neue Welt laden
	if path_index == 0:
		# Schwieriger Pfad mit besserem Loot
		current_world = 1  # ID für nächste Welt
		print("Schwieriger Pfad gewählt - Wechsel zu Welt: ", current_world)
	else:
		# Leichterer Pfad mit schlechterem Loot
		current_world = 2  # ID für alternative Welt
		print("Leichter Pfad gewählt - Wechsel zu Welt: ", current_world)
		
	current_wave = 0  # Wellen in neuer Welt zurücksetzen
	
	# Szene neu laden, um die nächste Welt zu starten
	print("Wechsle zu neuer Welt...")
	get_tree().paused = false  # Pause aufheben
	
	# Über den Loading Screen zur nächsten Welt wechseln
	call_deferred("_load_next_world")

func _load_next_world():
	# Erst zum Ladebildschirm, dann zur nächsten Welt
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

# Hilfsfunktionen
func get_allowed_buildings():
	if current_mode == GameMode.SANDBOX:
		return ["tower", "xp_farm", "gold_farm", "healing_station", "catapult", "minion_spawner"]
	else:
		return worlds[current_world].available_buildings

func get_allowed_npcs():
	if current_mode == GameMode.SANDBOX:
		return ["all"]  # Spezialcode für "alle erlaubt"
	else:
		return worlds[current_world].available_npcs

func get_max_waves_for_current_world():
	if current_mode == GameMode.SANDBOX:
		return -1  # Unendlich
	else:
		return WAVES_PER_WORLD

# Debug: Aktuellen Spielstatus abrufen
func get_game_status():
	var status = "Spielmodus: " + ("Kampagne" if is_campaign_mode() else "Sandbox")
	
	if is_campaign_mode():
		status += "\nWelt: " + str(current_world) + " (" + worlds[current_world].name + ")"
		status += "\nWelle: " + str(current_wave) + " von " + str(WAVES_PER_WORLD)
		status += "\nGesamt absolvierte Wellen: " + str(total_waves_completed)
		status += "\nPfadwahl verfügbar: " + str(path_choice_available)
	
	return status

# Methode, um die PathChoiceUI direkt anzuzeigen
func force_show_path_choice():
	path_choice_available = true
	emit_signal("path_choice_needed")
	
	var world = get_tree().get_current_scene()
	if world and world.has_node("PathChoiceUI"):
		var ui = world.get_node("PathChoiceUI")
		ui.visible = true
		if ui is CanvasLayer:
			ui.layer = 10
		get_tree().paused = true
		print("Path Choice UI wurde erzwungen angezeigt!")
