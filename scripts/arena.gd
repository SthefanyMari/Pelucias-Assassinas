extends Node2D
enum State { RUNNING, WON, LOST }
var state := State.RUNNING

func _ready() -> void:
	$Player.health_changed.connect(_on_health_changed)
	$Player.died.connect(_on_player_died)
	$Exit.escaped.connect(_on_escaped)
	$EscapeTimer.timeout.connect(_on_time_finished)
	_on_health_changed($Player.health)
	$EscapeTimer.start()
	
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
