class_name TestPeer
extends RefCounted
## Test helper: a raw client that records every decoded message it receives.

var transport: FakeTransport
var net: FakeNetwork
var inbox: Array[Dictionary] = []
var raw: Array[String] = []  # the exact text received
var seq: int = 0


func _init(t: FakeTransport, n: FakeNetwork) -> void:
	transport = t
	net = n
	t.message_received.connect(func(_p: int, text: String) -> void:
		raw.append(text)
		var m: Dictionary = Protocol.decode(text)
		if not m.is_empty():
			inbox.append(m))


## Sends a message and delivers everything.
func send(type: String, fields: Dictionary = {}) -> void:
	seq += 1
	transport.send_to(1, Protocol.encode(Protocol.make(type, fields, seq)))
	net.pump()


func send_raw(text: String) -> void:
	transport.send_to(1, text)
	net.pump()


func of_type(type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in inbox:
		if m["type"] == type:
			out.append(m)
	return out


func last(type: String) -> Dictionary:
	var l: Array[Dictionary] = of_type(type)
	return l[l.size() - 1] if not l.is_empty() else {}


func clear() -> void:
	inbox.clear()
	raw.clear()
