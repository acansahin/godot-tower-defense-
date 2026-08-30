extends Node2D
## The $Effects container as an object pool for the purely-drawn "particle" types —
## floating damage/gold numbers, enemy death bursts and elemental impact rings. They are
## short-lived and arrive in
## bursts (a splash kill can pop a dozen at once), so recycling them (hide + stop
## processing) instead of new()/queue_free() removes a lot of node churn on busy waves.
##
## FloatingText / DeathBurst have class_name, so they are built with their global
## constructors here. AreaRing and ImpactBurst have none (they are preloaded), so they are
## typed loosely. Every effect routes its own spawn() helper through this pool.

const SOFT_CAP := 512  ## Idle instances kept per type; any freed past this are actually released.
const AreaRing := preload("res://scripts/area_ring.gd")
const ImpactBurst := preload("res://scripts/impact_burst.gd")

var _free_text: Array[FloatingText] = []
var _free_burst: Array[DeathBurst] = []
var _free_area: Array = []  ## AreaRing has no class_name, so this stays untyped.
var _free_impact: Array = []  ## ImpactBurst is also preloaded, not globally named.

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

func acquire_area():
	var f
	if _free_area.is_empty():
		f = AreaRing.new()
		f.pool = self
		add_child(f)
	else:
		f = _free_area.pop_back()
		f.visible = true
		f.set_process(true)
	return f

func recycle_area(f) -> void:
	f.set_process(false)
	f.visible = false
	if _free_area.size() >= SOFT_CAP:
		f.queue_free()
		return
	_free_area.append(f)

func acquire_impact():
	var f
	if _free_impact.is_empty():
		f = ImpactBurst.new()
		f.pool = self
		add_child(f)
	else:
		f = _free_impact.pop_back()
		f.visible = true
		f.set_process(true)
	return f

func recycle_impact(f) -> void:
	f.set_process(false)
	f.visible = false
	if _free_impact.size() >= SOFT_CAP:
		f.queue_free()
		return
	_free_impact.append(f)
