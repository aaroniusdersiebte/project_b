# scripts/path_choice_ui.gd
extends Control

signal path_selected(path_index)

var game_manager

func _ready():
	# Critical: Make sure this node doesn't inadvertently pause the game
	print("PathChoiceUI: initializing, game paused state:", get_tree().paused)
	
	# Ensure visible property is properly set
	self.visible = false
	
	# Set process mode to Always so UI works in pause mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# UI setup for visibility
	if get_parent() is Viewport:
		# If directly under viewport, make sure it's visible
		z_index = 100
	
	# Set up input handling
	mouse_filter = Control.MOUSE_FILTER_STOP  # Blocks mouse events from passing through
	
	# Find GameManager
	game_manager = get_node("/root/GameManager")
	if not game_manager:
		print("WARNING: GameManager not found in PathChoiceUI")
	
	# Connect buttons
	if has_node("HardPathButton"):
		$HardPathButton.pressed.connect(_on_hard_path_pressed)
		print("Connected HardPathButton")
	else:
		print("ERROR: HardPathButton not found")
		
	if has_node("EasyPathButton"):
		$EasyPathButton.pressed.connect(_on_easy_path_pressed)
		print("Connected EasyPathButton")
	else:
		print("ERROR: EasyPathButton not found")
	
	# Add dim panel if not present
	if not has_node("DimPanel"):
		_add_dim_panel()
	
	# Make absolutely sure we're not visible initially
	self.visible = false
	
	print("PathChoiceUI initialized, visible:", self.visible, ", game paused:", get_tree().paused)

func _add_dim_panel():
	# Create a dim panel to make UI stand out
	var panel = Panel.new()
	panel.name = "DimPanel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.modulate = Color(0, 0, 0, 0.7)  # Semi-transparent black
	
	# Add to the beginning so it's behind other elements
	add_child(panel)
	move_child(panel, 0)
	
	print("Added DimPanel to PathChoiceUI")

func _on_hard_path_pressed():
	print("Hard path selected")
	handle_path_choice(0)  # Hard path (index 0)

func _on_easy_path_pressed():
	print("Easy path selected")
	handle_path_choice(1)  # Easy path (index 1)

func handle_path_choice(path_index):
	print("Handling path choice:", path_index)
	
	# Hide UI first
	self.visible = false
	
	# Unpause game first to avoid any race conditions
	get_tree().paused = false
	
	# Then notify game manager
	if game_manager:
		game_manager.make_path_choice(path_index)
		print("Notified GameManager of path choice:", path_index)
	else:
		print("ERROR: Cannot notify GameManager of path choice")
	
	# Emit signal for event handling
	emit_signal("path_selected", path_index)
	
	print("Path choice handling complete, game paused:", get_tree().paused)
