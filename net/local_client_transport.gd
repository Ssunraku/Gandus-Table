class_name LocalClientTransport
extends Transport
## The host's own player's end of a LocalLink: its only peer is the host.

var link: LocalLink


func send_to(_peer_id: int, text: String) -> void:
	link._from_local(text)


func broadcast(text: String) -> void:
	link._from_local(text)
