extends Node2D

# Radius des Kreises
var radius = 300.0
# Farbe des Kreises
var color = Color(0.0, 1.0, 0.0, 0.2)  # Halbtransparentes Grün

func _draw():
	# Kreis zeichnen
	draw_circle(Vector2.ZERO, radius, color)

func _process(delta):
	# Neuzeichnen bei Änderungen
	queue_redraw()
