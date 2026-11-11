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
var equipment_label: Label
var result_panel: PanelContainer
var power_status_label: Label


func _ready() -> void:
	$Player.health_changed.connect(_on_health_changed)
	$Player.died.connect(_on_player_died)
	$Exit.escaped.connect(_on_escaped)
	$EscapeTimer.timeout.connect(_on_time_finished)
	_on_health_changed($Player.health)
	$EscapeTimer.start(GameSession.escape_seconds())
	$SpawnTimer.timeout.connect(_on_spawn_timeout)
	_configure_enemy_difficulty()
	$SpawnTimer.start()
	_setup_achievement_label()
	_setup_equipment_label()
	_update_equipment_label()
	_setup_result_panel()
	_setup_power_status_label()


func _process(_delta: float) -> void:
	if state == State.RUNNING and not $Exit.unlocked:
		$HUD/TimeLabel.text = "Abre em: %d" % int(ceil($EscapeTimer.time_left))
	_update_power_status_label()


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
	$Player.stop_combat()
	$Player.set_physics_process(false)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("stop_combat"):
			enemy.stop_combat()
		else:
			enemy.set_physics_process(false)

	for projectile in get_tree().get_nodes_in_group("combat_projectiles"):
		projectile.stop_combat()

	var won := result == State.WON
	var message_label := result_panel.get_node("MessageLabel") as Label
	var message_color := Color.GREEN if won else Color.RED
	message_label.text = GameSession.next_result_message(won)
	var panel_style := result_panel.get_theme_stylebox(
		"panel"
	) as StyleBoxFlat

	panel_style.border_color = message_color
	result_panel.show()

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
	_update_equipment_label()


func _on_restart_pressed() -> void:
	if is_inside_tree():
		get_tree().reload_current_scene()


func _on_spawn_timeout() -> void:
	if state != State.RUNNING or enemy_scene == null:
		return
	if $Enemies.get_child_count() >= max_enemies:
		return

	var points: Array[Node2D] = []
	for point in $SpawnPoints.get_children():
		if point.global_position.distance_to($Player.global_position) >= 140.0:
			points.append(point)
	if points.is_empty():
		return

	var enemy := enemy_scene.instantiate() as Node2D
	if next_spawn_is_rabbit:
		var enemy_sprite := enemy.find_child("AnimatedSprite2D", true, false) as AnimatedSprite2D
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


func _setup_equipment_label() -> void:
	equipment_label = Label.new()
	equipment_label.name = "EquipmentLabel"
	$HUD.add_child(equipment_label)

	equipment_label.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER
	)

	equipment_label.offset_left = -280
	equipment_label.offset_right = 280
	equipment_label.offset_top = -65
	equipment_label.offset_bottom = 65

	equipment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	equipment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	equipment_label.add_theme_color_override(
		"font_color", Color.GOLD
	)
	equipment_label.add_theme_color_override(
		"font_outline_color", Color.BLACK
	)
	equipment_label.add_theme_constant_override(
		"outline_size", 6
	)
	equipment_label.add_theme_font_size_override(
		"font_size", 22
	)

	equipment_label.text = "ESPAÇO: %s\nQ: %s" % [
		$Player.get_weapon_name(),
		$Player.get_power_name()
	]

	get_tree().create_timer(3.0, false).timeout.connect(
		equipment_label.hide
	)


func _update_equipment_label() -> void:
	if equipment_label == null:
		return

	var status := "Pronto"
	var remaining: float = $Player.power_cooldown_remaining
	if state != State.RUNNING:
		status = "Partida encerrada"
	elif $Player.shield_remaining > 0.0:
		status = "Proteção ativa: %.1f s" % $Player.shield_remaining
	elif remaining > 0.0:
		status = "Recarga: %d s" % int(ceil(remaining))

	equipment_label.text = "ESPAÇO: %s\nQ: %s — %s" % [
		$Player.get_weapon_name(), $Player.get_power_name(), status
	]

func _configure_enemy_difficulty() -> void:
	var difficulty := clampi(GameSession.difficulty, 0, 2)

	match difficulty:
		0:
			max_enemies = 15
			$SpawnTimer.wait_time = 1.5

		1:
			max_enemies = 40
			$SpawnTimer.wait_time = 0.7

		2:
			max_enemies = 200
			$SpawnTimer.wait_time = 0.25

	$SpawnTimer.one_shot = false
	
func _setup_result_panel() -> void:
	var message_label := $HUD/MessageLabel as Label

	result_panel = PanelContainer.new()
	result_panel.name = "ResultPanel"
	$HUD.add_child(result_panel)

	result_panel.set_anchors_and_offsets_preset(
		Control.PRESET_CENTER
	)

	result_panel.offset_left = -280
	result_panel.offset_right = 280
	result_panel.offset_top = -100
	result_panel.offset_bottom = 100
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.z_index = 10

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#21152f")

	style.set_corner_radius_all(18)
	style.set_border_width_all(3)

	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0

	result_panel.add_theme_stylebox_override("panel", style)

	message_label.reparent(result_panel)
	message_label.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	message_label.custom_minimum_size = Vector2.ZERO
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.text = ""
	message_label.show()

	result_panel.hide()
	
func _setup_power_status_label() -> void:
	var time_label := $HUD/TimeLabel as Label

	power_status_label = Label.new()
	power_status_label.name = "PowerStatusLabel"
	time_label.add_child(power_status_label)

	power_status_label.position = Vector2(
		0.0,
		maxf(time_label.size.y, time_label.get_minimum_size().y) + 6.0
	)

	power_status_label.add_theme_color_override(
		"font_color", Color.GOLD
	)
	power_status_label.add_theme_color_override(
		"font_outline_color", Color.BLACK
	)
	power_status_label.add_theme_constant_override(
		"outline_size", 4
	)
	power_status_label.add_theme_font_size_override(
		"font_size", 18
	)

	power_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_power_status_label()


func _update_power_status_label() -> void:
	if power_status_label == null:
		return

	if state != State.RUNNING:
		power_status_label.hide()
		return

	power_status_label.show()

	var remaining: float = $Player.power_cooldown_remaining

	if remaining > 0.0:
		power_status_label.text = "Q disponível em: %d s" % int(
			ceil(remaining)
		)
	else:
		power_status_label.text = "Q pronto!"
	
