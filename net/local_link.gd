class_name LocalLink
extends Transport
## The transport the host uses. It joins two things: the host's own player (who lives on
## the same phone, so needs no network at all) and an optional network transport for
## everybody else. Local messages wait in a queue and are delivered by poll().

const LOCAL_PEER: int = 0

var inner: Transport
var _client: LocalClientTransport
var _queue: Array[Dictionary] = []


func _init(network: Transport = null) -> void:
	inner = network
	if inner != null:
		inner.peer_connected.connect(func(p: int) -> void: peer_connected.emit(p))
		inner.peer_disconnected.connect(func(p: int) -> void: peer_disconnected.emit(p))
		inner.message_received.connect(func(p: int, t: String) -> void: message_received.emit(p, t))


## The transport for the host's own SpadesClient. Its only peer is the host.
func local_client() -> Transport:
	if _client == null:
		_client = LocalClientTransport.new()
		_client.link = self
		_queue.append({"kind": "conn_host"})
		_queue.append({"kind": "conn_client"})
	return _client


func _from_local(text: String) -> void:
	_queue.append({"kind": "to_host", "text": text})


func send_to(peer_id: int, text: String) -> void:
	if peer_id == LOCAL_PEER:
		_queue.append({"kind": "to_client", "text": text})
	elif inner != null:
		inner.send_to(peer_id, text)


func broadcast(text: String) -> void:
	if _client != null:
		_queue.append({"kind": "to_client", "text": text})
	if inner != null:
		inner.broadcast(text)


func is_local_peer(peer_id: int) -> bool:
	return peer_id == LOCAL_PEER


func close() -> void:
	if inner != null:
		inner.close()


## Delivers every waiting local message in order (including ones sent while delivering),
## then lets the network transport do its own polling.
func poll() -> void:
	while not _queue.is_empty():
		var e: Dictionary = _queue.pop_front()
		match e["kind"]:
			"conn_host":
				peer_connected.emit(LOCAL_PEER)
			"conn_client":
				_client.peer_connected.emit(Transport.HOST_ID)
			"to_host":
				message_received.emit(LOCAL_PEER, e["text"])
			"to_client":
				_client.message_received.emit(Transport.HOST_ID, e["text"])
	if inner != null and inner.has_method("poll"):
		inner.call("poll")
