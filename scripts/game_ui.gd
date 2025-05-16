extends CanvasLayer

@onready var gold_label = $GoldDisplay/GoldLabel
@onready var wave_label = $WaveInfo/WaveLabel
@onready var enemies_label = $WaveInfo/EnemiesLabel
@onready var next_wave_button = $WaveInfo/NextWaveButton
@onready var wave_timer_label = $WaveInfo/TimerLabel

var gold_system
var wave_spawner

func _ready():
	# Initially hide next wave button until we connect it
	next_wave_button.visible = false
	
	# Find the gold system
	await get_tree().process_frame
	gold_system = get_tree().get_first_node_in_group("gold_system")
	
	if gold_system:
		gold_system.gold_changed.connect(_on_gold_changed)
		_on_gold_changed(gold_system.get_current_gold())
	else:
		print("ERROR: GoldSystem node not found!")
		
	# Find the wave spawner
	wave_spawner = get_tree().get_first_node_in_group("wave_spawner")
	
	if wave_spawner:
		wave_spawner.wave_started.connect(_on_wave_started)
		wave_spawner.wave_completed.connect(_on_wave_completed)
		wave_spawner.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
		
		# Connect the next wave button
		next_wave_button.visible = true
		next_wave_button.pressed.connect(_on_next_wave_button_pressed)
		
		# Initial UI update
		var wave_info = wave_spawner.get_current_wave_info()
		update_wave_info(wave_info)
	else:
		print("ERROR: WaveSpawner node not found!")

func _process(delta):
	if wave_spawner:
		var wave_info = wave_spawner.get_current_wave_info()
		
		# Update the timer if we're between waves
		if not wave_info.in_progress and wave_info.next_wave_time > 0:
			wave_timer_label.text = "Next wave in: " + str(int(wave_info.next_wave_time + 1))
			wave_timer_label.visible = true
			next_wave_button.visible = true
		else:
			wave_timer_label.visible = false
			next_wave_button.visible = false

func _on_gold_changed(amount):
	gold_label.text = str(amount)

func _on_wave_started(wave_number, enemy_count):
	wave_label.text = "Wave: " + str(wave_number)
	enemies_label.text = "Enemies: " + str(enemy_count)

func _on_wave_completed(wave_number):
	# Maybe add a visual notification here
	pass

func _on_enemies_remaining_changed(count):
	enemies_label.text = "Enemies: " + str(count)

func update_wave_info(info):
	wave_label.text = "Wave: " + str(info.wave_number)
	enemies_label.text = "Enemies: " + str(info.enemies_remaining)

func _on_next_wave_button_pressed():
	if wave_spawner:
		wave_spawner.manually_start_next_wave()
