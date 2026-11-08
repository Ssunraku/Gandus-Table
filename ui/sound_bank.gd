class_name SoundBank
extends Node
## Placeholder sounds made by code (no sound files, nothing to license): card snaps and
## flicks, a paper-like swish and two small jingles. Real recorded sounds can replace
## these later (see docs/ASSETS.md for how outside files must be recorded).

const EVENTS: Array[String] = ["deal", "play", "trick", "turn", "bid", "win", "lose"]
const MIX_RATE: int = 22050
const PEAK: float = 0.8  # loudest sample as a share of full scale, so nothing clips
const BASE_DB: float = -6.0

var enabled: bool = true
## 0.0 (silent) to 1.0 (full). The Settings screen's slider sets this.
var volume: float = 1.0:
	set(value):
		volume = clampf(value, 0.0, 1.0)
		_apply_volume()
## How many sounds were started (handy for tests).
var played_count: int = 0

var _streams: Dictionary = {}
var _players: Dictionary = {}


func _init() -> void:
	for e in EVENTS:
		_streams[e] = _build(e)
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = _streams[e]
		p.volume_db = BASE_DB
		_players[e] = p
		add_child(p)


func stream_for(event: String) -> AudioStreamWAV:
	return _streams.get(event)


## Starts the sound. Returns false (and plays nothing) if sound is off or the event is unknown.
func play(event: String) -> bool:
	if not enabled or volume <= 0.0 or not _players.has(event):
		return false
	(_players[event] as AudioStreamPlayer).play()
	played_count += 1
	return true


func _apply_volume() -> void:
	var db: float = BASE_DB + linear_to_db(maxf(volume, 0.0001))
	for p in _players.values():
		(p as AudioStreamPlayer).volume_db = db


# ---------- building the sounds ----------

static func _build(event: String) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345 + event.hash()  # fixed seed: every game sounds the same
	var buf: PackedFloat32Array = PackedFloat32Array()
	match event:
		"play":  # a card laid on the table: a crisp snap with a soft thump
			buf.resize(int(MIX_RATE * 0.10))
			_flick(buf, rng, 0.0, 0.10, 0.016, 1.0, 0.55, 150.0)
		"deal":  # four quick card flicks
			buf.resize(int(MIX_RATE * 0.32))
			for k in range(4):
				_flick(buf, rng, 0.07 * float(k), 0.08, 0.018, 0.8 + 0.05 * float(k), 0.6, 0.0)
		"trick":  # a paper-like swish while the cards are swept away
			buf.resize(int(MIX_RATE * 0.34))
			_swish(buf, rng, 0.34)
		"turn":  # a gentle tap: it is your turn
			buf.resize(int(MIX_RATE * 0.07))
			_flick(buf, rng, 0.0, 0.07, 0.010, 0.7, 0.7, 260.0, 0.12)
		"bid":  # a softer tap
			buf.resize(int(MIX_RATE * 0.08))
			_flick(buf, rng, 0.0, 0.08, 0.012, 0.7, 0.7, 200.0, 0.15)
		"win":
			buf.resize(int(MIX_RATE * 0.34))
			_notes(buf, [523.0, 659.0, 784.0], 0.11)
		"lose":
			buf.resize(int(MIX_RATE * 0.34))
			_notes(buf, [392.0, 294.0], 0.17)
	return _to_stream(buf)


## A short burst of noise that dies away quickly (like a card snapping), plus an optional
## low thump. `brightness` 0..1: higher = more hiss.
static func _flick(buf: PackedFloat32Array, rng: RandomNumberGenerator, start_s: float, length_s: float, decay_s: float, gain: float, brightness: float, thump_hz: float, thump_gain: float = 0.45) -> void:
	var start: int = int(start_s * MIX_RATE)
	var count: int = mini(int(length_s * MIX_RATE), buf.size() - start)
	var lp: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var n: float = rng.randf() * 2.0 - 1.0
		lp += (n - lp) * 0.35
		var hiss: float = (n - lp) * brightness + lp * (1.0 - brightness) * 0.6  # mostly high-pass noise
		var env: float = exp(-t / decay_s)
		var v: float = hiss * env * gain
		if thump_hz > 0.0:
			v += sin(TAU * thump_hz * t) * exp(-t / 0.012) * thump_gain * gain
		buf[start + i] += v


## Noise that swells and fades with the brightness sweeping up, like a page turning.
static func _swish(buf: PackedFloat32Array, rng: RandomNumberGenerator, length_s: float) -> void:
	var count: int = buf.size()
	var lp: float = 0.0
	for i in range(count):
		var x: float = float(i) / float(count)
		var n: float = rng.randf() * 2.0 - 1.0
		lp += (n - lp) * lerpf(0.9, 0.25, x)  # starts hissy, ends softer
		var env: float = pow(sin(PI * x), 1.4)
		buf[i] += (n * 0.55 + lp * 0.45) * env * 0.7


## A few short sine notes with a fade-out each.
static func _notes(buf: PackedFloat32Array, freqs: Array, note_s: float) -> void:
	for k in range(freqs.size()):
		var start: int = int(float(k) * note_s * MIX_RATE)
		var count: int = mini(int(note_s * 1.3 * MIX_RATE), buf.size() - start)
		for i in range(count):
			var t: float = float(i) / float(MIX_RATE)
			var fade: float = 1.0 - float(i) / float(count)
			buf[start + i] += sin(TAU * float(freqs[k]) * t) * fade * fade * 0.6


static func _to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var loudest: float = 0.0001
	for v in buf:
		loudest = maxf(loudest, absf(v))
	var scale: float = PEAK / loudest
	var data: PackedByteArray = PackedByteArray()
	data.resize(buf.size() * 2)
	for i in range(buf.size()):
		data.encode_s16(i * 2, int(clampf(buf[i] * scale, -1.0, 1.0) * 32767.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	return s
