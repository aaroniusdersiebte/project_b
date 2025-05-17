extends CanvasLayer

# UI-Elemente
@onready var player_level_label = $PlayerInfo/LevelLabel
@onready var xp_bar = $PlayerInfo/XPBar
@onready var health_bar = $PlayerInfo/HealthBar
@onready var gold_label = $ResourceInfo/GoldLabel

# System-Referenzen
var player
var level_system
var gold_system

func _ready():
	# Elemente initial verstecken, bis Referenzen gefunden wurden
	if $PlayerInfo and $ResourceInfo:
		$PlayerInfo.visible = false
		$ResourceInfo.visible = false
	
	# Auf Spiel-Initialisierung warten
	await get_tree().process_frame
	
	# Referenzen finden
	player = get_tree().get_first_node_in_group("player")
	level_system = get_tree().get_first_node_in_group("level_system")
	gold_system = get_tree().get_first_node_in_group("gold_system")
	
	# Signale verbinden, wenn Referenzen gefunden wurden
	if player:
		$PlayerInfo.visible = true
		if player.has_signal("xp_gained"):
			player.xp_gained.connect(_on_player_xp_gained)
		if player.has_signal("level_up"):
			player.level_up.connect(_on_player_level_up)
		
		# Initialisierung
		update_player_level_display(player.level if "level" in player else 1)
		update_xp_bar(player.current_xp if "current_xp" in player else 0, 
		              player.xp_to_next_level if "xp_to_next_level" in player else 100)
	
	if level_system:
		level_system.level_up.connect(_on_global_level_up)
		level_system.xp_gained.connect(_on_global_xp_gained)
	
	if gold_system:
		$ResourceInfo.visible = true
		gold_system.gold_changed.connect(_on_gold_changed)
		update_gold_display(gold_system.get_current_gold())
	
	print("Game UI initialisiert")

func _process(delta):
	# Regelmäßige Updates
	if Engine.get_frames_drawn() % 30 == 0:  # Alle ~0.5 Sekunden aktualisieren
		update_ui()

func update_ui():
	# Spieler-Level aktualisieren
	if player and "level" in player:
		update_player_level_display(player.level)
	elif level_system:
		update_player_level_display(level_system.current_level)
	
	# XP-Anzeige aktualisieren
	if player and "current_xp" in player and "xp_to_next_level" in player:
		update_xp_bar(player.current_xp, player.xp_to_next_level)
	elif level_system:
		update_xp_bar(level_system.current_xp, level_system.xp_to_next_level)
	
	# Gold aktualisieren
	if gold_system:
		update_gold_display(gold_system.get_current_gold())

func update_player_level_display(level):
	if player_level_label:
		player_level_label.text = "Level: " + str(level)

func update_xp_bar(current_xp, max_xp):
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.value = current_xp
		
		# Prozentanzeige aktualisieren
		var percentage = int((float(current_xp) / max_xp) * 100)
		xp_bar.get_node("PercentLabel").text = str(percentage) + "%"

func update_health_bar(current_health, max_health):
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

func update_gold_display(amount):
	if gold_label:
		gold_label.text = str(amount)

func _on_player_xp_gained(current_xp, max_xp):
	update_xp_bar(current_xp, max_xp)
	
	# Visueller Effekt für XP-Gewinn
	var xp_effect = create_tween()
	xp_effect.tween_property(xp_bar, "modulate", Color(0.5, 1.5, 0.5), 0.3)
	xp_effect.tween_property(xp_bar, "modulate", Color(1, 1, 1), 0.3)

func _on_player_level_up(new_level):
	update_player_level_display(new_level)
	
	# Visueller Level-Up Effekt
	var level_effect = create_tween()
	level_effect.tween_property(player_level_label, "modulate", Color(2, 2, 0.5), 0.5)
	level_effect.tween_property(player_level_label, "modulate", Color(1, 1, 1), 0.5)
	
	# Level-Up Popup anzeigen
	show_level_up_popup(new_level)

func _on_global_level_up(new_level):
	update_player_level_display(new_level)

func _on_global_xp_gained(current_xp, max_xp):
	update_xp_bar(current_xp, max_xp)

func _on_gold_changed(amount):
	update_gold_display(amount)
	
	# Visueller Effekt für Gold-Änderung
	var gold_effect = create_tween()
	gold_effect.tween_property(gold_label, "modulate", Color(1.5, 1.5, 0.5), 0.3)
	gold_effect.tween_property(gold_label, "modulate", Color(1, 1, 1), 0.3)

func show_level_up_popup(level):
	# Level-Up Popup erstellen
	var popup = Panel.new()
	popup.position = Vector2(200, 200)
	popup.size = Vector2(250, 150)
	add_child(popup)
	
	# Titel
	var title = Label.new()
	title.text = "LEVEL UP!"
	title.position = Vector2(10, 10)
	title.size = Vector2(230, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.modulate = Color(1, 0.8, 0.2)
	popup.add_child(title)
	
	# Level-Anzeige
	var level_text = Label.new()
	level_text.text = "Sie haben Level " + str(level) + " erreicht!"
	level_text.position = Vector2(10, 50)
	level_text.size = Vector2(230, 30)
	level_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_child(level_text)
	
	# Bonus-Info
	var bonus_text = Label.new()
	bonus_text.text = "Schaden +1\nSchussrate +10%\nRadius +30"
	bonus_text.position = Vector2(10, 80)
	bonus_text.size = Vector2(230, 60)
	bonus_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_child(bonus_text)
	
	# Animation und Entfernung
	var popup_tween = create_tween()
	popup_tween.tween_property(popup, "modulate", Color(1, 1, 1, 1), 0.5).from(Color(1, 1, 1, 0))
	popup_tween.tween_interval(2.0)
	popup_tween.tween_property(popup, "modulate", Color(1, 1, 1, 0), 0.5)
	popup_tween.tween_callback(popup.queue_free)