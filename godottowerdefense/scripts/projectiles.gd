extends Node2D
## The $Projectiles container, extended into a small object pool. Towers ask for a bolt with
## acquire(); a spent bolt returns itself via recycle() instead of queue_free(). Pooled
## instances stay parented here and are merely hidden + stopped, so a busy late wave no
## longer churns nodes in and out of the scene tree (the actual cost of the old
## instantiate/queue_free-per-shot pattern).

const PROJECTILE := preload("res://scenes/Projectile.tscn")
const SOFT_CAP := 512  ## Idle bolts kept for reuse; any freed past this are actually released.

var _free: Array[Projectile] = []

## A ready-to-fire projectile — reused if one is idle, else built once. The caller fills in
## start/target/payload exactly as before via Projectile.setup() plus the field assignments.
func acquire() -> Projectile:
	var p: Projectile
	if _free.is_empty():
		p = PROJECTILE.instantiate() as Projectile
		p.pool = self
		add_child(p)
	else:
		p = _free.pop_back()
		p.visible = true
		p.set_process(true)
	return p

## Returns a spent projectile to the pool (hidden + not processing) rather than freeing it.
func recycle(p: Projectile) -> void:
	p.set_process(false)
	p.visible = false
	if _free.size() >= SOFT_CAP:
		p.queue_free()
		return
	_free.append(p)
