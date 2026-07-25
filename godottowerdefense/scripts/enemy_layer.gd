extends Node2D
## A thin draw-only layer used by Enemy. Its _draw() forwards to a Callable the parent sets,
## so an enemy can split its visuals across separate CanvasItems that are each repainted only
## when their own contents change — while a plain Node2D `scale` handles the idle breathing
## wobble as a transform (no redraw). See enemy.gd for how the body/overlay layers are wired.
##
## No class_name on purpose: it is preloaded, which sidesteps the global-class-cache reimport
## dance for a brand-new script (see CLAUDE.md).

var draw_fn: Callable

func _draw() -> void:
	# Pass ourselves so the enemy's draw code targets THIS canvas item — draw_* calls are
	# only legal on the node whose _draw() is running, which is this layer, not the enemy.
	if draw_fn.is_valid():
		draw_fn.call(self)
