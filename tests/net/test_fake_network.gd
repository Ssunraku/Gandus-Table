extends GutTest

var net: FakeNetwork
var host: FakeTransport
var got: Array = []  # [who, peer, text]


func before_each() -> void:
	net = FakeNetwork.new()
	host = net.host_transport()
	got = []
	host.message_received.connect(func(p: int, t: String) -> void: got.append(["host", p, t]))


func _client(who: String, local: bool = false) -> FakeTransport:
	var c: FakeTransport = net.connect_client(local)
	c.message_received.connect(func(p: int, t: String) -> void: got.append([who, p, t]))
	return c


func test_client_message_reaches_host_with_the_client_peer_id() -> void:
	var a: FakeTransport = _client("a")
	net.pump()
	a.send_to(1, "hi")
	net.pump()
	assert_eq(got, [["host", a.my_id, "hi"]])


func test_host_send_to_reaches_only_that_client() -> void:
	var a: FakeTransport = _client("a")
	var b: FakeTransport = _client("b")
	net.pump()
	host.send_to(b.my_id, "x")
	net.pump()
	assert_eq(got, [["b", 1, "x"]])
	assert_not_null(a)


func test_broadcast_reaches_every_client() -> void:
	_client("a")
	_client("b")
	net.pump()
	host.broadcast("all")
	net.pump()
	assert_eq(got.size(), 2)


func test_nothing_is_delivered_until_pump() -> void:
	var a: FakeTransport = _client("a")
	net.pump()
	a.send_to(1, "hi")
	assert_eq(got.size(), 0)
	net.pump()
	assert_eq(got.size(), 1)


func test_messages_arrive_in_the_order_sent() -> void:
	var a: FakeTransport = _client("a")
	net.pump()
	for i in range(5):
		a.send_to(1, str(i))
	net.pump()
	var order: Array = []
	for g in got:
		order.append(g[2])
	assert_eq(order, ["0", "1", "2", "3", "4"])


func test_connection_events_fire_on_both_sides() -> void:
	var seen: Array = []
	host.peer_connected.connect(func(p: int) -> void: seen.append(["host", p]))
	var a: FakeTransport = net.connect_client()
	a.peer_connected.connect(func(p: int) -> void: seen.append(["client", p]))
	net.pump()
	assert_has(seen, ["host", a.my_id])
	assert_has(seen, ["client", 1])


func test_drop_tells_both_sides_and_stops_delivery() -> void:
	var a: FakeTransport = _client("a")
	net.pump()
	var seen: Array = []
	host.peer_disconnected.connect(func(p: int) -> void: seen.append(["host", p]))
	a.peer_disconnected.connect(func(p: int) -> void: seen.append(["client", p]))
	host.send_to(a.my_id, "lost?")
	net.drop(a)
	net.pump()
	assert_has(seen, ["host", a.my_id])
	assert_has(seen, ["client", 1])
	assert_eq(got.size(), 0, "a message to a dropped client is lost")
	a.send_to(1, "ghost")
	net.pump()
	assert_eq(got.size(), 0)


func test_is_local_peer_true_only_for_the_local_client() -> void:
	var me: FakeTransport = _client("me", true)
	var other: FakeTransport = _client("o")
	assert_true(host.is_local_peer(me.my_id))
	assert_false(host.is_local_peer(other.my_id))
	assert_false(host.is_local_peer(999))


func test_pump_handles_messages_sent_while_delivering() -> void:
	var a: FakeTransport = _client("a")
	net.pump()
	host.message_received.connect(func(p: int, t: String) -> void:
		if t == "ping":
			host.send_to(p, "pong"))
	a.send_to(1, "ping")
	net.pump()
	var texts: Array = []
	for g in got:
		texts.append(g[2])
	assert_has(texts, "pong")
