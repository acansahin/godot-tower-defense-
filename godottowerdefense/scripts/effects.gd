extends Node2D
## The $Effects container as an object pool for the two purely-drawn "particle" types —
## floating damage/gold numbers and enemy death bursts. Both are short-lived and arrive in
## bursts (a splash kill can pop a dozen at once), so recycling them (hide + stop
## processing) instead of new()/queue_free() removes a lot of node churn on busy waves.
##
## FloatingText / DeathBurst have class_name, so they are built with their global
## constructors here. FrostRing has none (it is preloaded), so it is typed loosely. All three
## route their own spawn() helpers through this pool (see those files).

const SOFT_CAP := 512  ## Idle instances kept per type; any freed past this are actually released.
const FrostRing := preload("res://scripts/frost_ring.gd")

var _free_text: Array[FloatingText] = []
var _free_burst: Array[DeathBurst] = []
var _free_frost: Array = []  ## FrostRing has no class_name, so this stays untyped.

func acquire_text() -> FloatingText:
	var t: FloatingText
	if _free_text.is_empty():
		t = FloatingText.new()
		t.pool = self
		add_child(t)
	else:
		t = _free_text.pop_back()
		t.visible = true
		t.set_process(true)
	return t

func recycle_text(t: FloatingText) -> void:
	t.set_process(false)
	t.visible = false
	if _free_text.size() >= SOFT_CAP:
		t.queue_free()
		return
	_free_text.append(t)

func acquire_burst() -> DeathBurst:
	var b: DeathBurst
	if _free_burst.is_empty():
		b = DeathBurst.new()
		b.pool = self
		add_child(b)
	else:
		b = _free_burst.pop_back()
		b.visible = true
		b.set_process(true)
	return b

func recycle_burst(b: DeathBurst) -> void:
	b.set_process(false)
	b.visible = false
	if _free_burst.size() >= SOFT_CAP:
		b.queue_free()
		return
	_free_burst.append(b)

func acquire_frost():
	var f
	if _free_frost.is_empty():
		f = FrostRing.new()
		f.pool = self
		add_child(f)
	else:
		f = _free_frost.pop_back()
		f.visible = true
		f.set_process(true)
	return f

func recycle_frost(f) -> void:
	f.set_process(false)
	f.visible = false
	if _free_frost.size() >= SOFT_CAP:
		f.queue_free()
		return
	_free_frost.append(f)
