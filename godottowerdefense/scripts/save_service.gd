extends Node
## "Save" autoload: the only thing in the project that touches persistent storage.
##
## Holds one JSON document split into named sections ("meta", "settings"), so a new system
## that needs persistence adds a section instead of a file. Callers never see the path, the
## format or the version — they read and write a Dictionary.
##
## THREE THINGS THIS GETS RIGHT ON PURPOSE, because retrofitting any of them after players
## have saves is painful:
##
##  * **Versioned.** Every document carries SAVE_VERSION and passes through _migrate() on
##    load, so a future format change has somewhere to go other than "wipe everyone".
##  * **Atomic.** Writes go to a temp file, the previous save is rotated to .bak, and only
##    then does the temp become the real save. A crash or a killed app mid-write can cost
##    the newest write, never the save itself.
##  * **Never fatal.** A missing, truncated, or garbage file loads as defaults rather than
##    throwing. Losing progress is bad; refusing to start the game is worse.

## 2: the Element TD port moved every number onto the original map's scale — gold costs
## went 40/45/70 -> a flat 50 with a 24444-gold top tier, and the wave hit-point curve
## went quadratic -> 75 * 1.16^n. A `best_wave` earned under the old curve does not mean
## the same thing, and Essence banked against it buys far more than it should.
const SAVE_VERSION := 2
const PATH := "user://save.json"
const PATH_TMP := "user://save.json.tmp"
const PATH_BAK := "user://save.bak.json"

## True if the last load fell back to defaults (missing or unreadable file). Callers can use
## it to tell "brand new player" from "returning player", which the offline reward needs.
var is_fresh: bool = true

var _doc: Dictionary = {}

func _ready() -> void:
	_load()

## The named section, or an empty Dictionary if absent. The returned Dictionary is the live
## one — mutate it and call flush(), or pass a new one to put_section().
func get_section(name: String) -> Dictionary:
	if not _doc.has(name):
		_doc[name] = {}
	return _doc[name]

func put_section(name: String, data: Dictionary) -> void:
	_doc[name] = data

## Writes the document to disk. Called eagerly whenever meta state changes rather than on a
## timer or at exit: a mobile app is killed without warning and the web build can be closed
## mid-frame, so "save later" frequently means "never". The document is a few hundred bytes,
## so the cost of writing it often is not worth optimising away.
func flush() -> void:
	_doc["version"] = SAVE_VERSION
	var json := JSON.stringify(_doc)
	var f := FileAccess.open(PATH_TMP, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot open %s (%d)" % [PATH_TMP, FileAccess.get_open_error()])
		return
	f.store_string(json)
	f.close()  # must close before renaming: the file is still open on Windows otherwise
	var dir := DirAccess.open("user://")
	if dir == null:
		push_warning("Save: cannot open user:// to rotate the save")
		return
	# Rotate rather than overwrite. rename() will not replace an existing file on every
	# platform, so the old save is moved aside first — and doubles as the .bak that _load()
	# falls back to.
	if dir.file_exists(PATH.get_file()):
		if dir.file_exists(PATH_BAK.get_file()):
			dir.remove(PATH_BAK.get_file())
		dir.rename(PATH.get_file(), PATH_BAK.get_file())
	dir.rename(PATH_TMP.get_file(), PATH.get_file())

## Wipes the save. Used by the debug harness; there is no in-game button for it.
func clear() -> void:
	_doc = {"version": SAVE_VERSION}
	is_fresh = true
	flush()

func _load() -> void:
	var doc := _read(PATH)
	if doc.is_empty():
		doc = _read(PATH_BAK)  # the previous good save, left behind by the last flush
		if not doc.is_empty():
			push_warning("Save: primary save unreadable, recovered from backup")
	if doc.is_empty():
		_doc = {"version": SAVE_VERSION}
		is_fresh = true
		return
	is_fresh = false
	_doc = _migrate(doc)

## Reads and parses one file, returning {} for anything that is not a usable document.
## Deliberately tolerant: every failure mode here ends in "start fresh", never in a crash.
func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)  # untyped: returns null on malformed JSON
	if parsed == null or not (parsed is Dictionary):
		push_warning("Save: %s is not valid JSON, ignoring it" % path)
		return {}
	return parsed

## Brings an older document up to SAVE_VERSION. Nothing to do yet — version 1 is the first
## format — but the seam exists so the first real migration is an `if`, not a redesign.
func _migrate(doc: Dictionary) -> Dictionary:
	var v := int(doc.get("version", 0))
	if v > SAVE_VERSION:
		# A save from a NEWER build. Keep it rather than "migrating" it backwards and
		# destroying fields this build does not know about.
		push_warning("Save: document version %d is newer than %d; leaving it alone"
				% [v, SAVE_VERSION])
		return doc
	if v < 2:
		# The port rescaled the whole game (see SAVE_VERSION). Rather than guess at a
		# conversion factor between two unrelated curves, retire the progression numbers
		# and keep what still means something: the player's settings, and the fact that
		# they are not a new player. Workshop levels go with the Essence that bought them,
		# so nobody is left holding upgrades they could not now afford.
		# Key names must match Meta._persist(): section "meta", levels under "levels".
		var meta: Dictionary = doc.get("meta", {})
		meta["essence"] = 0
		meta["best_wave"] = 0
		meta["levels"] = {}
		doc["meta"] = meta
	doc["version"] = SAVE_VERSION
	return doc
