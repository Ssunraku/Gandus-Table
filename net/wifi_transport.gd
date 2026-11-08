class_name WifiTransport
extends Transport
## Moves messages between phones on the same Wi-Fi using Godot's built-in ENet (reliable,
## ordered). Call poll() every frame. On a client the host is always peer 1.

const GAME_PORT: int = 24680
const MAX_CLIENTS: int = 3
## A phone that cannot reach the host gives up after this long instead of waiting forever.
const CONNECT_TIMEOUT_MS: int = 5000

var _connect_started_ms: int = 0

## "idle", "hosting", "connecting", "connected", "failed" or "closed".
var status: String = "idle"
var peer: ENetMultiplayerPeer


func start_host(port: int = GAME_PORT) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		peer = null
		status = "failed"
		return err
	_hook()
	status = "hosting"
	return OK


func connect_to(address: String, port: int = GAME_PORT) -> Error:
	close()
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address, port)
	if err != OK:
		peer = null
		status = "failed"
		return err
	_hook()
	status = "connecting"
	_connect_started_ms = Time.get_ticks_msec()
	return OK


func _hook() -> void:
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	peer.peer_connected.connect(func(id: int) -> void:
		if status == "connecting":
			status = "connected"
		peer_connected.emit(id))
	peer.peer_disconnected.connect(func(id: int) -> void:
		if status == "connected" and id == Transport.HOST_ID:
			status = "closed"
		peer_disconnected.emit(id))


## Must be called every frame.
func poll() -> void:
	if peer == null:
		return
	# ENet shuts a client down by itself when the host goes away; polling it then is an error.
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer = null
		if status == "connecting":
			status = "failed"
		elif status != "failed":
			status = "closed"
		return
	peer.poll()
	if peer == null:
		return
	if status == "connecting" and Time.get_ticks_msec() - _connect_started_ms > CONNECT_TIMEOUT_MS:
		peer.close()
		peer = null
		status = "failed"
		return
	while peer != null and peer.get_available_packet_count() > 0:
		var from: int = peer.get_packet_peer()
		var text: String = peer.get_packet().get_string_from_utf8()
		message_received.emit(from, text)


func send_to(peer_id: int, text: String) -> void:
	if peer == null:
		return
	peer.set_target_peer(peer_id)
	peer.put_packet(text.to_utf8_buffer())


func broadcast(text: String) -> void:
	if peer == null:
		return
	peer.set_target_peer(MultiplayerPeer.TARGET_PEER_BROADCAST)
	peer.put_packet(text.to_utf8_buffer())


func close() -> void:
	if peer != null:
		# Tell connected phones we are leaving (otherwise they only notice after a long timeout).
		if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED and peer.host != null:
			for p in peer.host.get_peers():
				p.peer_disconnect_later()  # (the plain disconnect throws queued messages away)
			for i in range(30):  # give ENet a moment (at most 0.3 s) to send them and finish the goodbye
				peer.host.service(10)
				if peer.host.get_peers().is_empty():
					break
		peer.close()
		peer = null
	if status != "failed":
		status = "closed" if status != "idle" else "idle"
