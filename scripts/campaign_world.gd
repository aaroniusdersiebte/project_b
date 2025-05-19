# scripts/campaign_world.gd
extends Node2D

var wave_manager
var path_choice_ui
var game_manager
var player
var camera

func _ready():
	# Verbindung zum GameManager für das Pfadwahl-Signal
	if game_manager:
		if game_manager.has_signal("path_choice_needed"):
			game_manager.connect("path_choice_needed", Callable(self, "show_path_choice"))
			print("Verbunden mit GameManager path_choice_needed Signal")
	
	
	# Spieler und Kamera finden
	player = get_tree().get_first_node_in_group("player")
	camera = $Camera2D
	
	if player:
		print("Spieler gefunden:", player.name)
	else:
		print("WARNUNG: Spieler nicht gefunden!")
	
	if camera:
		print("Kamera gefunden:", camera.name)
	else:
		print("WARNUNG: Kamera nicht gefunden!")
	
	# Wave Manager finden - mit Fehlerbehandlung
	await get_tree().process_frame
	wave_manager = get_tree().get_first_node_in_group("wave_spawner")
	if wave_manager:
		print("Wave Manager gefunden:", wave_manager.name)
		
		# Überprüfen und verbinden aller benötigten Signale
		var required_signals = ["wave_completed", "wave_started", "enemies_remaining_changed"]
		for signal_name in required_signals:
			if wave_manager.has_signal(signal_name):
				print("Signal gefunden: ", signal_name)
			else:
				print("WARNUNG: Signal nicht gefunden: ", signal_name)
		
		# Sicherer Weg, Signale zu verbinden
		if wave_manager.has_signal("wave_completed"):
			wave_manager.wave_completed.connect(_on_wave_completed)
		else:
			print("FEHLER: Signal 'wave_completed' nicht gefunden")
		
		# Setze maximal 5 Wellen für Kampagnenmodus
		# Nur wenn die Variable existiert
		if "max_waves" in wave_manager:
			wave_manager.max_waves = 5
			print("Max Waves auf 5 gesetzt")
		else:
			print("Info: Wave Manager hat keine 'max_waves' Variable")
	else:
		print("FEHLER: Wave Manager nicht gefunden!")
	
	# Pfadwahl-UI suchen
	path_choice_ui = $PathChoiceUI
	if path_choice_ui:
		path_choice_ui.visible = false
	
	print("Kampagnenwelt initialisiert")

func _process(delta):
	# Kamera folgt dem Spieler
	if player and is_instance_valid(player) and camera:
		camera.global_position = player.global_position

func _on_wave_completed(wave_number):
	print("Welle abgeschlossen: ", wave_number)
	if game_manager:
		game_manager.complete_wave()
		
		# Prüfen, ob Pfadwahl angezeigt werden soll
		if game_manager.path_choice_available:
			show_path_choice()

func show_path_choice():
	print("Zeige Pfadwahl an")
	# Spiel pausieren
	get_tree().paused = true
	
	# Pfadwahl-UI anzeigen
	if path_choice_ui:
		path_choice_ui.visible = true
	else:
		print("WARNUNG: PathChoiceUI nicht gefunden!")
