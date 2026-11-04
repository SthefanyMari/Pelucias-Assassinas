extends CanvasLayer

enum Screen { CLOSED, PAUSE, CONFIRM, COUNTDOWN }

var screen := Screen.CLOSED
var overlay: Control
var content: VBoxContainer
var menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20

	overlay = Control.new()
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	content = GameSession.make_panel(overlay, 420)
	overlay.hide()

	menu_button = $"../HUD/MenuButton"
	menu_button.pressed.connect(show_pause)

	var restart_button := get_node_or_null("../HUD/RestartButton") as Button
	if restart_button != null and restart_button.pressed.get_connections().is_empty():
		restart_button.pressed.connect(restart_game)
	
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey

	if key == null or not key.pressed or key.echo:
		return

	if key.keycode != KEY_ESCAPE and key.physical_keycode != KEY_ESCAPE:
		return

	get_viewport().set_input_as_handled()

	match screen:
		Screen.CLOSED:
			show_pause()

		Screen.PAUSE:
			resume_game()

		Screen.CONFIRM:
			show_pause()

		Screen.COUNTDOWN:
			pass


func show_pause() -> void:
	get_tree().paused = true
	screen = Screen.PAUSE
	overlay.show()

	GameSession.clear_panel(content)
	GameSession.add_text(content, "PAUSADO", 36)
	GameSession.add_button(content, "Voltar ao jogo", resume_game)
	GameSession.add_button(content, "Reiniciar", restart_game)
	GameSession.add_button(content, "Sair", confirm_exit)


func resume_game() -> void:
	screen = Screen.CLOSED
	overlay.hide()
	get_tree().paused = false


func restart_game() -> void:
	get_tree().paused = false
	var error := get_tree().reload_current_scene()
	if error != OK:
		show_pause()
		push_error("Não foi possível reiniciar a partida: %s" % error)


func confirm_exit() -> void:
	screen = Screen.CONFIRM
	var index := GameSession.difficulty

	GameSession.clear_panel(content)
	GameSession.add_text(content, "SAIR DA PARTIDA?", 28)
	GameSession.add_text(content, GameSession.EXIT_MESSAGES[index])
	GameSession.add_button(content, GameSession.EXIT_YES[index], leave_game)
	GameSession.add_button(content, GameSession.EXIT_NO[index], return_countdown)


func leave_game() -> void:
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(GameSession.MENU_SCENE)
	if error != OK:
		show_pause()
		push_error("Não foi possível abrir o menu inicial: %s" % error)


func return_countdown() -> void:
	screen = Screen.COUNTDOWN

	GameSession.clear_panel(content)
	GameSession.add_text(
		content,
		GameSession.RETURN_MESSAGES[GameSession.difficulty]
	)
	var counter := GameSession.add_text(content, "3", 52)

	for number in [3, 2, 1]:
		counter.text = str(number)
		await get_tree().create_timer(1.0, true).timeout

	counter.text = "GO"
	await get_tree().create_timer(0.5, true).timeout

	resume_game()
