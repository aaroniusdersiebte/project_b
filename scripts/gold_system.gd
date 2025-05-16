extends Node

signal gold_changed(amount)

@export var starting_gold = 100
var current_gold = 0

func _ready():
	add_to_group("gold_system")
	current_gold = starting_gold
	emit_signal("gold_changed", current_gold)

func add_gold(amount):
	current_gold += amount
	emit_signal("gold_changed", current_gold)
	print("Added " + str(amount) + " gold. New total: " + str(current_gold))

func spend_gold(amount):
	if can_afford(amount):
		current_gold -= amount
		emit_signal("gold_changed", current_gold)
		print("Spent " + str(amount) + " gold. Remaining: " + str(current_gold))
		return true
	else:
		print("Cannot afford " + str(amount) + " gold. Current gold: " + str(current_gold))
		return false

func can_afford(amount):
	return current_gold >= amount

func get_current_gold():
	return current_gold
