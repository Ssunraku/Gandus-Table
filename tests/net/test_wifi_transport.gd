extends GutTest
## Real ENet connections on this computer (127.0.0.1, test port 24700).

const PORT: int = 24700

var host: WifiTransport
var clients: Array[WifiTransport] = []
var host_got: Array = []     # [peer, text]
var host_events: Array = []  # ["c"/"d", peer]


func before_each() -> void:
	host_got = []
	host_events = []
	clients = []
	host = WifiTransport.new()
	host.message_received.connect(func(p: int, t: String) -> void: host_got.append([p, t]))
	host.peer_connected.connect(func(p: int) -> void: host_events.append(["c", p]))
	host.peer_disconnected.connect(func(p: int) -> void: host_events.append(["d", p]))


func after_each() -> void:
	for c in clients:
		c.close()
	host.close()


func _poll_all() -> void:
	host.poll()
	for c in clients:
		c.poll()


func _wait_until(cond: Callable, seconds: float = 3.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		_poll_all()
		if cond.call():
			return true
		OS.delay_msec(5)
	return cond.call()


## A client that is connected, and that the host has also registered.
func _connected_client() -> WifiTransport:
	var c: WifiTransport = WifiTransport.new()
	clients.append(c)
	var wanted: int = clients.size()
	assert_eq(c.connect_to("127.0.0.1", PORT), OK)
	assert_true(_wait_until(func() -> bool: return c.status == "connected"), "client connects")
	assert_true(_wait_until(func() -> bool: return host_events.filter(func(e: Array) -> bool: return e[0] == "c").size() >= wanted), "host registers it")
	return c


func test_client_connects_and_messages_flow_both_ways() -> void:
	assert_eq(host.start_host(PORT), OK)
	assert_eq(host.status, "hosting")
	var c: WifiTransport = _connected_client()
	var client_got: Array = []
	c.message_received.connect(func(p: int, t: String) -> void: client_got.append([p, t]))
	assert_true(_wait_until(func() -> bool: return host_events.size() >= 1))
	var client_id: int = host_events[0][1]
	c.send_to(Transport.HOST_ID, "hello host")
	assert_true(_wait_until(func() -> bool: return host_got.size() == 1))
	assert_eq(host_got[0], [client_id, "hello host"])
	host.send_to(client_id, "hello client")
	assert_true(_wait_until(func() -> bool: return client_got.size() == 1))
	assert_eq(client_got[0], [Transport.HOST_ID, "hello client"])


func test_broadcast_reaches_every_client() -> void:
	host.start_host(PORT)
	var a: WifiTransport = _connected_client()
	var b: WifiTransport = _connected_client()
	var got: Array = []
	a.message_received.connect(func(_p: int, t: String) -> void: got.append(t))
	b.message_received.connect(func(_p: int, t: String) -> void: got.append(t))
	host.broadcast("all")
	assert_true(_wait_until(func() -> bool: return got.size() == 2))


func test_messages_keep_their_order() -> void:
	host.start_host(PORT)
	var c: WifiTransport = _connected_client()
	for i in range(20):
		c.send_to(Transport.HOST_ID, str(i))
	assert_true(_wait_until(func() -> bool: return host_got.size() == 20))
	for i in range(20):
		assert_eq(host_got[i][1], str(i))


func test_a_client_closing_is_reported_to_the_host() -> void:
	host.start_host(PORT)
	var c: WifiTransport = _connected_client()
	assert_true(_wait_until(func() -> bool: return host_events.size() >= 1))
	c.close()
	assert_true(_wait_until(func() -> bool: return host_events.any(func(e: Array) -> bool: return e[0] == "d")), "host sees the disconnect")


func test_a_goodbye_sent_just_before_closing_still_arrives() -> void:
	host.start_host(PORT)
	var c: WifiTransport = _connected_client()
	c.send_to(Transport.HOST_ID, "bye")
	c.close()  # right away: the message must not be thrown away
	# (the host cannot answer inside close() here, because this test is one thread; the
	#  message itself is what matters)
	assert_true(_wait_until(func() -> bool: return host_got.size() >= 1), "the goodbye message arrived")
	if host_got.size() >= 1:
		assert_eq(host_got[0][1], "bye")


func test_a_message_from_the_host_just_before_it_closes_still_arrives() -> void:
	host.start_host(PORT)
	var c: WifiTransport = _connected_client()
	var got: Array = []
	c.message_received.connect(func(_p: int, t: String) -> void: got.append(t))
	host.broadcast("game over")
	host.close()
	assert_true(_wait_until(func() -> bool: return got.size() >= 1, 4.0), "the last message arrives before the connection ends")


func test_host_close_is_reported_to_the_client() -> void:
	host.start_host(PORT)
	var c: WifiTransport = _connected_client()
	var gone: Array = []
	c.peer_disconnected.connect(func(p: int) -> void: gone.append(p))
	host.close()
	assert_true(_wait_until(func() -> bool: return gone.size() >= 1, 6.0), "client notices the host left")
	if not gone.is_empty():
		assert_eq(gone[0], Transport.HOST_ID)


func test_starting_a_second_host_on_a_busy_port_fails_with_an_error_code() -> void:
	assert_eq(host.start_host(PORT), OK)
	var second: WifiTransport = WifiTransport.new()
	assert_ne(second.start_host(PORT), OK)
	assert_eq(second.status, "failed")
	assert_engine_error("Couldn't create an ENet host")  # expected: Godot logs it when a port is busy


func test_connecting_to_nothing_ends_as_failed_not_stuck() -> void:
	var c: WifiTransport = WifiTransport.new()
	clients.append(c)
	c.connect_to("127.0.0.1", 24799)
	assert_true(_wait_until(func() -> bool: return c.status == "failed", 8.0), "gives up instead of waiting forever")


func test_large_message_of_10000_characters_arrives_intact() -> void:
	host.start_host(PORT)
	var c: WifiTransport = _connected_client()
	var big: String = "x".repeat(10000)
	c.send_to(Transport.HOST_ID, big)
	assert_true(_wait_until(func() -> bool: return host_got.size() == 1))
	assert_eq(host_got[0][1], big)


func test_a_fourth_client_is_refused_when_three_are_connected() -> void:
	host.start_host(PORT)
	for i in range(3):
		_connected_client()
	var extra: WifiTransport = WifiTransport.new()
	clients.append(extra)
	extra.connect_to("127.0.0.1", PORT)
	_wait_until(func() -> bool: return extra.status == "failed", 6.0)
	assert_ne(extra.status, "connected")
