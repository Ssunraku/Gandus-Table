class_name PlayerProfile
extends RefCounted
## The player's saved details (just the name for now), kept in a small file on the phone.

const MAX_LENGTH: int = 12
const DEFAULT_NAME: String = "Player"
const DEFAULT_PATH: String = "user://profile.cfg"

var player_name: String = ""


func has_name() -> bool:
	return player_name != ""


func set_name(raw: String) -> void:
	player_name = clean(raw)


## Makes a typed name safe to show: no line breaks or other control characters,
## no spaces at the ends, at most 12 characters, and "Player" if nothing is left.
static func clean(raw: String) -> String:
	var out: String = ""
	for i in range(raw.length()):
		var code: int = raw.unicode_at(i)
		if code >= 32 and code != 127:
			out += raw[i]
	out = out.strip_edges()
	if out.length() > MAX_LENGTH:
		out = out.substr(0, MAX_LENGTH).strip_edges()
	return out if out != "" else DEFAULT_NAME


## The host uses this so two players never share a name: "Sam" becomes "Sam 2", "Sam 3"...
## (not case sensitive; the result still fits in 12 characters).
static func unique(wanted: String, taken: Array[String]) -> String:
	var used: Array[String] = []
	for t in taken:
		used.append(t.to_lower())
	if not used.has(wanted.to_lower()):
		return wanted
	var n: int = 2
	while true:
		var suffix: String = " %d" % n
		var candidate: String = wanted.substr(0, MAX_LENGTH - suffix.length()).strip_edges() + suffix
		if not used.has(candidate.to_lower()):
			return candidate
		n += 1
	return wanted  # never reached


## Returns false (and keeps the name empty) when there is no saved file.
func load_from(path: String) -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path) != OK:
		return false
	player_name = clean(str(cfg.get_value("player", "name", "")))
	if str(cfg.get_value("player", "name", "")).strip_edges() == "":
		player_name = ""
	return has_name()


func save_to(path: String) -> bool:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	return cfg.save(path) == OK
