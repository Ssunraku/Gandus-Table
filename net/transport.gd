class_name Transport
extends RefCounted
## The one contract every way of moving messages (fake, Wi-Fi, later Bluetooth) follows.
## Messages are plain text. On a client transport the only peer is the host (id 1);
## on a host transport the peers are the clients (ids 2, 3, ...).

## On a client, the host is always this peer.
const HOST_ID: int = 1

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal message_received(peer_id: int, text: String)


func send_to(_peer_id: int, _text: String) -> void:
	push_error("Transport.send_to is not implemented")


func broadcast(_text: String) -> void:
	push_error("Transport.broadcast is not implemented")


## True for the player who is on the host's own phone (connected without any network).
func is_local_peer(_peer_id: int) -> bool:
	return false


func close() -> void:
	pass
