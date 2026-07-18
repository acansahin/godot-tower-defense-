extends Control
class_name HUD
## Top bar showing gold, lives and the current wave. Values are pushed in from
## Main via signals.

@onready var gold_label: Label = $GoldLabel
@onready var lives_label: Label = $LivesLabel
@onready var wave_label: Label = $WaveLabel

func set_gold(value: int) -> void:
	gold_label.text = "Gold: %d" % value

func set_lives(value: int) -> void:
	lives_label.text = "Lives: %d" % value

func set_wave(number: int, total: int) -> void:
	wave_label.text = "Wave: %d / %d" % [number, total]
