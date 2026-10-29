extends Node2D
enum State { RUNNING, WON, LOST }
var state := State.RUNNING

@export var enemy_scene: PackedScene
@export var max_enemies: int = 35
@export var plush2: PackedScene


func _ready() -> void:
	$Player.health_changed.connect(_on_health_changed)
	$Player.died.connect(_on_player_died)
	$Exit.escaped.connect(_on_escaped)
	$EscapeTimer.timeout.connect(_on_time_finished)
	_on_health_changed($Player.health)
	$EscapeTimer.start()
	$HUD/RestartButton.pressed.connect(_on_restart_pressed)
	$SpawnTimer.timeout.connect(_on_spawn_timeout)
	$SpawnTimer.start()

	
func _process(_delta: float) -> void:
	if state == State.RUNNING and not $Exit.unlocked:
		$HUD/TimeLabel.text = "Abre em: %d" % int(
		ceil($EscapeTimer.time_left))
		
func _on_health_changed(value: int) -> void:
	$HUD/HealthLabel.text = "Vida: %d" % value

func _on_player_died() -> void:
	finish(State.LOST)

func _on_time_finished() -> void:
	if state != State.RUNNING:
		return
	$Exit.unlock()
	$HUD/TimeLabel.text = "Saida aberta!"
	
func _on_escaped() -> void:
	call_deferred("try_win")
	
func try_win() -> void:
	if state == State.RUNNING and $Player.health > 0:
		finish(State.WON)
		
func finish(result: State) -> void:
	if state != State.RUNNING:
		return
	state = result
	$EscapeTimer.stop()
	$Player.set_physics_process(false)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	$HUD/MessageLabel.text = (
		"Voce escapou!" if result == State.WON else "Fim de jogo!")
		
func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
	
func _on_spawn_timeout() -> void:
	if state != State.RUNNING:
		return
	if $Enemies.get_child_count() >= max_enemies:
		return
	var points: Array[Node2D] = []
	for point in $SpawnPoints.get_children():
		if point.global_position.distance_to(
				$Player.global_position) >= 140.0:
			points.append(point)
	if points.is_empty():
		return
	var selected_scene: PackedScene = enemy_scene
	if plush2 != null and randf() < 0.5:
		selected_scene =plush2

	var enemy = selected_scene.instantiate()
	$Enemies.add_child(enemy)
	enemy.global_position = points.pick_random().global_position
