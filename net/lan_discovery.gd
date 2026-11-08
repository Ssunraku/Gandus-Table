class_name LanDiscovery
extends RefCounted
## Finding games on the same Wi-Fi. A host "advertises" (answers questions); a finder
## sends the question "who is hosting?" to the whole network every ~1.5 s and keeps a
## list of the answers. Both sides must call poll() often. Anything that is not a small,
## well-formed message from this game is ignored.

const DISCOVERY_PORT: int = 24681
const MAX_PACKET: int = 512

var port: int = DISCOVERY_PORT
var query_address: String = "255.255.255.255"  # tests use 127.0.0.1
var query_interval_ms: int = 1500
var expire_ms: int = 6000
## What the finder has seen: {code, name, address, port, free_seats, exact}.
var found: Array[Dictionary] = []

var _server: PacketPeerUDP
var _info: Dictionary = {}
var _finder: PacketPeerUDP
var _wanted_code: String = ""
var _last_query_ms: int = -1000000
var _seen_ms: Dictionary = {}  # "code@address" -> time


# ---------- host side ----------

## `info`: code, name, game_port, free_seats, exact.
func advertise(info: Dictionary) -> Error:
	stop_advertising()
	_info = info.duplicate()
	_server = PacketPeerUDP.new()
	var err: Error = _server.bind(port)
	if err != OK:
		_server = null
	return err


func update_info(info: Dictionary) -> void:
	_info = info.duplicate()


func stop_advertising() -> void:
	if _server != null:
		_server.close()
		_server = null


# ---------- finder side ----------

## An empty code finds every game; a code finds only that game.
func search(code: String = "") -> Error:
	stop_searching()
	_wanted_code = code
	_finder = PacketPeerUDP.new()
	_finder.set_broadcast_enabled(true)
	var err: Error = _finder.set_dest_address(query_address, port)
	if err != OK:
		_finder = null
		return err
	_last_query_ms = -1000000
	found = []
	_seen_ms = {}
	return OK


func stop_searching() -> void:
	if _finder != null:
		_finder.close()
		_finder = null
	found = []
	_seen_ms = {}


func poll() -> void:
	if _server != null:
		_poll_server()
	if _finder != null:
		_poll_finder()


func _poll_server() -> void:
	while _server != null and _server.get_available_packet_count() > 0:
		var bytes: PackedByteArray = _server.get_packet()
		var ip: String = _server.get_packet_ip()
		var from_port: int = _server.get_packet_port()
		var m: Dictionary = _parse(bytes)
		if m.is_empty() or m.get("q") != "find":
			continue
		var wanted: String = m["code"] if m.get("code") is String else ""
		if wanted != "" and wanted != str(_info.get("code", "")):
			continue
		var reply: Dictionary = {
			"gt": 1, "r": "here",
			"code": _info.get("code", ""),
			"name": _info.get("name", ""),
			"port": _info.get("game_port", 0),
			"free": _info.get("free_seats", 0),
			"exact": _info.get("exact", 0),
		}
		_server.set_dest_address(ip, from_port)
		_server.put_packet(JSON.stringify(reply).to_utf8_buffer())


func _poll_finder() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_query_ms >= query_interval_ms:
		_last_query_ms = now
		_finder.put_packet(JSON.stringify({"gt": 1, "q": "find", "code": _wanted_code}).to_utf8_buffer())
	while _finder != null and _finder.get_available_packet_count() > 0:
		var bytes: PackedByteArray = _finder.get_packet()
		var ip: String = _finder.get_packet_ip()
		var m: Dictionary = _parse(bytes)
		if m.is_empty() or m.get("r") != "here":
			continue
		_remember(m, ip, now)
	# forget games that stopped answering
	var keep: Array[Dictionary] = []
	for g in found:
		var key: String = "%s@%s" % [g["code"], g["address"]]
		if now - int(_seen_ms.get(key, 0)) <= expire_ms:
			keep.append(g)
		else:
			_seen_ms.erase(key)
	found = keep


func _remember(m: Dictionary, ip: String, now: int) -> void:
	var code: String = m["code"] if m.get("code") is String else ""
	if not RoomCode.is_valid(code):
		return
	if _wanted_code != "" and code != _wanted_code:
		return
	var game_port: int = int(m["port"]) if (m.get("port") is float or m.get("port") is int) else 0
	if game_port < 1 or game_port > 65535:
		return
	var game_name: String = PlayerProfile.clean(m["name"]) if m.get("name") is String else "Game"
	var free: int = clampi(int(m["free"]), 0, 4) if (m.get("free") is float or m.get("free") is int) else 0
	var exact: int = clampi(int(m["exact"]), 0, 3) if (m.get("exact") is float or m.get("exact") is int) else 0
	var entry: Dictionary = {"code": code, "name": game_name, "address": ip, "port": game_port, "free_seats": free, "exact": exact}
	var key: String = "%s@%s" % [code, ip]
	_seen_ms[key] = now
	for i in range(found.size()):
		if found[i]["code"] == code and found[i]["address"] == ip:
			found[i] = entry
			return
	found.append(entry)


## {} unless the packet is small, valid JSON from this game (version 1).
static func _parse(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_PACKET or bytes.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	var d: Variant = json.data
	if not (d is Dictionary):
		return {}
	var m: Dictionary = d
	if not ((m.get("gt") is float or m.get("gt") is int) and int(m["gt"]) == 1):
		return {}
	return m


## Private IPv4 addresses of this phone (192.168.x.x, 10.x.x.x, 172.16-31.x.x).
static func local_addresses() -> Array[String]:
	var out: Array[String] = []
	for a in IP.get_local_addresses():
		var parts: PackedStringArray = a.split(".")
		if parts.size() != 4:
			continue
		var first: int = int(parts[0])
		var second: int = int(parts[1])
		var private_range: bool = first == 10 or (first == 192 and second == 168) or (first == 172 and second >= 16 and second <= 31)
		if private_range and not out.has(a):
			out.append(a)
	return out
