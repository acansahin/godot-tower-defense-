extends Node2D
## Sparse, code-drawn atmosphere above the painted board. The painting itself stays one
## texture and water/lava remain GPU-masked in map.gd; this layer supplies only the tiny
## moving cues a still image cannot: leaves, pollen, snow, dust, ash and embers.

const FOREST_COUNT := 22
const GLACIER_COUNT := 25
const DESERT_COUNT := 27
const ASH_COUNT := 32

var _kind: String = "forest"
var _time: float = 0.0
## x/y are normalized spawn positions, z is size and w is a phase/speed seed.
var _particles: Array[Vector4] = []

func setup(board_id: String, kind: String) -> void:
	_kind = kind
	_time = 0.0
	_particles.clear()
	# A board with no declared ambience gets none. Without this an empty kind fell through
	# the match below to the forest, and a greybox board grew drifting leaves.
	if kind == "":
		queue_redraw()
		return
	var count := FOREST_COUNT
	match kind:
		"glacier": count = GLACIER_COUNT
		"desert": count = DESERT_COUNT
		"ash": count = ASH_COUNT
	var rng := RandomNumberGenerator.new()
	# Stable per board: switching away and back does not visibly reshuffle the atmosphere.
	rng.seed = hash(board_id + ":ambience")
	for i in count:
		_particles.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.65, 1.35),
				rng.randf_range(0.0, TAU)))
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	match _kind:
		"glacier": _draw_glacier()
		"desert": _draw_desert()
		"ash": _draw_ash()
		_: _draw_forest()

## A few leaves ride long gusts while smaller pollen motes hover locally. The count is low
## enough that combat remains the only fast motion on the board.
func _draw_forest() -> void:
	for i in _particles.size():
		var p := _particles[i]
		if i % 3 == 0:
			var speed := 23.0 + p.w * 3.0
			var x := fposmod(p.x * Game.WORLD_SIZE.x + _time * speed,
					Game.WORLD_SIZE.x + 100.0) - 50.0
			var y := p.y * Game.WORLD_SIZE.y + sin(_time * 1.5 + p.w) * 15.0
			var at := Vector2(x, y)
			var size := 3.2 * p.z
			var turn := _time * (1.5 + p.z) + p.w
			var col := Color(0.58, 0.74, 0.22, 0.34)
			if i % 2 == 0:
				col = Color(0.82, 0.58, 0.18, 0.30)
			draw_colored_polygon(PackedVector2Array([
				at + Vector2(size, 0.0).rotated(turn),
				at + Vector2(0.0, -size * 0.45).rotated(turn),
				at + Vector2(-size, 0.0).rotated(turn),
				at + Vector2(0.0, size * 0.45).rotated(turn),
			]), col)
		else:
			var at := Vector2(p.x * Game.WORLD_SIZE.x + sin(_time * 0.55 + p.w) * 8.0,
					p.y * Game.WORLD_SIZE.y + sin(_time * 0.38 + p.w * 1.7) * 6.0)
			draw_circle(at, 1.2 * p.z, Color(0.92, 0.88, 0.48, 0.17))

func _draw_glacier() -> void:
	for i in _particles.size():
		var p := _particles[i]
		var fall := 10.0 + p.z * 8.0
		var y := fposmod(p.y * Game.WORLD_SIZE.y + _time * fall,
				Game.WORLD_SIZE.y + 40.0) - 20.0
		var x := p.x * Game.WORLD_SIZE.x + sin(_time * 0.65 + p.w) * 13.0
		var at := Vector2(x, y)
		if i % 5 == 0:
			var r := 3.0 * p.z
			draw_line(at - Vector2(r, 0.0), at + Vector2(r, 0.0),
					Color(0.84, 0.94, 1.0, 0.26), 1.0)
			draw_line(at - Vector2(0.0, r), at + Vector2(0.0, r),
					Color(0.84, 0.94, 1.0, 0.26), 1.0)
		else:
			draw_circle(at, 1.3 * p.z, Color(0.88, 0.95, 1.0, 0.23))

func _draw_desert() -> void:
	for i in _particles.size():
		var p := _particles[i]
		var speed := 17.0 + p.z * 12.0
		var x := fposmod(p.x * Game.WORLD_SIZE.x + _time * speed,
				Game.WORLD_SIZE.x + 80.0) - 40.0
		var y := p.y * Game.WORLD_SIZE.y + sin(_time * 0.72 + p.w) * 9.0
		var at := Vector2(x, y)
		var alpha := 0.10 + 0.06 * sin(_time * 0.8 + p.w)
		draw_line(at, at + Vector2(8.0 * p.z, 1.5),
				Color(0.90, 0.76, 0.48, alpha), 1.2 * p.z, true)

func _draw_ash() -> void:
	for i in _particles.size():
		var p := _particles[i]
		if i % 5 == 0:
			# Rare embers rise; most particles are slow, falling grey ash.
			var y := fposmod(p.y * Game.WORLD_SIZE.y - _time * (16.0 + p.z * 8.0),
					Game.WORLD_SIZE.y + 50.0) - 25.0
			var x := p.x * Game.WORLD_SIZE.x + sin(_time * 1.2 + p.w) * 10.0
			draw_circle(Vector2(x, y), 1.4 * p.z, Color(1.0, 0.34, 0.06, 0.30))
		else:
			var y := fposmod(p.y * Game.WORLD_SIZE.y + _time * (8.0 + p.z * 5.0),
					Game.WORLD_SIZE.y + 40.0) - 20.0
			var x := p.x * Game.WORLD_SIZE.x + sin(_time * 0.48 + p.w) * 12.0
			draw_circle(Vector2(x, y), 1.5 * p.z, Color(0.50, 0.46, 0.43, 0.20))
