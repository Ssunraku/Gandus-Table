class_name SoundBank
extends Node
## One simple, light sound made by code (no sound files, nothing to license): a soft,
## low "tap" when a card is laid on the table. Every other game event is silent.
## Real recorded sounds can replace this later (see docs/ASSETS.md).

const EVENTS: Array[String] = ["play"]
const MIX_RATE: int = 22050
const PEAK: float = 0.35  # quiet on purpose: a gentle tap, never a snap
const BASE_DB: float = -8.0

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


## Starts the sound. Returns false (and plays nothing) if sound is off or the event has no sound.
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


# ---------- building the sound ----------

static func _build(event: String) -> AudioStreamWAV:
	var buf: PackedFloat32Array = PackedFloat32Array()
	if event == "play":
		buf.resize(int(MIX_RATE * 0.09))
		_tap(buf, 300.0, 0.022)
	return _to_stream(buf)


## A soft wooden-ish "tock": a low sine that fades in over ~5 ms (no click) and dies away fast.
static func _tap(buf: PackedFloat32Array, hz: float, decay_s: float) -> void:
	for i in range(buf.size()):
		var t: float = float(i) / float(MIX_RATE)
		var attack: float = minf(t / 0.005, 1.0)
		var env: float = attack * exp(-t / decay_s)
		buf[i] = (sin(TAU * hz * t) + 0.25 * sin(TAU * hz * 2.0 * t)) * env


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
