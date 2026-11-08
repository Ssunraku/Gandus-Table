class_name FakeTransport
extends Transport
## A pretend connection that lives inside FakeNetwork. Nothing is delivered until the
## network is pumped.

var network: FakeNetwork
var is_host: bool = false
var my_id: int = 0       # a client's own id (the host is always 1)
var is_local: bool = false
var connected: bool = true


func send_to(peer_id: int, text: String) -> void:
	network._send(self, peer_id, text)


func broadcast(text: String) -> void:
	network._broadcast(self, text)


func is_local_peer(peer_id: int) -> bool:
	if not is_host:
		return false
	var c: FakeTransport = network.clients.get(peer_id)
	return c != null and c.is_local


func close() -> void:
	if is_host:
		for c in network.clients.values().duplicate():
			network.drop(c)
	else:
		network.drop(self)
