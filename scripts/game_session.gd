extends Node

const MENU_SCENE := "res://scenes/main_menu.tscn"
const ARENA_SCENE := "res://scenes/arena.tscn"
const SAVE_PATH := "user://ultima_volta.cfg"

const DIFFICULTY_NAMES := [
	"Ainda Uso Rodinhas na Bike",
	"Humano Padrão de Fábrica",
	"Me Bate Mais que Tá Pouco"
]

const ESCAPE_TIMES := [15.0, 60.0, 100.0]

const DEFEAT_MESSAGES := [
	[
		"Quinze segundos. As rodinhas pediram transferência.",
		"Você caiu no modo fácil. Até a placa de saída ficou sem graça.",
		"As pelúcias disseram que foi treino. Para elas."
	],
	[
		"Humano Padrão de Fábrica: reprovado no controle de qualidade.",
		"Um minuto era a meta. Aparentemente, era uma meta ambiciosa.",
		"O urso pediu revanche. Foi informado de que isso exige uma disputa."
	],
	[
		"Você pediu 'Me Bate Mais que Tá Pouco'. O parque levou ao pé da letra.",
		"O moedor registrou mais uma entrega no prazo.",
		"O coelho chamou isso de aquecimento. Ele nem alongou."
	]
]

const ACHIEVEMENTS := [
	"Rodinhas Aprovadas",
	"Controle de Qualidade",
	"O Moedor Pediu Demissão"
]

const EXIT_MESSAGES := [
	"Desistindo? O sistema detectou que mesmo com as rodinhas de proteção e o modo tutorial ativo, você conseguiu falhar. O erro foi seu em nascer, e passar vergonha no modo mais fácil é um recorde pessoal seu. Tem certeza que quer sair?",
	"Desistindo? O sistema detectou que o 'Humano Padrão de Fábrica' não aguenta nem o feijão com arroz do jogo. O erro foi seu em nascer, e sua mediocridade foi atualizada com sucesso. Tem certeza que quer sair?",
	"Desistindo? O sistema detectou que a sua configuração de fábrica veio com defeito. O erro foi seu em nascer, mas a escolha de passar vergonha é toda sua. Tem certeza que quer sair?"
]

const EXIT_YES := [
	"Sim, nem assim eu consigo",
	"Sim, sou só um medíocre",
	"Sim, sou fraco"
]

const EXIT_NO := [
	"Não, vou parar de chorar",
	"Não, vou honrar meu sistema",
	"Não, vou tentar de novo"
]

const RETURN_MESSAGES := [
	"Engoliu o choro? Ótimo.",
	"Orgulho reiniciado. Volte a fazer o mínimo esperado de você.",
	"Voltou pro moedor? Excelente. Gosto de ver erro persistente."
]

var difficulty: int = 1
var progress := ConfigFile.new()


func _ready() -> void:
	if progress.load(SAVE_PATH) == OK:
		difficulty = clampi(
			int(progress.get_value("options", "difficulty", 1)), 0, 2
		)


func set_difficulty(index: int) -> void:
	difficulty = clampi(index, 0, 2)
	progress.set_value("options", "difficulty", difficulty)
	save_progress()


func escape_seconds() -> float:
	return float(ESCAPE_TIMES[difficulty])


func has_won(index: int) -> bool:
	return bool(progress.get_value("achievements", "won_%d" % index, false))


func has_won_all() -> bool:
	return has_won(0) and has_won(1) and has_won(2)


func register_win() -> String:
	if has_won(difficulty):
		return ""

	progress.set_value("achievements", "won_%d" % difficulty, true)
	save_progress()

	var unlocked := str(ACHIEVEMENTS[difficulty])
	if has_won_all():
		unlocked += " + A Última Palavra"

	return unlocked


func save_progress() -> void:
	var error := progress.save(SAVE_PATH)
	if error != OK:
		push_warning("Não foi possível salvar o progresso: %s" % error)


func make_panel(host: Control, panel_width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	host.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(panel_width, 390)
	panel.add_theme_stylebox_override(
		"panel",
		make_style(Color("#21152f"), Color("#c9934f"), 18)
	)
	center.add_child(panel)

	var margin := MarginContainer.new()
	panel.add_child(margin)

	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)

	return content

func clear_panel(content: VBoxContainer) -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func add_text(content: VBoxContainer, value: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	content.add_child(label)
	return label


func add_button(content: VBoxContainer, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#fff3dc"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)

	var normal := Color("#56326f")
	var hover := Color("#75478f")

	if title == "Play":
		normal = Color("#365b3c")
		hover = Color("#49784f")

	button.add_theme_stylebox_override(
		"normal", make_style(normal, Color("#b98349"), 9)
	)
	button.add_theme_stylebox_override(
		"hover", make_style(hover, Color("#efbd76"), 9)
	)
	button.add_theme_stylebox_override(
		"pressed", make_style(normal.darkened(0.2), Color("#efbd76"), 9)
	)

	button.pressed.connect(action)
	content.add_child(button)

	return button
	
func make_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

const VICTORY_MESSAGES := [
	[
		"Você escapou! As rodinhas vão querer metade do crédito.",
		"Quinze segundos de glória. Já dá para colocar no currículo.",
		"Vitória confirmada. O tutorial agora quer ser citado nos créditos."
	],
	[
		"Parabéns, Humano Padrão de Fábrica. Você atingiu o mínimo esperado.",
		"Sessenta segundos e uma fuga. A garantia foi renovada por mais um dia.",
		"Você escapou! O parque vai abrir um chamado para investigar."
	],
	[
		"Cem segundos. O moedor pediu demissão e o urso pediu férias.",
		"Você escapou no difícil. As pelúcias juram que estavam distraídas.",
		"'Me Bate Mais que Tá Pouco'? Depois dessa, quem pediu pausa foi o parque."
	]
]

var result_message_counts: Dictionary = {}


func next_result_message(won: bool) -> String:
	var messages: Array

	if won:
		messages = VICTORY_MESSAGES[difficulty]
	else:
		messages = DEFEAT_MESSAGES[difficulty]

	var result_key := "won" if won else "lost"
	var key := "%s_%d" % [result_key, difficulty]
	var count := int(result_message_counts.get(key, 0))

	result_message_counts[key] = count + 1

	return str(messages[count % messages.size()])
