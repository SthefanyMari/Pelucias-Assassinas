extends Control

var content: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = GameSession.make_panel(self, 420)
	show_difficulty_select()


func show_main_menu() -> void:
	GameSession.clear_panel(content)
	GameSession.add_text(content, "ÚLTIMA VOLTA", 42)
	GameSession.add_text(
		content,
		"Dificuldade: %s" % GameSession.DIFFICULTY_NAMES[GameSession.difficulty]
	)
	GameSession.add_button(content, "Play", show_difficulty_select)
	GameSession.add_button(content, "Options", show_options)
	GameSession.add_button(content, "Créditos", show_credits)
	GameSession.add_button(content, "Exit", exit_game)


func show_options() -> void:
	GameSession.clear_panel(content)
	GameSession.add_text(content, "OPTIONS", 30)
	GameSession.add_text(content, "Escolha a dificuldade:")

	var picker := OptionButton.new()
	for index in range(GameSession.DIFFICULTY_NAMES.size()):
		picker.add_item(
			"%s — %d segundos" % [
				GameSession.DIFFICULTY_NAMES[index],
				int(GameSession.ESCAPE_TIMES[index])
			]
		)

	picker.select(GameSession.difficulty)
	picker.item_selected.connect(GameSession.set_difficulty)
	content.add_child(picker)

	GameSession.add_button(content, "Conquistas", show_achievements)
	GameSession.add_button(content, "Voltar", show_main_menu)


func show_achievements() -> void:
	GameSession.clear_panel(content)
	GameSession.add_text(content, "CONQUISTAS", 30)

	for index in range(GameSession.ACHIEVEMENTS.size()):
		var status := "Desbloqueada" if GameSession.has_won(index) else "Bloqueada"
		GameSession.add_text(
			content,
			"%s — %s\nEscape em: %s" % [
				GameSession.ACHIEVEMENTS[index],
				status,
				GameSession.DIFFICULTY_NAMES[index]
			]
		)

	if GameSession.has_won_all():
		GameSession.add_text(content, "A Última Palavra — Desbloqueada")
	else:
		GameSession.add_text(content, "??? — O parque ainda guarda um segredo.")

	GameSession.add_button(content, "Voltar", show_options)


func show_credits() -> void:
	GameSession.clear_panel(content)
	GameSession.add_text(content, "CRÉDITOS", 30)
	GameSession.add_text(content, "Diretores: Sthefany Mariany")
	GameSession.add_text(content, "Programadores e Engenheiros: Sthefany Mariany")
	GameSession.add_text(content, "Artistas e Animadores: Sthefany Mariany")
	GameSession.add_text(content, "Designers de Jogo: Sthefany Mariany e ChatGPT")
	GameSession.add_text(content, "Roteiristas: Sthefany Mariany e Carlos Eduardo")
	GameSession.add_text(
		content,
		"Colaboradores: Sthefany Mariany, Carlos Eduardo e ChatGPT"
	)
	GameSession.add_button(content, "Voltar", show_main_menu)


func play_game() -> void:
	get_tree().change_scene_to_file(GameSession.ARENA_SCENE)


func exit_game() -> void:
	get_tree().quit()
	
func show_difficulty_select() -> void:
	GameSession.clear_panel(content)
	GameSession.add_text(content, "ESCOLHA A DIFICULDADE", 26)

	for index in range(GameSession.DIFFICULTY_NAMES.size()):
		var title := "%s\n%d segundos" % [
			GameSession.DIFFICULTY_NAMES[index],
			int(GameSession.ESCAPE_TIMES[index])
		]
		GameSession.add_button(
			content,
			title,
			start_with_difficulty.bind(index)
		)

	GameSession.add_button(content, "Voltar", show_main_menu)


func start_with_difficulty(index: int) -> void:
	GameSession.set_difficulty(index)
	play_game()
