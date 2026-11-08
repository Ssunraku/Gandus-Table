class_name FakeNetwork
extends RefCounted
## An in-memory "Wi-Fi" for tests: one host and any number of clients. Messages wait in
## a queue and are delivered, in order, only when pump() is called.

const HOST_ID: int = Transport.HOST_ID

var clients: Dictionary = {}  # id -> FakeTransport
var _host: FakeTransport
var _next_id: int = 2
var _queue: Array[Dictionary] = []


func host_transport() -> FakeTransport:
	if _host == null:
		_host = FakeTransport.new()
		_host.network = self
		_host.is_host = true
		_host.my_id = HOST_ID
	return _host


## `local` = the host's own player on the same phone.
func connect_client(local: bool = false) -> FakeTransport:
	var t: FakeTransport = FakeTransport.new()
	t.network = self
	t.my_id = _next_id
	_next_id += 1
	t.is_local = local
	clients[t.my_id] = t
	_queue.append({"kind": "conn", "to": host_transport(), "peer": t.my_id})
	_queue.append({"kind": "conn", "to": t, "peer": HOST_ID})
	return t


## Simulates a lost connection: both sides are told, and nothing more is delivered.
## With `graceful` (a clean close) messages already waiting are still delivered first.
func drop(client: FakeTransport, graceful: bool = false) -> void:
	if client == null or not client.connected or client.closing_started:
		return
	client.closing_started = true
	if not graceful:
		client.connected = false
		clients.erase(client.my_id)
	_queue.append({"kind": "disc", "to": host_transport(), "peer": client.my_id, "client": client})
	_queue.append({"kind": "disc", "to": client, "peer": HOST_ID, "client": client})


func _send(from: FakeTransport, peer_id: int, text: String) -> void:
	if from.is_host:
		var c: FakeTransport = clients.get(peer_id)
		if c != null and c.connected:
			_queue.append({"kind": "msg", "to": c, "peer": HOST_ID, "text": text})
	elif from.connected and peer_id == HOST_ID:
		_queue.append({"kind": "msg", "to": host_transport(), "peer": from.my_id, "text": text})


func _broadcast(from: FakeTransport, text: String) -> void:
	if from.is_host:
		for id in clients.keys():
			_send(from, id, text)
	else:
		_send(from, HOST_ID, text)


## Delivers everything waiting, including messages sent while delivering. Returns how many.
func pump() -> int:
	var n: int = 0
	while not _queue.is_empty():
		var e: Dictionary = _queue.pop_front()
		var to: FakeTransport = e["to"]
		n += 1
		match e["kind"]:
			"conn":
				to.peer_connected.emit(e["peer"])
			"disc":
				var gone: FakeTransport = e["client"]
				gone.connected = false  # (a clean close only stops delivery once its goodbye is out)
				clients.erase(gone.my_id)
				to.peer_disconnected.emit(e["peer"])
			"msg":
				# a message to or from someone who has since dropped is lost
				if to.is_host:
					if clients.has(e["peer"]):
						to.message_received.emit(e["peer"], e["text"])
				elif to.connected:
					to.message_received.emit(e["peer"], e["text"])
	return n
