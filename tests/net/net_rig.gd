class_name NetRig
extends RefCounted
## Test helper: a fake network with a SpadesHost and any number of raw test peers.

var net: FakeNetwork = FakeNetwork.new()
var host: SpadesHost
var peers: Array[TestPeer] = []


func _init(settings: SpadesSettings = null, seed_value: int = 5) -> void:
	var s: SpadesSettings = settings if settings != null else SpadesSettings.new()
	s.blind_nil_enabled = s.blind_nil_enabled  # (left as given)
	host = SpadesHost.new(net.host_transport(), s, seed_value)


func peer(local: bool = false) -> TestPeer:
	var p: TestPeer = TestPeer.new(net.connect_client(local), net)
	peers.append(p)
	net.pump()
	return p


## A peer that has joined (and sits in `seat` if seat >= 0).
func joined(player_name: String, seat: int = -1, as_host: bool = false) -> TestPeer:
	var p: TestPeer = peer(as_host)
	p.send("join_request", {"name": player_name, "as_host": as_host})
	if seat >= 0:
		p.send("seat_request", {"seat": seat})
	return p


func pump() -> void:
	net.pump()


## Runs host.step() until it waits for a person, pumping after each step. Returns steps done.
func run_bots(limit: int = 500) -> int:
	var n: int = 0
	while n < limit and host.step():
		n += 1
		net.pump()
	return n
