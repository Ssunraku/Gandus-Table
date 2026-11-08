class_name SoundBank
extends Node
## Placeholder sounds: a few short beeps made by code (no sound files, nothing to license).
## Real recorded sounds can replace these later.

const EVENTS: Array[String] = ["deal", "play", "trick", "turn", "bid", "win", "lose"]
const MIX_RATE: int = 22050

## Pitch (Hz) and length (seconds) of each beep.
const TONES: Dictionary = {
	"deal": [440.0, 0.12],
	"play": [330.0, 0.08],
	"trick": [523.0, 0.15],
	"turn": [660.0, 0.10],
	"bid": [392.0, 0.08],
	"win": [784.0, 0.30],
	"lose": [196.0, 0.30],
}

var enabled: bool = true
## How many sounds were started (handy for tests).
var played_count: int = 0

var _streams: Dictionary = {}
var _players: Dictionary = {}


func _init() -> void:
	for e in EVENTS:
		_streams[e] = _make_tone(TONES[e][0], TONES[e][1])
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = _streams[e]
		p.volume_db = -8.0
		_players[e] = p
		add_child(p)


func stream_for(event: String) -> AudioStreamWAV:
	return _streams.get(event)


## Starts the sound. Returns false (and plays nothing) if sound is off or the event is unknown.
func play(event: String) -> bool:
	if not enabled or not _players.has(event):
		return false
	(_players[event] as AudioStreamPlayer).play()
	played_count += 1
	return true


static func _make_tone(freq: float, seconds: float) -> AudioStreamWAV:
	var count: int = int(float(MIX_RATE) * seconds)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t: float = float(i) / float(MIX_RATE)
		var fade: float = 1.0 - float(i) / float(count)  # fades out so there is no click
		var sample: float = sin(TAU * freq * t) * fade * 0.6
		data.encode_s16(i * 2, int(sample * 32767.0))
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = data
	return s
