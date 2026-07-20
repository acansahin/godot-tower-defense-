extends Node
## "Audio" autoload: all sound effects are SYNTHESIZED in code at startup — no audio
## files ship with the game, matching its everything-drawn-in-code philosophy. Each
## effect is baked once into an AudioStreamWAV and replayed through a small pool of
## AudioStreamPlayers so overlapping shots never cut each other off.
##
## Voiced as retro CHIPTUNE / 8-bit: NES-style pulse (square) leads with duty cycles,
## rapid arpeggios for "chords", pitch slides, triangle-wave bass, and sample-and-hold
## noise for percussion/explosions. Press M to mute. Registered as the "Audio" autoload.

const SR := 22050          ## Sample rate for every baked buffer (mono, 16-bit).
const VOLUME_DB := -12.0    ## Master trim (square waves are hot, so trimmed a bit more).
const MUSIC_VOLUME_DB := -20.0  ## Background loop sits well under the SFX.
const POOL_SIZE := 12       ## Concurrent one-shot voices.

var _sfx: Dictionary = {}                 ## name -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer            ## Dedicated looping background-music voice.
var _next: int = 0
var _muted: bool = false

func _ready() -> void:
	# Keep playing while the end screen pauses the tree (victory/game-over stinger).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players.append(p)
	_build_all()

	# Continuous low-volume chiptune loop so between-wave lulls aren't silent.
	_music = AudioStreamPlayer.new()
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	_music.stream = _build_music()
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.play()

## Toggle mute (SFX + music) with the M key (no input map entry needed).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		_muted = not _muted
		_apply_mute()

# --- Public API ----------------------------------------------------------------

## Plays a baked effect by name, with optional random pitch jitter (+/- pitch_var)
## and an extra volume trim in dB.
func play(sfx_name: String, pitch_var: float = 0.0, volume_db: float = 0.0) -> void:
	if _muted:
		return
	var stream: AudioStreamWAV = _sfx.get(sfx_name)
	if stream == null:
		return
	var p := _free_player()
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = VOLUME_DB + volume_db
	p.play()

## Picks the shot sound for a tower. The four base elements key off `element`;
## lightning and the neutral dual towers (element == "") key off `id`.
func play_tower_fire(id: String, element: String) -> void:
	var key := element
	if key == "":
		match id:
			"lightning": key = "lightning"
			_: key = "shot_generic"   # steam / lava / ice
	play(key, 0.05, -3.0)

func set_muted(value: bool) -> void:
	_muted = value
	_apply_mute()

## Pause/resume the music loop to match the mute state (SFX are gated in play()).
func _apply_mute() -> void:
	if _music != null:
		_music.stream_paused = _muted

# --- Player pool ---------------------------------------------------------------

## An idle player if one exists, else the next in round-robin (steals the oldest).
func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	return p

# --- Synthesis (chiptune) ------------------------------------------------------
# _pulse = NES square/pulse lead, _arp = fast arpeggio "chord", _tri = triangle bass,
# _noise8 = sample-and-hold noise (NES percussion/explosions). Tune per-sound here.

func _build_all() -> void:
	# Tower shots — short, punchy "pew"s so a full board isn't fatiguing.
	var fire := _buf(0.10)
	_pulse(fire, 0.0, 0.10, 260.0, 150.0, 0.5, 0.5, 30.0)
	_noise8(fire, 0.0, 0.06, 0.18, 40.0, 10)
	_sfx["fire"] = _encode(fire, 0.7)

	var water := _buf(0.11)
	_pulse(water, 0.0, 0.11, 540.0, 300.0, 0.5, 0.55, 26.0)
	_sfx["water"] = _encode(water, 0.6)

	var nature := _buf(0.10)
	_pulse(nature, 0.0, 0.10, 680.0, 620.0, 0.125, 0.5, 34.0)   # thin nasal pluck
	_sfx["nature"] = _encode(nature, 0.55)

	var earth := _buf(0.14)
	_tri(earth, 0.0, 0.14, 150.0, 80.0, 0.8, 22.0)             # triangle bass thud
	_noise8(earth, 0.0, 0.05, 0.22, 40.0, 14)
	_sfx["earth"] = _encode(earth, 0.8)

	var lightning := _buf(0.12)
	_arp(lightning, 0.0, 0.12, 440.0, [0, 12, 7], 0.018, 0.25, 0.45, 20.0)   # zap arpeggio
	_noise8(lightning, 0.0, 0.08, 0.2, 26.0, 6)
	_sfx["lightning"] = _encode(lightning, 0.6)

	var shot := _buf(0.08)
	_pulse(shot, 0.0, 0.08, 480.0, 360.0, 0.25, 0.5, 30.0)
	_sfx["shot_generic"] = _encode(shot, 0.55)

	# Projectile impact — tiny NES tick (fires a lot, kept quiet).
	var hit := _buf(0.04)
	_noise8(hit, 0.0, 0.035, 0.3, 70.0, 6)
	_pulse(hit, 0.0, 0.03, 300.0, 260.0, 0.5, 0.2, 60.0)
	_sfx["hit"] = _encode(hit, 0.4)

	# Enemy deaths — downward "defeated" sweep + noise; boss = big explosion.
	var death := _buf(0.16)
	_pulse(death, 0.0, 0.16, 520.0, 120.0, 0.5, 0.55, 18.0)
	_noise8(death, 0.0, 0.10, 0.25, 22.0, 8)
	_sfx["enemy_death"] = _encode(death, 0.65)

	var boss_death := _buf(0.5)
	_tri(boss_death, 0.0, 0.45, 200.0, 45.0, 0.85, 7.0)
	_noise8(boss_death, 0.0, 0.45, 0.5, 7.0, 12)
	_sfx["boss_death"] = _encode(boss_death, 0.85)

	# Enemy reached the end — descending "aww".
	var leak := _buf(0.3)
	_pulse(leak, 0.0, 0.3, 420.0, 150.0, 0.5, 0.5, 6.0)
	_sfx["leak"] = _encode(leak, 0.55)

	# Boss appears — low ominous minor arpeggio over triangle drone.
	var boss_spawn := _buf(0.55)
	_tri(boss_spawn, 0.0, 0.5, 110.0, 80.0, 0.6, 4.0)
	_arp(boss_spawn, 0.0, 0.45, 110.0, [0, 3, 7], 0.06, 0.5, 0.35, 4.0)
	_noise8(boss_spawn, 0.0, 0.5, 0.12, 4.0, 18)
	_sfx["boss_spawn"] = _encode(boss_spawn, 0.7)

	# UI — classic chip blips.
	var build := _buf(0.09)
	_pulse(build, 0.0, 0.09, 440.0, 660.0, 0.5, 0.5, 22.0)      # quick up
	_sfx["build"] = _encode(build, 0.5)

	var upgrade := _buf(0.22)
	_arp(upgrade, 0.0, 0.20, 523.0, [0, 4, 7, 12], 0.035, 0.5, 0.5, 7.0)   # power-up
	_sfx["upgrade"] = _encode(upgrade, 0.5)

	var sell := _buf(0.2)
	_pulse(sell, 0.0, 0.06, 988.0, 988.0, 0.5, 0.5, 16.0)       # coin: two rising notes
	_pulse(sell, 0.05, 0.14, 1319.0, 1319.0, 0.5, 0.45, 10.0)
	_sfx["sell"] = _encode(sell, 0.5)

	var denied := _buf(0.12)
	_pulse(denied, 0.0, 0.12, 160.0, 120.0, 0.5, 0.5, 10.0)     # low error buzz
	_sfx["denied"] = _encode(denied, 0.55)

	# Waves — little chip fanfare / jingle.
	var wave_start := _buf(0.24)
	_arp(wave_start, 0.0, 0.22, 330.0, [0, 4, 7], 0.05, 0.5, 0.5, 6.0)
	_sfx["wave_start"] = _encode(wave_start, 0.5)

	var wave_clear := _buf(0.38)
	_pulse(wave_clear, 0.0, 0.16, 523.0, 523.0, 0.5, 0.5, 8.0)
	_pulse(wave_clear, 0.09, 0.16, 659.0, 659.0, 0.5, 0.5, 8.0)
	_pulse(wave_clear, 0.18, 0.20, 784.0, 784.0, 0.5, 0.5, 7.0)
	_sfx["wave_clear"] = _encode(wave_clear, 0.5)

	var send_early := _buf(0.09)
	_pulse(send_early, 0.0, 0.09, 500.0, 800.0, 0.5, 0.5, 18.0)
	_sfx["send_early"] = _encode(send_early, 0.45)

	# End of game — victory jingle / game-over descent.
	var victory := _buf(0.8)
	_pulse(victory, 0.0, 0.14, 523.0, 523.0, 0.5, 0.5, 8.0)     # C
	_pulse(victory, 0.13, 0.14, 659.0, 659.0, 0.5, 0.5, 8.0)    # E
	_pulse(victory, 0.26, 0.14, 784.0, 784.0, 0.5, 0.5, 8.0)    # G
	_arp(victory, 0.39, 0.40, 1046.0, [0, 4, 7], 0.03, 0.5, 0.5, 4.0)  # high C chord
	_sfx["victory"] = _encode(victory, 0.55)

	var gameover := _buf(0.75)
	_pulse(gameover, 0.0, 0.16, 392.0, 392.0, 0.5, 0.55, 6.0)   # G
	_pulse(gameover, 0.15, 0.16, 330.0, 330.0, 0.5, 0.55, 6.0)  # E
	_pulse(gameover, 0.30, 0.16, 262.0, 262.0, 0.5, 0.55, 6.0)  # C
	_pulse(gameover, 0.45, 0.28, 196.0, 196.0, 0.5, 0.6, 4.0)   # low G
	_sfx["gameover"] = _encode(gameover, 0.6)

# --- Background music ----------------------------------------------------------
# A 16-second seamless chiptune loop: triangle bass + pulse arpeggio melody over a
# vi-IV-I-V progression (Am-F-C-G), with a soft kick and hats. Second half lifts the
# melody an octave for a little variety. Kept quiet (MUSIC_VOLUME_DB) under the SFX.

func _build_music() -> AudioStreamWAV:
	var beat := 0.5            # 120 BPM
	var bar := beat * 4.0
	var m := _buf(bar * 8.0)   # 8 bars, 16 s
	# Each bar: bass root (MIDI) + the chord's three tones (MIDI) for the arp.
	var prog := [
		{"bass": 45, "tones": [69, 72, 76]},  # Am
		{"bass": 41, "tones": [65, 69, 72]},  # F
		{"bass": 48, "tones": [72, 76, 79]},  # C
		{"bass": 43, "tones": [67, 71, 74]},  # G
		{"bass": 41, "tones": [65, 69, 72]},  # F
		{"bass": 48, "tones": [72, 76, 79]},  # C
		{"bass": 43, "tones": [67, 71, 74]},  # G
		{"bass": 43, "tones": [67, 71, 74]},  # G
	]
	var bass_steps := [0, 12, 7, 12]   # walking bass within each bar
	for b in prog.size():
		var chord: Dictionary = prog[b]
		var t0 := b * bar
		var bass: int = chord["bass"]
		var tones: Array = chord["tones"]
		var oct := 12 if b >= 4 else 0   # second phrase an octave up
		for j in 4:
			var bf := _midi(bass + bass_steps[j])
			_tri(m, t0 + j * beat, 0.45, bf, bf, 0.5, 5.0)          # bass
		for j in 8:
			var tf := _midi(int(tones[j % 3]) + oct)
			_pulse(m, t0 + j * (beat * 0.5), 0.22, tf, tf, 0.5, 0.24, 12.0)  # arp melody
		_tri(m, t0, 0.12, 70.0, 55.0, 0.35, 30.0)                  # kick on beat 1
		_tri(m, t0 + 2.0 * beat, 0.12, 70.0, 55.0, 0.35, 30.0)     # kick on beat 3
		for j in 8:
			_noise8(m, t0 + j * (beat * 0.5), 0.03, 0.04, 80.0, 3) # soft hats
	return _encode_loop(m, 0.9)

## MIDI note number -> frequency (A4 = 69 = 440 Hz).
func _midi(note: int) -> float:
	return 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)

## Fresh zero-filled float buffer for `dur` seconds.
func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * SR))
	return b

## NES-style pulse/square lead: `duty` is the pulse width (0.5 = square, 0.25/0.125 =
## thinner/brighter). Linear pitch slide f0->f1, exponential decay envelope.
func _pulse(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float,
		duty: float, amp: float, decay: float) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t := float(i) / SR
		var f: float = lerp(f0, f1, t / dur)
		phase = fmod(phase + f / SR, 1.0)
		var s: float = 1.0 if phase < duty else -1.0
		buf[idx] += amp * exp(-t * decay) * s

## Fast arpeggio: cycles the pulse pitch through `semis` (semitone offsets from `base`),
## switching every `step` seconds — the classic chiptune way to imply a chord.
func _arp(buf: PackedFloat32Array, start: float, dur: float, base: float, semis: Array,
		step: float, duty: float, amp: float, decay: float) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t := float(i) / SR
		var k := int(t / step) % semis.size()
		var f: float = base * pow(2.0, float(semis[k]) / 12.0)
		phase = fmod(phase + f / SR, 1.0)
		var s: float = 1.0 if phase < duty else -1.0
		buf[idx] += amp * exp(-t * decay) * s

## Triangle-wave bass (NES third channel): softer than a square, good for low thumps.
func _tri(buf: PackedFloat32Array, start: float, dur: float, f0: float, f1: float,
		amp: float, decay: float) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var phase := 0.0
	for i in n:
		var idx := i0 + i
		if idx < 0 or idx >= buf.size():
			continue
		var t := float(i) / SR
		var f: float = lerp(f0, f1, t / dur)
		phase = fmod(phase + f / SR, 1.0)
		var s: float = 4.0 * absf(phase - 0.5) - 1.0   # /\ triangle in [-1,1]
		buf[idx] += amp * exp(-t * decay) * s

## Sample-and-hold noise (holds each random value for `hold` samples → NES-ish grit,
## bigger hold = lower/rougher). Exponential decay envelope.
func _noise8(buf: PackedFloat32Array, start: float, dur: float, amp: float,
		decay: float, hold: int) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var cur := 0.0
	var cnt := 0
	for i in n:
		var idx := i0 + i
		if idx < 0 or idx >= buf.size():
			continue
		if cnt <= 0:
			cur = randf() * 2.0 - 1.0
			cnt = maxi(1, hold)
		cnt -= 1
		var t := float(i) / SR
		buf[idx] += amp * exp(-t * decay) * cur

## Clips, de-clicks the edges, and encodes the float buffer to a 16-bit AudioStreamWAV.
func _encode(buf: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var n := buf.size()
	# Short fade in/out so buffer edges don't click.
	var fin := mini(n, int(0.002 * SR))
	var fout := mini(n, int(0.004 * SR))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var edge := 1.0
		if i < fin:
			edge = float(i) / float(fin)
		elif i > n - fout:
			edge = float(n - i) / float(fout)
		var v := clampf(buf[i] * gain * edge, -1.0, 1.0)
		var iv := int(round(v * 32767.0))
		if iv < 0:
			iv += 65536
		data[i * 2] = iv & 0xFF
		data[i * 2 + 1] = (iv >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	return w

## Encodes a buffer as a seamlessly-looping AudioStreamWAV (no edge fades, which would
## dip the volume at the loop seam — the loop is designed to end in a low-energy beat).
func _encode_loop(buf: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var n := buf.size()
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := clampf(buf[i] * gain, -1.0, 1.0)
		var iv := int(round(v * 32767.0))
		if iv < 0:
			iv += 65536
		data[i * 2] = iv & 0xFF
		data[i * 2 + 1] = (iv >> 8) & 0xFF
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	w.data = data
	return w
