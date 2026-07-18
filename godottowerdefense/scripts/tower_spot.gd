extends Area2D
class_name TowerSpot
## A clickable build pad beside the road. Emits `pressed` when the player
## clicks it while it is still empty.

signal pressed(spot: TowerSpot)

var occupied: bool = false
var _hovered: bool = false

func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if occupied:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)

func _on_mouse_enter() -> void:
	_hovered = true
	queue_redraw()

func _on_mouse_exit() -> void:
	_hovered = false
	queue_redraw()

func set_occupied() -> void:
	occupied = true
	_hovered = false
	queue_redraw()

func _draw() -> void:
	if occupied:
		return
	var fill := Color(0.25, 0.22, 0.16, 0.55)
	if _hovered:
		fill = Color(0.95, 0.85, 0.30, 0.75)
	draw_circle(Vector2.ZERO, 26.0, fill)
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 28, Color(1, 1, 1, 0.7), 2.0, true)
	# Plus sign to signal "build here".
	draw_line(Vector2(-9, 0), Vector2(9, 0), Color(1, 1, 1, 0.85), 3.0)
	draw_line(Vector2(0, -9), Vector2(0, 9), Color(1, 1, 1, 0.85), 3.0)
