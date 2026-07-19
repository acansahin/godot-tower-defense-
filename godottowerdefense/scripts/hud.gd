extends Control
class_name HUD
## Top bar showing gold, lives and the current wave. Values are pushed in from
## Main via signals.

signal send_pressed  ## Player asked to send the next wave early.

@onready var gold_label: Label = $GoldLabel
@onready var lives_label: Label = $LivesLabel
@onready var wave_label: Label = $WaveLabel
@onready var next_label: Label = $NextLabel
@onready var send_button: Button = $SendButton

func _ready() -> void:
	send_button.pressed.connect(func() -> void: send_pressed.emit())

func set_gold(value: int) -> void:
	gold_label.text = "Gold: %d" % value

func set_lives(value: int) -> void:
	lives_label.text = "Lives: %d" % value

func set_wave(number: int, total: int) -> void:
	wave_label.text = "Wave: %d / %d" % [number, total]
	send_button.disabled = true  # a wave is active now

func set_next(text: String, color: Color) -> void:
	next_label.text = text
	next_label.add_theme_color_override("font_color", color)

## Re-enabled during the between-waves gap.
func enable_send() -> void:
	send_button.disabled = false
