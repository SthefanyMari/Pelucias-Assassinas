extends Node2D

enum State { RUNNING, WON, LOST }

const RABBIT_FRAMES: SpriteFrames = preload(
	"res://Kit_Ultima_Volta/godot/rabbit_frames.tres"
)

@export var enemy_scene: PackedScene
@export var max_enemies: int = 35
@export var plush2: PackedScene

var state := State.RUNNING
var next_spawn_is_rabbit := false
var achievement_label: Label


func _ready() -> void:
	$Player.health_changed.connect(_on_health_changed)
	$Player.died.connect(_on_player_died)
	$Exit.escaped.connect(_on_escaped)
	$EscapeTimer.timeout.connect(_on_time_finished)
	_on_health_changed($Player.health)
	$EscapeTimer.start(GameSession.escape_seconds())
	$SpawnTimer.timeout.connect(_on_spawn_timeout)
	$SpawnTimer.start()
	_setup_achievement_label()


func _process(_delta: float) -> void:
	if state == State.RUNNING and not $Exit.unlocked:
		$HUD/TimeLabel.text = "Abre em: %d" % int(
			ceil($EscapeTimer.time_left)
		)


func _on_health_changed(value: int) -> void:
	$HUD/HealthLabel.text = "Vida: %d" % value


func _on_player_died() -> void:
	finish(State.LOST)


func _on_time_finished() -> void:
	if state != State.RUNNING:
		return

	$Exit.unlock()
	$HUD/TimeLabel.text = "Saída aberta!"


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
	$SpawnTimer.stop()
	$Player.set_physics_process(false)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)

	var won := result == State.WON
	var message_label: Label = $HUD/MessageLabel
	var message_color := Color.GREEN if won else Color.RED

	message_label.text = GameSession.next_result_message(won)

	if won:
		var unlocked := GameSession.register_win()

		if unlocked.is_empty():
			var title: String = GameSession.ACHIEVEMENTS[GameSession.difficulty]
			achievement_label.text = "Conquista já desbloqueada: " + title
		else:
			achievement_label.text = "Conquista desbloqueada: " + unlocked

		achievement_label.show()

	if message_label.label_settings != null:
		var settings := message_label.label_settings.duplicate() as LabelSettings
		settings.font_color = message_color
		message_label.label_settings = settings
	else:
		message_label.add_theme_color_override("font_color", message_color)

	message_label.show()


func _on_restart_pressed() -> void:
	if is_inside_tree():
		get_tree().reload_current_scene()


func _on_spawn_timeout() -> void:
	if state != State.RUNNING:
		return

	if enemy_scene == null:
		return

	if $Enemies.get_child_count() >= max_enemies:
		return

	var points: Array[Node2D] = []

	for point in $SpawnPoints.get_children():
		if point.global_position.distance_to(
			$Player.global_position
		) >= 140.0:
			points.append(point)

	if points.is_empty():
		return

	var enemy := enemy_scene.instantiate() as Node2D

	if next_spawn_is_rabbit:
		var enemy_sprite := enemy.find_child(
			"AnimatedSprite2D", true, false
		) as AnimatedSprite2D

		if enemy_sprite != null:
			enemy_sprite.sprite_frames = RABBIT_FRAMES

	$Enemies.add_child(enemy)
	enemy.global_position = points.pick_random().global_position
	next_spawn_is_rabbit = not next_spawn_is_rabbit
	
func _setup_achievement_label() -> void:
	achievement_label = Label.new()
	achievement_label.name = "AchievementLabel"
	$HUD.add_child(achievement_label)

	achievement_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	achievement_label.offset_left = 16
	achievement_label.offset_right = 440
	achievement_label.offset_top = -76
	achievement_label.offset_bottom = -16
	achievement_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	achievement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	achievement_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	achievement_label.add_theme_color_override("font_color", Color.YELLOW)
	achievement_label.add_theme_color_override("font_outline_color", Color.BLACK)
	achievement_label.add_theme_constant_override("outline_size", 4)
	achievement_label.hide()
