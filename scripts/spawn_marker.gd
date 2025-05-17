extends Node2D

@export var pulse_speed = 2.0  # Wie schnell das Icon pulsiert
@export var pulse_size_min = 0.8  # Minimale Größe während des Pulsierens
@export var pulse_size_max = 1.5  # Maximale Größe während des Pulsierens
@export var circle_color = Color(1, 0, 0, 0.5)  # Rötlicher Kreis, mehr Deckkraft
@export var circle_radius = 60.0  # Größe des Kreises erhöht
@export var flash_before_spawn = true  # Soll der Marker vor dem Spawnen blinken?

var time = 0.0
var active_warning = false  # Wird aktiviert kurz vor dem Spawnen
var warning_time = 3.0  # Wie lange vor dem Spawnen soll gewarnt werden
var warning_flash_speed = 5.0  # Wie schnell das Blinken sein soll

@onready var exclamation = $ExclamationMark
@onready var circle_node = $Circle

func _ready():
	# Zufälliger Startoffset für verschiedene Pulsfrequenzen
	time = randf_range(0, 2 * PI)
	
	# Sicherstellen, dass die Referenzen korrekt sind
	exclamation = $ExclamationMark
	circle_node = $Circle
	
	if not exclamation:
		print("WARNUNG: ExclamationMark Node konnte nicht gefunden werden!")
	
	if not circle_node:
		print("WARNUNG: Circle Node konnte nicht gefunden werden!")

func _process(delta):
	time += delta * pulse_speed
	
	# Normales Pulsieren
	var pulse_factor = lerp(pulse_size_min, pulse_size_max, (sin(time) + 1) / 2.0)
	scale = Vector2(pulse_factor, pulse_factor)
	
	if is_instance_valid(exclamation) and is_instance_valid(circle_node):
		# Wenn Warnblinkung aktiv ist
		if active_warning:
			# Schnelleres Blinken mit variabler Transparenz
			var flash_alpha = (sin(time * warning_flash_speed) + 1) / 2.0
			exclamation.modulate.a = flash_alpha
			circle_node.modulate.a = flash_alpha
		else:
			exclamation.modulate.a = 1.0
			circle_node.modulate.a = 1.0

func _draw():
	# Zeichne einen Kreis
	draw_circle(Vector2.ZERO, circle_radius, circle_color)

func set_warning(active):
	active_warning = active
	
	# Prüfe, ob die Referenzen gültig sind, bevor wir sie verwenden
	if is_instance_valid(exclamation) and exclamation != null:
		# Farbe ändern für Warnung
		if active:
			exclamation.modulate = Color(1, 1, 0, 1)  # Gelb während der Warnung
		else:
			exclamation.modulate = Color(1, 0, 0, 1)  # Zurück zu Rot
	
	# Ändern der Kreisfarbe
	if active:
		circle_color = Color(1, 0.5, 0, 0.5)  # Orangener Kreis
	else:
		circle_color = Color(1, 0, 0, 0.3)  # Rötlicher Kreis
	
	queue_redraw()  # Kreis neu zeichnen
