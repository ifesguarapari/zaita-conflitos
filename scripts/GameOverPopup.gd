extends CanvasLayer

signal play_again_requested

@onready var restart_button: Button = $Card/Margin/Content/Body/RightColumn/ButtonHolder/RestartButton
@onready var title_label: Label = $Card/Margin/Content/TitleBar/TitleMargin/Title
@onready var description_label: Label = $Card/Margin/Content/Body/RightColumn/TextPanel/TextMargin/Description


func _ready() -> void:
	restart_button.pressed.connect(func() -> void:
		hide_popup()
		play_again_requested.emit()
	)


func show_popup(child_name: String = "") -> void:
	var displayed_name := child_name if not child_name.is_empty() else "Zaíta"
	title_label.text = "%s foi atingida" % displayed_name
	description_label.text = (
		"O tiro interrompe a procura pela figurinha-flor e deixa o beco em silêncio. "
		+ "Benícia, a mãe, e a irmã carregam a dor de quem só queria ver as meninas voltarem para casa. "
		+ "A frase final pesa como memória e culpa: \"Zaíta, você esqueceu de guardar os brinquedos\". "
		+ "Tente de novo: mova o irmão, mire nos inimigos e proteja Zaíta e Naíta até o fim."
	)
	visible = true


func hide_popup() -> void:
	visible = false
