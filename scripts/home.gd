extends StaticBody2D

signal home_destroyed
signal home_damaged(current_health, max_health)

@export var max_health = 100
@export var current_health = 100
@export var defense = 0  # For future upgrades

@onready var health_display = $HealthDisplay

func _ready():
	add_to_group("home")
	health_display.max_value = max_health
	health_display.value = current_health
	update_display()

func take_damage(amount):
	var actual_damage = max(1, amount - defense)
	current_health -= actual_damage
	update_display()
	
	emit_signal("home_damaged", current_health, max_health)
	
	if current_health <= 0:
		emit_signal("home_destroyed")
		game_over()

func update_display():
	health_display.value = current_health

func game_over():
	# Pause the game
	get_tree().paused = true
	
	# Show game over UI (this will be implemented later)
	print("GAME OVER - Home destroyed!")
	
	# You can trigger a game over screen here later

func upgrade_health(amount):
	max_health += amount
	current_health += amount
	health_display.max_value = max_health
	update_display()

func upgrade_defense(amount):
	defense += amount
