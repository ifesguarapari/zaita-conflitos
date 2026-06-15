extends CanvasLayer

signal play_requested

@onready var play_button: Button = $Card/Margin/Content/Body/RightColumn/ButtonHolder/PlayButton


func _ready() -> void:
	play_button.pressed.connect(func() -> void:
		hide_popup()
		play_requested.emit()
	)


func show_popup() -> void:
	visible = true


func hide_popup() -> void:
	visible = false
