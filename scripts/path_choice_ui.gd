# scripts/path_choice_ui.gd
extends Control

signal path_selected(path_index)

var game_manager

func _ready():
	# Process-Modus auf 'Always' setzen, damit die UI auch im Pause-Modus funktioniert
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# GameManager finden
	game_manager = get_node("/root/GameManager")
	
	# Buttons verbinden
	if $HardPathButton:
		$HardPathButton.connect("pressed", Callable(self, "_on_hard_path_pressed"))
	if $EasyPathButton:
		$EasyPathButton.connect("pressed", Callable(self, "_on_easy_path_pressed"))
	
	# Standardmäßig verstecken
	visible = false
	
	print("PathChoiceUI initialisiert, sichtbar: ", visible)

func _on_hard_path_pressed():
	handle_path_choice(0)  # Schwieriger Pfad (Index 0)

func _on_easy_path_pressed():
	handle_path_choice(1)  # Leichter Pfad (Index 1)

func handle_path_choice(path_index):
	if game_manager:
		game_manager.make_path_choice(path_index)
	
	# Signal senden für event handling
	emit_signal("path_selected", path_index)
	
	# UI verstecken und Spiel fortsetzen
	visible = false
	get_tree().paused = false
