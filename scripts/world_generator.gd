extends Node2D

# World size parameters
@export var world_width = 2000
@export var world_height = 2000
@export var border_thickness = 100

# Decoration parameters
@export var tree_count = 50
@export var bush_count = 100
@export var rock_count = 30
@export var min_decoration_distance = 80  # Minimum distance between decorations

# References to decoration scenes
var tree_scene
var bush_scene
var rock_scene

# Arrays to store placed decorations
var decorations = []

# Reference to tilemap for ground
@onready var ground_tilemap = $GroundTileMap

func _ready():
	# Debug-Ausgabe für die Pfade
	print("Versuche zu laden: res://scenes/tree.tscn")
	print("Versuche zu laden: res://scenes/bush.tscn")  
	print("Versuche zu laden: res://scenes/rock.tscn")
	
	# Prüfe, ob die Dateien existieren
	var tree_exists = ResourceLoader.exists("res://scenes/tree.tscn")
	var bush_exists = ResourceLoader.exists("res://scenes/bush.tscn")
	var rock_exists = ResourceLoader.exists("res://scenes/rock.tscn")
	
	print("Tree exists: ", tree_exists)
	print("Bush exists: ", bush_exists)
	print("Rock exists: ", rock_exists)
	
	# Versuche die Szenen zu laden, nur wenn sie existieren
	if tree_exists:
		tree_scene = load("res://scenes/tree.tscn")
		print("Tree scene loaded: ", tree_scene != null)
	else:
		print("FEHLER: tree.tscn nicht gefunden!")
		
	if bush_exists:
		bush_scene = load("res://scenes/bush.tscn")
		print("Bush scene loaded: ", bush_scene != null)
	else:
		print("FEHLER: bush.tscn nicht gefunden!")
		
	if rock_exists:
		rock_scene = load("res://scenes/rock.tscn")
		print("Rock scene loaded: ", rock_scene != null)
	else:
		print("FEHLER: rock.tscn nicht gefunden!")
		
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = Vector2.ZERO
	
	# Dann erst die Welt generieren
	add_to_group("world_generator")
	create_boundaries()
	generate_ground()
	generate_decorations()
	
	# Set up decoration scenes when user creates them
	# These will be placeholder paths until the user creates actual scenes
	tree_scene = load("res://scenes/tree.tscn")
	bush_scene = load("res://scenes/bush.tscn")
	rock_scene = load("res://scenes/rock.tscn")
	
	# Create world boundaries
	create_boundaries()
	
	# Generate the ground
	generate_ground()
	
	# Generate decorations
	generate_decorations()
	
	print("World generation complete!")

func create_boundaries():
	# Create a simple rectangular boundary
	var boundary = StaticBody2D.new()
	boundary.name = "WorldBoundary"
	add_child(boundary)
	
	# Top wall
	var top_collision = CollisionShape2D.new()
	var top_shape = RectangleShape2D.new()
	top_shape.extents = Vector2(world_width / 2, border_thickness / 2)
	top_collision.shape = top_shape
	top_collision.position = Vector2(0, -world_height / 2)
	boundary.add_child(top_collision)
	
	# Bottom wall
	var bottom_collision = CollisionShape2D.new()
	var bottom_shape = RectangleShape2D.new()
	bottom_shape.extents = Vector2(world_width / 2, border_thickness / 2)
	bottom_collision.shape = bottom_shape
	bottom_collision.position = Vector2(0, world_height / 2)
	boundary.add_child(bottom_collision)
	
	# Left wall
	var left_collision = CollisionShape2D.new()
	var left_shape = RectangleShape2D.new()
	left_shape.extents = Vector2(border_thickness / 2, world_height / 2)
	left_collision.shape = left_shape
	left_collision.position = Vector2(-world_width / 2, 0)
	boundary.add_child(left_collision)
	
	# Right wall
	var right_collision = CollisionShape2D.new()
	var right_shape = RectangleShape2D.new()
	right_shape.extents = Vector2(border_thickness / 2, world_height / 2)
	right_collision.shape = right_shape
	right_collision.position = Vector2(world_width / 2, 0)
	boundary.add_child(right_collision)
	
	# Add visual borders for debugging
	var border_visual = Node2D.new()
	border_visual.name = "BorderVisual"
	add_child(border_visual)
	
	# We'll use _draw to visualize the boundary
	border_visual.set_script(create_border_visual_script())

func create_border_visual_script():
	var script = GDScript.new()
	script.source_code = """
extends Node2D

@onready var world_generator = get_parent()

func _draw():
	var rect = Rect2(
		Vector2(-world_generator.world_width/2, -world_generator.world_height/2),
		Vector2(world_generator.world_width, world_generator.world_height)
	)
	draw_rect(rect, Color(1, 0, 0, 0.5), false, 5.0)
"""
	return script

func generate_ground():
	# If using a TileMap for the ground, initialize it here
	# For now, we'll just create a visual representation
	var ground = ColorRect.new()
	ground.name = "Ground"
	ground.color = Color(0.2, 0.6, 0.2, 1.0)  # Green for grass
	ground.size = Vector2(world_width, world_height)
	ground.position = Vector2(-world_width/2, -world_height/2)
	add_child(ground)

func generate_decorations():
	# Generate trees
	for i in range(tree_count):
		attempt_place_decoration(tree_scene, "tree")
	
	# Generate bushes
	for i in range(bush_count):
		attempt_place_decoration(bush_scene, "bush")
	
	# Generate rocks
	for i in range(rock_count):
		attempt_place_decoration(rock_scene, "rock")

func attempt_place_decoration(scene, type):
	var max_attempts = 30
	var attempts = 0
	
	while attempts < max_attempts:
		var position = get_random_position()
		
		# Check if position is valid
		if is_position_valid(position):
			var decoration = scene.instantiate()
			decoration.position = position
			
			# Add some random rotation for visual variety
			if type != "rock":  # Rocks can have any rotation
				decoration.rotation = randf_range(0, 2 * PI)
			
			add_child(decoration)
			decorations.append(decoration)
			break
		
		attempts += 1

func get_random_position():
	# Get a random position within the world bounds
	var x = randf_range(-world_width / 2 + border_thickness, world_width / 2 - border_thickness)
	var y = randf_range(-world_height / 2 + border_thickness, world_height / 2 - border_thickness)
	return Vector2(x, y)

func is_position_valid(pos):
	# Check distance from all existing decorations
	for decoration in decorations:
		if pos.distance_to(decoration.position) < min_decoration_distance:
			return false
	
	# Make sure position is not too close to center (where player spawns)
	if pos.length() < 200:
		return false
	
	return true
